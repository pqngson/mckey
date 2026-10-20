// UKEngine.swift — Stage 3: verbatim port of ukengine.cpp (Telex + VNI).
// Output is computed directly as Unicode (UTF-8 charset path), so the
// StdVnChar/charset library is unnecessary; getSeqSteps counts symbols.
//
// Defaults match UniKey: freeMarking=1, modernStyle=0, spellCheck=1,
// autoNonVnRestore=0.

import Foundation

private let MAX_UK_ENGINE = 128

enum VnWordForm: Int { case vnw_nonVn, vnw_empty, vnw_c, vnw_v, vnw_cv, vnw_vc, vnw_cvc }

struct UkOptions {
    var freeMarking = true
    var modernStyle = false
    var spellCheckEnabled = true
    var autoNonVnRestore = false
    var macroEnabled = false
    var disableWordStartShortcuts = false
}

private struct WordInfo {
    var form: VnWordForm = .vnw_empty
    var c1Offset = -1, vOffset = -1, c2Offset = -1
    // vseq and cseq share storage (a C++ union in ukengine.h). Reading a
    // consonant entry's vseq therefore yields an in-range value, matching the
    // original; default 0 avoids an out-of-range index before any seq is set.
    var seqRaw = 0
    var vseq: VowelSeq {
        get { VowelSeq(rawValue: seqRaw) ?? .vs_nil }
        set { seqRaw = newValue.rawValue }
    }
    var cseq: ConSeq {
        get { ConSeq(rawValue: seqRaw) ?? .cs_nil }
        set { seqRaw = newValue.rawValue }
    }
    var caps = false
    var tone = 0
    var vnSym: VnLexiName = .vnl_nonVnChar
    var keyCode: UInt = 0
}

private struct KeyBufEntry {
    var ev = UkKeyEvent()
    var converted = false
}

struct UkResult {
    var ret = 0
    var backspaces = 0
    var output = ""
    var outType: UkOutputType = .charOutput
}

// MARK: - Validity (ukengine.cpp)

private func isValidCV(_ c: ConSeq, _ v: VowelSeq) -> Bool {
    if c == .cs_nil || v == .vs_nil { return true }
    let vInfo = VSeqList[v.rawValue]
    if (c == .cs_gi && vInfo.v[0] == .vnl_i) || (c == .cs_qu && vInfo.v[0] == .vnl_u) {
        return false
    }
    if c == .cs_k {
        let kVseq: Set<VowelSeq> = [.vs_e, .vs_i, .vs_y, .vs_er, .vs_eo, .vs_eu,
                                    .vs_eru, .vs_ia, .vs_ie, .vs_ier, .vs_ieu, .vs_ieru]
        return kVseq.contains(v)
    }
    return true
}

private func isValidVC(_ v: VowelSeq, _ c: ConSeq) -> Bool {
    if v == .vs_nil || c == .cs_nil { return true }
    if VSeqList[v.rawValue].conSuffix == 0 { return false }
    if !CSeqList[c.rawValue].suffix { return false }
    return validVC(v, c)
}

private func isValidCVC(_ c1: ConSeq, _ v: VowelSeq, _ c2: ConSeq) -> Bool {
    if v == .vs_nil { return (c1 == .cs_nil || c2 != .cs_nil) }
    if c1 == .cs_nil { return isValidVC(v, c2) }
    if c2 == .cs_nil { return isValidCV(c1, v) }
    let okCV = isValidCV(c1, v)
    let okVC = isValidVC(v, c2)
    if okCV && okVC { return true }
    if !okVC {
        if c1 == .cs_qu && v == .vs_y && (c2 == .cs_n || c2 == .cs_nh) { return true }
        if c1 == .cs_gi && (v == .vs_e || v == .vs_er) && (c2 == .cs_n || c2 == .cs_ng) { return true }
    }
    return false
}

private func isAlpha(_ kc: UInt) -> Bool {
    (kc >= 0x41 && kc <= 0x5A) || (kc >= 0x61 && kc <= 0x7A)
}

// MARK: - Engine

final class UkEngine {
    var options = UkOptions()
    var vietKey = true
    let input = UkInputProcessor()
    var keyCheck: () -> (shift: Bool, caps: Bool) = { (false, false) }

    private var buffer = [WordInfo](repeating: WordInfo(), count: MAX_UK_ENGINE)
    private var keyStrokes = [KeyBufEntry](repeating: KeyBufEntry(), count: MAX_UK_ENGINE)
    private var current = -1
    private var keyCurrent = -1
    private var changePos = 0
    private var backs = 0
    private var singleMode = false
    private var toEscape = false
    private var reverted = false
    private var keyRestored = false
    private var keyRestoring = false
    private var outType: UkOutputType = .charOutput

    private var out = ""             // accumulated output (replaces m_pOutBuf)
    private var outputWritten = false
    private var telexWUsedAsMapChar = false   // static in processTelexW

    init() { input.setIM(.telex) }

    func setIM(_ im: UkInputMethod) { input.setIM(im); reset() }

    func reset() {
        current = -1; keyCurrent = -1; singleMode = false; toEscape = false
    }

    func atWordBeginning() -> Bool { current < 0 || buffer[current].form == .vnw_empty }

    // MARK: getTonePosition

    private func getTonePosition(_ vs: VowelSeq, _ terminated: Bool) -> Int {
        if vs.rawValue < 0 || vs.rawValue >= VSeqList.count { return 0 }   // garbage guard
        let info = VSeqList[vs.rawValue]
        if info.len == 1 { return 0 }
        if info.roofPos != -1 { return info.roofPos }
        if info.hookPos != -1 {
            if vs == .vs_uhoh || vs == .vs_uhohi || vs == .vs_uhohu { return 1 }
            return info.hookPos
        }
        if info.len == 3 { return 1 }
        if options.modernStyle && (vs == .vs_oa || vs == .vs_oe || vs == .vs_uy) { return 1 }
        return terminated ? 0 : 1
    }

    // MARK: getSeqSteps / markChange (UTF-8: one step per symbol)

