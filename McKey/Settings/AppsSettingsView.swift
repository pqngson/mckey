// Adapted from PHTV UI/SettingsTabs/AppsSettingsView.swift
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppsSettingsView: View {
    @ObservedObject var settings: McKeySettings

    var body: some View {
        McKeySettingsPage {
            McKeySettingsCard(
                mcKeyText(settings, "Tiếng Anh theo ứng dụng", "English per app"),
                subtitle: mcKeyText(
                    settings,
                    "Tự chuyển hoặc khoá tiếng Anh riêng cho từng ứng dụng",
                    "Switch to or lock English in chosen apps"
                )
            ) {
                VStack(alignment: .leading, spacing: McKeyTheme.AppsPage.contentSpacing) {
                    if settings.englishApps.isEmpty {
                        Text(mcKeyText(settings, "Chưa có ứng dụng nào", "No apps yet"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, McKeyTheme.AppsPage.emptyStateVerticalPadding)
                    } else {
                        ForEach(settings.englishApps) { app in
                            McKeyAppRowView(settings: settings, app: app)
                            if app.id != settings.englishApps.last?.id {
                                McKeySettingsDivider()
                            }
                        }
                    }

                    McKeySettingsDivider()

                    HStack(spacing: McKeyTheme.AppsPage.buttonSpacing) {
                        Button(mcKeyText(settings, "Thêm ứng dụng…", "Add applications…")) {
                            addApplicationsFromPanel()
                        }

                        Menu(mcKeyText(settings, "Thêm ứng dụng đang chạy", "Add running app")) {
                            if runningApplicationsToAdd.isEmpty {
                                Text(mcKeyText(settings, "Không có ứng dụng khả dụng", "No available applications"))
                            } else {
                                ForEach(runningApplicationsToAdd, id: \.processIdentifier) { app in
                                    Button {
                                        addRunningApplication(app)
                                    } label: {
                                        if let icon = app.icon {
                                            Label {
                                                Text(app.localizedName ?? app.bundleIdentifier ?? "")
                                            } icon: {
                                                Image(nsImage: icon)
                                            }
                                        } else {
                                            Label(
                                                app.localizedName ?? app.bundleIdentifier ?? "",
                                                systemImage: "app"
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: McKeyTheme.AppsPage.buttonSpacerMinLength)
                    }
                    .padding(.vertical, McKeyTheme.AppsPage.buttonRowVerticalPadding)
                }
            }
        }
    }

    private var runningApplicationsToAdd: [NSRunningApplication] {
        let currentBundleID = Bundle.main.bundleIdentifier
        let existingBundleIDs = Set(settings.englishApps.map(\.bundleID))
        return NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular,
                      let bundleID = app.bundleIdentifier,
                      bundleID != currentBundleID,
                      !existingBundleIDs.contains(bundleID) else {
                    return false
                }
                return true
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func addApplicationsFromPanel() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application, .applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = mcKeyText(settings, "Chọn", "Choose")
        if panel.runModal() == .OK {
            for url in panel.urls {
                addApplication(at: url)
            }
        }
    }

    private func addApplication(at url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            return
        }
        guard !settings.englishApps.contains(where: { $0.bundleID == bundleID }) else {
            return
        }
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let appName = displayName ?? bundleName ?? bundleID
        let newApp = McKeyEnglishApp(bundleID: bundleID, name: appName, behavior: .switchToEnglish)
        settings.englishApps.append(newApp)
    }

    private func addRunningApplication(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }
        guard !settings.englishApps.contains(where: { $0.bundleID == bundleID }) else { return }
        let name: String
        if let bundleURL = app.bundleURL, let bundle = Bundle(url: bundleURL) {
            let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            name = displayName ?? bundleName ?? app.localizedName ?? bundleID
        } else {
            name = app.localizedName ?? bundleID
        }
        let newApp = McKeyEnglishApp(bundleID: bundleID, name: name, behavior: .switchToEnglish)
        settings.englishApps.append(newApp)
    }
}

private struct McKeyAppRowView: View {
    @ObservedObject var settings: McKeySettings
    let app: McKeyEnglishApp
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: McKeyTheme.AppsPage.rowSpacing) {
            appIcon

            VStack(alignment: .leading, spacing: McKeyTheme.AppsPage.appInfoSpacing) {
                Text(app.name)
                    .font(.body)
                    .lineLimit(McKeyTheme.AppsPage.singleLineLimit)
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(McKeyTheme.AppsPage.singleLineLimit)
            }

            Spacer(minLength: McKeyTheme.AppsPage.rowSpacing)

            Picker(
                selection: Binding(
                    get: { app.behavior },
                    set: { newBehavior in
                        if let index = settings.englishApps.firstIndex(where: { $0.id == app.id }) {
                            settings.englishApps[index].behavior = newBehavior
                        }
                    }
                ),
                label: EmptyView()
            ) {
                Label(
                    mcKeyText(settings, "Tự chuyển", "Switch to English"),
                    systemImage: "arrow.right.circle"
                )
                .tag(McKeyEnglishAppBehavior.switchToEnglish)
                .help(behaviorHelpText(.switchToEnglish))

                Label {
                    Text(mcKeyText(settings, "Giữ EN", "Keep EN"))
                } icon: {
                    Image(nsImage: McKeyBadge.make("EN", filled: false))
                }
                .tag(McKeyEnglishAppBehavior.lockEnglish)
                .help(behaviorHelpText(.lockEnglish))

                Label {
                    Text(mcKeyText(settings, "Giữ VN", "Keep VN"))
                } icon: {
                    Image(nsImage: McKeyBadge.make("VI", filled: true))
                }
                .tag(McKeyEnglishAppBehavior.lockVietnamese)
                .help(behaviorHelpText(.lockVietnamese))
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: McKeyTheme.AppsPage.pickerWidth)
            .help(behaviorHelpText(app.behavior))

            Button {
                settings.englishApps.removeAll { $0.id == app.id }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(isHovered ? Color.red : .secondary)
            }
            .buttonStyle(.plain)
            .help(mcKeyText(settings, "Xoá khỏi danh sách", "Remove from list"))
        }
        .padding(.vertical, McKeyTheme.AppsPage.rowVerticalPadding)
        .padding(.horizontal, McKeyTheme.AppsPage.rowHorizontalPadding)
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: McKeyTheme.AppsPage.hoverCornerRadius)
                    .fill(Color.primary.opacity(McKeyTheme.AppsPage.hoverBackgroundOpacity))
            }
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                if let index = settings.englishApps.firstIndex(where: { $0.id == app.id }) {
                    settings.englishApps[index].behavior = .switchToEnglish
                }
            } label: {
                Label(
                    mcKeyText(settings, "Tự chuyển", "Switch to English"),
                    systemImage: "arrow.right.circle"
                )
            }
            Button {
                if let index = settings.englishApps.firstIndex(where: { $0.id == app.id }) {
                    settings.englishApps[index].behavior = .lockEnglish
                }
            } label: {
                Label {
                    Text(mcKeyText(settings, "Giữ EN", "Keep EN"))
                } icon: {
                    Image(nsImage: McKeyBadge.make("EN", filled: false))
                }
            }
            Button {
                if let index = settings.englishApps.firstIndex(where: { $0.id == app.id }) {
                    settings.englishApps[index].behavior = .lockVietnamese
                }
            } label: {
                Label {
                    Text(mcKeyText(settings, "Giữ VN", "Keep VN"))
                } icon: {
                    Image(nsImage: McKeyBadge.make("VI", filled: true))
                }
            }
            Divider()
            Button(role: .destructive) {
                settings.englishApps.removeAll { $0.id == app.id }
            } label: {
                Text(mcKeyText(settings, "Xoá khỏi danh sách", "Remove from list"))
            }
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
                .frame(width: McKeyTheme.AppsPage.iconSize, height: McKeyTheme.AppsPage.iconSize)
        } else {
            Image(systemName: "app")
                .resizable()
                .scaledToFit()
                .frame(width: McKeyTheme.AppsPage.iconSize, height: McKeyTheme.AppsPage.iconSize)
                .foregroundStyle(.secondary)
        }
    }

    private func behaviorHelpText(_ behavior: McKeyEnglishAppBehavior) -> String {
        switch behavior {
        case .switchToEnglish:
            return mcKeyText(
                settings,
                "Chuyển sang tiếng Anh khi mở ứng dụng, nhưng vẫn cho phép bật lại tiếng Việt.",
                "Switch to English when entering the app, but still allow switching back to Vietnamese."
            )
        case .lockEnglish:
            return mcKeyText(
                settings,
                "Luôn giữ tiếng Anh và chặn mọi cách bật tiếng Việt trong ứng dụng.",
                "Always keep English and prevent switching to Vietnamese in this app."
            )
        case .lockVietnamese:
            return mcKeyText(
                settings,
                "Luôn giữ tiếng Việt và chặn chuyển sang tiếng Anh trong ứng dụng này.",
                "Always keep Vietnamese and prevent switching to English in this app."
            )
        }
    }
}
