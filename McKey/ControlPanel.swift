// Settings-window bridge adapted from PHTV UI/Shared/WindowController.swift.
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import AppKit
import SwiftUI

final class ControlPanelController: NSWindowController, NSWindowDelegate {
    private weak var app: AppDelegate?
    private let navigation = McKeySettingsNavigator()

    init(app: AppDelegate) {
        self.app = app
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: McKeyTheme.Window.width,
                height: McKeyTheme.Window.height
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MćKey"
        window.titlebarSeparatorStyle = .none
        if !window.setFrameUsingName("McKeySettingsWindow") { window.center() }
        window.setFrameAutosaveName("McKeySettingsWindow")
        window.minSize = NSSize(
            width: McKeyTheme.Window.minimumWidth,
            height: McKeyTheme.Window.minimumHeight
        )
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: McKeySettingsWindowView(
                settings: app.settings,
                navigation: navigation,
                previewSwitchSound: { [weak app] in app?.playModeSound() }
            )
        )
        syncFromState()
    }

    required init?(coder: NSCoder) { fatalError() }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        app?.controlPanelDidHide()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func syncFromState() {
        // McKeySettings publishes the shared runtime state to SwiftUI.
    }

    func about() {
        navigation.selectedPage = .about
        show()
    }
}