    private func getSeqSteps(_ first: Int, _ last: Int) -> Int {
        last < first ? 0 : (last - first + 1)
    }

    private func markChange(_ pos: Int) {
        if pos < changePos {
            backs += getSeqSteps(pos, changePos - 1)
            changePos = pos
        }
    }

    // MARK: processRoof

    private func processRoof(_ ev: inout UkKeyEvent) -> Int {
        if !vietKey || current < 0 || buffer[current].vOffset < 0 { return processAppend(&ev) }

        var target: VnLexiName = .vnl_nonVnChar
        switch UkKeyEvName(rawValue: ev.evType)! {
        case .vneRoof_a: target = .vnl_ar
        case .vneRoof_e: target = .vnl_er
        case .vneRoof_o: target = .vnl_or
        default: target = .vnl_nonVnChar
        }

        let vEnd = current - buffer[current].vOffset
        let vs = buffer[vEnd].vseq
        let vStart = vEnd - (VSeqList[vs.rawValue].len - 1)
        let curTonePos = vStart + getTonePosition(vs, vEnd == current)
        let tone = buffer[curTonePos].tone

        var newVs: VowelSeq
        var doubleChangeUO = false
        if vs == .vs_uho || vs == .vs_uhoh || vs == .vs_uhoi || vs == .vs_uhohi {
            newVs = lookupVSeq(.vnl_u, .vnl_or, VSeqList[vs.rawValue].v[2])
            doubleChangeUO = true
        } else {
            newVs = VSeqList[vs.rawValue].withRoof
        }

        var roofRemoved = false
        var changePosLocal: Int
        var pInfo: VowelSeqInfo

        if newVs == .vs_nil {
            if VSeqList[vs.rawValue].roofPos == -1 { return processAppend(&ev) }
            let curCh = buffer[vStart + VSeqList[vs.rawValue].roofPos].vnSym
            if target != .vnl_nonVnChar && curCh != target { return processAppend(&ev) }
            let newCh: VnLexiName = (curCh == .vnl_ar) ? .vnl_a : ((curCh == .vnl_er) ? .vnl_e : .vnl_o)
            changePosLocal = vStart + VSeqList[vs.rawValue].roofPos
            if !options.freeMarking && changePosLocal != current { return processAppend(&ev) }
            markChange(changePosLocal)
            buffer[changePosLocal].vnSym = newCh
            if VSeqList[vs.rawValue].len == 3 {
                newVs = lookupVSeq(buffer[vStart].vnSym, buffer[vStart + 1].vnSym, buffer[vStart + 2].vnSym)
            } else if VSeqList[vs.rawValue].len == 2 {
                newVs = lookupVSeq(buffer[vStart].vnSym, buffer[vStart + 1].vnSym)
            } else {
                newVs = lookupVSeq(buffer[vStart].vnSym)
            }
            pInfo = VSeqList[newVs.rawValue]
            roofRemoved = true
        } else {
            pInfo = VSeqList[newVs.rawValue]
            if target != .vnl_nonVnChar && pInfo.v[pInfo.roofPos] != target { return processAppend(&ev) }
            var c1: ConSeq = .cs_nil, c2: ConSeq = .cs_nil
            if buffer[current].c1Offset != -1 { c1 = buffer[current - buffer[current].c1Offset].cseq }
            if buffer[current].c2Offset != -1 { c2 = buffer[current - buffer[current].c2Offset].cseq }
            if !isValidCVC(c1, newVs, c2) { return processAppend(&ev) }
            changePosLocal = doubleChangeUO ? vStart : (vStart + pInfo.roofPos)
            if !options.freeMarking && changePosLocal != current { return processAppend(&ev) }
            markChange(changePosLocal)
            if doubleChangeUO {
                buffer[vStart].vnSym = .vnl_u
                buffer[vStart + 1].vnSym = .vnl_or
            } else {
                buffer[changePosLocal].vnSym = pInfo.v[pInfo.roofPos]
            }
        }

        for i in 0..<pInfo.len { buffer[vStart + i].vseq = pInfo.sub[i] }

        let newTonePos = vStart + getTonePosition(newVs, vEnd == current)
        if curTonePos != newTonePos && tone != 0 {
            markChange(newTonePos); buffer[newTonePos].tone = tone
            markChange(curTonePos); buffer[curTonePos].tone = 0
        }
        if roofRemoved {
            singleMode = false
            _ = processAppend(&ev)
            reverted = true
        }
        return 1
    }

    // MARK: processHookWithUO

