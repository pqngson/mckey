import Cocoa
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let tap = KeyTap()
    let defaults = UserDefaults.standard
    let settings = McKeySettings()
    private var statusItem: NSStatusItem!
    private var panel: ControlPanelController?
    private weak var switchItem: NSMenuItem?
    private var gateWindow: NSWindow?
    private var gateTimer: Timer?

    private(set) var lastActivityAt = ProcessInfo.processInfo.systemUptime
    private var lastTextFieldAt: TimeInterval = -1e9
    private var manualAXSetAt: TimeInterval = -1e9
    private var autoSwitchTimer: Timer?
    private var englishAppRules = McKeyEnglishAppRuleState()
    private var currentFrontBundleID: String?
    private let logger = Logger(subsystem: "com.qngson.mckey", category: "click")

    /// Whether the UI is shown in Vietnamese (shared by menu + dialog).
    var viUI: Bool { settings.vietnameseUI }
    func L(_ viText: String, _ enText: String) -> String { viUI ? viText : enText }

    // MARK: - App Preferences

    var switchSound: Bool { get { settings.switchSound } set { settings.switchSound = newValue } }
    var clickSound: Bool { get { settings.clickSound } set { settings.clickSound = newValue } }
    var clickSoundDelay: Int { get { settings.clickSoundDelay } set { settings.clickSoundDelay = newValue } }
    var soundVolume: Double { get { settings.soundVolume } set { settings.soundVolume = newValue } }
    var autoSwitchEnabled: Bool { get { settings.autoSwitchEnabled } set { settings.autoSwitchEnabled = newValue } }
    var autoSwitchToVietnamese: Bool { get { settings.autoSwitchToVietnamese } set { settings.autoSwitchToVietnamese = newValue } }
    var autoSwitchDelay: Int { get { settings.autoSwitchDelay } set { settings.autoSwitchDelay = newValue } }

    func noteActivity() {
        lastActivityAt = ProcessInfo.processInfo.systemUptime
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadPreferences()
        settings.onChange = { [weak self] in
            guard let self else { return }
            self.noteActivity()
            self.applySettings()
            self.refresh()
        }
        buildMainMenu()
        setupStatusItem()

        tap.onLanguageToggle = { [weak self] _ in
            DispatchQueue.main.async { self?.languageDidSwitch() }
        }
        tap.onMouseDown = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.handleMouseDown(retry: false)
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(focusChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        refresh()

        // The app is useless without Accessibility — block on a gate until granted.
        if AXIsProcessTrusted() {
            finishStartup()
        } else {
            showAccessibilityGate()
        }
    }

    /// Start the keyboard tap and (optionally) show the control panel.
    private func finishStartup() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let bundleID = frontApp.bundleIdentifier
            tap.setFrontmostApp(bundleID: bundleID)
            if bundleID != Bundle.main.bundleIdentifier {
                currentFrontBundleID = bundleID
                applyEnglishAppRule()
            }
            let pid = frontApp.processIdentifier
            if pid != ProcessInfo.processInfo.processIdentifier {
                FocusProbe.enableManualAX(pid: pid)
                manualAXSetAt = ProcessInfo.processInfo.systemUptime
            }
        }
        _ = tap.start()
        refresh()
        startAutoSwitchTimer()
        if settings.showDialogAtStart {
            showControlPanel()
        } else {
            updateActivationPolicy()
        }
    }

    private func startAutoSwitchTimer() {
        autoSwitchTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleAutoSwitchTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoSwitchTimer = timer
    }

    private func applyEnglishAppRule() {
        let result = englishAppRules.activate(bundleID: currentFrontBundleID, rule: settings.englishApp(for: currentFrontBundleID), currentVietnamese: tap.enabled)
        tap.languageLock = result.lock
        if tap.enabled != result.vietnamese { tap.enabled = result.vietnamese; languageDidSwitch(silent: true) } else { refresh() }
    }

    private func handleAutoSwitchTick() {
        guard autoSwitchEnabled else { return }
        let target = autoSwitchToVietnamese
        if target && tap.languageLock == .english { return }
        if !target && tap.languageLock == .vietnamese { return }
        guard tap.enabled != target else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - max(tap.lastKeyAt, lastActivityAt) >= Double(autoSwitchDelay) {
            tap.enabled = target
            languageDidSwitch()
        }
    }

    private func handleMouseDown(retry: Bool) {
        guard switchSound && clickSound else { return }
        let (isText, role, bundleID) = FocusProbe.textInputFocused()
        let now = ProcessInfo.processInfo.systemUptime
        if !isText {
            if !retry && now - manualAXSetAt < 2.0 {
                logger.notice("handleMouseDown outcome=retry-scheduled bundleID=\(bundleID, privacy: .public) role=\(role, privacy: .public) isText=\(isText, privacy: .public) retry=\(retry, privacy: .public)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.handleMouseDown(retry: true)
                }
                return
            } else {
                logger.notice("handleMouseDown outcome=not-text bundleID=\(bundleID, privacy: .public) role=\(role, privacy: .public) isText=\(isText, privacy: .public) retry=\(retry, privacy: .public)")
                return
            }
        }
        let away = now - max(lastTextFieldAt, tap.lastKeyAt)
        lastTextFieldAt = now
        if away >= Double(clickSoundDelay) {
            playModeSound()
            logger.notice("handleMouseDown outcome=played bundleID=\(bundleID, privacy: .public) role=\(role, privacy: .public) isText=\(isText, privacy: .public) retry=\(retry, privacy: .public) away=\(away, privacy: .public)")
        } else {
            logger.notice("handleMouseDown outcome=away-suppressed bundleID=\(bundleID, privacy: .public) role=\(role, privacy: .public) isText=\(isText, privacy: .public) retry=\(retry, privacy: .public) away=\(away, privacy: .public)")
        }
    }

    // MARK: - Preferences

    func loadPreferences() {
        if defaults.object(forKey: "enabled") != nil {
            tap.enabled = defaults.bool(forKey: "enabled")
        }
        settings.save()
        applySettings()
    }

    func savePreferences() {
        defaults.set(tap.enabled, forKey: "enabled")
        settings.save()
    }

    private func applySettings() {
        tap.apply(options: settings.engine, primaryHotkey: settings.primaryHotkey,
                  secondaryHotkey: settings.secondaryHotkey,
                  secondaryHotkeyEnabled: settings.secondaryHotkeyEnabled,
                  restoreKey: settings.restoreKey, pauseEnabled: settings.pauseEnabled,
                  pauseKey: settings.pauseKey,
                  isRecordingHotkey: settings.isRecordingHotkey)
        updateActivationPolicy()
        applyEnglishAppRule()
    }

    @objc private func focusChanged(_ notification: Notification) {
        tap.resetWord()
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let bundleID = app.bundleIdentifier
            tap.setFrontmostApp(bundleID: bundleID)
            if bundleID != Bundle.main.bundleIdentifier {
                currentFrontBundleID = bundleID
                applyEnglishAppRule()
            }
            let pid = app.processIdentifier
            if pid != ProcessInfo.processInfo.processIdentifier {
                FocusProbe.enableManualAX(pid: pid)
                manualAXSetAt = ProcessInfo.processInfo.systemUptime
            }
        }
    }

    // MARK: - Accessibility gate (blocks until permission is granted)

    private func showAccessibilityGate() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
                         styleMask: [.titled], backing: .buffered, defer: false)
        w.title = L("Cần quyền Trợ năng", "Accessibility Required")
        w.titlebarSeparatorStyle = .none
        w.isReleasedWhenClosed = false
        w.level = .floating
        guard let c = w.contentView else { return }

        if let icon = NSApp.applicationIconImage {
            let iv = NSImageView(frame: NSRect(x: (460 - 76) / 2, y: 200, width: 76, height: 76))
            iv.image = icon
            iv.imageScaling = .scaleProportionallyUpOrDown
            c.addSubview(iv)
        }

        let title = NSTextField(labelWithString: L("MćKey cần quyền Trợ năng", "MćKey needs Accessibility access"))
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 168, width: 420, height: 24)
        c.addSubview(title)

        let msg = NSTextField(wrappingLabelWithString: L(
            "Để gõ tiếng Việt, MćKey cần quyền Trợ năng để đọc và sửa phím. Hãy bật MćKey trong Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Trợ năng. Cửa sổ này tự đóng khi được cấp quyền.",
            "To type Vietnamese, MćKey needs Accessibility permission to read and edit keystrokes. Enable MćKey in System Settings › Privacy & Security › Accessibility. This window closes automatically once granted."))
        msg.alignment = .center
        msg.font = .systemFont(ofSize: 12)
        msg.frame = NSRect(x: 30, y: 92, width: 400, height: 72)
        c.addSubview(msg)

        let open = NSButton(title: L("Mở Cài đặt…", "Open Settings…"),
                            target: self, action: #selector(openAccessibilitySettings))
        open.bezelStyle = .rounded
        open.keyEquivalent = "\r"
        open.frame = NSRect(x: (460 - 170) / 2, y: 48, width: 170, height: 30)
        c.addSubview(open)

        let quit = NSButton(title: L("Thoát", "Quit"), target: self, action: #selector(quit))
        quit.bezelStyle = .rounded
        quit.frame = NSRect(x: (460 - 100) / 2, y: 14, width: 100, height: 28)
        c.addSubview(quit)

        w.center()
        w.makeKeyAndOrderFront(nil)
        gateWindow = w

        // Trigger the system permission prompt.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        gateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self = self, AXIsProcessTrusted() else { return }
                t.invalidate(); self.gateTimer = nil
                self.gateWindow?.orderOut(nil); self.gateWindow = nil
                self.finishStartup()
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Activation policy (full menu bar only while a window is open)

    private func updateActivationPolicy() {
        let needsRegular = settings.showDockIcon || (gateWindow != nil) || (panel?.window?.isVisible ?? false)
        NSApp.setActivationPolicy(needsRegular ? .regular : .accessory)
        panel?.window?.level = settings.alwaysOnTop ? .floating : .normal
    }

    /// Called by the control panel when it is hidden/closed.
    func controlPanelDidHide() {
        guard gateWindow == nil else { updateActivationPolicy(); return }
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        panel?.window?.level = settings.alwaysOnTop ? .floating : .normal
    }

    // MARK: - Application main menu (shown while the dialog is open)

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "MćKey")
        appItem.submenu = appMenu
        let about = NSMenuItem(title: L("Thông tin MćKey", "About MćKey"),
                               action: #selector(menuAbout), keyEquivalent: "")
        about.target = self
        about.image = symbol("info.circle")
        appMenu.addItem(about)
        appMenu.addItem(.separator())
        let reset = NSMenuItem(title: L("Đặt lại mặc định", "Reset to Default"),
                               action: #selector(menuReset), keyEquivalent: "")
        reset.target = self
        reset.image = symbol("arrow.counterclockwise")
        appMenu.addItem(reset)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: L("Thoát MćKey", "Quit MćKey"),
                                  action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = symbol("xmark.rectangle")
        appMenu.addItem(quitItem)

        // Edit menu so the dialog's text fields get standard copy/paste/select-all.
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: L("Sửa", "Edit"))
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: L("Cắt", "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("Sao chép", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("Dán", "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("Chọn tất cả", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func menuAbout() {
        showControlPanel()
        panel?.about()
    }

    @objc private func menuReset() { resetToDefaults() }

    func resetToDefaults() {
        settings.resetToDefaults()
        tap.resetWord()
        savePreferences()
        refresh()
        panel?.syncFromState()
    }

    // MARK: - Status item (VI / EN badge)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuildMenu()
    }

    /// Rebuilds the status-bar menu in the current UI language.
    func rebuildMenu() {
        buildMainMenu()   // keep the application menu in the same language
        let menu = NSMenu()
        menu.autoenablesItems = false

        // "Switch to <language>" with the shortcut shown right-aligned. A plain
        // menu item never greys out the way an NSSwitch does in a background app.
        let switchItem = NSMenuItem(title: "", action: #selector(toggleEnabled), keyEquivalent: "")
        switchItem.target = self
        switchItem.image = symbol("globe")
        self.switchItem = switchItem
        menu.addItem(switchItem)
        updateSwitchItem()

        menu.addItem(.separator())
        let cp = NSMenuItem(title: L("Cài đặt…", "Settings…"),
                            action: #selector(showControlPanel), keyEquivalent: "")
        cp.target = self
        cp.image = symbol("gearshape")
        menu.addItem(cp)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("Thoát MćKey", "Quit MćKey"),
                              action: #selector(quit), keyEquivalent: "")
        quit.target = self
        quit.image = symbol("xmark.rectangle")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func symbol(_ name: String) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
    }

    /// "Switch to <other language>" with the ⌃⇧ shortcut right-aligned.
    private func updateSwitchItem() {
        guard let item = switchItem else { return }
        if tap.languageLock != .none {
            item.isEnabled = false
            item.attributedTitle = nil
            item.title = tap.languageLock == .english
                ? L("Khoá tiếng Anh trong ứng dụng này", "English locked in this app")
                : L("Giữ tiếng Việt trong ứng dụng này", "Vietnamese kept in this app")
            return
        }
        item.isEnabled = true
        let target = tap.enabled ? "EN" : "VI"
        let title = L("Chuyển sang ", "Switch to ") + target
        let shortcut = settings.switchShortcutText
        let full = "\(title)\t\(shortcut)"

        let para = NSMutableParagraphStyle()
        para.tabStops = [NSTextTab(textAlignment: .right, location: 240)]
        let attr = NSMutableAttributedString(string: full)
        let whole = NSRange(location: 0, length: (full as NSString).length)
        attr.addAttribute(.font, value: NSFont.menuFont(ofSize: 0), range: whole)
        attr.addAttribute(.paragraphStyle, value: para, range: whole)
        let scRange = (full as NSString).range(of: shortcut)
        attr.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: scRange)
        item.attributedTitle = attr
    }

    /// Theme-aware template badge: VI is filled, EN is outlined; the menu bar
    /// tints the template to match light/dark appearance automatically.
    private func makeBadge(_ text: String, filled: Bool) -> NSImage {
        McKeyBadge.make(text, filled: filled)
    }

    func refresh() {
        if let button = statusItem?.button {
            button.image = makeBadge(tap.enabled ? "VI" : "EN", filled: tap.enabled)
            button.imagePosition = .imageOnly
        }
        updateSwitchItem()
        panel?.syncFromState()
    }

    // MARK: - Actions

    func languageDidSwitch(silent: Bool = false) {
        lastActivityAt = ProcessInfo.processInfo.systemUptime
        savePreferences()
        if !silent { playSwitchSound() }
        refresh()
    }

    @objc func toggleEnabled() {
        if (tap.languageLock == .english && !tap.enabled) || (tap.languageLock == .vietnamese && tap.enabled) { NSSound.beep(); return }
        tap.enabled.toggle()
        languageDidSwitch()
    }

    func playModeSound() {
        let name = tap.enabled ? "Tink" : "Pop"
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.stop()
            sound.volume = Float(soundVolume)
            sound.play()
        }
    }

    private func playSwitchSound() {
        guard switchSound else { return }
        playModeSound()
    }

    @objc func showControlPanel() {
        if panel == nil { panel = ControlPanelController(app: self) }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        panel?.show()
        updateActivationPolicy()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
