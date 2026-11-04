// Adapted from PHTV UI/Components/SettingsComponents.swift
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import AppKit
import SwiftUI

struct McKeySettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: McKeyTheme.Layout.headerSpacing) {
            VStack(alignment: .leading, spacing: McKeyTheme.Layout.compactSpacing) {
                Text(title).font(.headline).foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, McKeyTheme.Layout.cardHorizontalPadding)

            content
                .padding(.horizontal, McKeyTheme.Layout.cardHorizontalPadding)
                .padding(.vertical, McKeyTheme.Layout.cardVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: McKeyTheme.Layout.cardCornerRadius)
                        .fill(Color.primary.opacity(McKeyTheme.Layout.cardSurfaceOpacity))
                }
        }
        .frame(maxWidth: McKeyTheme.Window.pageWidth, alignment: .leading)
    }
}

struct McKeySettingsPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: McKeyTheme.Layout.sectionSpacing) {
                content
            }
            .frame(maxWidth: McKeyTheme.Window.pageWidth, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(McKeyTheme.Layout.pagePadding)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct McKeySettingsDivider: View {
    var body: some View { Divider() }
}

@MainActor
func mcKeyText(_ settings: McKeySettings, _ vietnamese: String, _ english: String) -> String {
    settings.vietnameseUI ? vietnamese : english
}

struct McKeySettingsRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let control: Control

    init(_ title: String, subtitle: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: McKeyTheme.Layout.rowSpacing) {
            VStack(alignment: .leading, spacing: McKeyTheme.Layout.compactSpacing) {
                Text(title).font(.body).foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control
                .frame(width: McKeyTheme.Layout.rowColumnWidth, alignment: .trailing)
        }
        .padding(.vertical, McKeyTheme.Layout.rowVerticalPadding)
    }
}

struct McKeyToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        McKeySettingsRow(title, subtitle: subtitle) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(width: McKeyTheme.Layout.toggleWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

struct McKeySettingsPickerRow<Value: Hashable, Options: View>: View {
    let title: String
    let subtitle: String?
    let selectedTitle: String?
    @Binding var selection: Value
    let options: Options

    init(
        _ title: String,
        subtitle: String? = nil,
        selection: Binding<Value>,
        selectedTitle: String? = nil,
        @ViewBuilder options: () -> Options
    ) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.selectedTitle = selectedTitle
        self.options = options()
    }

    var body: some View {
        McKeySettingsRow(title, subtitle: subtitle) {
            Group {
                if let selectedTitle {
                    Menu {
                        Picker(title, selection: $selection) { options }
                            .pickerStyle(.inline)
                    } label: {
                        Text(selectedTitle).lineLimit(McKeyTheme.Layout.singleLineLimit)
                    }
                    .menuStyle(.button)
                    .accessibilityLabel(title)
                    .accessibilityValue(selectedTitle)
                } else {
                    Picker(title, selection: $selection) { options }
                        .labelsHidden()
                        .pickerStyle(.menu)
                }
            }
            .controlSize(.small)
        }
    }
}

struct McKeyShortcutRecorderLabel: View {
    let title: String
    let isRecording: Bool

    var body: some View {
        HStack(spacing: McKeyTheme.Layout.compactSpacing) {
            Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                .foregroundStyle(isRecording ? Color.accentColor : .secondary)
            Text(title)
                .foregroundStyle(isRecording ? Color.accentColor : .primary)
                .lineLimit(McKeyTheme.Layout.singleLineLimit)
                .minimumScaleFactor(McKeyTheme.Layout.smallTextScale)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, McKeyTheme.Layout.cardHorizontalPadding)
        .frame(width: McKeyTheme.Layout.recorderWidth, height: McKeyTheme.Layout.controlHeight)
        .background {
            RoundedRectangle(cornerRadius: McKeyTheme.Layout.recorderCornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: McKeyTheme.Layout.recorderCornerRadius)
                        .stroke(isRecording ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: McKeyTheme.Layout.controlStrokeWidth)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: McKeyTheme.Layout.compactSpacing))
    }
}

final class McKeyHotkeyCaptureView: NSView {
    var onCaptured: ((Int?, NSEvent.ModifierFlags) -> Void)?
    var onCancelled: (() -> Void)?
    var isRecording = false {
        didSet { isRecording ? startRecording() : stopRecording() }
    }
    private var monitor: Any?
    private var heldModifiers: NSEvent.ModifierFlags = []

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isRecording { window?.makeFirstResponder(self) }
    }

    private func startRecording() {
        window?.makeFirstResponder(self)
        guard monitor == nil else { return }
        heldModifiers = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.type == .flagsChanged {
                if !flags.isEmpty {
                    self.heldModifiers.formUnion(flags)
                } else if !self.heldModifiers.isEmpty {
                    self.capture(keyCode: nil, flags: self.heldModifiers)
                    return nil
                }
                return event
            }
            if event.keyCode == 53 && flags.isEmpty {
                self.stopRecording()
                DispatchQueue.main.async { self.onCancelled?() }
                return nil
            }
            self.capture(keyCode: Int(event.keyCode), flags: flags.union(self.heldModifiers))
            return nil
        }
    }

    func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }

    private func capture(keyCode: Int?, flags: NSEvent.ModifierFlags) {
        isRecording = false
        DispatchQueue.main.async { self.onCaptured?(keyCode, flags) }
    }
}

struct McKeyHotkeyCapture: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCaptured: (Int?, NSEvent.ModifierFlags) -> Void
    let onCancelled: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = McKeyHotkeyCaptureView()
        view.onCaptured = onCaptured
        view.onCancelled = onCancelled
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? McKeyHotkeyCaptureView)?.isRecording = isRecording
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        (nsView as? McKeyHotkeyCaptureView)?.stopRecording()
    }
}