    private func processHookWithUO(_ ev: inout UkKeyEvent) -> Int {
        var newVs: VowelSeq = .vs_nil
        var hookRemoved = false
        let removeWithUndo = true

        if !options.freeMarking && buffer[current].vOffset != 0 { return processAppend(&ev) }

        let vEnd = current - buffer[current].vOffset
        let vs = buffer[vEnd].vseq
        let vStart = vEnd - (VSeqList[vs.rawValue].len - 1)
        let v = VSeqList[vs.rawValue].v
        let curTonePos = vStart + getTonePosition(vs, vEnd == current)
        let tone = buffer[curTonePos].tone

        switch UkKeyEvName(rawValue: ev.evType)! {
        case .vneHook_u:
            if v[0] == .vnl_u {
                newVs = VSeqList[vs.rawValue].withHook
                markChange(vStart); buffer[vStart].vnSym = .vnl_uh
            } else {
                newVs = lookupVSeq(.vnl_u, .vnl_o, v[2])
                markChange(vStart)
                buffer[vStart].vnSym = .vnl_u
                buffer[vStart + 1].vnSym = .vnl_o
                hookRemoved = true
            }
        case .vneHook_o:
            if v[1] == .vnl_o || v[1] == .vnl_or {
                if vEnd == current && VSeqList[vs.rawValue].len == 2 &&
                    buffer[current].form == .vnw_cv && buffer[current - 2].cseq == .cs_th {
                    newVs = VSeqList[vs.rawValue].withHook
                    markChange(vStart + 1); buffer[vStart + 1].vnSym = .vnl_oh
                } else {
                    newVs = lookupVSeq(.vnl_uh, .vnl_oh, v[2])
                    if v[0] == .vnl_u {
                        markChange(vStart)
                        buffer[vStart].vnSym = .vnl_uh
                        buffer[vStart + 1].vnSym = .vnl_oh
                    } else {
                        markChange(vStart + 1); buffer[vStart + 1].vnSym = .vnl_oh
                    }
                }
            } else {
                newVs = lookupVSeq(.vnl_u, .vnl_o, v[2])
                if v[0] == .vnl_uh {
                    markChange(vStart)
                    buffer[vStart].vnSym = .vnl_u
                    buffer[vStart + 1].vnSym = .vnl_o
                } else {
                    markChange(vStart + 1); buffer[vStart + 1].vnSym = .vnl_o
                }
                hookRemoved = true
            }
        default:   // vneHookAll, vneHook_uo
            if v[0] == .vnl_u {
                if v[1] == .vnl_o || v[1] == .vnl_or {
                    if (vs == .vs_uo || vs == .vs_uor) && vEnd == current &&
                        buffer[current].form == .vnw_cv && buffer[current - 2].cseq == .cs_th {
                        newVs = .vs_uoh
                        markChange(vStart + 1); buffer[vStart + 1].vnSym = .vnl_oh
                    } else {
                        newVs = VSeqList[vs.rawValue].withHook
                        markChange(vStart); buffer[vStart].vnSym = .vnl_uh
                        newVs = VSeqList[newVs.rawValue].withHook
                        buffer[vStart + 1].vnSym = .vnl_oh
                    }
                } else {
                    newVs = VSeqList[vs.rawValue].withHook
                    markChange(vStart); buffer[vStart].vnSym = .vnl_uh
                }
            } else {
                if v[1] == .vnl_o {
                    newVs = VSeqList[vs.rawValue].withHook
                    markChange(vStart + 1); buffer[vStart + 1].vnSym = .vnl_oh
                } else {
                    newVs = lookupVSeq(.vnl_u, .vnl_o, v[2])
                    markChange(vStart)
                    buffer[vStart].vnSym = .vnl_u
                    buffer[vStart + 1].vnSym = .vnl_o
                    hookRemoved = true
                }
            }
        }

        let p = VSeqList[newVs.rawValue]
        for i in 0..<p.len { buffer[vStart + i].vseq = p.sub[i] }

        let newTonePos = vStart + getTonePosition(newVs, vEnd == current)
        if curTonePos != newTonePos && tone != 0 {
            markChange(newTonePos); buffer[newTonePos].tone = tone
            markChange(curTonePos); buffer[curTonePos].tone = 0
        }
        if hookRemoved && removeWithUndo {
            singleMode = false
            _ = processAppend(&ev)
            reverted = true
        }
        return 1
    }

    // MARK: processHook

    private func processHook(_ ev: inout UkKeyEvent) -> Int {
        if !vietKey || current < 0 || buffer[current].vOffset < 0 { return processAppend(&ev) }

        let vEnd = current - buffer[current].vOffset
        let vs = buffer[vEnd].vseq
        let v = VSeqList[vs.rawValue].v
        let evt = UkKeyEvName(rawValue: ev.evType)!

        if VSeqList[vs.rawValue].len > 1 && evt != .vneBowl &&
            (v[0] == .vnl_u || v[0] == .vnl_uh) &&
            (v[1] == .vnl_o || v[1] == .vnl_oh || v[1] == .vnl_or) {
            return processHookWithUO(&ev)
        }

        let vStart = vEnd - (VSeqList[vs.rawValue].len - 1)
        let curTonePos = vStart + getTonePosition(vs, vEnd == current)
        let tone = buffer[curTonePos].tone

        var newVs = VSeqList[vs.rawValue].withHook
        var hookRemoved = false
        var pInfo: VowelSeqInfo
        var changePosLocal: Int

        if newVs == .vs_nil {
            if VSeqList[vs.rawValue].hookPos == -1 { return processAppend(&ev) }
            let curCh = buffer[vStart + VSeqList[vs.rawValue].hookPos].vnSym
            let newCh: VnLexiName = (curCh == .vnl_ab) ? .vnl_a : ((curCh == .vnl_uh) ? .vnl_u : .vnl_o)
            changePosLocal = vStart + VSeqList[vs.rawValue].hookPos
            if !options.freeMarking && changePosLocal != current { return processAppend(&ev) }
            switch evt {
            case .vneHook_u: if curCh != .vnl_uh { return processAppend(&ev) }
            case .vneHook_o: if curCh != .vnl_oh { return processAppend(&ev) }
            case .vneBowl:   if curCh != .vnl_ab { return processAppend(&ev) }
            default:         if evt == .vneHook_uo && curCh == .vnl_ab { return processAppend(&ev) }
            }
            markChange(changePosLocal)
            buffer[changePosLocal].vnSym = newCh
            if VSeqList[vs.rawValue].len == 3 {
                newVs = lookupVSeq(buffer[vStart].vnSym, buffer[vStart + 1].vnSym, buffer[vStart + 2].vnSym)
            } else if VSeqList[vs.rawValue].len == 2 {
                newVs = lookupVSeq(buffer[vStart].vnSym, buffer[vStart + 1].vnSym)
            } else {
                newVs = lookupVSeq(buffer[vStart].vnSym)
            }
            pInfo = VSeqList[newVs.rawValue]
            hookRemoved = true
        } else {
            pInfo = VSeqList[newVs.rawValue]
            switch evt {
            case .vneHook_u: if pInfo.v[pInfo.hookPos] != .vnl_uh { return processAppend(&ev) }
            case .vneHook_o: if pInfo.v[pInfo.hookPos] != .vnl_oh { return processAppend(&ev) }
            case .vneBowl:   if pInfo.v[pInfo.hookPos] != .vnl_ab { return processAppend(&ev) }
            default:         if evt == .vneHook_uo && pInfo.v[pInfo.hookPos] == .vnl_ab { return processAppend(&ev) }
            }
            var c1: ConSeq = .cs_nil, c2: ConSeq = .cs_nil
            if buffer[current].c1Offset != -1 { c1 = buffer[current - buffer[current].c1Offset].cseq }
            if buffer[current].c2Offset != -1 { c2 = buffer[current - buffer[current].c2Offset].cseq }
            if !isValidCVC(c1, newVs, c2) { return processAppend(&ev) }
            changePosLocal = vStart + pInfo.hookPos
            if !options.freeMarking && changePosLocal != current { return processAppend(&ev) }
            markChange(changePosLocal)
            buffer[changePosLocal].vnSym = pInfo.v[pInfo.hookPos]
        }

        for i in 0..<pInfo.len { buffer[vStart + i].vseq = pInfo.sub[i] }

        let newTonePos = vStart + getTonePosition(newVs, vEnd == current)
        if curTonePos != newTonePos && tone != 0 {
            markChange(newTonePos); buffer[newTonePos].tone = tone
            markChange(curTonePos); buffer[curTonePos].tone = 0
        }
        if hookRemoved {
            singleMode = false
            _ = processAppend(&ev)
            reverted = true
        }
        return 1
    }

