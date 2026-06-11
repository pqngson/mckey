// UKInput.swift — Stage 2 of the UniKey engine port.
// Ports inputproc.h / inputproc.cpp: UkKeyEvent, the Telex/VNI keymaps, the
// character classifier (UkcMap) and the ASCII → VnLexiName map (IsoVnLexiMap).

import Foundation

// UkKeyEvName — order matches inputproc.h; vneCount is the action-base offset.
enum UkKeyEvName: Int {
    case vneRoofAll = 0, vneRoof_a, vneRoof_e, vneRoof_o
    case vneHookAll, vneHook_uo, vneHook_u, vneHook_o, vneBowl
    case vneDd
    case vneTone0, vneTone1, vneTone2, vneTone3, vneTone4, vneTone5
    case vne_telex_w
    case vneMapChar
    case vneEscChar
    case vneNormal
}
let vneCount = 20   // number of UkKeyEvName cases

enum UkCharType { case ukcVn, ukcWordBreak, ukcNonVn, ukcReset }

struct UkKeyEvent {
    var evType: Int = UkKeyEvName.vneNormal.rawValue
    var chType: UkCharType = .ukcNonVn
    var vnSym: VnLexiName = .vnl_nonVnChar
    var keyCode: UInt = 0
    var tone: Int = 0
}

// MARK: - Keymaps (inputproc.cpp). action ≥ vneCount means a mapped symbol.

private struct UkKeyMapping { let key: UInt8; let action: Int }

private let TelexMethodMapping: [UkKeyMapping] = [
    .init(key: UInt8(ascii: "Z"), action: UkKeyEvName.vneTone0.rawValue),
    .init(key: UInt8(ascii: "S"), action: UkKeyEvName.vneTone1.rawValue),
    .init(key: UInt8(ascii: "F"), action: UkKeyEvName.vneTone2.rawValue),
    .init(key: UInt8(ascii: "R"), action: UkKeyEvName.vneTone3.rawValue),
    .init(key: UInt8(ascii: "X"), action: UkKeyEvName.vneTone4.rawValue),
    .init(key: UInt8(ascii: "J"), action: UkKeyEvName.vneTone5.rawValue),
    .init(key: UInt8(ascii: "W"), action: UkKeyEvName.vne_telex_w.rawValue),
    .init(key: UInt8(ascii: "A"), action: UkKeyEvName.vneRoof_a.rawValue),
    .init(key: UInt8(ascii: "E"), action: UkKeyEvName.vneRoof_e.rawValue),
    .init(key: UInt8(ascii: "O"), action: UkKeyEvName.vneRoof_o.rawValue),
    .init(key: UInt8(ascii: "D"), action: UkKeyEvName.vneDd.rawValue),
    .init(key: UInt8(ascii: "["), action: vneCount + VnLexiName.vnl_oh.rawValue),
    .init(key: UInt8(ascii: "]"), action: vneCount + VnLexiName.vnl_uh.rawValue),
    .init(key: UInt8(ascii: "{"), action: vneCount + VnLexiName.vnl_Oh.rawValue),
    .init(key: UInt8(ascii: "}"), action: vneCount + VnLexiName.vnl_Uh.rawValue),
]

private let VniMethodMapping: [UkKeyMapping] = [
    .init(key: UInt8(ascii: "0"), action: UkKeyEvName.vneTone0.rawValue),
    .init(key: UInt8(ascii: "1"), action: UkKeyEvName.vneTone1.rawValue),
    .init(key: UInt8(ascii: "2"), action: UkKeyEvName.vneTone2.rawValue),
    .init(key: UInt8(ascii: "3"), action: UkKeyEvName.vneTone3.rawValue),
    .init(key: UInt8(ascii: "4"), action: UkKeyEvName.vneTone4.rawValue),
    .init(key: UInt8(ascii: "5"), action: UkKeyEvName.vneTone5.rawValue),
    .init(key: UInt8(ascii: "6"), action: UkKeyEvName.vneRoofAll.rawValue),
    .init(key: UInt8(ascii: "7"), action: UkKeyEvName.vneHook_uo.rawValue),
    .init(key: UInt8(ascii: "8"), action: UkKeyEvName.vneBowl.rawValue),
    .init(key: UInt8(ascii: "9"), action: UkKeyEvName.vneDd.rawValue),
]

// MARK: - Classifier + ISO→lexi tables (built once)

private let WordBreakSyms: [UInt8] = Array(",;:.\"'!?<>=+-*/\\_@#$%&(){}[]|".utf8) + [UInt8(ascii: " ")]

private let AZLexiUpper: [VnLexiName] = [
    .vnl_A,.vnl_B,.vnl_C,.vnl_D,.vnl_E,.vnl_F,.vnl_G,.vnl_H,.vnl_I,.vnl_J,
    .vnl_K,.vnl_L,.vnl_M,.vnl_N,.vnl_O,.vnl_P,.vnl_Q,.vnl_R,.vnl_S,.vnl_T,
    .vnl_U,.vnl_V,.vnl_W,.vnl_X,.vnl_Y,.vnl_Z]
private let AZLexiLower: [VnLexiName] = [
    .vnl_a,.vnl_b,.vnl_c,.vnl_d,.vnl_e,.vnl_f,.vnl_g,.vnl_h,.vnl_i,.vnl_j,
    .vnl_k,.vnl_l,.vnl_m,.vnl_n,.vnl_o,.vnl_p,.vnl_q,.vnl_r,.vnl_s,.vnl_t,
    .vnl_u,.vnl_v,.vnl_w,.vnl_x,.vnl_y,.vnl_z]

