// Adapted from PHTV UI/SettingsTabs/TypingSettingsView.swift
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TypingSettingsView: View {
    @ObservedObject var settings: McKeySettings
    @State private var consonantDraft = ""

    private let consonantAlphabet = Set("BCDFGHJKLMNPQRSTVWXZ")

    var body: some View {
        McKeySettingsPage {
            McKeySettingsCard(mcKeyText(settings, "Thiết lập bộ gõ", "Input method")) {
                VStack(spacing: 0) {
                    McKeySettingsPickerRow(
                        mcKeyText(settings, "Phương pháp gõ", "Input method"),
                        selection: $settings.engine.inputType,
                        selectedTitle: methodName(settings.engine.inputType)
                    ) {
                        Text("Telex").tag(0)
                        Text("VNI").tag(1)
                        Text("Simple Telex 1").tag(2)
                        Text("Simple Telex 2").tag(3)
                    }
                    McKeySettingsDivider()
                    McKeySettingsPickerRow(
                        mcKeyText(settings, "Bảng mã", "Code table"),
                        selection: $settings.engine.codeTable,
                        selectedTitle: codeTableName(settings.engine.codeTable)
                    ) {
                        Text("Unicode").tag(0)
                        Text("TCVN3").tag(1)
                        Text("VNI Windows").tag(2)
                        Text("Unicode Composite").tag(3)
                        Text("Vietnamese Locale (CP1258)").tag(4)
                    }
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Tối ưu gõ", "Typing enhancements")) {
                VStack(spacing: 0) {
                    toggle("Kiểm tra chính tả", "Spell checking", "Tự động sửa lỗi cấu trúc tiếng Việt", "Automatically correct invalid Vietnamese spelling", \.checkSpelling)
                    McKeySettingsDivider()
                    toggle("Chính tả mới (oà, uý)", "Modern orthography (oà, uý)", "Ưu tiên dấu trên chữ thay vì òa, úy", "Place tones on the preferred vowel in oa, oe, and uy", \.modernOrthography)
                    McKeySettingsDivider()
                    McKeySettingsRow(mcKeyText(settings, "Tự động khôi phục từ", "Automatically restore words")) {
                        HStack(spacing: McKeyTheme.Layout.compactSpacing) {
                            Picker(mcKeyText(settings, "Chế độ khôi phục", "Restore mode"), selection: $settings.engine.autoRestoreEnglishWordMode) {
                                Text("Không phải tiếng Việt").tag(0)
                                Text("Chỉ tiếng Anh").tag(1)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.small)
                            .disabled(!settings.engine.autoRestoreEnglishWord)
                            Toggle(
                                mcKeyText(settings, "Tự động khôi phục từ", "Automatically restore words"),
                                isOn: $settings.engine.autoRestoreEnglishWord
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    McKeySettingsDivider()
                    toggle("Gõ nhanh Telex", "Quick Telex", "cc→ch, gg→gi, kk→kh, nn→ng…", "Shortcuts such as cc→ch, gg→gi, kk→kh, nn→ng…", \.quickTelex)
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Phụ âm nhanh", "Quick consonants")) {
                VStack(alignment: .leading, spacing: McKeyTheme.Layout.compactSpacing) {
                    toggle("Phụ âm tùy chỉnh", "Custom consonants", "Bổ sung phụ âm đầu gồm một hoặc hai chữ cái", "Add one or two letter initial consonants", \.allowCustomConsonants)
                    if settings.engine.allowCustomConsonants {
                        customConsonantsEditor
                    }
                    McKeySettingsDivider()
                    toggle("Phụ âm đầu nhanh", "Quick initial consonants", "f→ph, j→gi, w→qu…", "Shortcuts such as f→ph, j→gi, w→qu…", \.quickStartConsonant)
                    McKeySettingsDivider()
                    toggle("Phụ âm cuối nhanh", "Quick final consonants", "g→ng, h→nh, k→ch…", "Shortcuts such as g→ng, h→nh, k→ch…", \.quickEndConsonant)
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Tùy chọn McKey", "McKey options")) {
                toggle("Tắt gõ tắt w→ư, [→ơ ở đầu từ", "Disable w→ư and [→ơ word-start shortcuts", "Không tự đổi w hoặc [ ở đầu từ", "Keep w and [ literal at the start of a word", \.disableWordStartShortcuts)
            }
        }
    }

    private func toggle(
        _ vietnamese: String,
        _ english: String,
        _ viSubtitle: String,
        _ enSubtitle: String,
        _ keyPath: WritableKeyPath<PHTVOptions, Bool>
    ) -> some View {
        McKeyToggleRow(
            title: mcKeyText(settings, vietnamese, english),
            subtitle: mcKeyText(settings, viSubtitle, enSubtitle),
            isOn: Binding(
                get: { settings.engine[keyPath: keyPath] },
                set: { settings.engine[keyPath: keyPath] = $0 }
            )
        )
    }


    private var customConsonantsEditor: some View {
        VStack(alignment: .leading, spacing: McKeyTheme.Layout.compactSpacing) {
            if settings.engine.customConsonants.isEmpty {
                Text(mcKeyText(settings, "Chưa có phụ âm bổ sung.", "No additional consonants."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: McKeyTheme.Layout.compactSpacing) {
                    ForEach(settings.engine.customConsonants, id: \.self) { entry in
                        HStack(spacing: McKeyTheme.Layout.compactSpacing) {
                            Text(entry).font(.system(.callout, design: .monospaced).weight(.medium))
                            Button {
                                settings.engine.customConsonants.removeAll { $0 == entry }
                            } label: {
                                Image(systemName: "xmark").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(entry)")
                        }
                        .padding(.horizontal, McKeyTheme.Layout.compactSpacing)
                        .padding(.vertical, McKeyTheme.Layout.smallChipVerticalPadding)
                        .background(Color.secondary.opacity(McKeyTheme.Layout.pillOpacity), in: Capsule())
                    }
                }
            }

            HStack(spacing: McKeyTheme.Layout.compactSpacing) {
                TextField("Z, DZ", text: $consonantDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: McKeyTheme.Layout.consonantInputWidth)
                    .onSubmit(addConsonant)
                Button(action: addConsonant) {
                    Label(mcKeyText(settings, "Thêm", "Add"), systemImage: "plus")
                }
                .disabled(!validConsonant)
                Button(mcKeyText(settings, "Mặc định", "Defaults")) {
                    settings.engine.customConsonants = PHTVOptions().customConsonants
                    consonantDraft = ""
                }
                .disabled(settings.engine.customConsonants == PHTVOptions().customConsonants)
            }
            .controlSize(.small)

            if !consonantDraft.isEmpty && !validConsonant {
                Text(mcKeyText(settings, "Nhập 1–2 chữ cái phụ âm không dấu, ví dụ Z hoặc DZ.", "Enter one or two unaccented consonants, such as Z or DZ."))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, McKeyTheme.Layout.editorTopPadding)
        .padding(.bottom, McKeyTheme.Layout.editorBottomPadding)
    }

    private var normalizedConsonant: String { consonantDraft.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var validConsonant: Bool {
        let candidate = normalizedConsonant
        return (1...2).contains(candidate.count)
            && candidate.allSatisfy { consonantAlphabet.contains($0) }
            && !settings.engine.customConsonants.contains(candidate)
            && settings.engine.customConsonants.count < 32
    }

    private func addConsonant() {
        guard validConsonant else { return }
        settings.engine.customConsonants.append(normalizedConsonant)
        consonantDraft = ""
    }

    private func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let name = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String else {
            return bundleID
        }
        return name
    }

    private func methodName(_ value: Int) -> String {
        ["Telex", "VNI", "Simple Telex 1", "Simple Telex 2"].indices.contains(value)
            ? ["Telex", "VNI", "Simple Telex 1", "Simple Telex 2"][value]
            : "Telex"
    }

    private func codeTableName(_ value: Int) -> String {
        let names = ["Unicode", "TCVN3", "VNI Windows", "Unicode Composite", "Vietnamese Locale (CP1258)"]
        return names.indices.contains(value) ? names[value] : "Unicode"
    }
}
