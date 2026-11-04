// Adapted from PHTV UI/SettingsTabs/HotkeySettingsView.swift and HotkeyConfigView.swift
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import AppKit
import SwiftUI

private enum McKeyShortcutSlot: Hashable { case primary, secondary }

struct HotkeySettingsView: View {
    @ObservedObject var settings: McKeySettings
    let previewSwitchSound: () -> Void
    @State private var recording: McKeyShortcutSlot?
    @State private var invalidCapture = false

    private var restoreConflict: Bool {
        guard settings.engine.restoreOnEscape else { return false }
        return switch settings.restoreKey {
        case .esc: false
        case .option: settings.primaryHotkey.option || (settings.secondaryHotkeyEnabled && settings.secondaryHotkey.option)
        case .control: settings.primaryHotkey.control || (settings.secondaryHotkeyEnabled && settings.secondaryHotkey.control)
        }
    }

    private var duplicateConflict: Bool {
        settings.secondaryHotkeyEnabled && settings.primaryHotkey == settings.secondaryHotkey
    }

    private var pauseSwitchConflict: Bool {
        guard settings.pauseEnabled else { return false }
        let activeHotkeys = [settings.primaryHotkey] + (settings.secondaryHotkeyEnabled ? [settings.secondaryHotkey] : [])
        return activeHotkeys.contains { hotkey in
            return switch settings.pauseKey {
            case .option: hotkey.option
            case .control: hotkey.control
            case .shift: hotkey.shift
            case .fn: hotkey.fn
            }
        }
    }

    private var pauseRestoreConflict: Bool {
        guard settings.pauseEnabled && settings.engine.restoreOnEscape else { return false }
        return switch (settings.pauseKey, settings.restoreKey) {
        case (.option, .option), (.control, .control): true
        default: false
        }
    }

