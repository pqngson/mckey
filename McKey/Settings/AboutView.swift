// Adapted from PHTV UI/SettingsTabs/AboutView.swift
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import AppKit
import SwiftUI

struct AboutView: View {
    @ObservedObject var settings: McKeySettings

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        McKeySettingsPage {
            McKeySettingsCard(mcKeyText(settings, "Ứng dụng", "Application")) {
                HStack(spacing: McKeyTheme.Layout.rowSpacing) {
                    appIcon
                        .frame(width: McKeyTheme.Layout.iconSize, height: McKeyTheme.Layout.iconSize)
                    VStack(alignment: .leading, spacing: McKeyTheme.Layout.compactSpacing) {
                        Text("MćKey").font(.title2.weight(.semibold))
                        Text(mcKeyText(settings, "Bộ gõ tiếng Việt dành cho macOS", "Vietnamese input for macOS"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(mcKeyText(settings, "Phiên bản", "Version")) \(version)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Giới thiệu", "About")) {
                Text(mcKeyText(
                    settings,
                    "MćKey dùng Accessibility và event tap để xử lý đầu vào tiếng Việt. Hỗ trợ Telex, VNI và các phương pháp từ PHTV.",
                    "MćKey uses Accessibility and an event tap for Vietnamese input. It supports Telex, VNI, and methods from PHTV."
                ))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            }

            McKeySettingsCard(mcKeyText(settings, "Mã nguồn và giấy phép", "Source and license")) {
                VStack(alignment: .leading, spacing: McKeyTheme.Layout.rowVerticalPadding) {
                    Text(mcKeyText(
                        settings,
                        "Bộ máy gõ và giao diện cài đặt được điều chỉnh từ PHTV.",
                        "The input engine and settings interface are adapted from PHTV."
                    ))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    Text("Copyright © 2026 Phạm Hùng Tiến")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("PHTV source revision: 0a42ef4")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: McKeyTheme.Layout.rowSpacing) {
                        Link("PHTV source", destination: URL(string: "https://github.com/PhamHungTien/PHTV")!)
                        Link("GNU AGPL v3.0", destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
                    }
                    HStack(spacing: McKeyTheme.Layout.rowSpacing) {
                        Link("McKey source", destination: URL(string: "https://github.com/weekend-at-qngson/mckey")!)
                        Link("GNU GPL v3.0", destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!)
                    }
                }
                .font(.body)
            }

            VStack(spacing: McKeyTheme.Layout.compactSpacing) {
                Text(mcKeyText(settings, "Bao gồm mã nguồn theo GPL v3.0 và AGPL v3.0", "Includes source under GPL v3.0 and AGPL v3.0"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(mcKeyText(settings, "Mã nguồn mở", "Open source software"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: McKeyTheme.Window.pageWidth)
            .padding(.bottom, McKeyTheme.Layout.pagePadding)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon).resizable().scaledToFit()
        } else if let icon = NSImage(named: NSImage.applicationIconName) {
            Image(nsImage: icon).resizable().scaledToFit()
        } else {
            Image(systemName: "keyboard.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tint)
        }
    }
}
