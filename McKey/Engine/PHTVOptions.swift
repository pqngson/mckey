import Foundation

struct PHTVOptions: Codable, Equatable {
    var inputType = 0
    var codeTable = 0
    var checkSpelling = true
    var modernOrthography = false
    var autoRestoreEnglishWord = true
    var autoRestoreEnglishWordMode = 1
    var quickTelex = false
    var allowCustomConsonants = true
    var customConsonants = ["Z", "F", "W", "J", "DZ"]
    var quickStartConsonant = false
    var quickEndConsonant = false
    var restoreOnEscape = true
    var disableWordStartShortcuts = false
    var freeMark = false
    var restoreIfWrongSpelling = false
}

struct PHTVResult {
    let handled: Bool
    let backspaces: Int
    let output: String
}