    var body: some View {
        McKeySettingsPage {
            McKeySettingsCard(mcKeyText(settings, "Chuyển chế độ gõ", "Switch typing mode")) {
                VStack(spacing: 0) {
                    hotkeyRow(
                        mcKeyText(settings, "Phím tắt chuyển đổi", "Switch shortcut"),
                        slot: .primary,
                        hotkey: $settings.primaryHotkey
                    )
                    modifierSelectors($settings.primaryHotkey)
                    if invalidCapture {
                        warning(mcKeyText(settings, "Phím tắt cần có ít nhất một phím bổ trợ.", "A shortcut needs at least one modifier."))
                    }
                    McKeySettingsDivider()

                    if settings.secondaryHotkeyEnabled {
                        hotkeyRow(
                            mcKeyText(settings, "Phím tắt chuyển đổi phụ", "Secondary switch shortcut"),
                            slot: .secondary,
                            hotkey: $settings.secondaryHotkey
                        )
                        modifierSelectors($settings.secondaryHotkey)
                        if duplicateConflict {
                            warning(mcKeyText(settings, "Hai phím tắt đang giống nhau.", "The two shortcuts are identical."))
                        }
                        Button(role: .destructive) {
                            settings.secondaryHotkeyEnabled = false
                            settings.secondaryHotkey = McKeyHotkey()
                        } label: {
                            Label(mcKeyText(settings, "Xóa phím phụ", "Remove secondary shortcut"), systemImage: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, McKeyTheme.Layout.rowVerticalPadding)
                    } else {
                        Button {
                            settings.secondaryHotkeyEnabled = true
                            if settings.secondaryHotkey.keyCode == nil && !hasModifiers(settings.secondaryHotkey) {
                                settings.secondaryHotkey = McKeyHotkey(control: true, shift: true)
                            }
                        } label: {
                            Label(mcKeyText(settings, "Thêm phím tắt chuyển đổi phụ", "Add secondary shortcut"), systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, McKeyTheme.Layout.rowVerticalPadding)
                    }
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Khôi phục ký tự", "Restore raw keys")) {
                VStack(spacing: 0) {
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Hoàn tác về ký tự gốc", "Restore original characters"),
                        subtitle: mcKeyText(settings, "Dùng phím hoàn tác để trả về ký tự trước khi biến đổi", "Restore the text before the engine transformed it."),
                        isOn: $settings.engine.restoreOnEscape
                    )
                    if settings.engine.restoreOnEscape {
                        McKeySettingsDivider()
                        McKeySettingsRow(mcKeyText(settings, "Phím hoàn tác", "Restore key")) {
                            Picker(mcKeyText(settings, "Phím hoàn tác", "Restore key"), selection: $settings.restoreKey) {
                                Text("Esc").tag(McKeyRestoreKey.esc)
                                Text("⌥ Option").tag(McKeyRestoreKey.option)
                                Text("⌃ Control").tag(McKeyRestoreKey.control)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }
                    }
                    if restoreConflict {
                        Label(
                            mcKeyText(settings, "Phím hoàn tác trùng với phím bổ trợ của phím tắt chuyển chế độ", "The restore key conflicts with a switch shortcut modifier."),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Tạm dừng gõ tiếng Việt", "Pause Vietnamese typing")) {
                VStack(spacing: 0) {
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Bật tính năng tạm dừng", "Enable hold-to-pause"),
                        subtitle: mcKeyText(settings, "Giữ phím bổ trợ để tạm chuyển sang tiếng Anh", "Hold a modifier to temporarily switch to English."),
                        isOn: $settings.pauseEnabled
                    )
                    if settings.pauseEnabled {
                        McKeySettingsDivider()
                        McKeySettingsRow(mcKeyText(settings, "Phím giữ", "Hold key")) {
                            Picker(mcKeyText(settings, "Phím giữ", "Hold key"), selection: $settings.pauseKey) {
                                Text("⌥ Option").tag(McKeyModifierKey.option)
                                Text("⌃ Control").tag(McKeyModifierKey.control)
                                Text("⇧ Shift").tag(McKeyModifierKey.shift)
                                Text("fn").tag(McKeyModifierKey.fn)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }
                        if pauseSwitchConflict {
                            warning(mcKeyText(settings, "Phím tạm dừng trùng với phím bổ trợ của phím chuyển đổi.", "The pause key conflicts with a switch shortcut modifier."))
                        }
                        if pauseRestoreConflict {
                            warning(mcKeyText(settings, "Phím tạm dừng trùng với phím hoàn tác.", "The pause key conflicts with the restore key."))
                        }
                    }
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Âm thanh", "Sound")) {
                VStack(spacing: 0) {
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Phát âm thanh khi chuyển chế độ", "Play sound when switching modes"),
                        subtitle: mcKeyText(settings, "Phát Tink khi bật tiếng Việt và Pop khi tắt", "Play Tink for Vietnamese and Pop for English."),
                        isOn: $settings.switchSound
                    )
                    McKeySettingsDivider()
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Cả khi bấm vào ô nhập", "Also when clicking a text field"),
                        subtitle: mcKeyText(settings, "Phát âm thanh sau khi rời ô nhập quá thời gian đã chọn", "Play the current mode sound after leaving a text field for the selected delay."),
                        isOn: $settings.clickSound
                    )
                    .disabled(!settings.switchSound)
                    McKeySettingsRow(mcKeyText(settings, "Thời gian rời ô nhập", "Away from text field")) {
                        Picker(mcKeyText(settings, "Thời gian", "Delay"), selection: $settings.clickSoundDelay) {
                            ForEach([5, 10, 15, 30, 60, 120, 300], id: \.self) { seconds in
                                Text(delayTitle(seconds)).tag(seconds)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .disabled(!settings.switchSound || !settings.clickSound)
                    }
                    McKeySettingsDivider()
                    McKeySettingsRow(mcKeyText(settings, "Âm lượng", "Volume"), subtitle: mcKeyText(settings, "Tink/Pop đang dùng", "Used for Tink and Pop")) {
                        VStack(alignment: .trailing, spacing: McKeyTheme.Layout.compactSpacing) {
                            Slider(value: $settings.soundVolume, in: 0...1, onEditingChanged: { editing in
                                if !editing { previewSwitchSound() }
                            })
                            Text("\(Int(settings.soundVolume * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .disabled(!settings.switchSound)
                    }
                }
            }
        }
        .onDisappear {
            recording = nil
            settings.isRecordingHotkey = false
        }
    }

    private func hotkeyRow(_ title: String, slot: McKeyShortcutSlot, hotkey: Binding<McKeyHotkey>) -> some View {
        McKeySettingsRow(title, subtitle: mcKeyText(settings, "Nhập phím tắt hoặc giữ phím bổ trợ", "Press a shortcut or hold a modifier")) {
            HStack(spacing: McKeyTheme.Layout.compactSpacing) {
                Button {
                    recording = slot
                    settings.isRecordingHotkey = true
                } label: {
                    McKeyShortcutRecorderLabel(
                        title: recording == slot ? mcKeyText(settings, "Nhấn phím…", "Press keys…") : shortcutName(hotkey.wrappedValue),
                        isRecording: recording == slot
                    )
                }
                .buttonStyle(.plain)
                .background {
                    McKeyHotkeyCapture(
                        isRecording: Binding(get: { recording == slot }, set: { if !$0 && recording == slot { recording = nil } }),
                        onCaptured: { keyCode, flags in
                            guard !flags.intersection([.control, .option, .command, .shift, .function]).isEmpty else {
                                invalidCapture = true
                                recording = nil
                                settings.isRecordingHotkey = false
                                return
                            }
                            invalidCapture = false
                            var value = hotkey.wrappedValue
                            value.keyCode = keyCode
                            value.control = flags.contains(.control)
                            value.option = flags.contains(.option)
                            value.command = flags.contains(.command)
                            value.shift = flags.contains(.shift)
                            value.fn = flags.contains(.function)
                            hotkey.wrappedValue = value
                            recording = nil
                            settings.isRecordingHotkey = false
                        },
                        onCancelled: {
                            recording = nil
                            settings.isRecordingHotkey = false
                        }
                    )
                }
                if hotkey.wrappedValue.keyCode != nil || hasModifiers(hotkey.wrappedValue) {
                    Button {
                        hotkey.wrappedValue = McKeyHotkey()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mcKeyText(settings, "Xóa phím tắt", "Clear shortcut"))
                }
            }
        }
    }

    private func modifierSelectors(_ hotkey: Binding<McKeyHotkey>) -> some View {
        McKeySettingsRow(mcKeyText(settings, "Phím bổ trợ", "Modifiers")) {
            HStack(spacing: McKeyTheme.Hotkeys.modifierSpacing) {
                modifier("⌃", title: "Control", binding: binding(hotkey, \.control))
                modifier("⌥", title: "Option", binding: binding(hotkey, \.option))
                modifier("⇧", title: "Shift", binding: binding(hotkey, \.shift))
                modifier("⌘", title: "Command", binding: binding(hotkey, \.command))
                modifier("fn", title: "Fn", binding: binding(hotkey, \.fn))
            }
        }
    }

    private func modifier(_ label: String, title: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(label)
        }
        .toggleStyle(.button)
        .controlSize(.small)
        .font(.system(size: McKeyTheme.Hotkeys.modifierFontSize, weight: .semibold))
        .frame(width: McKeyTheme.Hotkeys.modifierButtonWidth)
        .accessibilityLabel(title)
        .help(title)
    }

    private func warning(_ title: String) -> some View {
        Label(title, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, McKeyTheme.Layout.rowVerticalPadding)
    }

    private func binding(_ hotkey: Binding<McKeyHotkey>, _ keyPath: WritableKeyPath<McKeyHotkey, Bool>) -> Binding<Bool> {
        Binding(get: { hotkey.wrappedValue[keyPath: keyPath] }, set: { hotkey.wrappedValue[keyPath: keyPath] = $0 })
    }

    private func hasModifiers(_ hotkey: McKeyHotkey) -> Bool {
        hotkey.control || hotkey.option || hotkey.command || hotkey.shift || hotkey.fn
    }

    private func shortcutName(_ hotkey: McKeyHotkey) -> String {
        var parts: [String] = []
        if hotkey.fn { parts.append("fn") }
        if hotkey.control { parts.append("⌃") }
        if hotkey.option { parts.append("⌥") }
        if hotkey.shift { parts.append("⇧") }
        if hotkey.command { parts.append("⌘") }
        if let keyCode = hotkey.keyCode { parts.append(keyName(keyCode)) }
        return parts.isEmpty ? mcKeyText(settings, "Chưa đặt", "Not set") : parts.joined(separator: " + ")
    }

    private func keyName(_ code: Int) -> String {
        let names: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
            12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4",
            22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 51: "Delete",
            53: "Esc", 115: "Home", 116: "Page Up", 117: "Forward Delete", 119: "End", 121: "Page Down",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
            109: "F10", 103: "F11", 111: "F12", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return names[code] ?? "Key \(code)"
    }

    private func delayTitle(_ value: Int) -> String {
        "\(value) \(mcKeyText(settings, "giây", "sec"))"
    }
}