    // MARK: processTone

    private func processTone(_ ev: inout UkKeyEvent) -> Int {
        if current < 0 || !vietKey { return processAppend(&ev) }

        if buffer[current].form == .vnw_c &&
            (buffer[current].cseq == .cs_gi || buffer[current].cseq == .cs_gin) {
            let p = (buffer[current].cseq == .cs_gi) ? current : current - 1
            if buffer[p].tone == 0 && ev.tone == 0 { return processAppend(&ev) }
            markChange(p)
            if buffer[p].tone == ev.tone {
                buffer[p].tone = 0
                singleMode = false
                _ = processAppend(&ev)
                reverted = true
                return 1
            }
            buffer[p].tone = ev.tone
            return 1
        }

        if buffer[current].vOffset < 0 { return processAppend(&ev) }

        let vEnd = current - buffer[current].vOffset
        let vs = buffer[vEnd].vseq
        let info = VSeqList[vs.rawValue]
        if options.spellCheckEnabled && !options.freeMarking && info.complete == 0 {
            return processAppend(&ev)
        }

        if buffer[current].form == .vnw_vc || buffer[current].form == .vnw_cvc {
            let cs = buffer[current].cseq
            if (cs == .cs_c || cs == .cs_ch || cs == .cs_p || cs == .cs_t) &&
                (ev.tone == 2 || ev.tone == 3 || ev.tone == 4) {
                return processAppend(&ev)
            }
        }

        let toneOffset = getTonePosition(vs, vEnd == current)
        let tonePos = vEnd - (info.len - 1) + toneOffset
        if buffer[tonePos].tone == 0 && ev.tone == 0 { return processAppend(&ev) }

        if buffer[tonePos].tone == ev.tone {
            markChange(tonePos); buffer[tonePos].tone = 0
            singleMode = false
            _ = processAppend(&ev)
            reverted = true
            return 1
        }
        markChange(tonePos); buffer[tonePos].tone = ev.tone
        return 1
    }

    // MARK: processDd

    private func processDd(_ ev: inout UkKeyEvent) -> Int {
        if !vietKey || current < 0 { return processAppend(&ev) }

        if buffer[current].form == .vnw_nonVn && buffer[current].vnSym == .vnl_d &&
            (buffer[current - 1].vnSym == .vnl_nonVnChar || !isVnVowel(buffer[current - 1].vnSym)) {
            singleMode = true
            let pos = current
            markChange(pos)
            buffer[pos].cseq = .cs_dd
            buffer[pos].vnSym = .vnl_dd
            buffer[pos].form = .vnw_c
            buffer[pos].c1Offset = 0
            buffer[pos].c2Offset = -1
            buffer[pos].vOffset = -1
            return 1
        }

        if buffer[current].c1Offset < 0 { return processAppend(&ev) }
        let pos = current - buffer[current].c1Offset
        if !options.freeMarking && pos != current { return processAppend(&ev) }

        if buffer[pos].cseq == .cs_d {
            markChange(pos); buffer[pos].cseq = .cs_dd; buffer[pos].vnSym = .vnl_dd
            return 1
        }
        if buffer[pos].cseq == .cs_dd {
            markChange(pos); buffer[pos].cseq = .cs_d; buffer[pos].vnSym = .vnl_d
            singleMode = false
            _ = processAppend(&ev)
            reverted = true
            return 1
        }
        return processAppend(&ev)
    }

    // MARK: processMapChar

    private func processMapChar(_ ev: inout UkKeyEvent) -> Int {
        let (_, capsLockOn) = keyCheck()
        if capsLockOn { ev.vnSym = changeCase(ev.vnSym) }

        var ret = processAppend(&ev)
        if !vietKey { return ret }

        if current >= 0 && buffer[current].form != .vnw_empty && buffer[current].form != .vnw_nonVn {
            return 1
        }
        if current < 0 { return 0 }

        current -= 1
        var undo = false
        let form = buffer[current].form
        if form != .vnw_empty && form != .vnw_nonVn {
            var prevSym = buffer[current].vnSym
            if buffer[current].caps { prevSym = VnLexiName(rawValue: prevSym.rawValue - 1)! }
            if prevSym == ev.vnSym {
                if form != .vnw_c {
                    let vEnd = current - buffer[current].vOffset
                    let vs = buffer[vEnd].vseq
                    let vStart = vEnd - VSeqList[vs.rawValue].len + 1
                    let curTonePos = vStart + getTonePosition(vs, vEnd == current)
                    let tone = buffer[curTonePos].tone
                    markChange(current)
                    current -= 1
                    if tone != 0 && current >= 0 &&
                        (buffer[current].form == .vnw_v || buffer[current].form == .vnw_cv) {
                        let newVs = buffer[current].vseq
                        let newTonePos = vStart + getTonePosition(newVs, true)
                        if newTonePos != curTonePos {
                            markChange(newTonePos); buffer[newTonePos].tone = tone
                            markChange(curTonePos); buffer[curTonePos].tone = 0
                        }
                    }
                } else {
                    markChange(current)
                    current -= 1
                }
                undo = true
            }
        }

        ev.evType = UkKeyEvName.vneNormal.rawValue
        ev.chType = input.getCharType(ev.keyCode)
        ev.vnSym = input.vnLexiFor(ev.keyCode)
        ret = processAppend(&ev)
        if undo {
            singleMode = false
            reverted = true
            return 1
        }
        return ret
    }

