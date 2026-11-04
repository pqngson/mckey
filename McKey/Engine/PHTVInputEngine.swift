import Foundation

private enum PHTVDictionaryBootstrap {
    static let loaded: Void = {
        let override = ProcessInfo.processInfo.environment["PHTV_DICTIONARIES"].map(URL.init(fileURLWithPath:))
        let executableResources = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("../Resources")
        let candidates = [override, Bundle.main.resourceURL?.appendingPathComponent("Dictionaries"), Bundle.main.resourceURL, executableResources].compactMap { $0 }
        for directory in candidates {
            if let path = directory.appendingPathComponent("en_dict.bin").path as String? { _ = path.withCString { phtvDictionaryInitEnglish($0) } }
            if let path = directory.appendingPathComponent("vi_dict.bin").path as String? { _ = path.withCString { phtvDictionaryInitVietnamese($0) } }
            if phtvDictionaryEnglishWordCount() > 0 && phtvDictionaryVietnameseWordCount() > 0 { return }
        }
    }()
}

final class PHTVInputEngine {
    var options = PHTVOptions() {
        didSet { options.inputType = min(3, max(0, options.inputType)); options.codeTable = min(4, max(0, options.codeTable)) }
    }
    private let core = PHTVVietnameseEngine()
    private var renderedItems: [String] = []

    init() {
        phtvAdapterLock.lock(); phtvActiveOptions = options; core.vKeyInit(); phtvAdapterLock.unlock()
        _ = PHTVDictionaryBootstrap.loaded
    }

    func reset() {
        renderedItems.removeAll()
        phtvAdapterLock.lock(); phtvActiveOptions = options; core.resetInputSession(); phtvAdapterLock.unlock()
    }

    func process(keyCode: UInt16, shift: Bool, capsLock: Bool, characters: String, vietnamese: Bool) -> PHTVResult {
        guard let mapped = Self.mapCharacter(characters) ?? Self.controlKey(keyCode) else {
            reset()
            return PHTVResult(handled: false, backspaces: 0, output: "")
        }
        let capsStatus: UInt8 = shift && capsLock ? 3 : (shift ? 1 : (capsLock ? 2 : 0))
        let hook: PHTVEngineHookSnapshot
        phtvAdapterLock.lock()
        phtvActiveOptions = options
        if vietnamese {
            core.vKeyHandleEvent(event: .keyboard, state: .keyDown, data: mapped, capsStatus: capsStatus, otherControlKey: false)
        } else {
            core.vEnglishMode(state: .keyDown, data: mapped, isCaps: capsStatus == 1 || capsStatus == 2, otherControlKey: false)
        }
        hook = Self.snapshot(core)
        phtvAdapterLock.unlock()
        let recognized = hook.code == HookCodeState.willProcess.rawValue || hook.code == HookCodeState.restore.rawValue || hook.code == HookCodeState.restoreAndStartNewSession.rawValue
        guard recognized else {
            if keyCode == 51, !renderedItems.isEmpty {
                let last = renderedItems.removeLast()
                if last.count > 1 { renderedItems.append(String(last.dropLast())) }
                return PHTVResult(handled: false, backspaces: 0, output: "")
            }
            if characters.contains(where: { !$0.isLetter && !$0.isNumber && $0 != "'" }) { renderedItems.removeAll() }
            if !characters.isEmpty { renderedItems.append(characters) }
            return PHTVResult(handled: false, backspaces: 0, output: "")
        }
        let count = min(renderedItems.count, max(0, Int(hook.backspaceCount)))
        let removed = count == 0 ? [] : Array(renderedItems.suffix(count))
        if count > 0 { renderedItems.removeLast(count) }
        let decoded = Self.decodeItems(hook, codeTable: options.codeTable)
        var output = decoded.joined()
        if hook.code == HookCodeState.restore.rawValue || hook.code == HookCodeState.restoreAndStartNewSession.rawValue {
            output += characters
        }
        renderedItems.append(contentsOf: decoded)
        if hook.code == HookCodeState.restore.rawValue, !characters.isEmpty {
            renderedItems.append(characters)
        }
        if hook.code == HookCodeState.restoreAndStartNewSession.rawValue {
            renderedItems.removeAll()
            if !characters.isEmpty { renderedItems.append(characters) }
        }
        let backspaces = removed.reduce(0) { $0 + $1.count }
        return PHTVResult(handled: true, backspaces: backspaces, output: output)
    }

