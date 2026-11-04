import Combine
import Foundation

enum McKeyRestoreKey: String, Codable, CaseIterable {
    case esc
    case option
    case control
}

enum McKeyModifierKey: String, Codable, CaseIterable {
    case option
    case control
    case shift
    case fn
}

enum McKeySettingsImportError: LocalizedError {
    case invalidEngineOption(String)
    case invalidHotkey(String)
    case duplicateHotkeys
    case invalidPreference(String)

    var errorDescription: String? {
        switch self {
        case .invalidEngineOption(let name): return "Invalid engine setting: \(name)."
        case .invalidHotkey(let name): return "Invalid keyboard shortcut: \(name)."
        case .duplicateHotkeys: return "The primary and secondary shortcuts must be different."
        case .invalidPreference(let name): return "Invalid setting: \(name)."
        }
    }
}

struct McKeyHotkey: Codable, Equatable {
    var keyCode: Int?
    var control: Bool
    var option: Bool
    var command: Bool
    var shift: Bool
    var fn: Bool

    init(keyCode: Int? = nil, control: Bool = false, option: Bool = false,
         command: Bool = false, shift: Bool = false, fn: Bool = false) {
        self.keyCode = keyCode
        self.control = control
        self.option = option
        self.command = command
        self.shift = shift
        self.fn = fn
    }

    var modifierMask: Int {
        (control ? 1 : 0) | (option ? 2 : 0) | (command ? 4 : 0) | (shift ? 8 : 0) | (fn ? 16 : 0)
    }
}

struct McKeyHotkeyEventResult: Equatable {
    var consumed = false
    var triggeredIndex: Int?
    var chordActive = false
}

enum McKeyRuntimeModifiers {
    static func normalize(control: Bool, option: Bool, command: Bool, shift: Bool, fn: Bool,
                          duplicateModifierSides: Bool = false) -> Int {
        (control ? 1 : 0) | (option ? 2 : 0) | (command ? 4 : 0) | (shift ? 8 : 0) |
        (fn ? 16 : 0) | (duplicateModifierSides ? 32 : 0)
    }

    static func pauseIsActive(flags: Int, pauseMask: Int) -> Bool {
        pauseMask != 0 && flags & pauseMask != 0
    }

    static func shouldRestoreRaw(oldFlags: Int, newFlags: Int, restoreMask: Int,
                                 restoreWasDown: Bool, restoreCancelled: Bool,
                                 hotkeyChordActive: Bool, hotkeyTriggered: Bool,
                                 restoreEnabled: Bool) -> Bool {
        restoreEnabled && restoreMask != 0 && restoreWasDown &&
        oldFlags & restoreMask != 0 && newFlags & restoreMask == 0 &&
        newFlags == 0 && !restoreCancelled && !hotkeyChordActive && !hotkeyTriggered
    }
}

struct McKeyPauseReducer {
    private(set) var isPaused = false

    mutating func update(flags: Int, pauseMask: Int) -> Bool {
        let next = McKeyRuntimeModifiers.pauseIsActive(flags: flags, pauseMask: pauseMask)
        guard next != isPaused else { return false }
        isPaused = next
        return true
    }

    mutating func reset() { isPaused = false }
}

/// Release-triggered chord state adapted from PHTV's PHTVHotkeyService.
struct McKeyHotkeyReducer {
    private(set) var flags = 0
    private var armedModifierIndex: Int?
    private var pendingKey: (index: Int, keyCode: Int)?
    private var keyPressedWhileModifiersHeld = false

    mutating func flagsChanged(_ newFlags: Int, hotkeys: [McKeyHotkey]) -> McKeyHotkeyEventResult {
        let oldFlags = flags
        flags = newFlags & 0x1f
        guard let index = armedModifierIndex else {
            if let match = hotkeys.enumerated().first(where: { $0.element.keyCode == nil &&
                $0.element.modifierMask != 0 && flags == $0.element.modifierMask }) {
                armedModifierIndex = match.offset
                keyPressedWhileModifiersHeld = false
                return .init(chordActive: true)
            }
            return .init()
        }

        let required = hotkeys.indices.contains(index) ? hotkeys[index].modifierMask : 0
        guard required != 0, flags & ~required == 0 else {
            armedModifierIndex = nil
            return .init()
        }
        if oldFlags & required != 0 && flags & required == 0 {
            armedModifierIndex = nil
            let trigger = keyPressedWhileModifiersHeld ? nil : index
            keyPressedWhileModifiersHeld = false
            return .init(triggeredIndex: trigger)
        }
        return .init(chordActive: true)
    }

