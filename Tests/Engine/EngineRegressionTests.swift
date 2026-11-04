import Foundation

@main
enum EngineRegressionTests {
    static func main() {
        let test = CommandLine.arguments.dropFirst().first ?? "telex"
        switch test {
        case "telex": expect("aas", inputType: 0, table: 0, "ấ")
        case "vni": expect("a61", inputType: 1, table: 0, "ấ")
        case "simple": expect("aas", inputType: 2, table: 0, "ấ")
        case "tables":
            let expected = [[0x1EA5], [0x00CA], [0x0061, 0x00E1], [0x00E2, 0x0301], [0x00E2, 0x00EC]]
            for table in 0...4 {
                let actual = replay("aas", inputType: 0, table: table)
                precondition(actual.unicodeScalars.map(\.value) == expected[table].map(UInt32.init), "code table \(table) mismatch")
            }
        case "backspace":
            let engine = PHTVInputEngine(); engine.options.autoRestoreEnglishWord = false
            var text = ""
            for c in "aas" {
                let value = String(c)
                let next = engine.process(keyCode: 0, shift: false, capsLock: false, characters: value, vietnamese: true)
                if next.handled { for _ in 0..<min(text.count, next.backspaces) { text.removeLast() }; text += next.output } else { text += value }
            }
            let result = engine.process(keyCode: 51, shift: false, capsLock: false, characters: "", vietnamese: true)
            if result.handled { for _ in 0..<min(text.count, result.backspaces) { text.removeLast() }; text += result.output }
            else if !text.isEmpty { text.removeLast() }
            precondition(text.isEmpty, "backspace replay produced \(text.debugDescription)")
            engine.reset()
            expect("aas", inputType: 0, table: 0, "ấ")
        case "vni-backspace":
            let engine = PHTVInputEngine(); engine.options.inputType = 0; engine.options.codeTable = 2
            var text = run(engine, "aas")
            let result = engine.process(keyCode: 51, shift: false, capsLock: false, characters: "", vietnamese: true)
            if result.handled { for _ in 0..<min(text.count, result.backspaces) { text.removeLast() }; text += result.output }
            else if !text.isEmpty { text.removeLast() }
            precondition(text == "a", "VNI multi-unit backspace left \(text.debugDescription)")
        case "caps":
            let upper = replay("AAS", inputType: 0, table: 0)
            precondition(upper == "Ấ", "uppercase output was \(upper)")
            let caps = replay("aas", inputType: 0, table: 0, caps: true)
            precondition(caps == "Ấ", "caps lock output was \(caps)")
            let shiftCaps = replay("aas", inputType: 0, table: 0, shift: true, caps: true)
            precondition(shiftCaps == "ấ", "shift+caps output was \(shiftCaps)")
        case "reset":
            let engine = PHTVInputEngine(); _ = engine.process(keyCode: 0, shift: false, capsLock: false, characters: "a", vietnamese: true)
            engine.reset(); expect("aas", inputType: 0, table: 0, "ấ")
        case "escape":
            let engine = PHTVInputEngine(); _ = engine.process(keyCode: 0, shift: false, capsLock: false, characters: "a", vietnamese: true)
            _ = engine.process(keyCode: 0, shift: false, capsLock: false, characters: "a", vietnamese: true)
            let result = engine.process(keyCode: 53, shift: false, capsLock: false, characters: "", vietnamese: true)
            precondition(result.handled)
        case "dictionary":
            _ = PHTVInputEngine()
            precondition(phtvDictionaryEnglishWordCount() > 0, "English dictionary not initialized")
            precondition(phtvDictionaryVietnameseWordCount() > 0, "Vietnamese dictionary not initialized")
        case "instances":
            let first = PHTVInputEngine(); let second = PHTVInputEngine()
            first.options.autoRestoreEnglishWord = false; second.options.autoRestoreEnglishWord = false
            _ = first.process(keyCode: 0, shift: false, capsLock: false, characters: "a", vietnamese: true)
            _ = second.process(keyCode: 0, shift: false, capsLock: false, characters: "e", vietnamese: true)
            _ = first.process(keyCode: 0, shift: false, capsLock: false, characters: "a", vietnamese: true)
            let one = first.process(keyCode: 0, shift: false, capsLock: false, characters: "s", vietnamese: true)
            _ = second.process(keyCode: 0, shift: false, capsLock: false, characters: "s", vietnamese: true)
            precondition(one.output.contains("ấ"), "first engine state leaked across instances: \(one.output.debugDescription)")
        case "modern":
            let old = replay("hoas", inputType: 0, table: 0, modern: false)
            let modern = replay("hoas", inputType: 0, table: 0, modern: true)
            precondition(old != modern, "modern tone placement did not change output")
        case "shortcuts":
            let normalW = PHTVInputEngine()
            let disabledW = PHTVInputEngine(); disabledW.options.disableWordStartShortcuts = true
            let normalBracket = PHTVInputEngine()
            let disabledBracket = PHTVInputEngine(); disabledBracket.options.disableWordStartShortcuts = true
            let normalWResult = run(normalW, "w")
            let disabledWResult = run(disabledW, "w")
            let normalBracketResult = run(normalBracket, "[")
            let disabledBracketResult = run(disabledBracket, "[")
            precondition(normalWResult == "ư" && disabledWResult == "w", "word-start W: \(normalWResult.debugDescription), \(disabledWResult.debugDescription)")
            precondition(normalBracketResult == "ơ" && disabledBracketResult == "[", "word-start bracket: \(normalBracketResult.debugDescription), \(disabledBracketResult.debugDescription)")
            precondition(run(PHTVInputEngine(), "t[") == "tơ", "midword bracket shortcut changed")
        case "quick":
            let engine = PHTVInputEngine(); engine.options.quickTelex = true
            let result = engine.process(keyCode: 8, shift: false, capsLock: false, characters: "c", vietnamese: true)
            precondition(result.handled && result.output == "ch", "quick Telex output: \(result.output.debugDescription)")
        case "restore":
            let engine = PHTVInputEngine(); engine.options.autoRestoreEnglishWord = true; engine.options.autoRestoreEnglishWordMode = 0
            var text = ""
            var sawTransformed = false
            var trace: [String] = []
            for c in "haaland " {
                let input = String(c)
                let result = engine.process(keyCode: input == " " ? 49 : 0, shift: false, capsLock: false, characters: input, vietnamese: true)
                trace.append("\(input):\(result.handled):\(result.backspaces):\(result.output)")
                if input == "a" && text.hasSuffix("ha") { sawTransformed = result.handled && result.output.contains("â") }
                if result.handled { for _ in 0..<min(text.count, result.backspaces) { text.removeLast() }; text += result.output }
                else { text += input }
            }
            precondition(sawTransformed && text == "haaland ", "dictionary restore: transformed=\(sawTransformed), output=\(text.debugDescription), trace=\(trace)")
        case "raw":
            let engine = PHTVInputEngine(); engine.options.autoRestoreEnglishWord = false
            _ = engine.process(keyCode: 0, shift: false, capsLock: false, characters: "a", vietnamese: true)
            _ = engine.process(keyCode: 0, shift: false, capsLock: false, characters: "a", vietnamese: true)
            let result = engine.restoreRaw()
            precondition(result.handled && result.output == "aa" && result.backspaces == 1, "raw restore returned \(result)")
        case "quick-start":
            let engine = PHTVInputEngine(); engine.options.quickStartConsonant = true
            let value = run(engine, "fa ")
            precondition(value == "pha ", "quick start output: \(value.debugDescription)")
        case "quick-end":
            let engine = PHTVInputEngine(); engine.options.quickEndConsonant = true
            let value = run(engine, "ag ")
            precondition(value == "ang ", "quick end output: \(value.debugDescription)")
        case "words":
            precondition(replay("xin chao", inputType: 0, table: 0) == "xin chao")
            precondition(replay("aas", inputType: 3, table: 0) == "ấ")
        case "custom":
            let customRows = PHTVCustomConsonants.rows(["DZ", "dz", "invalid!"])
            precondition(customRows == [[KEY_D, KEY_Z]], "custom consonant normalization failed")
            let engine = PHTVInputEngine(); engine.options.allowCustomConsonants = false
            phtvAdapterLock.lock(); phtvActiveOptions = engine.options
            let rows = phtvRuntimeCustomConsonantRows()
            phtvAdapterLock.unlock()
            precondition(rows.isEmpty, "disabled custom consonants remained active")
        case "no-capitalize":
            let engine = PHTVInputEngine()
            let text = run(engine, "abc. d")
            precondition(text == "abc. d", "sentence capitalization output: \(text.debugDescription)")
        case "legacy-options":
            do {
                let encoded = try JSONEncoder().encode(PHTVOptions())
                var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
                json["doubleSpacePeriod"] = true
                json["upperCaseFirstChar"] = true
                let merged = try JSONSerialization.data(withJSONObject: json)
                let decoded = try JSONDecoder().decode(PHTVOptions.self, from: merged)
                precondition(decoded == PHTVOptions(), "legacy options decode mismatch")
            } catch {
                preconditionFailure("legacy options test failed: \(error)")
            }
        case "boundary-delete":
            let engine = PHTVInputEngine(); engine.options.autoRestoreEnglishWord = false
            var text = run(engine, "haaland ")
            for _ in 0..<2 {
                let result = engine.process(keyCode: 51, shift: false, capsLock: false, characters: "", vietnamese: true)
                if result.handled { for _ in 0..<min(text.count, result.backspaces) { text.removeLast() }; text += result.output }
                else if !text.isEmpty { text.removeLast() }
            }
            precondition(text.count <= "haaland ".count, "backspace after word break corrupted \(text.debugDescription)")
        case "restore-backspace":
            let engine = PHTVInputEngine(); engine.options.autoRestoreEnglishWordMode = 0; engine.options.restoreIfWrongSpelling = true
            var text = run(engine, "haaland")
            _ = engine.process(keyCode: 51, shift: false, capsLock: false, characters: "", vietnamese: true)
            text = String(text.dropLast())
            _ = engine.process(keyCode: 2, shift: false, capsLock: false, characters: "d", vietnamese: true)
            text += "d"
            let result = engine.process(keyCode: 49, shift: false, capsLock: false, characters: " ", vietnamese: true)
            precondition(result.handled && result.output == "haaland ", "backspace and retype restore: \(result.output.debugDescription)")
        default: fatalError("unknown case \(test)")
        }
        print("PASS \(test)")
    }