    // MARK: processTelexW

    private func processTelexW(_ ev: inout UkKeyEvent) -> Int {
        if !vietKey { return processAppend(&ev) }
        let (_, capsLockOn) = keyCheck()

        if telexWUsedAsMapChar {
            ev.evType = UkKeyEvName.vneMapChar.rawValue
            ev.vnSym = (ev.keyCode >= 0x41 && ev.keyCode <= 0x5A) ? .vnl_Uh : .vnl_uh
            if capsLockOn { ev.vnSym = changeCase(ev.vnSym) }
            ev.chType = .ukcVn
            let ret = processMapChar(&ev)
            if ret == 0 {
                if current >= 0 { current -= 1 }
                telexWUsedAsMapChar = false
                ev.evType = UkKeyEvName.vneHookAll.rawValue
                return processHook(&ev)
            }
            return ret
        }

        ev.evType = UkKeyEvName.vneHookAll.rawValue
        telexWUsedAsMapChar = false
        let ret = processHook(&ev)
        if ret == 0 {
            if current >= 0 { current -= 1 }
            ev.evType = UkKeyEvName.vneMapChar.rawValue
            ev.vnSym = (ev.keyCode >= 0x41 && ev.keyCode <= 0x5A) ? .vnl_Uh : .vnl_uh
            if capsLockOn { ev.vnSym = changeCase(ev.vnSym) }
            ev.chType = .ukcVn
            telexWUsedAsMapChar = true
            return processMapChar(&ev)
        }
        return ret
    }

    // MARK: processEscChar / pass / processNoSpellCheck

    private func processEscChar(_ ev: inout UkKeyEvent) -> Int {
        if vietKey && current >= 0 &&
            buffer[current].form != .vnw_empty && buffer[current].form != .vnw_nonVn {
            toEscape = true
        }
        return processAppend(&ev)
    }

    func pass(_ keyCode: UInt) {
        var ev = UkKeyEvent()
        input.keyCodeToEvent(keyCode, &ev)
        _ = processAppend(&ev)
    }

    private func processNoSpellCheck(_ ev: inout UkKeyEvent) -> Int {
        if isVnVowel(buffer[current].vnSym) {
            buffer[current].form = .vnw_v
            buffer[current].vOffset = 0
            buffer[current].vseq = lookupVSeq(buffer[current].vnSym)
            buffer[current].c1Offset = -1; buffer[current].c2Offset = -1
        } else {
            buffer[current].form = .vnw_c
            buffer[current].c1Offset = 0; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
            buffer[current].cseq = lookupCSeq(buffer[current].vnSym)
        }
        if ev.evType == UkKeyEvName.vneNormal.rawValue && isAlpha(buffer[current].keyCode) {
            return 0
        }
        markChange(current)
        return 1
    }

    // MARK: processAppend

    private func processAppend(_ ev: inout UkKeyEvent) -> Int {
        switch ev.chType {
        case .ukcReset:
            reset()
            return 0
        case .ukcWordBreak:
            singleMode = false
            return processWordEnd(&ev)
        case .ukcNonVn:
            current += 1
            buffer[current].form = (ev.chType == .ukcWordBreak) ? .vnw_empty : .vnw_nonVn
            buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
            buffer[current].keyCode = ev.keyCode
            buffer[current].vnSym = vnToLower(ev.vnSym)
            buffer[current].tone = 0
            buffer[current].caps = (buffer[current].vnSym != ev.vnSym)
            return 0   // UTF-8 charset: pass through
        case .ukcVn:
            if isVnVowel(ev.vnSym) {
                let v = stdVnNoTone(vnToLower(ev.vnSym))
                if current >= 0 && buffer[current].form == .vnw_c &&
                    ((buffer[current].cseq == .cs_q && v == .vnl_u) ||
                     (buffer[current].cseq == .cs_g && v == .vnl_i)) {
                    return appendConsonnant(&ev)
                }
                return appendVowel(&ev)
            }
            return appendConsonnant(&ev)
        }
    }

    // MARK: appendVowel