    mutating func keyDown(_ keyCode: Int, flags: Int, hotkeys: [McKeyHotkey], isRepeat: Bool) -> McKeyHotkeyEventResult {
        if let pendingKey, pendingKey.keyCode == keyCode {
            return .init(consumed: true)
        }
        if let match = hotkeys.enumerated().first(where: { $0.element.keyCode == keyCode &&
            $0.element.modifierMask != 0 && $0.element.modifierMask == flags & 0x1f }) {
            if !isRepeat { pendingKey = (match.offset, keyCode) }
            return .init(consumed: true)
        }
        if armedModifierIndex != nil {
            keyPressedWhileModifiersHeld = true
            armedModifierIndex = nil
        }
        return .init()
    }

    mutating func keyUp(_ keyCode: Int) -> McKeyHotkeyEventResult {
        guard let pendingKey, pendingKey.keyCode == keyCode else { return .init() }
        self.pendingKey = nil
        return .init(consumed: true, triggeredIndex: pendingKey.index)
    }

    mutating func cancel() {
        armedModifierIndex = nil
        pendingKey = nil
        keyPressedWhileModifiersHeld = false
    }
}

@MainActor
final class McKeySettings: ObservableObject {
    private let defaults: UserDefaults
    private var isApplyingSnapshot = false
    var onChange: (() -> Void)?

    @Published var engine: PHTVOptions { didSet { changed() } }
    @Published var switchSound: Bool { didSet { changed() } }
    @Published var clickSound: Bool { didSet { changed() } }
    @Published var clickSoundDelay: Int { didSet { changed() } }
    @Published var soundVolume: Double { didSet { changed() } }
    @Published var autoSwitchEnabled: Bool { didSet { changed() } }
    @Published var autoSwitchToVietnamese: Bool { didSet { changed() } }
    @Published var autoSwitchDelay: Int { didSet { changed() } }
    @Published var showDialogAtStart: Bool { didSet { changed() } }
    @Published var vietnameseUI: Bool { didSet { changed() } }
    @Published var primaryHotkey: McKeyHotkey { didSet { changed() } }
    @Published var secondaryHotkey: McKeyHotkey { didSet { changed() } }
    @Published var secondaryHotkeyEnabled: Bool { didSet { changed() } }
    @Published var restoreKey: McKeyRestoreKey { didSet { changed() } }
    @Published var pauseEnabled: Bool { didSet { changed() } }
    @Published var pauseKey: McKeyModifierKey { didSet { changed() } }
    @Published var showDockIcon: Bool { didSet { changed() } }
    @Published var alwaysOnTop: Bool { didSet { changed() } }
    @Published var englishApps: [McKeyEnglishApp] { didSet { changed() } }
    @Published var isRecordingHotkey = false { didSet { onChange?() } }

    func englishApp(for bundleID: String?) -> McKeyEnglishApp? {
        guard let bundleID else { return nil }
        return englishApps.first { $0.bundleID == bundleID }
    }