    static func expect(_ input: String, inputType: Int, table: Int, _ expected: String) {
        let actual = replay(input, inputType: inputType, table: table)
        precondition(actual == expected, "\(input) => \(actual.debugDescription), expected \(expected.debugDescription)")
    }

    static func run(_ engine: PHTVInputEngine, _ input: String) -> String {
        var text = ""
        for c in input {
            let source = String(c)
            let key: UInt16 = source == " " ? 49 : 0
            let result = engine.process(keyCode: key, shift: false, capsLock: false, characters: source, vietnamese: true)
            if result.handled { for _ in 0..<min(text.count, result.backspaces) { text.removeLast() }; text += result.output }
            else { text += source }
        }
        return text
    }

    static func replay(_ input: String, inputType: Int, table: Int, shift: Bool = false, caps: Bool = false, modern: Bool = false) -> String {
        let engine = PHTVInputEngine()
        engine.options.inputType = inputType; engine.options.codeTable = table
        engine.options.autoRestoreEnglishWord = false
        engine.options.modernOrthography = modern
        var text = ""
        for character in input {
            let source = String(character)
            let result = engine.process(keyCode: 0, shift: shift || source != source.lowercased(), capsLock: caps, characters: source, vietnamese: true)
            if result.handled {
                for _ in 0..<min(text.count, result.backspaces) { text.removeLast() }
                text += result.output
            } else {
                text += source
            }
        }
        return text
    }
}
