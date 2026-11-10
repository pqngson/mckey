import Cocoa
import CoreGraphics

private let kInjectedMagic: Int64 = 0x554B4559   // "UKEY" — marks our own events

final class KeyTap {
    let engine = PHTVInputEngine()
    var enabled = true {
        didSet { engine.reset() }
    }
    var languageLock: McKeyLanguageLock = .none

    var onLanguageToggle: ((Bool) -> Void)?
    var onMouseDown: (() -> Void)?
    var lastKeyAt = ProcessInfo.processInfo.systemUptime

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let src = CGEventSource(stateID: .combinedSessionState)

    private var curShift = false
    private var curCaps = false
    private let axSystem = AXUIElementCreateSystemWide()
    private var hotkeyReducer = McKeyHotkeyReducer()
    private var hotkeys: [McKeyHotkey] = [McKeyHotkey(control: true, shift: true), McKeyHotkey(shift: true, fn: true)]
    private var secondaryHotkeyEnabled = true
    private var restoreKey: McKeyRestoreKey = .esc
    private var pauseEnabled = false
    private var pauseKey: McKeyModifierKey = .option
    private var pauseReducer = McKeyPauseReducer()
    private var restoreModifierWasDown = false
    private var restoreModifierKeyPressed = false
    private var isRecordingHotkey = false
    private var frontmostBundleID: String?

    init() {
        engine.options = PHTVOptions()
    }

    func apply(options: PHTVOptions, primaryHotkey: McKeyHotkey, secondaryHotkey: McKeyHotkey,
               secondaryHotkeyEnabled: Bool, restoreKey: McKeyRestoreKey,
               pauseEnabled: Bool, pauseKey: McKeyModifierKey,
               isRecordingHotkey: Bool) {
        engine.options = options
        engine.reset()
        hotkeys = [primaryHotkey, secondaryHotkey]
        self.secondaryHotkeyEnabled = secondaryHotkeyEnabled
        self.restoreKey = restoreKey
        self.pauseEnabled = pauseEnabled
        self.pauseKey = pauseKey
        self.isRecordingHotkey = isRecordingHotkey
        pauseReducer.reset()
        restoreModifierWasDown = false
        restoreModifierKeyPressed = false
        hotkeyReducer.cancel()
    }

    func setFrontmostApp(bundleID: String?) { frontmostBundleID = bundleID }

    // MARK: - Lifecycle

    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let me = Unmanaged<KeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func resetWord() { engine.reset() }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Ignore events we injected ourselves.
        if event.getIntegerValueField(.eventSourceUserData) == kInjectedMagic {
            return Unmanaged.passUnretained(event)
        }

        // Re-enable if the tap got disabled by the system.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .leftMouseDown:
            resetWord()
            onMouseDown?()
            return Unmanaged.passUnretained(event)

        case .rightMouseDown:
            resetWord()
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            handleFlagsChanged(event)
            return Unmanaged.passUnretained(event)

        case .keyUp:
            return handleKeyUp(event)