    var switchShortcutText: String {
        let primary = primaryHotkey.displayText
        guard secondaryHotkeyEnabled else { return primary }
        return "\(primary)  \(vietnameseUI ? "hoặc" : "or")  \(secondaryHotkey.displayText)"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decodedEngine = defaults.data(forKey: "phtvEngineOptions")
            .flatMap { try? JSONDecoder().decode(PHTVOptions.self, from: $0) }
        var engineOptions = decodedEngine.flatMap { Self.validate($0) ? $0 : nil } ?? PHTVOptions()
        if decodedEngine == nil {
            if defaults.string(forKey: "method")?.caseInsensitiveCompare("VNI") == .orderedSame { engineOptions.inputType = 1 }
            engineOptions.modernOrthography = defaults.bool(forKey: "modernStyle")
            engineOptions.disableWordStartShortcuts = defaults.bool(forKey: "disableWordStartShortcuts")
        }
        self.engine = engineOptions
        self.switchSound = defaults.object(forKey: "switchSound") == nil ? true : defaults.bool(forKey: "switchSound")
        self.clickSound = defaults.object(forKey: "clickSound") == nil ? true : defaults.bool(forKey: "clickSound")
        let clickDelay = defaults.integer(forKey: "clickSoundDelay")
        self.clickSoundDelay = clickDelay > 0 ? clickDelay : 10
        self.soundVolume = defaults.object(forKey: "soundVolume") == nil ? 1 : min(max(defaults.double(forKey: "soundVolume"), 0), 1)
        self.autoSwitchEnabled = defaults.object(forKey: "autoSwitchEnabled") == nil ? true : defaults.bool(forKey: "autoSwitchEnabled")
        self.autoSwitchToVietnamese = defaults.bool(forKey: "autoSwitchToVietnamese")
        let autoDelay = defaults.integer(forKey: "autoSwitchDelay")
        self.autoSwitchDelay = autoDelay > 0 ? autoDelay : 10
        self.showDialogAtStart = defaults.object(forKey: "showDialogAtStart") == nil ? true : defaults.bool(forKey: "showDialogAtStart")
        self.vietnameseUI = defaults.object(forKey: "vietnameseUI") == nil ? true : defaults.bool(forKey: "vietnameseUI")
        let secondaryEnabled = defaults.object(forKey: "secondaryHotkeyEnabled") == nil
            ? true : defaults.bool(forKey: "secondaryHotkeyEnabled")
        self.secondaryHotkeyEnabled = secondaryEnabled
        let storedPrimary = Self.decode(McKeyHotkey.self, key: "primaryHotkey", defaults: defaults)
        self.primaryHotkey = storedPrimary.flatMap { Self.isValidHotkey($0) ? $0 : nil }
            ?? McKeyHotkey(shift: true, fn: true)
        let storedSecondary = Self.decode(McKeyHotkey.self, key: "secondaryHotkey", defaults: defaults)
        self.secondaryHotkey = secondaryEnabled
            ? (storedSecondary.flatMap { Self.isValidHotkey($0) ? $0 : nil } ?? McKeyHotkey(control: true, shift: true))
            : (storedSecondary ?? McKeyHotkey())
        self.restoreKey = Self.decode(McKeyRestoreKey.self, key: "restoreKey", defaults: defaults) ?? .esc
        self.pauseEnabled = defaults.bool(forKey: "pauseEnabled")
        self.pauseKey = Self.decode(McKeyModifierKey.self, key: "pauseKey", defaults: defaults) ?? .option
        self.showDockIcon = defaults.bool(forKey: "showDockIcon")
        self.alwaysOnTop = defaults.bool(forKey: "alwaysOnTop")
        self.englishApps = Self.decode([McKeyEnglishApp].self, key: "englishApps", defaults: defaults) ?? []
    }

    func resetToDefaults() {
        isApplyingSnapshot = true
        engine = PHTVOptions()
        switchSound = true
        clickSound = true
        clickSoundDelay = 10
        soundVolume = 1
        autoSwitchEnabled = true
        autoSwitchToVietnamese = false
        autoSwitchDelay = 10
        showDialogAtStart = true
        vietnameseUI = true
        primaryHotkey = McKeyHotkey(shift: true, fn: true)
        secondaryHotkey = McKeyHotkey(control: true, shift: true)
        secondaryHotkeyEnabled = true
        restoreKey = .esc
        pauseEnabled = false
        pauseKey = .option
        showDockIcon = false
        alwaysOnTop = false
        englishApps = []
        isApplyingSnapshot = false
        save()
        onChange?()
    }

