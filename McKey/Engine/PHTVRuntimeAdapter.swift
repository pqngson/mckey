import Foundation

// The upstream core reads settings through this narrow runtime facade. The
// public adapter serializes calls while installing its per-instance snapshot.
var phtvActiveOptions = PHTVOptions()
let phtvAdapterLock = NSRecursiveLock()
enum AutoRestoreEnglishMode: Int { case nonVietnamese = 0, englishOnly = 1 }
enum EngineBitMask {
    static let caps: UInt32 = 0x0001_0000
    static let charCode: UInt32 = 0x0200_0000
    static let pureCharacter: UInt32 = 0x8000_0000
}
enum EnginePackedData {
    static let marks: [UInt16] = [0x0301, 0x0300, 0x0309, 0x0303, 0x0323]
    static func lowByte(_ value: UInt32) -> UInt16 { UInt16(truncatingIfNeeded: value & 0xff) }
    static func highByte(_ value: UInt32) -> UInt16 { UInt16(truncatingIfNeeded: (value >> 8) & 0xff) }
    static func unicodeCompoundMark(at index: Int32) -> UInt16 { marks.indices.contains(Int(index)) ? marks[Int(index)] : 0 }
}
enum EngineInputClassification {
    static func isDoubleCodeTable(_ codeTable: Int32) -> Bool { codeTable == 2 || codeTable == 3 }
}
enum EngineMacroKeyMap {
    static func character(for data: UInt32) -> UInt16 {
        let code = UInt16(data & 0xff)
        let shifted = (data & EngineBitMask.caps) != 0
        let letters: [UInt16: UInt16] = [0:97,11:98,8:99,2:100,14:101,3:102,5:103,4:104,34:105,38:106,40:107,37:108,46:109,45:110,31:111,35:112,12:113,15:114,1:115,17:116,32:117,9:118,13:119,7:120,16:121,6:122]
        if let value = letters[code] { return shifted ? value - 32 : value }
        let unshifted: [UInt16: UInt16] = [18:49,19:50,20:51,21:52,23:53,22:54,26:55,28:56,25:57,29:48,50:96,27:45,24:61,33:91,30:93,42:92,41:59,39:39,43:44,47:46,44:47,49:32]
        let shiftedValues: [UInt16: UInt16] = [18:33,19:64,20:35,21:36,23:37,22:94,26:38,28:42,25:40,29:41,50:126,27:95,24:43,33:123,30:125,42:124,41:58,39:34,43:60,47:62,44:63]
        return (shifted ? shiftedValues : unshifted)[code] ?? 0
    }
}

func phtvRuntimeRestoreOnEscapeEnabled() -> Int32 { phtvActiveOptions.restoreOnEscape ? 1 : 0 }
func phtvRuntimeAutoCapsMacroValue() -> Int32 { 0 }
func phtvRuntimeAutoRestoreEnglishWordEnabled() -> Int32 { phtvActiveOptions.autoRestoreEnglishWord ? 1 : 0 }
func phtvRuntimeAutoRestoreEnglishWordModeValue() -> Int32 { Int32(phtvActiveOptions.autoRestoreEnglishWordMode) }
func phtvRuntimeRestoreIfWrongSpellingEnabled() -> Int32 { phtvActiveOptions.restoreIfWrongSpelling ? 1 : 0 }
func phtvRuntimeUpperCaseFirstCharEnabled() -> Int32 { 0 }
func phtvRuntimeUpperCaseExcludedForVietnamese() -> Int32 { 0 }
func phtvRuntimeDoubleSpacePeriodEnabled() -> Int32 { 0 }
func phtvRuntimeUseMacroEnabled() -> Int32 { 0 }
func phtvRuntimeNativeSystemTextReplacementEnabled() -> Int32 { 0 }
func phtvRuntimeInputTypeValue() -> Int32 { Int32(min(3, max(0, phtvActiveOptions.inputType))) }
func phtvRuntimeCodeTableValue() -> Int32 { Int32(min(4, max(0, phtvActiveOptions.codeTable))) }
func phtvRuntimeCheckSpellingValue() -> Int32 { phtvActiveOptions.checkSpelling ? 1 : 0 }
func phtvRuntimeSetCheckSpellingValue(_ value: Int32) { phtvActiveOptions.checkSpelling = value != 0 }
func phtvRuntimeUseModernOrthographyEnabled() -> Int32 { phtvActiveOptions.modernOrthography ? 1 : 0 }
func phtvRuntimeQuickTelexEnabled() -> Int32 { phtvActiveOptions.quickTelex ? 1 : 0 }
func phtvRuntimeFreeMarkEnabled() -> Int32 { phtvActiveOptions.freeMark ? 1 : 0 }
func phtvRuntimeAllowConsonantZFWJEnabled() -> Int32 { phtvActiveOptions.allowCustomConsonants ? 1 : 0 }
func phtvRuntimeDisableWordStartShortcutsEnabled() -> Int32 { phtvActiveOptions.disableWordStartShortcuts ? 1 : 0 }
func phtvRuntimeQuickStartConsonantEnabled() -> Int32 { phtvActiveOptions.quickStartConsonant ? 1 : 0 }
func phtvRuntimeQuickEndConsonantEnabled() -> Int32 { phtvActiveOptions.quickEndConsonant ? 1 : 0 }
func phtvRuntimeCustomConsonantRows() -> [[UInt16]] { phtvActiveOptions.allowCustomConsonants ? PHTVCustomConsonants.rows(phtvActiveOptions.customConsonants) : [] }
func phtvRuntimeConsonantSpellingRows() -> [[UInt16]] { phtvActiveOptions.allowCustomConsonants ? PHTVCustomConsonants.spellingRows(phtvActiveOptions.customConsonants) : PHTVCustomConsonants.standardRows }

enum EngineMacroSnippetType { case systemTextReplacement }
enum PHTVEngineRuntimeFacade {
    static func engineDataMatchedMacroSnippetType() -> EngineMacroSnippetType? { nil }
    static func engineDataMatchedMacroIsExactMatch() -> Bool { false }
}

func phtvFindMacroContentForNormalizedKeys(_ keys: UnsafePointer<UInt32>?, _ count: Int32, _ autoCaps: Int32, _ output: UnsafeMutablePointer<UInt32>?, _ capacity: Int32) -> Int32 { -1 }
func phtvHasNativeTextReplacementPrefix(_ keys: UnsafePointer<UInt32>?, _ count: Int32) -> Int32 { 0 }

// Custom dictionaries are an optional app service and aren't part of this
// engine port. Built-in English and Vietnamese dictionaries remain active.
func phtvCustomDictionaryEnglishCount() -> Int32 { 0 }
func phtvCustomDictionaryVietnameseCount() -> Int32 { 0 }
func phtvCustomDictionaryContainsEnglishWord(_ word: UnsafePointer<CChar>?) -> Int32 { 0 }
func phtvCustomDictionaryContainsVietnameseWord(_ word: UnsafePointer<CChar>?) -> Int32 { 0 }

