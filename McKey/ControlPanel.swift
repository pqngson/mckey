import Cocoa
import ServiceManagement

final class ControlPanelController: NSWindowController, NSWindowDelegate {
    private weak var app: AppDelegate!
    private var vi: Bool { app.defaults.object(forKey: "vietnameseUI") == nil ? true
                            : app.defaults.bool(forKey: "vietnameseUI") }

    // Controls we read back from.
    private var charsetPopup: NSPopUpButton!
    private var methodPopup: NSPopUpButton!
    private var modernCheck: NSButton!
    private var showAtStartCheck: NSButton!
    private var launchLoginCheck: NSButton!
    private var vietUICheck: NSButton!
    private var aboutWindow: NSWindow?

    init(app: AppDelegate) {
        self.app = app
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        win.title = "MćKey"
        win.titlebarSeparatorStyle = .none   // cleaner — no divider under the title bar
        super.init(window: win)
        win.delegate = self
        buildUI()
        syncFromState()
    }

    required init?(coder: NSCoder) { fatalError() }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === window {
            app.controlPanelDidHide()
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    // Bilingual label helper.
    private func L(_ viText: String, _ enText: String) -> String { vi ? viText : enText }

    // MARK: - Build

    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.subviews.forEach { $0.removeFromSuperview() }

        // Label column is widened ~25% (80 → 100); controls shift right to match.
        let labelW: CGFloat = 100
        let ctlX: CGFloat = 120

        // ===== Section: Điều khiển / Control =====
        let ctrlBox = section(L("Điều khiển", "Control"), in: content,
                              frame: NSRect(x: 12, y: 276, width: 336, height: 96))

        ctrlBox.contentView?.addSubview(label(L("Bảng mã:", "Charset:"), x: 12, y: 62, w: labelW))
        charsetPopup = popup(items: ["Unicode"], x: ctlX, y: 60, w: 200)
        charsetPopup.isEnabled = false   // always Unicode
        ctrlBox.contentView?.addSubview(charsetPopup)

        ctrlBox.contentView?.addSubview(label(L("Kiểu gõ:", "Input method:"), x: 12, y: 32, w: labelW))
        methodPopup = popup(items: ["Telex", "VNI"], x: ctlX, y: 30, w: 200)
        methodPopup.target = self; methodPopup.action = #selector(apply)
        ctrlBox.contentView?.addSubview(methodPopup)

        ctrlBox.contentView?.addSubview(label(L("Phím chuyển:", "Switch key:"), x: 12, y: 4, w: labelW))
        let switchHint = label("fn ⇧   \(L("hoặc", "or"))   ⌃ ⇧", x: ctlX, y: 4, w: 200)
        switchHint.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        ctrlBox.contentView?.addSubview(switchHint)

        // ===== Section: Tùy chọn khác / Other options =====
        let optBox = section(L("Tùy chọn khác", "Other options"), in: content,
                             frame: NSRect(x: 12, y: 178, width: 336, height: 38))

        modernCheck = check(L("Đặt dấu oà, uý (thay vì òa, úy)", "Old-style tone (oà, uý)"), x: 12, y: 6, w: 320)
        modernCheck.target = self; modernCheck.action = #selector(apply)
        optBox.contentView?.addSubview(modernCheck)

        // ===== Section: Hệ thống / System =====
        let sysBox = section(L("Hệ thống", "System"), in: content,
                             frame: NSRect(x: 12, y: 58, width: 336, height: 84))

        showAtStartCheck = check(L("Bật hội thoại này khi khởi động", "Show this dialog at launch"), x: 12, y: 54, w: 320)
        showAtStartCheck.target = self; showAtStartCheck.action = #selector(apply)
        sysBox.contentView?.addSubview(showAtStartCheck)

        launchLoginCheck = check(L("Khởi động cùng macOS", "Launch at login"), x: 12, y: 30, w: 320)
        launchLoginCheck.target = self; launchLoginCheck.action = #selector(apply)
        sysBox.contentView?.addSubview(launchLoginCheck)

        vietUICheck = check(L("Giao diện tiếng Việt", "Vietnamese interface"), x: 12, y: 6, w: 320)
        vietUICheck.target = self; vietUICheck.action = #selector(toggleUILanguage)
        sysBox.contentView?.addSubview(vietUICheck)

        // ===== Bottom row: ••• overflow menu (left) + OK default (right) =====
        let more = NSPopUpButton(frame: NSRect(x: 12, y: 14, width: 52, height: 28), pullsDown: true)
        more.bezelStyle = .rounded
        more.addItem(withTitle: "•••")   // label shown on the button (pull-down title)
        let aboutItem = NSMenuItem(title: L("Thông tin MćKey", "About MćKey"),
                                   action: #selector(about), keyEquivalent: "i")
        aboutItem.target = self
        aboutItem.image = symbol("info.circle")
        let resetItem = NSMenuItem(title: L("Đặt lại mặc định", "Reset to Default"),
                                   action: #selector(restoreDefaults), keyEquivalent: "r")
        resetItem.target = self
        resetItem.image = symbol("arrow.counterclockwise")
        let quitItem = NSMenuItem(title: L("Thoát MćKey", "Quit MćKey"),
                                  action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = symbol("xmark.rectangle")
        more.menu?.addItem(aboutItem)
        more.menu?.addItem(resetItem)
        more.menu?.addItem(.separator())
        more.menu?.addItem(quitItem)
        content.addSubview(more)

        let ok = actionButton(L("Đồng ý", "OK"), x: 360 - 12 - 90, y: 14, w: 90, action: #selector(closePanel))
        ok.keyEquivalent = "\r"   // default button → rendered blue by the system
        content.addSubview(ok)
    }

    // MARK: - State sync

    func syncFromState() {
        guard isWindowLoaded, window != nil, methodPopup != nil else { return }
        methodPopup.selectItem(withTitle: app.tap.method.rawValue)
        modernCheck.state = app.tap.modernStyle ? .on : .off
        let showAtStart = app.defaults.object(forKey: "showDialogAtStart") == nil
            || app.defaults.bool(forKey: "showDialogAtStart")
        showAtStartCheck.state = showAtStart ? .on : .off
        launchLoginCheck.state = isLaunchAtLoginEnabled() ? .on : .off
        vietUICheck.state = vi ? .on : .off
    }

    @objc private func apply() {
        app.tap.method = methodPopup.indexOfSelectedItem == 1 ? .vni : .telex
        app.tap.modernStyle = modernCheck.state == .on
        app.tap.resetWord()
        app.defaults.set(showAtStartCheck.state == .on, forKey: "showDialogAtStart")
        setLaunchAtLogin(launchLoginCheck.state == .on)
        app.savePreferences()
        app.refresh()
    }

    // MARK: - Launch at login

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    private func setLaunchAtLogin(_ on: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if on {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("Launch-at-login change failed: \(error)")
        }
    }

    // MARK: - Buttons

    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func closePanel() {
        window?.orderOut(nil)
        app.controlPanelDidHide()
    }

    @objc private func toggleUILanguage() {
        app.defaults.set(vietUICheck.state == .on, forKey: "vietnameseUI")
        buildUI()              // rebuild dialog with new labels
        syncFromState()
        app.rebuildMenu()      // and the status-bar menu
        if let aw = aboutWindow, aw.isVisible {
            buildAboutContent()   // keep an open About window in sync
        }
    }

    @objc func about() {
        if aboutWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 270),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            win.titlebarSeparatorStyle = .none
            win.isReleasedWhenClosed = false
            aboutWindow = win
        }
        buildAboutContent()
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    private func buildAboutContent() {
        guard let win = aboutWindow, let content = win.contentView else { return }
        content.subviews.forEach { $0.removeFromSuperview() }
        win.title = L("Thông tin", "About")

        if let icon = NSApp.applicationIconImage {
            let iv = NSImageView(frame: NSRect(x: (380 - 80) / 2, y: 168, width: 80, height: 80))
            iv.image = icon
            iv.imageScaling = .scaleProportionallyUpOrDown
            content.addSubview(iv)
        }

        let name = NSTextField(labelWithString: "MćKey")
        name.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        name.alignment = .center
        name.frame = NSRect(x: 20, y: 128, width: 340, height: 36)
        content.addSubview(name)

        let version = NSTextField(labelWithString: L("Phiên bản 1.0", "Version 1.0"))
        version.font = NSFont.systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor
        version.alignment = .center
        version.frame = NSRect(x: 20, y: 108, width: 340, height: 18)
        content.addSubview(version)

        let desc = NSTextField(wrappingLabelWithString: L(
            "Bộ gõ tiếng Việt dùng Accessibility — không gạch chân, không lỗi với gợi ý tự động. Hỗ trợ kiểu gõ Telex & VNI.",
            "Vietnamese input via Accessibility — no marked-text underline, autocomplete-safe. Supports Telex & VNI."))
        desc.font = NSFont.systemFont(ofSize: 12)
        desc.alignment = .center
        desc.frame = NSRect(x: 30, y: 44, width: 320, height: 56)
        content.addSubview(desc)
    }

    @objc private func restoreDefaults() {
        app.resetToDefaults()
    }

    // MARK: - Control factory helpers

    /// A grouped box with a header drawn as our own label above it — NSBox's
    /// built-in title clips Vietnamese stacked diacritics (Điều, Hệ, Tùy).
    private func section(_ title: String, in content: NSView, frame: NSRect) -> NSBox {
        let b = NSBox(frame: frame)
        b.titlePosition = .noTitle
        content.addSubview(b)

        let header = NSTextField(labelWithString: title)
        header.font = NSFont.systemFont(ofSize: 11)
        header.textColor = .secondaryLabelColor
        header.frame = NSRect(x: frame.minX + 4, y: frame.maxY + 1, width: frame.width - 8, height: 20)
        content.addSubview(header)
        return b
    }

    private func symbol(_ name: String) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
    }

    private func label(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        // Taller frame so Vietnamese stacked diacritics (ể, ữ, à…) aren't clipped.
        l.frame = NSRect(x: x, y: y, width: w, height: 22)
        return l
    }

    private func popup(items: [String], x: CGFloat, y: CGFloat, w: CGFloat) -> NSPopUpButton {
        let p = NSPopUpButton(frame: NSRect(x: x, y: y, width: w, height: 26))
        p.addItems(withTitles: items)
        return p
    }

    private func check(_ title: String, x: CGFloat, y: CGFloat, w: CGFloat) -> NSButton {
        let b = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        b.frame = NSRect(x: x, y: y, width: w, height: 20)
        return b
    }

    private func actionButton(_ title: String, x: CGFloat, y: CGFloat, w: CGFloat = 110, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.frame = NSRect(x: x, y: y, width: w, height: 28)
        return b
    }
}
