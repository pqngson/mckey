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