private let AscVnLexiList: [(Int, VnLexiName)] = [
    (0xC0,.vnl_A2),(0xC1,.vnl_A1),(0xC2,.vnl_Ar),(0xC2,.vnl_A4),(0xC8,.vnl_E2),(0xC9,.vnl_E1),
    (0xCA,.vnl_Er),(0xCC,.vnl_I2),(0xCD,.vnl_I1),(0xD2,.vnl_O2),(0xD3,.vnl_O1),(0xD4,.vnl_Or),
    (0xD5,.vnl_O4),(0xD9,.vnl_U2),(0xDA,.vnl_U1),(0xDD,.vnl_Y1),(0xE0,.vnl_a2),(0xE1,.vnl_a1),
    (0xE2,.vnl_ar),(0xE3,.vnl_a4),(0xE8,.vnl_e2),(0xE9,.vnl_e1),(0xEA,.vnl_er),(0xEC,.vnl_i2),
    (0xED,.vnl_i1),(0xF2,.vnl_o2),(0xF3,.vnl_o1),(0xF4,.vnl_or),(0xF5,.vnl_o4),(0xF9,.vnl_u2),
    (0xFA,.vnl_u1),(0xFD,.vnl_y1),
]

private let (UkcMap, IsoVnLexiMap): ([UkCharType], [VnLexiName]) = {
    var ukc = [UkCharType](repeating: .ukcNonVn, count: 256)
    for c in 0...32 { ukc[c] = .ukcReset }
    for c in 33..<256 { ukc[c] = .ukcNonVn }
    for c in Int(UInt8(ascii: "a"))...Int(UInt8(ascii: "z")) { ukc[c] = .ukcVn }
    for c in Int(UInt8(ascii: "A"))...Int(UInt8(ascii: "Z")) { ukc[c] = .ukcVn }
    for (asc, _) in AscVnLexiList { ukc[asc] = .ukcVn }
    for ch in ["j", "J", "f", "F", "w", "W"] { ukc[Int(ch.utf8.first!)] = .ukcNonVn }
    for s in WordBreakSyms { ukc[Int(s)] = .ukcWordBreak }

    var iso = [VnLexiName](repeating: .vnl_nonVnChar, count: 256)
    for (asc, lexi) in AscVnLexiList { iso[asc] = lexi }
    for c in 0..<26 {
        iso[Int(UInt8(ascii: "a")) + c] = AZLexiLower[c]
        iso[Int(UInt8(ascii: "A")) + c] = AZLexiUpper[c]
    }
    return (ukc, iso)
}()

private func isoToVnLexi(_ keyCode: UInt) -> VnLexiName {
    keyCode >= 256 ? .vnl_nonVnChar : IsoVnLexiMap[Int(keyCode)]
}

// MARK: - UkInputProcessor

final class UkInputProcessor {
    private(set) var im: UkInputMethod = .telex
    private var keyMap = [Int](repeating: UkKeyEvName.vneNormal.rawValue, count: 256)

    func setIM(_ method: UkInputMethod) {
        im = method
        switch method {
        case .telex: useBuiltIn(TelexMethodMapping)
        case .vni:   useBuiltIn(VniMethodMapping)
        }
    }

    private func useBuiltIn(_ map: [UkKeyMapping]) {
        for i in 0..<256 { keyMap[i] = UkKeyEvName.vneNormal.rawValue }
        for m in map {
            keyMap[Int(m.key)] = m.action
            if m.action < vneCount {
                let ch = Character(UnicodeScalar(m.key))
                if ch.isLowercase { keyMap[Int(ch.uppercased().utf8.first!)] = m.action }
                else if ch.isUppercase { keyMap[Int(ch.lowercased().utf8.first!)] = m.action }
            }
        }
    }

    func keyCodeToEvent(_ keyCode: UInt, _ ev: inout UkKeyEvent) {
        ev.keyCode = keyCode
        if keyCode > 255 {
            ev.evType = UkKeyEvName.vneNormal.rawValue
            ev.vnSym = isoToVnLexi(keyCode)
            ev.chType = (ev.vnSym == .vnl_nonVnChar) ? .ukcNonVn : .ukcVn
        } else {
            ev.chType = UkcMap[Int(keyCode)]
            ev.evType = keyMap[Int(keyCode)]

            if ev.evType >= UkKeyEvName.vneTone0.rawValue && ev.evType <= UkKeyEvName.vneTone5.rawValue {
                ev.tone = ev.evType - UkKeyEvName.vneTone0.rawValue
            }
            if ev.evType >= vneCount {
                ev.chType = .ukcVn
                ev.vnSym = VnLexiName(rawValue: ev.evType - vneCount) ?? .vnl_nonVnChar
                ev.evType = UkKeyEvName.vneMapChar.rawValue
            } else {
                ev.vnSym = isoToVnLexi(keyCode)
            }
        }
    }

    func keyCodeToSymbol(_ keyCode: UInt, _ ev: inout UkKeyEvent) {
        ev.keyCode = keyCode
        ev.evType = UkKeyEvName.vneNormal.rawValue
        ev.vnSym = isoToVnLexi(keyCode)
        if keyCode > 255 {
            ev.chType = (ev.vnSym == .vnl_nonVnChar) ? .ukcNonVn : .ukcVn
        } else {
            ev.chType = UkcMap[Int(keyCode)]
        }
    }

    func getCharType(_ keyCode: UInt) -> UkCharType {
        if keyCode > 255 { return isoToVnLexi(keyCode) == .vnl_nonVnChar ? .ukcNonVn : .ukcVn }
        return UkcMap[Int(keyCode)]
    }

    func vnLexiFor(_ keyCode: UInt) -> VnLexiName { isoToVnLexi(keyCode) }
}
