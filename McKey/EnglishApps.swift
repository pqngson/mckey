import Foundation

enum McKeyLanguageLock {
    case none
    case english
    case vietnamese
}

enum McKeyEnglishAppBehavior: String, Codable, CaseIterable {
    case switchToEnglish
    case lockEnglish
    case lockVietnamese

    var languageLock: McKeyLanguageLock {
        switch self {
        case .switchToEnglish:
            return .none
        case .lockEnglish:
            return .english
        case .lockVietnamese:
            return .vietnamese
        }
    }
}

struct McKeyEnglishApp: Codable, Equatable, Identifiable {
    var id: String { bundleID }
    let bundleID: String
    var name: String
    var behavior: McKeyEnglishAppBehavior
}

struct McKeyEnglishAppRuleState {
    private(set) var isInEnglishApp = false
    private var vietnameseBeforeEntry = false
    private var lastBundleID: String?
    private var lastRule: McKeyEnglishApp?
    private var hasActivated = false

    /// Call on every frontmost-app change or settings change. Returns the language to use and whether it is locked.
    mutating func activate(bundleID: String?, rule: McKeyEnglishApp?, currentVietnamese: Bool) -> (vietnamese: Bool, lock: McKeyLanguageLock) {
        let sameRule = rule?.bundleID == lastRule?.bundleID && rule?.behavior == lastRule?.behavior
        if hasActivated && bundleID == lastBundleID && sameRule {
            lastRule = rule
            return (currentVietnamese, rule?.behavior.languageLock ?? .none)
        }
        hasActivated = true
        lastBundleID = bundleID
        lastRule = rule

        if let rule = rule {
            if !isInEnglishApp {
                vietnameseBeforeEntry = currentVietnamese
                isInEnglishApp = true
            }
            let target = rule.behavior == .lockVietnamese
            return (target, rule.behavior.languageLock)
        } else {
            if isInEnglishApp {
                isInEnglishApp = false
                return (vietnameseBeforeEntry, .none)
            } else {
                return (currentVietnamese, .none)
            }
        }
    }
}