    private func appendVowel(_ ev: inout UkKeyEvent) -> Int {
        current += 1
        let lowerSym = vnToLower(ev.vnSym)
        let canSym = stdVnNoTone(lowerSym)

        buffer[current].vnSym = canSym
        buffer[current].caps = (lowerSym != ev.vnSym)
        buffer[current].tone = (lowerSym.rawValue - canSym.rawValue) / 2
        buffer[current].keyCode = ev.keyCode

        if current == 0 || !vietKey {
            buffer[current].form = .vnw_v
            buffer[current].c1Offset = -1; buffer[current].c2Offset = -1
            buffer[current].vOffset = 0
            buffer[current].vseq = lookupVSeq(canSym)
            if !vietKey || isAlpha(buffer[current].keyCode) { return 0 }
            markChange(current); return 1
        }

        let prevIdx = current - 1
        var newVs: VowelSeq = .vs_nil

        switch buffer[prevIdx].form {
        case .vnw_empty:
            buffer[current].form = .vnw_v
            buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = 0
            buffer[current].vseq = lookupVSeq(canSym)

        case .vnw_nonVn, .vnw_cvc, .vnw_vc:
            buffer[current].form = .vnw_nonVn
            buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1

        case .vnw_v, .vnw_cv:
            let vs = buffer[prevIdx].vseq
            let prevTonePos = prevIdx - (VSeqList[vs.rawValue].len - 1) + getTonePosition(vs, true)
            var tone = buffer[prevTonePos].tone

            if lowerSym != canSym && tone != 0 {
                newVs = .vs_nil
            } else {
                if VSeqList[vs.rawValue].len == 3 { newVs = .vs_nil }
                else if VSeqList[vs.rawValue].len == 2 {
                    newVs = lookupVSeq(VSeqList[vs.rawValue].v[0], VSeqList[vs.rawValue].v[1], canSym)
                } else {
                    newVs = lookupVSeq(VSeqList[vs.rawValue].v[0], canSym)
                }
            }

            if newVs != .vs_nil && buffer[prevIdx].form == .vnw_cv {
                let cs = buffer[prevIdx - buffer[prevIdx].c1Offset].cseq
                if !isValidCV(cs, newVs) { newVs = .vs_nil }
            }

            if newVs == .vs_nil {
                buffer[current].form = .vnw_nonVn
                buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
                break
            }

            buffer[current].form = buffer[prevIdx].form
            buffer[current].c1Offset = (buffer[prevIdx].form == .vnw_cv) ? buffer[prevIdx].c1Offset + 1 : -1
            buffer[current].c2Offset = -1
            buffer[current].vOffset = 0
            buffer[current].vseq = newVs
            buffer[current].tone = 0

            let newTone = (lowerSym.rawValue - canSym.rawValue) / 2
            if tone == 0 {
                if newTone != 0 {
                    tone = newTone
                    let tonePos = getTonePosition(newVs, true) + (prevIdx - VSeqList[vs.rawValue].len + 1)
                    markChange(tonePos); buffer[tonePos].tone = tone
                    return 1
                }
            } else {
                let newTonePos = getTonePosition(newVs, true) + (prevIdx - VSeqList[vs.rawValue].len + 1)
                if newTonePos != prevTonePos {
                    markChange(prevTonePos); buffer[prevTonePos].tone = 0
                    markChange(newTonePos)
                    if newTone != 0 { tone = newTone }
                    buffer[newTonePos].tone = tone
                    return 1
                }
                if newTone != 0 && newTone != tone {
                    tone = newTone
                    markChange(prevTonePos); buffer[prevTonePos].tone = tone
                    return 1
                }
            }

        case .vnw_c:
            newVs = lookupVSeq(canSym)
            let cs = buffer[prevIdx].cseq
            if !isValidCV(cs, newVs) {
                buffer[current].form = .vnw_nonVn
                buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
                break
            }
            buffer[current].form = .vnw_cv
            buffer[current].c1Offset = 1; buffer[current].c2Offset = -1; buffer[current].vOffset = 0
            buffer[current].vseq = newVs
            if cs == .cs_gi && buffer[prevIdx].tone != 0 {
                if buffer[current].tone == 0 { buffer[current].tone = buffer[prevIdx].tone }
                markChange(prevIdx); buffer[prevIdx].tone = 0
                return 1
            }
        }

        if isAlpha(buffer[current].keyCode) { return 0 }
        markChange(current)
        return 1
    }

    // MARK: appendConsonnant

    private func appendConsonnant(_ ev: inout UkKeyEvent) -> Int {
        var complexEvent = false
        current += 1
        let lowerSym = vnToLower(ev.vnSym)

        buffer[current].vnSym = lowerSym
        buffer[current].caps = (lowerSym != ev.vnSym)
        buffer[current].keyCode = ev.keyCode
        buffer[current].tone = 0

        if current == 0 || !vietKey {
            buffer[current].form = .vnw_c
            buffer[current].c1Offset = 0; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
            buffer[current].cseq = lookupCSeq(lowerSym)
            return 0   // UTF-8 charset: pass through
        }

        let prevIdx = current - 1

        switch buffer[prevIdx].form {
        case .vnw_nonVn:
            buffer[current].form = .vnw_nonVn
            buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
            return 0
        case .vnw_empty:
            buffer[current].form = .vnw_c
            buffer[current].c1Offset = 0; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
            buffer[current].cseq = lookupCSeq(lowerSym)
            return 0
        case .vnw_v, .vnw_cv:
            let vs = buffer[prevIdx].vseq
            var newVs = vs
            if vs == .vs_uoh || vs == .vs_uho { newVs = .vs_uhoh }
            var c1: ConSeq = .cs_nil
            if buffer[prevIdx].c1Offset != -1 { c1 = buffer[prevIdx - buffer[prevIdx].c1Offset].cseq }
            let newCs = lookupCSeq(lowerSym)
            let isValid = isValidCVC(c1, newVs, newCs)

            if isValid {
                if vs == .vs_uho {
                    markChange(prevIdx)
                    buffer[prevIdx].vnSym = .vnl_oh
                    buffer[prevIdx].vseq = .vs_uhoh
                    complexEvent = true
                } else if vs == .vs_uoh {
                    markChange(current - 2)
                    buffer[current - 2].vnSym = .vnl_uh
                    buffer[current - 2].vseq = .vs_uh
                    buffer[prevIdx].vseq = .vs_uhoh
                    complexEvent = true
                }
                if buffer[prevIdx].form == .vnw_v {
                    buffer[current].form = .vnw_vc
                    buffer[current].c1Offset = -1; buffer[current].c2Offset = 0; buffer[current].vOffset = 1
                } else {
                    buffer[current].form = .vnw_cvc
                    buffer[current].c1Offset = buffer[prevIdx].c1Offset + 1
                    buffer[current].c2Offset = 0; buffer[current].vOffset = 1
                }
                buffer[current].cseq = newCs

                let oldIdx = prevIdx - (VSeqList[vs.rawValue].len - 1) + getTonePosition(vs, true)
                if buffer[oldIdx].tone != 0 {
                    let newIdx = prevIdx - (VSeqList[newVs.rawValue].len - 1) + getTonePosition(newVs, false)
                    if newIdx != oldIdx {
                        markChange(newIdx); buffer[newIdx].tone = buffer[oldIdx].tone
                        markChange(oldIdx); buffer[oldIdx].tone = 0
                        return 1
                    }
                }
            } else {
                buffer[current].form = .vnw_nonVn
                buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
            }

            if complexEvent { return 1 }
            return 0
        case .vnw_c, .vnw_vc, .vnw_cvc:
            let cs = buffer[prevIdx].cseq
            var newCs: ConSeq
            if cs == .cs_nil { newCs = .cs_nil }            // prev isn't a known consonant (e.g. 'z')
            else if CSeqList[cs.rawValue].len == 3 { newCs = .cs_nil }
            else if CSeqList[cs.rawValue].len == 2 {
                newCs = lookupCSeq(CSeqList[cs.rawValue].c[0], CSeqList[cs.rawValue].c[1], lowerSym)
            } else {
                newCs = lookupCSeq(CSeqList[cs.rawValue].c[0], lowerSym)
            }

            if newCs != .cs_nil && (buffer[prevIdx].form == .vnw_vc || buffer[prevIdx].form == .vnw_cvc) {
                var c1: ConSeq = .cs_nil
                if buffer[prevIdx].c1Offset != -1 { c1 = buffer[prevIdx - buffer[prevIdx].c1Offset].cseq }
                let vIdx = prevIdx - buffer[prevIdx].vOffset
                let vs = buffer[vIdx].vseq
                if !isValidCVC(c1, vs, newCs) { newCs = .cs_nil }
            }

            if newCs == .cs_nil {
                buffer[current].form = .vnw_nonVn
                buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
            } else {
                if buffer[prevIdx].form == .vnw_c {
                    buffer[current].form = .vnw_c
                    buffer[current].c1Offset = 0; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
                } else if buffer[prevIdx].form == .vnw_vc {
                    buffer[current].form = .vnw_vc
                    buffer[current].c1Offset = -1; buffer[current].c2Offset = 0
                    buffer[current].vOffset = buffer[prevIdx].vOffset + 1
                } else {
                    buffer[current].form = .vnw_cvc
                    buffer[current].c1Offset = buffer[prevIdx].c1Offset + 1
                    buffer[current].c2Offset = 0
                    buffer[current].vOffset = buffer[prevIdx].vOffset + 1
                }
                buffer[current].cseq = newCs
            }
            return 0
        }
    }