        case .keyDown:
            return handleKeyDown(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        lastKeyAt = ProcessInfo.processInfo.systemUptime
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        curShift = flags.contains(.maskShift)
        curCaps = flags.contains(.maskAlphaShift)
        let pass = Unmanaged.passUnretained(event)

        if restoreModifierIsHeld(flags) { restoreModifierKeyPressed = true }

        let hotkeyResult = hotkeyReducer.keyDown(Int(keycode), flags: normalizedModifiers(flags),
            hotkeys: activeHotkeys, isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        if hotkeyResult.consumed { return nil }

        if pauseReducer.isPaused {
            return pass
        }

        if keycode == 53, restoreKey == .esc, engine.options.restoreOnEscape {
            let restored = engine.restoreRaw()
            if restored.handled {
                emit(backspaces: restored.backspaces, insert: restored.output)
                return nil
            }
        }

        // Let command/control/option shortcuts through untouched.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) ||
           flags.contains(.maskAlternate) {
            resetWord()
            return pass
        }

        // The PHTV adapter handles deletion and tone repositioning itself.
        if keycode == 51 {
            if !enabled { return pass }
            let result = engine.process(keyCode: UInt16(keycode), shift: curShift,
                capsLock: curCaps, characters: "", vietnamese: enabled)
            if result.handled {
                emit(backspaces: result.backspaces, insert: result.output)
                return nil
            }
            return pass
        }

        // Navigation / control keys reset the engine (frontend doesn't filter them).
        switch keycode {
        case 36, 76, 48, 53,                 // return, enter, tab, esc
             123, 124, 125, 126,             // arrows
             115, 116, 119, 121, 117:        // home, pageup, end, pagedown, fwd-del
            resetWord()
            return pass
        default:
            break
        }

        if !enabled { return pass }

        // Feed the produced character to the engine (letters, digits, space,
        // punctuation — the engine classifies and handles word breaks itself).
        guard let typed = producedString(event), !typed.isEmpty else {
            resetWord()
            return pass
        }

        let result = process(typed, keyCode: UInt16(keycode), shift: curShift, capsLock: curCaps)
        if !result.handled {
            return pass   // engine made no change — original keystroke types itself
        }

        emit(backspaces: result.backspaces, insert: result.output)
        return nil
    }

    private func handleKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let result = hotkeyReducer.keyUp(keycode)
        if let index = result.triggeredIndex { triggerLanguageSwitch(for: index) }
        return result.consumed ? nil : Unmanaged.passUnretained(event)
    }

    private func process(_ typed: String, keyCode: UInt16, shift: Bool, capsLock: Bool) -> PHTVResult {
        engine.process(keyCode: keyCode, shift: shift, capsLock: capsLock,
                       characters: typed, vietnamese: enabled)
    }

    // MARK: - Autocomplete detection

