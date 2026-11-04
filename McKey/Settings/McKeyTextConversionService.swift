//
//  McKeyTextConversionService.swift
//  McKey, adapted from PHTV System/PHTVConvertToolTextConversionService.swift
//
//  Swift implementation of Convert Tool text conversion.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//  Adapted from pqngson/PHTV revision 0a42ef4; GNU AGPL v3.0.
//

import Foundation

struct McKeyTextConversionOptions: Equatable {
    var toAllCaps = false
    var toAllNonCaps = false
    var toCapsFirstLetter = false
    var toCapsEachWord = false
    var removeMark = false
    var fromCode = 0
    var toCode = 0
}

enum McKeyConvertCodeTable: Int, CaseIterable, Identifiable {
    case unicode = 0
    case tcvn3 = 1
    case vniWindows = 2
    case unicodeComposite = 3
    case cp1258 = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .unicode: "Unicode"
        case .tcvn3: "TCVN3"
        case .vniWindows: "VNI Windows"
        case .unicodeComposite: "Unicode Composite"
        case .cp1258: "Vietnamese Locale (CP1258)"
        }
    }
}

enum McKeyTextConversionService {
    private static let breakCodes: Set<UInt16> = [46, 63, 33] // . ? !
    static func convert(_ text: String, options incomingOptions: McKeyTextConversionOptions) -> String {
        guard !text.isEmpty else {
            return text
        }

        var options = incomingOptions
        options.fromCode = sanitizeCodeTable(options.fromCode)
        options.toCode = sanitizeCodeTable(options.toCode)
        if options.toAllCaps {
            options.toAllNonCaps = false
            options.toCapsFirstLetter = false
            options.toCapsEachWord = false
        } else if options.toAllNonCaps {
            options.toCapsFirstLetter = false
            options.toCapsEachWord = false
        }
        let source = Array(text.utf16)
        var converted: [UInt16] = []
        converted.reserveCapacity(source.count + 4)

        var hasBreak = false
        var shouldUpperCase = options.toCapsFirstLetter || options.toCapsEachWord
        var index = 0

        while index < source.count {
            if index + 1 < source.count {
                var compoundCharacter = source[index]
                var consumedExtra = 0
                var hasCompoundCandidate = false

                switch options.fromCode {
                case McKeyConvertCodeTable.vniWindows.rawValue, McKeyConvertCodeTable.cp1258.rawValue:
                    compoundCharacter = source[index] | (source[index + 1] << 8)
                    consumedExtra = 1
                    hasCompoundCandidate = true

                case McKeyConvertCodeTable.unicodeComposite.rawValue:
                    let mark = unicodeCompoundMarkIndex(for: source[index + 1])
                    if mark > 0 {
                        compoundCharacter = source[index] | mark
                        consumedExtra = 1
                        hasCompoundCandidate = true
                    }

                default:
                    break
                }

                if hasCompoundCandidate,
                   tryConvertCharacter(
                       compoundCharacter,
                       options: options,
                       shouldUpperCase: shouldUpperCase,
                       output: &converted
                   ) {
                    index += consumedExtra + 1
                    shouldUpperCase = false
                    hasBreak = false
                    continue
                }
            }

            let singleCharacter = source[index]
            if tryConvertCharacter(
                singleCharacter,
                options: options,
                shouldUpperCase: shouldUpperCase,
                output: &converted
            ) {
                shouldUpperCase = false
                hasBreak = false
                index += 1
                continue
            }

            let forceUpperCase = options.toAllCaps || shouldUpperCase
            let forceLowerCase = options.toAllNonCaps || options.toCapsFirstLetter || options.toCapsEachWord

            if forceUpperCase {
                converted.append(uppercased(singleCharacter))
            } else if forceLowerCase {
                converted.append(lowercased(singleCharacter))
            } else {
                converted.append(singleCharacter)
            }

            if singleCharacter == 10 || (hasBreak && singleCharacter == 32) {
                if options.toCapsFirstLetter || options.toCapsEachWord {
                    shouldUpperCase = true
                }
            } else if singleCharacter == 32 && options.toCapsEachWord {
                shouldUpperCase = true
            } else if breakCodes.contains(singleCharacter) {
                hasBreak = true
            } else {
                shouldUpperCase = false
                hasBreak = false
            }

            index += 1
        }

        return String(decoding: converted, as: UTF16.self)
    }