    // MARK: processWordEnd

    private func processWordEnd(_ ev: inout UkKeyEvent) -> Int {
        if !options.spellCheckEnabled || singleMode || current < 0 || keyRestoring {
            current += 1
            buffer[current].form = .vnw_empty
            buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
            buffer[current].keyCode = ev.keyCode
            buffer[current].vnSym = vnToLower(ev.vnSym)
            buffer[current].caps = (buffer[current].vnSym != ev.vnSym)
            return 0
        }

        if options.autoNonVnRestore && lastWordIsNonVn() {
            if restoreKeyStrokes() { keyRestored = true; outputWritten = true }
        }

        current += 1
        buffer[current].form = .vnw_empty
        buffer[current].c1Offset = -1; buffer[current].c2Offset = -1; buffer[current].vOffset = -1
        buffer[current].keyCode = ev.keyCode
        buffer[current].vnSym = vnToLower(ev.vnSym)
        buffer[current].caps = (buffer[current].vnSym != ev.vnSym)

        if keyRestored {
            out.append(Character(UnicodeScalar(UInt32(ev.keyCode)) ?? " "))
            return 1
        }
        return 0
    }

    private func lastWordIsNonVn() -> Bool {
        if current < 0 { return false }
        switch buffer[current].form {
        case .vnw_nonVn: return true
        case .vnw_empty, .vnw_c: return false
        case .vnw_v, .vnw_cv:
            return VSeqList[buffer[current].vseq.rawValue].complete == 0
        case .vnw_vc, .vnw_cvc:
            let vIndex = current - buffer[current].vOffset
            let vs = buffer[vIndex].vseq
            if VSeqList[vs.rawValue].complete == 0 { return true }
            let cs = buffer[current].cseq
            var c1: ConSeq = .cs_nil
            if buffer[current].c1Offset != -1 { c1 = buffer[current - buffer[current].c1Offset].cseq }
            if !isValidCVC(c1, vs, cs) { return true }
            let tonePos = (vIndex - VSeqList[vs.rawValue].len + 1) + getTonePosition(vs, false)
            let tone = buffer[tonePos].tone
            if (cs == .cs_c || cs == .cs_ch || cs == .cs_p || cs == .cs_t) &&
                (tone == 2 || tone == 3 || tone == 4) { return true }
            return false
        }
    }

    private func lastWordHasVnMark() -> Bool {
        var i = current
        while i >= 0 && buffer[i].form != .vnw_empty {
            let sym = buffer[i].vnSym
            if sym != .vnl_nonVnChar {
                if isVnVowel(sym) && buffer[i].tone != 0 { return true }
                if sym != stdVnRootChar(sym) { return true }
            }
            i -= 1
        }
        return false
    }

    // MARK: restoreKeyStrokes

    @discardableResult
    private func restoreKeyStrokes() -> Bool {
        outType = .keyOutput
        if !lastWordHasVnMark() { return false }

        backs = 0
        changePos = current + 1

        var keyStart = keyCurrent
        var converted = false
        while keyStart >= 0 && keyStrokes[keyStart].ev.chType != .ukcWordBreak {
            if keyStrokes[keyStart].converted { converted = true }
            keyStart -= 1
        }
        keyStart += 1
        if !converted { return false }

        while current >= 0 && buffer[current].form != .vnw_empty { current -= 1 }
        markChange(current + 1)

        keyRestoring = true
        out = ""
        var i = keyStart
        while i <= keyCurrent {
            out.append(Character(UnicodeScalar(UInt32(keyStrokes[i].ev.keyCode)) ?? " "))
            var ev = UkKeyEvent()
            input.keyCodeToSymbol(keyStrokes[i].ev.keyCode, &ev)
            keyStrokes[i].converted = false
            _ = processAppend(&ev)
            i += 1
        }
        keyRestoring = false
        return true
    }

    // MARK: writeOutput

