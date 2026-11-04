import Foundation

@main
enum ConversionTests {
    static func main() {
        let test = CommandLine.arguments.dropFirst().first ?? "tables"
        switch test {
        case "tables":
            for table in McKeyConvertCodeTable.allCases {
                let toLegacy = McKeyTextConversionOptions(fromCode: 0, toCode: table.rawValue)
                let toUnicode = McKeyTextConversionOptions(fromCode: table.rawValue, toCode: 0)
                let encoded = McKeyTextConversionService.convert("Tiếng Việt", options: toLegacy)
                let decoded = McKeyTextConversionService.convert(encoded, options: toUnicode)
                precondition(decoded == "Tiếng Việt", "\(table.title) round trip returned \(decoded.debugDescription)")
            }
        case "exhaustive":
            let keys: [UInt32] = [
                0, 31, 32, 14, 2,
                0x20000, 0x40000, 0x2001F, 0x4001F, 0x40020, 0x2000E,
                22, 16
            ]
            var checkCount = 0
            for keyCode in keys {
                let variantCount = EngineCodeTableLookup.variantCount(codeTable: 0, keyCode: keyCode)
                for variantIndex in 0..<variantCount {
                    guard let charCode = EngineCodeTableLookup.characterForKey(
                        codeTable: 0,
                        keyCode: keyCode,
                        variantIndex: variantIndex
                    ), charCode != 0 else {
                        continue
                    }
                    guard let scalar = UnicodeScalar(charCode) else {
                        fatalError("Invalid Unicode scalar: \(charCode)")
                    }
                    let original = String(scalar)

                    for table in 0...4 {
                        let toTarget = McKeyTextConversionOptions(fromCode: 0, toCode: table)
                        let encoded = McKeyTextConversionService.convert(original, options: toTarget)

                        if table == McKeyConvertCodeTable.tcvn3.rawValue {
                            var toUnicodeUpper = McKeyTextConversionOptions(fromCode: table, toCode: 0)
                            toUnicodeUpper.toAllCaps = true
                            let decoded = McKeyTextConversionService.convert(encoded, options: toUnicodeUpper)
                            precondition(
                                decoded == original.uppercased(),
                                "TCVN3 decode with toAllCaps failed for \(original): got \(decoded)"
                            )
                        } else {
                            let toUnicode = McKeyTextConversionOptions(fromCode: table, toCode: 0)
                            let decoded = McKeyTextConversionService.convert(encoded, options: toUnicode)
                            precondition(
                                decoded == original,
                                "Round-trip failed for \(original) in table \(table): got \(decoded)"
                            )
                        }
                        checkCount += 1
                    }
                }
            }
            precondition(checkCount == 620, "Expected 620 checks, got \(checkCount)")
        case "tcvn-canonical":
            let toTcvn = McKeyTextConversionOptions(fromCode: 0, toCode: McKeyConvertCodeTable.tcvn3.rawValue)
            let fromTcvnDefault = McKeyTextConversionOptions(fromCode: McKeyConvertCodeTable.tcvn3.rawValue, toCode: 0)
            var fromTcvnUpper = McKeyTextConversionOptions(fromCode: McKeyConvertCodeTable.tcvn3.rawValue, toCode: 0)
            fromTcvnUpper.toAllCaps = true

            let tcvnUpperA = McKeyTextConversionService.convert("Á", options: toTcvn)
            let tcvnLowerA = McKeyTextConversionService.convert("á", options: toTcvn)
            precondition(tcvnUpperA == tcvnLowerA, "Á and á should share bytes in TCVN3")
            precondition(McKeyTextConversionService.convert(tcvnUpperA, options: fromTcvnDefault) == "á", "TCVN3 Á should decode to lowercase á by default")
            precondition(McKeyTextConversionService.convert(tcvnLowerA, options: fromTcvnDefault) == "á", "TCVN3 á should decode to lowercase á by default")
            precondition(McKeyTextConversionService.convert(tcvnUpperA, options: fromTcvnUpper) == "Á", "Explicit uppercase conversion should produce Á")
            precondition(McKeyTextConversionService.convert(tcvnLowerA, options: fromTcvnUpper) == "Á", "Explicit uppercase conversion should produce Á")

            let tcvnUpperCircumflex = McKeyTextConversionService.convert("Â", options: toTcvn)
            let tcvnLowerCircumflex = McKeyTextConversionService.convert("â", options: toTcvn)
            precondition(tcvnUpperCircumflex != tcvnLowerCircumflex, "Â and â should have distinct bytes in TCVN3")
            precondition(McKeyTextConversionService.convert(tcvnUpperCircumflex, options: fromTcvnDefault) == "Â", "TCVN3 Â should retain uppercase Â")
            precondition(McKeyTextConversionService.convert(tcvnLowerCircumflex, options: fromTcvnDefault) == "â", "TCVN3 â should retain lowercase â")
            precondition(McKeyTextConversionService.convert(tcvnLowerCircumflex, options: fromTcvnUpper) == "Â", "Explicit uppercase conversion should produce Â")

            let tcvnUpperD = McKeyTextConversionService.convert("Đ", options: toTcvn)
            let tcvnLowerD = McKeyTextConversionService.convert("đ", options: toTcvn)
            precondition(tcvnUpperD != tcvnLowerD, "Đ and đ should have distinct bytes in TCVN3")
            precondition(McKeyTextConversionService.convert(tcvnUpperD, options: fromTcvnDefault) == "Đ", "TCVN3 Đ should retain uppercase Đ")
            precondition(McKeyTextConversionService.convert(tcvnLowerD, options: fromTcvnDefault) == "đ", "TCVN3 đ should retain lowercase đ")
            precondition(McKeyTextConversionService.convert(tcvnLowerD, options: fromTcvnUpper) == "Đ", "Explicit uppercase conversion should produce Đ")

            let phrase = "Ánh Âm Đàn á â đ"
            let encodedPhrase = McKeyTextConversionService.convert(phrase, options: toTcvn)
            let defaultDecoded = McKeyTextConversionService.convert(encodedPhrase, options: fromTcvnDefault)
            precondition(defaultDecoded == "ánh Âm Đàn á â đ", "Ambiguous uppercase decoded to lowercase canonical while distinct uppercase preserved: got \(defaultDecoded)")
            let upperDecoded = McKeyTextConversionService.convert(encodedPhrase, options: fromTcvnUpper)
            precondition(upperDecoded == "ÁNH ÂM ĐÀN Á Â Đ", "Explicit uppercase decoded phrase: got \(upperDecoded)")
        case "fallback-passthrough":
            let fallbackOptions = McKeyTextConversionOptions(fromCode: -99, toCode: 999)
            precondition(
                McKeyTextConversionService.convert("Tiếng Việt 123", options: fallbackOptions) == "Tiếng Việt 123",
                "Invalid code table indices should fall back to Unicode"
            )

            let supplementary = "Tiếng Việt 👋 🇻🇳 𝄢"
            for table in McKeyConvertCodeTable.allCases {
                let toLegacy = McKeyTextConversionOptions(fromCode: 0, toCode: table.rawValue)
                let toUnicode = McKeyTextConversionOptions(fromCode: table.rawValue, toCode: 0)
                let encoded = McKeyTextConversionService.convert(supplementary, options: toLegacy)
                if table == .tcvn3 {
                    let decoded = McKeyTextConversionService.convert(encoded, options: toUnicode)
                    precondition(
                        decoded.contains("👋 🇻🇳 𝄢"),
                        "Supplementary characters must pass through TCVN3 unchanged: got \(decoded)"
                    )
                } else {
                    let decoded = McKeyTextConversionService.convert(encoded, options: toUnicode)
                    precondition(
                        decoded == supplementary,
                        "\(table.title) should pass through supplementary Unicode characters: got \(decoded)"
                    )
                }
            }
        case "remove-marks":
            var options = McKeyTextConversionOptions()
            options.removeMark = true
            precondition(McKeyTextConversionService.convert("Tiếng Việt", options: options) == "Tieng Viet")
        case "tcvn-uppercase":
            var encode = McKeyTextConversionOptions()
            encode.toCode = McKeyConvertCodeTable.tcvn3.rawValue
            let tcvnText = McKeyTextConversionService.convert("Tiếng Việt", options: encode)
            var decode = McKeyTextConversionOptions(fromCode: McKeyConvertCodeTable.tcvn3.rawValue, toCode: 0)
            decode.toAllCaps = true
            precondition(McKeyTextConversionService.convert(tcvnText, options: decode) == "TIẾNG VIỆT")
        case "case-modes":
            var options = McKeyTextConversionOptions()
            options.toAllCaps = true
            precondition(McKeyTextConversionService.convert("tiếng Việt", options: options) == "TIẾNG VIỆT")
            options = McKeyTextConversionOptions()
            options.toCapsFirstLetter = true
            precondition(McKeyTextConversionService.convert("xin chào. tạm biệt", options: options) == "Xin chào. Tạm biệt")
            options = McKeyTextConversionOptions()
            options.toCapsEachWord = true
            precondition(McKeyTextConversionService.convert("xin chào", options: options) == "Xin Chào")
        default:
            fatalError("Unknown conversion test: \(test)")
        }
    }
}
