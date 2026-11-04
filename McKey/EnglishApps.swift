import Foundation

enum McKeyEnglishAppBehavior: String, Codable, CaseIterable {
    case switchToEnglish
    case lockEnglish
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
    mutating func activate(bundleID: String?, rule: McKeyEnglishApp?, currentVietnamese: Bool) -> (vietnamese: Bool, locked: Bool) {
        let sameRule = rule?.bundleID == lastRule?.bundleID && rule?.behavior == lastRule?.behavior
        if hasActivated && bundleID == lastBundleID && sameRule {
            lastRule = rule
            return (currentVietnamese, rule?.behavior == .lockEnglish)
        }
        hasActivated = true
        lastBundleID = bundleID
        lastRule = rule

        if let rule = rule {
            if !isInEnglishApp {
                vietnameseBeforeEntry = currentVietnamese
                isInEnglishApp = true
            }
            return (false, rule.behavior == .lockEnglish)
        } else {
            if isInEnglishApp {
                isInEnglishApp = false
                return (vietnameseBeforeEntry && !currentVietnamese ? true : currentVietnamese, false)
            } else {
                return (currentVietnamese, false)
            }
        }
    }
}