    private func focusedElementHasSelection() -> Bool {
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(axSystem, kAXFocusedUIElementAttribute as CFString, &focused) == .success else {
            return false
        }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.05)
        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText) == .success else {
            return false
        }
        let text = selectedText as? String ?? ""
        return !text.isEmpty
    }

    // MARK: - Injection

    private func emit(backspaces: Int, insert: String) {
        if backspaces > 0 && focusedElementHasSelection() {
            emitInsertThenDelete(backspaces: backspaces, insert: insert)
            return
        }
        for _ in 0..<max(0, backspaces) {
            postKey(virtualKey: 51)   // Backspace
        }
        if !insert.isEmpty {
            postUnicode(insert)
        }
    }

    /// Fallback for fields with inline autocomplete: insert first (dismisses
    /// the suggestion), then go back and delete the old characters.
    private func emitInsertThenDelete(backspaces: Int, insert: String) {
        if !insert.isEmpty {
            postUnicode(insert)
        }
        let insertLen = insert.count
        for _ in 0..<insertLen {
            postKey(virtualKey: 123)   // Left Arrow
        }
        for _ in 0..<backspaces {
            postKey(virtualKey: 51)    // Backspace
        }
        for _ in 0..<insertLen {
            postKey(virtualKey: 124)   // Right Arrow
        }
    }

    private func postKey(virtualKey: CGKeyCode) {
        if let down = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true) {
            down.setIntegerValueField(.eventSourceUserData, value: kInjectedMagic)
            down.post(tap: .cgSessionEventTap)
        }
        if let up = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false) {
            up.setIntegerValueField(.eventSourceUserData, value: kInjectedMagic)
            up.post(tap: .cgSessionEventTap)
        }
    }

    private func postUnicode(_ s: String) {
        var units = Array(s.utf16)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) else { return }
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        down.setIntegerValueField(.eventSourceUserData, value: kInjectedMagic)
        up.setIntegerValueField(.eventSourceUserData, value: kInjectedMagic)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private func producedString(_ event: CGEvent) -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let oldModifiers = normalizedModifiers(previousFlags)
        let newModifiers = normalizedModifiers(flags)
        updatePause(newFlags: newModifiers)

        let restoreMask = restoreModifierMask
        let wasRestoredModifierDown = restoreModifierWasDown
        let restoreWasCancelled = restoreModifierKeyPressed

        let result = hotkeyReducer.flagsChanged(newModifiers, hotkeys: activeHotkeys)
        if let index = result.triggeredIndex {
            triggerLanguageSwitch(for: index)
        }

        if McKeyRuntimeModifiers.shouldRestoreRaw(oldFlags: oldModifiers, newFlags: newModifiers,
            restoreMask: restoreMask, restoreWasDown: wasRestoredModifierDown,
            restoreCancelled: restoreWasCancelled, hotkeyChordActive: result.chordActive,
            hotkeyTriggered: result.triggeredIndex != nil, restoreEnabled: engine.options.restoreOnEscape) {
            let restored = engine.restoreRaw()
            if restored.handled { emit(backspaces: restored.backspaces, insert: restored.output) }
        }
        if restoreMask != 0 && newModifiers & restoreMask != 0 {
            restoreModifierWasDown = true
            if newModifiers & ~restoreMask != 0 { restoreModifierKeyPressed = true }
        }
        if restoreMask != 0 && oldModifiers & restoreMask != 0 && newModifiers & restoreMask == 0 {
            restoreModifierWasDown = false
            restoreModifierKeyPressed = false
        }
        previousFlags = flags
        _ = keycode
    }

    private var previousFlags: CGEventFlags = []

    private var activeHotkeys: [McKeyHotkey] {
        if isRecordingHotkey { return [] }
        let configured = secondaryHotkeyEnabled ? hotkeys : Array(hotkeys.prefix(1))
        guard pauseEnabled else { return configured }
        return configured.filter { $0.modifierMask & pauseModifierMask == 0 }
    }

    private var restoreModifierMask: Int {
        guard engine.options.restoreOnEscape else { return 0 }
        switch restoreKey {
        case .esc: return 0
        case .option: return 2
        case .control: return 1
        }
    }

    private func normalizedModifiers(_ flags: CGEventFlags) -> Int {
        let raw = UInt64(flags.rawValue)
        let hasBothSides = ((raw & 0x0001) != 0 && (raw & 0x2000) != 0) ||
            ((raw & 0x0002) != 0 && (raw & 0x0004) != 0) ||
            ((raw & 0x0008) != 0 && (raw & 0x0010) != 0) ||
            ((raw & 0x0020) != 0 && (raw & 0x0040) != 0)
        return McKeyRuntimeModifiers.normalize(control: flags.contains(.maskControl),
            option: flags.contains(.maskAlternate), command: flags.contains(.maskCommand),
            shift: flags.contains(.maskShift), fn: flags.contains(.maskSecondaryFn),
            duplicateModifierSides: hasBothSides)
    }

    private func restoreModifierIsHeld(_ flags: CGEventFlags) -> Bool {
        let mask = restoreModifierMask
        return mask != 0 && normalizedModifiers(flags) & mask != 0
    }

    private var pauseModifierMask: Int {
        switch pauseKey {
        case .option: return 2
        case .control: return 1
        case .shift: return 8
        case .fn: return 16
        }
    }

    private func updatePause(newFlags: Int) {
        let mask = pauseEnabled ? pauseModifierMask : 0
        if pauseReducer.update(flags: newFlags, pauseMask: mask) { resetWord() }
    }

    private func triggerLanguageSwitch(for index: Int) {
        if languageLock == .english && !enabled { return }
        if languageLock == .vietnamese && enabled { return }
        guard index < activeHotkeys.count else { return }
        enabled.toggle()
        onLanguageToggle?(enabled)
    }
}
