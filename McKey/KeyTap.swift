import Cocoa
import CoreGraphics

private let kInjectedMagic: Int64 = 0x554B4559   // "UKEY" — marks our own events

final class KeyTap {
    let engine = UkEngine()
    var enabled = true {
        didSet { engine.vietKey = enabled; engine.reset() }
    }

    /// Input method + tone-placement style proxy to the ported engine.
    var method: UkInputMethod {
        get { engine.input.im }
        set { engine.setIM(newValue) }
    }
    var modernStyle: Bool {
        get { engine.options.modernStyle }
        set { engine.options.modernStyle = newValue }
    }
    var disableWordStartShortcuts: Bool {
        get { engine.options.disableWordStartShortcuts }
        set { engine.options.disableWordStartShortcuts = newValue }
    }

    var onLanguageToggle: ((Bool) -> Void)?
    var onMouseDown: (() -> Void)?
    var lastKeyAt = ProcessInfo.processInfo.systemUptime

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let src = CGEventSource(stateID: .combinedSessionState)

    private var curShift = false
    private var curCaps = false
    private let axSystem = AXUIElementCreateSystemWide()

    // Language-switch chord tracking: (Ctrl or Fn) + Left-Shift.
    private var leftShiftDown = false
    private var leftControlDown = false
    private var fnDown = false
    private var armed = false

    init() {
        engine.vietKey = enabled
        engine.keyCheck = { [weak self] in (self?.curShift ?? false, self?.curCaps ?? false) }
    }

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
            return Unmanaged.passUnretained(event)

        case .keyDown:
            return handleKeyDown(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        lastKeyAt = ProcessInfo.processInfo.systemUptime

        // Any real key cancels a pending language-switch chord.
        armed = false

        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        curShift = flags.contains(.maskShift)
        curCaps = flags.contains(.maskAlphaShift)
        let pass = Unmanaged.passUnretained(event)

        // Let command/control/option shortcuts through untouched.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) ||
           flags.contains(.maskAlternate) {
            resetWord()
            return pass
        }

        // Backspace: let the engine reposition tones if needed.
        if keycode == 51 {
            if !enabled { return pass }
            let r = engine.processBackspace()
            if r.ret != 0 {
                emit(backspaces: r.backspaces, insert: r.output)
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
        guard let typed = producedString(event),
              let scalar = typed.unicodeScalars.first else {
            resetWord()
            return pass
        }

        let result = engine.process(UInt(scalar.value))
        if result.ret == 0 {
            return pass   // engine made no change — original keystroke types itself
        }

        emit(backspaces: result.backspaces, insert: result.output)
        return nil
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

    // MARK: - Language switch hotkey: (Ctrl or Fn) + Left-Shift

    private func handleFlagsChanged(_ event: CGEvent) {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        switch keycode {
        case 56: leftShiftDown = flags.contains(.maskShift)        // left shift
        case 59: leftControlDown = flags.contains(.maskControl)    // left control
        case 63: fnDown = flags.contains(.maskSecondaryFn)         // fn
        default: break
        }

        // Reject if other modifiers (cmd/option/right-shift) are involved.
        let extra = flags.contains(.maskCommand) || flags.contains(.maskAlternate)
        let combo = leftShiftDown && (leftControlDown || fnDown)

        if combo && !extra {
            armed = true
            return
        }

        // All chord modifiers released while still armed → toggle the language.
        if armed && !leftShiftDown && !leftControlDown && !fnDown {
            armed = false
            enabled.toggle()
            onLanguageToggle?(enabled)
        } else if extra {
            armed = false
        }
    }
}