    func save() {
        guard let engineData = try? JSONEncoder().encode(engine) else { return }
        defaults.set(engineData, forKey: "phtvEngineOptions")
        defaults.set(engine.inputType == 1 ? "VNI" : "Telex", forKey: "method")
        defaults.set(engine.modernOrthography, forKey: "modernStyle")
        defaults.set(engine.disableWordStartShortcuts, forKey: "disableWordStartShortcuts")
        defaults.set(switchSound, forKey: "switchSound")
        defaults.set(clickSound, forKey: "clickSound")
        defaults.set(clickSoundDelay, forKey: "clickSoundDelay")
        defaults.set(min(max(soundVolume, 0), 1), forKey: "soundVolume")
        defaults.set(autoSwitchEnabled, forKey: "autoSwitchEnabled")
        defaults.set(autoSwitchToVietnamese, forKey: "autoSwitchToVietnamese")
        defaults.set(autoSwitchDelay, forKey: "autoSwitchDelay")
        defaults.set(showDialogAtStart, forKey: "showDialogAtStart")
        defaults.set(vietnameseUI, forKey: "vietnameseUI")
        Self.encode(primaryHotkey, key: "primaryHotkey", defaults: defaults)
        Self.encode(secondaryHotkey, key: "secondaryHotkey", defaults: defaults)
        defaults.set(secondaryHotkeyEnabled, forKey: "secondaryHotkeyEnabled")
        Self.encode(restoreKey, key: "restoreKey", defaults: defaults)
        defaults.set(pauseEnabled, forKey: "pauseEnabled")
        Self.encode(pauseKey, key: "pauseKey", defaults: defaults)
        defaults.set(showDockIcon, forKey: "showDockIcon")
        defaults.set(alwaysOnTop, forKey: "alwaysOnTop")
        Self.encode(englishApps, key: "englishApps", defaults: defaults)
    }

    func exportJSON() throws -> Data {
        try JSONEncoder().encode(Snapshot(settings: self))
    }

    func importJSON(_ data: Data) throws {
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        try Self.validate(snapshot)
        isApplyingSnapshot = true
        engine = snapshot.engine
        switchSound = snapshot.switchSound
        clickSound = snapshot.clickSound
        clickSoundDelay = snapshot.clickSoundDelay
        soundVolume = snapshot.soundVolume
        autoSwitchEnabled = snapshot.autoSwitchEnabled
        autoSwitchToVietnamese = snapshot.autoSwitchToVietnamese
        autoSwitchDelay = snapshot.autoSwitchDelay
        showDialogAtStart = snapshot.showDialogAtStart
        vietnameseUI = snapshot.vietnameseUI
        primaryHotkey = snapshot.primaryHotkey
        secondaryHotkey = snapshot.secondaryHotkey
        secondaryHotkeyEnabled = snapshot.secondaryHotkeyEnabled
        restoreKey = snapshot.restoreKey
        pauseEnabled = snapshot.pauseEnabled
        pauseKey = snapshot.pauseKey
        showDockIcon = snapshot.showDockIcon
        alwaysOnTop = snapshot.alwaysOnTop
        englishApps = snapshot.englishApps ?? []
        isApplyingSnapshot = false
        save()
        onChange?()
    }

    private func changed() {
        guard !isApplyingSnapshot else { return }
        save()
        onChange?()
    }