    private static func tryConvertCharacter(
        _ sourceCharacter: UInt16,
        options: McKeyTextConversionOptions,
        shouldUpperCase: Bool,
        output: inout [UInt16]
    ) -> Bool {
        guard let (sourceKeyCode, sourceVariantIndex) = EngineCodeTableLookup.findSourceKey(
            codeTable: Int32(options.fromCode),
            character: sourceCharacter
        ) else {
            return false
        }

        var targetVariantIndex = sourceVariantIndex
        let forceUpperCase = options.toAllCaps || shouldUpperCase
        let forceLowerCase = options.toAllNonCaps || options.toCapsFirstLetter || options.toCapsEachWord
        let targetVariantCount = EngineCodeTableLookup.variantCount(
            codeTable: Int32(options.toCode),
            keyCode: sourceKeyCode
        )

        if forceUpperCase && (targetVariantIndex % 2 != 0) && targetVariantIndex > 0 {
            targetVariantIndex -= 1
        } else if forceLowerCase &&
                    (targetVariantIndex % 2 == 0) &&
                    (targetVariantIndex + 1) < targetVariantCount {
            targetVariantIndex += 1
        }

        guard var targetCharacter = EngineCodeTableLookup.characterForKey(
            codeTable: Int32(options.toCode),
            keyCode: sourceKeyCode,
            variantIndex: targetVariantIndex
        ) else {
            return false
        }

        if options.removeMark {
            let baseKeyCode = UInt32(UInt8(truncatingIfNeeded: sourceKeyCode))
            targetCharacter = EngineMacroKeyMap.character(for: baseKeyCode)
            if options.toAllCaps {
                targetCharacter = uppercased(targetCharacter)
            } else if options.toAllNonCaps {
                targetCharacter = lowercased(targetCharacter)
            }
        }

        appendTargetByCode(
            codeTable: options.toCode,
            targetCharacter: targetCharacter,
            output: &output
        )
        return true
    }

    private static func appendTargetByCode(
        codeTable: Int,
        targetCharacter: UInt16,
        output: inout [UInt16]
    ) {
        switch codeTable {
        case McKeyConvertCodeTable.unicode.rawValue, McKeyConvertCodeTable.tcvn3.rawValue:
            output.append(targetCharacter)

        case McKeyConvertCodeTable.vniWindows.rawValue, McKeyConvertCodeTable.cp1258.rawValue:
            let lowByte = targetCharacter & 0x00FF
            let highByte = (targetCharacter >> 8) & 0x00FF
            output.append(lowByte)
            if highByte > 32 {
                output.append(highByte)
            }

        case McKeyConvertCodeTable.unicodeComposite.rawValue:
            let markIndex = Int32(targetCharacter >> 13)
            if markIndex > 0 {
                output.append(targetCharacter & 0x1FFF)
                output.append(EnginePackedData.unicodeCompoundMark(at: markIndex - 1))
            } else {
                output.append(targetCharacter)
            }

        default:
            output.append(targetCharacter)
        }
    }

    private static func unicodeCompoundMarkIndex(for mark: UInt16) -> UInt16 {
        for index in 0..<5 {
            if mark == EnginePackedData.unicodeCompoundMark(at: Int32(index)) {
                return UInt16((index + 1) << 13)
            }
        }
        return 0
    }

    private static func uppercased(_ character: UInt16) -> UInt16 {
        transformCase(character, upper: true)
    }

    private static func lowercased(_ character: UInt16) -> UInt16 {
        transformCase(character, upper: false)
    }

    private static func transformCase(_ character: UInt16, upper: Bool) -> UInt16 {
        guard let scalar = UnicodeScalar(Int(character)) else {
            return character
        }
        let transformed = upper ? String(scalar).uppercased() : String(scalar).lowercased()
        guard transformed.utf16.count == 1, let value = transformed.utf16.first else {
            return character
        }
        return value
    }

    private static func sanitizeCodeTable(_ codeTable: Int) -> Int {
        McKeyConvertCodeTable(rawValue: codeTable)?.rawValue ?? McKeyConvertCodeTable.unicode.rawValue
    }
}