    func restoreRaw() -> PHTVResult {
        phtvAdapterLock.lock()
        phtvActiveOptions = options
        guard core.vRestoreToRawKeys() else { phtvAdapterLock.unlock(); return PHTVResult(handled: false, backspaces: 0, output: "") }
        let hook = Self.snapshot(core)
        phtvAdapterLock.unlock()
        let count = min(renderedItems.count, max(0, Int(hook.backspaceCount)))
        let removed = count == 0 ? [] : Array(renderedItems.suffix(count))
        if count > 0 { renderedItems.removeLast(count) }
        let output = Self.decodeItems(hook, codeTable: options.codeTable).joined()
        renderedItems.append(contentsOf: Self.decodeItems(hook, codeTable: options.codeTable))
        return PHTVResult(handled: true, backspaces: removed.reduce(0) { $0 + $1.count }, output: output)
    }

    private static func decodeItems(_ hook: PHTVEngineHookSnapshot, codeTable: Int) -> [String] {
        let values = Array(hook.chars.prefix(max(0, min(Int(hook.newCharCount), hook.chars.count))))
        return values.reversed().compactMap { data in
            guard let item = PHTVTextOutputEncoder.item(data, codeTable: Int32(codeTable)) else { return nil }
            var units: [UInt16] = []
            item.append(to: &units)
            return String(decoding: units, as: UTF16.self)
        }
    }

    private static func snapshot(_ core: PHTVVietnameseEngine) -> PHTVEngineHookSnapshot {
        PHTVEngineHookSnapshot(code: core.hCode, extCode: core.hExt, backspaceCount: Int32(core.hBPC), newCharCount: Int32(core.hNCC), chars: core.hData)
    }

    // Map the produced character, not the physical US-layout position. This
    // supports alternate layouts while refusing multi-scalar dead-key input.
    private static func mapCharacter(_ value: String) -> UInt16? {
        guard value.unicodeScalars.count == 1, let scalar = value.unicodeScalars.first else { return nil }
        let c = Character(String(scalar).lowercased())
        let letters: [Character: UInt16] = ["a":0,"b":11,"c":8,"d":2,"e":14,"f":3,"g":5,"h":4,"i":34,"j":38,"k":40,"l":37,"m":46,"n":45,"o":31,"p":35,"q":12,"r":15,"s":1,"t":17,"u":32,"v":9,"w":13,"x":7,"y":16,"z":6]
        if let code = letters[c] { return code }
        let punctuation: [Character: UInt16] = [" ":49,"1":18,"2":19,"3":20,"4":21,"5":23,"6":22,"7":26,"8":28,"9":25,"0":29,"-":27,"=":24,"[":33,"]":30,"\\":42,";":41,"'":39,",":43,".":47,"/":44,"`":50]
        if let key = punctuation[c] { return key }
        let shifted: [Character: UInt16] = ["!":18,"@":19,"#":20,"$":21,"%":23,"^":22,"&":26,"*":28,"(":25,")":29,"_":27,"+":24,"{":33,"}":30,"|":42,":":41,"\"":39,"<":43,">":47,"?":44,"~":50]
        return shifted[Character(scalar)]
    }

    private static func controlKey(_ keyCode: UInt16) -> UInt16? {
        switch keyCode {
        case 36, 48, 49, 51, 53, 76, 115, 116, 117, 119, 121, 123, 124, 125, 126: return keyCode
        default: return nil
        }
    }
}