    private static func encode<T: Encodable>(_ value: T, key: String, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func validate(_ engine: PHTVOptions) -> Bool {
        (0...3).contains(engine.inputType) && (0...4).contains(engine.codeTable) &&
        (0...1).contains(engine.autoRestoreEnglishWordMode) &&
        !engine.customConsonants.contains(where: { $0.isEmpty || $0.count > 8 }) &&
        engine.customConsonants.count <= 32
    }

    private static func validate(_ hotkey: McKeyHotkey, name: String) throws {
        if let keyCode = hotkey.keyCode, !(0...127).contains(keyCode) {
            throw McKeySettingsImportError.invalidHotkey(name)
        }
        if hotkey.modifierMask == 0 {
            throw McKeySettingsImportError.invalidHotkey(name)
        }
    }

    private static func isValidHotkey(_ hotkey: McKeyHotkey) -> Bool {
        let keyCodeIsValid = hotkey.keyCode.map { (0...127).contains($0) } ?? true
        return keyCodeIsValid && hotkey.modifierMask != 0
    }

    private static func validate(_ snapshot: Snapshot) throws {
        let engine = snapshot.engine
        guard (0...3).contains(engine.inputType) else { throw McKeySettingsImportError.invalidEngineOption("inputType") }
        guard (0...4).contains(engine.codeTable) else { throw McKeySettingsImportError.invalidEngineOption("codeTable") }
        guard (0...1).contains(engine.autoRestoreEnglishWordMode) else {
            throw McKeySettingsImportError.invalidEngineOption("autoRestoreEnglishWordMode")
        }
        guard engine.customConsonants.count <= 32,
              !engine.customConsonants.contains(where: { $0.isEmpty || $0.count > 8 }) else {
            throw McKeySettingsImportError.invalidEngineOption("customConsonants")
        }
        try validate(snapshot.primaryHotkey, name: "primary")
        if snapshot.secondaryHotkeyEnabled { try validate(snapshot.secondaryHotkey, name: "secondary") }
        if snapshot.secondaryHotkeyEnabled && snapshot.primaryHotkey == snapshot.secondaryHotkey {
            throw McKeySettingsImportError.duplicateHotkeys
        }
        guard (1...300).contains(snapshot.clickSoundDelay), (1...300).contains(snapshot.autoSwitchDelay) else {
            throw McKeySettingsImportError.invalidPreference("delay")
        }
        guard snapshot.soundVolume.isFinite && (0...1).contains(snapshot.soundVolume) else {
            throw McKeySettingsImportError.invalidPreference("soundVolume")
        }
        let englishApps = snapshot.englishApps ?? []
        let bundleIDs = englishApps.map(\.bundleID)
        guard !bundleIDs.contains(where: { $0.isEmpty }),
              Set(bundleIDs).count == bundleIDs.count else {
            throw McKeySettingsImportError.invalidPreference("englishApps")
        }
    }

    private struct Snapshot: Codable {
        var engine: PHTVOptions
        var switchSound: Bool
        var clickSound: Bool
        var clickSoundDelay: Int
        var soundVolume: Double
        var autoSwitchEnabled: Bool
        var autoSwitchToVietnamese: Bool
        var autoSwitchDelay: Int
        var showDialogAtStart: Bool
        var vietnameseUI: Bool
        var primaryHotkey: McKeyHotkey
        var secondaryHotkey: McKeyHotkey
        var secondaryHotkeyEnabled: Bool
        var restoreKey: McKeyRestoreKey
        var pauseEnabled: Bool
        var pauseKey: McKeyModifierKey
        var showDockIcon: Bool
        var alwaysOnTop: Bool
        var englishApps: [McKeyEnglishApp]?

        @MainActor init(settings: McKeySettings) {
            engine = settings.engine
            switchSound = settings.switchSound
            clickSound = settings.clickSound
            clickSoundDelay = settings.clickSoundDelay
            soundVolume = settings.soundVolume
            autoSwitchEnabled = settings.autoSwitchEnabled
            autoSwitchToVietnamese = settings.autoSwitchToVietnamese
            autoSwitchDelay = settings.autoSwitchDelay
            showDialogAtStart = settings.showDialogAtStart
            vietnameseUI = settings.vietnameseUI
            primaryHotkey = settings.primaryHotkey
            secondaryHotkey = settings.secondaryHotkey
            secondaryHotkeyEnabled = settings.secondaryHotkeyEnabled
            restoreKey = settings.restoreKey
            pauseEnabled = settings.pauseEnabled
            pauseKey = settings.pauseKey
            showDockIcon = settings.showDockIcon
            alwaysOnTop = settings.alwaysOnTop
            englishApps = settings.englishApps
        }
    }
}

private extension McKeyHotkey {
    var displayText: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        if fn { parts.append("fn") }
        if let keyCode { parts.append("Key \(keyCode)") }
        return parts.joined(separator: " ")
    }
}