    private func writeOutput() {
        out = ""
        guard current >= changePos else { return }
        for i in changePos...current {
            if buffer[i].vnSym != .vnl_nonVnChar {
                out += renderSymbol(buffer[i].vnSym, tone: buffer[i].tone, caps: buffer[i].caps)
            } else if let scalar = UnicodeScalar(UInt32(buffer[i].keyCode)) {
                out.append(Character(scalar))
            }
        }
    }

    // MARK: prepareBuffer

    private func prepareBuffer() {
        if current >= 0 && current + 10 >= MAX_UK_ENGINE {
            var rid = current / 2
            while buffer[rid].form != .vnw_empty && rid < current { rid += 1 }
            if rid == current {
                current = -1
            } else {
                rid += 1
                for k in 0...(current - rid) { buffer[k] = buffer[rid + k] }
                current -= rid
            }
        }
        if keyCurrent > 0 && keyCurrent + 1 >= MAX_UK_ENGINE {
            let rid = keyCurrent / 2
            for k in 0...(keyCurrent - rid) { keyStrokes[k] = keyStrokes[rid + k] }
            keyCurrent -= rid
        }
    }

    // MARK: process (main entry)

    func process(_ keyCode: UInt) -> UkResult {
        var ev = UkKeyEvent()
        prepareBuffer()
        backs = 0
        changePos = current + 1
        out = ""
        outputWritten = false
        reverted = false
        keyRestored = false
        keyRestoring = false
        outType = .charOutput

        input.keyCodeToEvent(keyCode, &ev)

        var ret: Int
        if !toEscape {
            // Treat word-start shortcuts (w, [ ] { }) as literal characters if disabled.
            if options.disableWordStartShortcuts && vietKey && atWordBeginning() &&
                (ev.evType == UkKeyEvName.vne_telex_w.rawValue || ev.evType == UkKeyEvName.vneMapChar.rawValue) {
                input.keyCodeToSymbol(keyCode, &ev)
                telexWUsedAsMapChar = false
            }
            ret = dispatch(ev.evType, &ev)
        } else {
            toEscape = false
            if current < 0 || ev.evType == UkKeyEvName.vneNormal.rawValue ||
                ev.evType == UkKeyEvName.vneEscChar.rawValue {
                ret = processAppend(&ev)
            } else {
                current -= 1
                _ = processAppend(&ev)
                markChange(current)
                ret = 1
            }
        }

        if vietKey && current >= 0 && buffer[current].form == .vnw_nonVn &&
            ev.chType == .ukcVn && (!options.spellCheckEnabled || singleMode) {
            ret = processNoSpellCheck(&ev)
        }

        if current >= 0 {
            ev.chType = input.getCharType(ev.keyCode)
            keyCurrent += 1
            keyStrokes[keyCurrent].ev = ev
            keyStrokes[keyCurrent].converted = (ret != 0 && !keyRestored)
        }

        var result = UkResult()
        if ret == 0 {
            result.ret = 0; result.backspaces = 0; result.output = ""; result.outType = outType
            return result
        }
        if !outputWritten { writeOutput() }
        result.ret = ret
        result.backspaces = backs
        result.output = out
        result.outType = outType
        return result
    }

    // Pointer-to-member dispatch (UkKeyProcList).
    private func dispatch(_ evType: Int, _ ev: inout UkKeyEvent) -> Int {
        switch UkKeyEvName(rawValue: evType)! {
        case .vneRoofAll, .vneRoof_a, .vneRoof_e, .vneRoof_o: return processRoof(&ev)
        case .vneHookAll, .vneHook_uo, .vneHook_u, .vneHook_o, .vneBowl: return processHook(&ev)
        case .vneDd: return processDd(&ev)
        case .vneTone0, .vneTone1, .vneTone2, .vneTone3, .vneTone4, .vneTone5: return processTone(&ev)
        case .vne_telex_w: return processTelexW(&ev)
        case .vneMapChar: return processMapChar(&ev)
        case .vneEscChar: return processEscChar(&ev)
        case .vneNormal: return processAppend(&ev)
        }
    }

    // MARK: processBackspace

    func processBackspace() -> UkResult {
        var result = UkResult()
        result.outType = .charOutput
        if !vietKey || current < 0 { return result }

        backs = 0
        changePos = current + 1
        markChange(current)

        if current == 0 ||
            buffer[current].form == .vnw_empty || buffer[current].form == .vnw_nonVn ||
            buffer[current].form == .vnw_c ||
            buffer[current - 1].form == .vnw_c || buffer[current - 1].form == .vnw_cvc ||
            buffer[current - 1].form == .vnw_vc {
            current -= 1
            synchKeyStrokeBuffer()
            result.backspaces = backs; result.output = ""
            result.ret = (backs > 1) ? 1 : 0
            return result
        }

        let vEnd = current - buffer[current].vOffset
        let vs = buffer[vEnd].vseq
        let vStart = vEnd - VSeqList[vs.rawValue].len + 1
        let newVs = buffer[current - 1].vseq
        let curTonePos = vStart + getTonePosition(vs, vEnd == current)
        let newTonePos = vStart + getTonePosition(newVs, true)
        let tone = buffer[curTonePos].tone

        if tone == 0 || curTonePos == newTonePos ||
            (curTonePos == current && buffer[current].tone != 0) {
            current -= 1
            synchKeyStrokeBuffer()
            result.backspaces = backs; result.output = ""
            result.ret = (backs > 1) ? 1 : 0
            return result
        }

        markChange(newTonePos); buffer[newTonePos].tone = tone
        markChange(curTonePos); buffer[curTonePos].tone = 0
        current -= 1
        synchKeyStrokeBuffer()
        writeOutput()
        result.backspaces = backs; result.output = out; result.ret = 1
        return result
    }

    private func synchKeyStrokeBuffer() {
        if keyCurrent >= 0 { keyCurrent -= 1 }
        if current >= 0 && buffer[current].form == .vnw_empty {
            while keyCurrent >= 0 && keyStrokes[keyCurrent].ev.chType != .ukcWordBreak {
                keyCurrent -= 1
            }
        }
    }
}
