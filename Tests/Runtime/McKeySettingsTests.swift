import Foundation

@main
struct McKeySettingsTests {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("pass one named test case") }
        switch CommandLine.arguments[1] {
        case "migration": try legacyPreferencesMigrate()
        case "malformed-import": try malformedSettingsAreRejected()
        case "roundtrip": try importExportRoundtrip()
        case "reset-batch": resetBatchesCallback()
        case "modifier-release": modifierChordReleasesInEitherOrder()
        case "cancel": extraModifiersAndTypingCancel()
        case "key-release": keyChordWaitsForReleaseAndIgnoresRepeats()
        case "modifier-map": modifierFlagMappingIsStable()
        case "restore-release": restoreIsStandaloneAndConflictSafe()
        case "pause-hold": pauseResumesOnModifierRelease()
        case "english-apps": englishAppRules()
        case "english-apps-persist": try englishAppsPersist()
        default: fatalError("unknown test case: \(CommandLine.arguments[1])")
        }
        print("Runtime test passed: \(CommandLine.arguments[1])")
    }

    @MainActor
    private static func legacyPreferencesMigrate() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("VNI", forKey: "method")
        defaults.set(false, forKey: "switchSound")
        defaults.set(0.4, forKey: "soundVolume")
        let settings = McKeySettings(defaults: defaults)
        precondition(settings.engine.inputType == 1)
        precondition(!settings.switchSound)
        precondition(settings.soundVolume == 0.4)
        settings.save()
        precondition(defaults.string(forKey: "method") == "VNI")
        precondition(defaults.data(forKey: "phtvEngineOptions") != nil)
    }

    @MainActor
    private static func malformedSettingsAreRejected() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = McKeySettings(defaults: defaults)
        let valid = try settings.exportJSON()
        var object = try JSONSerialization.jsonObject(with: valid) as! [String: Any]
        var engine = object["engine"] as! [String: Any]
        engine["inputType"] = 99
        object["engine"] = engine
        let invalid = try JSONSerialization.data(withJSONObject: object)
        do {
            try settings.importJSON(invalid)
            preconditionFailure("invalid engine option was accepted")
        } catch is McKeySettingsImportError { }
    }

    @MainActor
    private static func importExportRoundtrip() throws {
        let source = McKeySettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        source.switchSound = false
        source.clickSound = false
        source.clickSoundDelay = 30
        source.soundVolume = 0.25
        source.autoSwitchEnabled = false
        source.autoSwitchToVietnamese = true
        source.autoSwitchDelay = 15
        let destination = McKeySettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        try destination.importJSON(source.exportJSON())
        precondition(destination.switchSound == false && destination.clickSound == false)
        precondition(destination.clickSoundDelay == 30 && destination.soundVolume == 0.25)
        precondition(!destination.autoSwitchEnabled && destination.autoSwitchToVietnamese)
        precondition(destination.autoSwitchDelay == 15)

        var legacyObject = try JSONSerialization.jsonObject(with: source.exportJSON()) as! [String: Any]
        legacyObject["upperCaseExcludedAppScopes"] = ["a.b": "both"]
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacySettings = McKeySettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        try legacySettings.importJSON(legacyData)
        precondition(legacySettings.switchSound == false)
    }

    @MainActor
    private static func resetBatchesCallback() {
        let settings = McKeySettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        var callbackCount = 0
        settings.onChange = { callbackCount += 1 }
        settings.resetToDefaults()
        precondition(callbackCount == 1)
    }

    private static func modifierChordReleasesInEitherOrder() {
        let chord = McKeyHotkey(control: true, shift: true)
        for transitions in [[8, 9, 8, 0], [8, 9, 1, 0]] {
            var reducer = McKeyHotkeyReducer()
            var result = McKeyHotkeyEventResult()
            for flags in transitions { result = reducer.flagsChanged(flags, hotkeys: [chord]) }
            precondition(result.triggeredIndex == 0)
        }
    }

    private static func extraModifiersAndTypingCancel() {
        let chord = McKeyHotkey(control: true, shift: true)
        var extra = McKeyHotkeyReducer()
        _ = extra.flagsChanged(8, hotkeys: [chord])
        _ = extra.flagsChanged(9, hotkeys: [chord])
        _ = extra.flagsChanged(13, hotkeys: [chord])
        precondition(extra.flagsChanged(0, hotkeys: [chord]).triggeredIndex == nil)

        var typed = McKeyHotkeyReducer()
        _ = typed.flagsChanged(8, hotkeys: [chord])
        _ = typed.flagsChanged(9, hotkeys: [chord])
        _ = typed.keyDown(0, flags: 9, hotkeys: [chord], isRepeat: false)
        precondition(typed.flagsChanged(0, hotkeys: [chord]).triggeredIndex == nil)
    }

    private static func keyChordWaitsForReleaseAndIgnoresRepeats() {
        let chord = McKeyHotkey(keyCode: 49, control: true)
        var reducer = McKeyHotkeyReducer()
        let initial = reducer.keyDown(49, flags: 1, hotkeys: [chord], isRepeat: false)
        precondition(initial.consumed && initial.triggeredIndex == nil)
        precondition(reducer.keyDown(49, flags: 1, hotkeys: [chord], isRepeat: true).triggeredIndex == nil)
        let released = reducer.keyUp(49)
        precondition(released.consumed && released.triggeredIndex == 0)
    }

    private static func modifierFlagMappingIsStable() {
        precondition(McKeyRuntimeModifiers.normalize(control: true, option: true,
            command: true, shift: true, fn: true) == 31)
        precondition(McKeyRuntimeModifiers.normalize(control: false, option: true,
            command: false, shift: true, fn: false) == 10)
        precondition(McKeyRuntimeModifiers.normalize(control: true, option: false,
            command: false, shift: false, fn: false, duplicateModifierSides: true) == 33)
    }

    private static func restoreIsStandaloneAndConflictSafe() {
        precondition(McKeyRuntimeModifiers.shouldRestoreRaw(oldFlags: 2, newFlags: 0,
            restoreMask: 2, restoreWasDown: true, restoreCancelled: false,
            hotkeyChordActive: false, hotkeyTriggered: false, restoreEnabled: true))
        precondition(!McKeyRuntimeModifiers.shouldRestoreRaw(oldFlags: 6, newFlags: 0,
            restoreMask: 2, restoreWasDown: true, restoreCancelled: true,
            hotkeyChordActive: false, hotkeyTriggered: false, restoreEnabled: true))

        let conflicting = McKeyHotkey(option: true)
        var reducer = McKeyHotkeyReducer()
        _ = reducer.flagsChanged(2, hotkeys: [conflicting])
        let release = reducer.flagsChanged(0, hotkeys: [conflicting])
        precondition(release.triggeredIndex == 0)
        precondition(!McKeyRuntimeModifiers.shouldRestoreRaw(oldFlags: 2, newFlags: 0,
            restoreMask: 2, restoreWasDown: true, restoreCancelled: false,
            hotkeyChordActive: release.chordActive, hotkeyTriggered: release.triggeredIndex != nil,
            restoreEnabled: true))
    }

    private static func pauseResumesOnModifierRelease() {
        var reducer = McKeyPauseReducer()
        precondition(reducer.update(flags: 2, pauseMask: 2) && reducer.isPaused)
        precondition(!reducer.update(flags: 6, pauseMask: 2) && reducer.isPaused)
        precondition(reducer.update(flags: 0, pauseMask: 2) && !reducer.isPaused)
        precondition(!reducer.update(flags: 0, pauseMask: 2) && !reducer.isPaused)
    }

    private static func englishAppRules() {
        let switchApp = McKeyEnglishApp(bundleID: "com.example.switch", name: "Switch App", behavior: .switchToEnglish)
        let lockApp = McKeyEnglishApp(bundleID: "com.example.lock", name: "Lock App", behavior: .lockEnglish)

        // 1. VN, enter switch app → (false, .none); leave with currentVietnamese false → (true, .none).
        var state1 = McKeyEnglishAppRuleState()
        let res1_enter = state1.activate(bundleID: switchApp.bundleID, rule: switchApp, currentVietnamese: true)
        precondition(res1_enter == (false, .none))
        precondition(state1.isInEnglishApp)
        let res1_leave = state1.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: false)
        precondition(res1_leave == (true, .none))
        precondition(!state1.isInEnglishApp)

        // 2. VN, enter lock app → (false, .english).
        var state2 = McKeyEnglishAppRuleState()
        let res2 = state2.activate(bundleID: lockApp.bundleID, rule: lockApp, currentVietnamese: true)
        precondition(res2 == (false, .english))
        precondition(state2.isInEnglishApp)

        // 3. VN, enter lock app, then switch app → (false, .none); leave → (true, .none).
        var state3 = McKeyEnglishAppRuleState()
        let res3_lock = state3.activate(bundleID: lockApp.bundleID, rule: lockApp, currentVietnamese: true)
        precondition(res3_lock == (false, .english))
        let res3_switch = state3.activate(bundleID: switchApp.bundleID, rule: switchApp, currentVietnamese: false)
        precondition(res3_switch == (false, .none))
        let res3_leave = state3.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: false)
        precondition(res3_leave == (true, .none))

        // 4. EN, enter switch app, leave → (false, .none).
        var state4 = McKeyEnglishAppRuleState()
        let res4_enter = state4.activate(bundleID: switchApp.bundleID, rule: switchApp, currentVietnamese: false)
        precondition(res4_enter == (false, .none))
        let res4_leave = state4.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: false)
        precondition(res4_leave == (false, .none))

        // 5. VN, enter switch app, user turned VN on inside (leave with currentVietnamese true) → (true, .none).
        var state5 = McKeyEnglishAppRuleState()
        let res5_enter = state5.activate(bundleID: switchApp.bundleID, rule: switchApp, currentVietnamese: true)
        precondition(res5_enter == (false, .none))
        let res5_leave = state5.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: true)
        precondition(res5_leave == (true, .none))

        // 6. No rule, not in app, currentVietnamese true → (true, .none).
        var state6 = McKeyEnglishAppRuleState()
        let res6 = state6.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: true)
        precondition(res6 == (true, .none))

        // 7. VN, enter switch app "a" → EN; user turns VN on; activate again with same "a"/rule and currentVietnamese true → (true, .none).
        // Also: changing app "a"'s behaviour from switch to lock (same bundleID, different rule) → (false, .english).
        var state7 = McKeyEnglishAppRuleState()
        let appA_switch = McKeyEnglishApp(bundleID: "a", name: "A", behavior: .switchToEnglish)
        let res7_enter = state7.activate(bundleID: "a", rule: appA_switch, currentVietnamese: true)
        precondition(res7_enter == (false, .none))
        let res7_reapply = state7.activate(bundleID: "a", rule: appA_switch, currentVietnamese: true)
        precondition(res7_reapply == (true, .none))
        let appA_lock = McKeyEnglishApp(bundleID: "a", name: "A", behavior: .lockEnglish)
        let res7_changeBehavior = state7.activate(bundleID: "a", rule: appA_lock, currentVietnamese: true)
        precondition(res7_changeBehavior == (false, .english))

        // 8. Rename regression: enter switch app, manually enable Vietnamese, rename entry with same bundle ID and behavior,
        // reapply => Vietnamese true unlocked; change renamed rule to lock => English locked; remove => unlock and restore prior language.
        var state8 = McKeyEnglishAppRuleState()
        let appB_switch = McKeyEnglishApp(bundleID: "b", name: "Original Name", behavior: .switchToEnglish)
        let res8_enter = state8.activate(bundleID: "b", rule: appB_switch, currentVietnamese: true)
        precondition(res8_enter == (false, .none))
        let appB_renamed = McKeyEnglishApp(bundleID: "b", name: "Renamed App", behavior: .switchToEnglish)
        let res8_rename = state8.activate(bundleID: "b", rule: appB_renamed, currentVietnamese: true)
        precondition(res8_rename == (true, .none))
        let appB_lock = McKeyEnglishApp(bundleID: "b", name: "Renamed App", behavior: .lockEnglish)
        let res8_lock = state8.activate(bundleID: "b", rule: appB_lock, currentVietnamese: true)
        precondition(res8_lock == (false, .english))
        let res8_remove = state8.activate(bundleID: "b", rule: nil, currentVietnamese: false)
        precondition(res8_remove == (true, .none))

        // 9. Lock Vietnamese behavior:
        // a) Fresh state, VN off, rule lockVietnamese for app "c" -> returns (true, .vietnamese).
        var state9 = McKeyEnglishAppRuleState()
        let appC_lock = McKeyEnglishApp(bundleID: "c", name: "C", behavior: .lockVietnamese)
        let res9_enter = state9.activate(bundleID: "c", rule: appC_lock, currentVietnamese: false)
        precondition(res9_enter == (true, .vietnamese))
        // b) Then same app/rule, currentVietnamese: true -> (true, .vietnamese).
        let res9_same = state9.activate(bundleID: "c", rule: appC_lock, currentVietnamese: true)
        precondition(res9_same == (true, .vietnamese))
        // c) Then rule: nil for leaving with currentVietnamese: true -> (false, .none).
        let res9_leave = state9.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: true)
        precondition(res9_leave == (false, .none))

        // d) Same bundle "d": switchToEnglish -> (false, .none); then lockVietnamese -> (true, .vietnamese).
        var state10 = McKeyEnglishAppRuleState()
        let appD_switch = McKeyEnglishApp(bundleID: "d", name: "D", behavior: .switchToEnglish)
        let res10_switch = state10.activate(bundleID: "d", rule: appD_switch, currentVietnamese: true)
        precondition(res10_switch == (false, .none))
        let appD_lockVN = McKeyEnglishApp(bundleID: "d", name: "D", behavior: .lockVietnamese)
        let res10_lockVN = state10.activate(bundleID: "d", rule: appD_lockVN, currentVietnamese: false)
        precondition(res10_lockVN == (true, .vietnamese))

        // 11. EN before, enter switch app -> (false, .none); user turns VN on inside; leave with currentVietnamese true -> (false, .none).
        var state11 = McKeyEnglishAppRuleState()
        let res11_enter = state11.activate(bundleID: switchApp.bundleID, rule: switchApp, currentVietnamese: false)
        precondition(res11_enter == (false, .none))
        let res11_leave = state11.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: true)
        precondition(res11_leave == (false, .none))

        // 12. VN before, enter lockVietnamese app -> (true, .vietnamese); leave with currentVietnamese true -> (true, .none).
        var state12 = McKeyEnglishAppRuleState()
        let lockVNApp = McKeyEnglishApp(bundleID: "com.example.lockvn", name: "Lock VN", behavior: .lockVietnamese)
        let res12_enter = state12.activate(bundleID: lockVNApp.bundleID, rule: lockVNApp, currentVietnamese: true)
        precondition(res12_enter == (true, .vietnamese))
        let res12_leave = state12.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: true)
        precondition(res12_leave == (true, .none))

        // 13. EN before, enter lockEnglish app, move to lockVietnamese app (different bundle) -> (true, .vietnamese), leave -> (false, .none).
        var state13 = McKeyEnglishAppRuleState()
        let res13_lockEN = state13.activate(bundleID: lockApp.bundleID, rule: lockApp, currentVietnamese: false)
        precondition(res13_lockEN == (false, .english))
        let res13_lockVN = state13.activate(bundleID: lockVNApp.bundleID, rule: lockVNApp, currentVietnamese: false)
        precondition(res13_lockVN == (true, .vietnamese))
        let res13_leave = state13.activate(bundleID: "com.apple.finder", rule: nil, currentVietnamese: true)
        precondition(res13_leave == (false, .none))
    }

    @MainActor
    private static func englishAppsPersist() throws {
        precondition(McKeyEnglishAppBehavior(rawValue: "lockVietnamese") == .lockVietnamese)

        let suite = UUID().uuidString
        let sourceDefaults = UserDefaults(suiteName: suite)!
        let source = McKeySettings(defaults: sourceDefaults)
        let app1 = McKeyEnglishApp(bundleID: "com.apple.Terminal", name: "Terminal", behavior: .switchToEnglish)
        let app2 = McKeyEnglishApp(bundleID: "com.sublimetext.4", name: "Sublime", behavior: .lockEnglish)
        let app3 = McKeyEnglishApp(bundleID: "com.example.vn", name: "VN App", behavior: .lockVietnamese)
        source.englishApps = [app1, app2, app3]

        // export, import into a fresh one → equal lists; englishApp(for:) finds one, returns nil for unknown and nil.
        let freshDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let freshSettings = McKeySettings(defaults: freshDefaults)
        try freshSettings.importJSON(source.exportJSON())
        precondition(freshSettings.englishApps == [app1, app2, app3])
        precondition(freshSettings.englishApp(for: "com.apple.Terminal") == app1)
        precondition(freshSettings.englishApp(for: "com.example.vn") == app3)
        precondition(freshSettings.englishApp(for: "com.unknown") == nil)
        precondition(freshSettings.englishApp(for: nil) == nil)

        // a second McKeySettings created on the SAME defaults as the source reloads the list (persistence).
        let reloaded = McKeySettings(defaults: sourceDefaults)
        precondition(reloaded.englishApps == [app1, app2, app3])

        // JSON from exportJSON() with the englishApps key removed (JSONSerialization) still imports, giving [].
        var jsonObject = try JSONSerialization.jsonObject(with: source.exportJSON()) as! [String: Any]
        jsonObject.removeValue(forKey: "englishApps")
        let legacyData = try JSONSerialization.data(withJSONObject: jsonObject)
        let importedWithoutField = McKeySettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        try importedWithoutField.importJSON(legacyData)
        precondition(importedWithoutField.englishApps.isEmpty)

        // JSON with two entries sharing a bundleID throws.
        var dupObject = try JSONSerialization.jsonObject(with: source.exportJSON()) as! [String: Any]
        let dupEntry: [String: Any] = ["bundleID": "com.apple.Terminal", "name": "Dup", "behavior": "lockEnglish"]
        let originalApps = dupObject["englishApps"] as! [[String: Any]]
        dupObject["englishApps"] = originalApps + [dupEntry]
        let dupData = try JSONSerialization.data(withJSONObject: dupObject)
        let failSettings = McKeySettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        do {
            try failSettings.importJSON(dupData)
            preconditionFailure("duplicate bundleID was accepted")
        } catch McKeySettingsImportError.invalidPreference(let key) {
            precondition(key == "englishApps")
        }
    }
}
