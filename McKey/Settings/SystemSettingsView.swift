// Adapted from PHTV UI/SettingsTabs/SystemSettingsView.swift
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SystemSettingsView: View {
    @ObservedObject var settings: McKeySettings
    @State private var loginAtStartup = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var showingResetConfirmation = false
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var showingConvertTool = false
    @State private var showingError = false
    @State private var exportData = Data()
    @State private var errorMessage = ""

    var body: some View {
        McKeySettingsPage {
            McKeySettingsCard(mcKeyText(settings, "Giao diện", "Interface")) {
                VStack(spacing: 0) {
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Giao diện tiếng Việt", "Vietnamese interface"),
                        subtitle: mcKeyText(settings, "Hiển thị cài đặt bằng tiếng Việt", "Show settings in Vietnamese"),
                        isOn: $settings.vietnameseUI
                    )
                    McKeySettingsDivider()
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Cài đặt luôn ở trên", "Keep settings on top"),
                        subtitle: mcKeyText(settings, "Giữ cửa sổ Cài đặt trên các ứng dụng khác", "Keep the settings window above other apps"),
                        isOn: $settings.alwaysOnTop
                    )
                    McKeySettingsDivider()
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Hiện icon trên Dock", "Show icon in Dock"),
                        subtitle: mcKeyText(settings, "Hiển thị MćKey trên Dock khi mở Cài đặt", "Show MćKey in the Dock while Settings is open"),
                        isOn: $settings.showDockIcon
                    )
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Thanh menu", "Menu bar")) {
                HStack(spacing: McKeyTheme.Layout.rowSpacing) {
                    Image(systemName: "menubar.rectangle")
                        .foregroundStyle(.secondary)
                    Text(mcKeyText(
                        settings,
                        "Biểu tượng VI/EN đổi theo chế độ hiện tại.",
                        "The VI/EN status icon reflects the current input mode."
                    ))
                    .font(.body)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, McKeyTheme.Layout.rowVerticalPadding)
            }

            McKeySettingsCard(mcKeyText(settings, "Khởi động", "Startup")) {
                VStack(alignment: .leading, spacing: McKeyTheme.Layout.compactSpacing) {
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Hiện cửa sổ Cài đặt khi khởi động", "Show Settings at launch"),
                        subtitle: mcKeyText(settings, "Mở cửa sổ này sau khi MćKey khởi động", "Open this window when MćKey starts"),
                        isOn: $settings.showDialogAtStart
                    )
                    McKeySettingsDivider()
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Mở cùng hệ thống", "Launch at login"),
                        subtitle: mcKeyText(settings, "Tự động mở MćKey khi đăng nhập macOS", "Start MćKey when you log in to macOS"),
                        isOn: Binding(
                            get: { loginAtStartup },
                            set: { setLaunchAtLogin($0) }
                        )
                    )
                    if let loginError {
                        Label(loginError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if SMAppService.mainApp.status == .requiresApproval {
                        Text(mcKeyText(settings, "Cho phép MćKey trong Cài đặt hệ thống > Cài đặt chung > Mục đăng nhập.", "Allow MćKey in System Settings > General > Login Items."))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Chuyển chế độ khi không gõ", "Switch mode while idle")) {
                VStack(spacing: 0) {
                    McKeyToggleRow(
                        title: mcKeyText(settings, "Tự chuyển khi không gõ phím", "Auto-switch when idle"),
                        subtitle: mcKeyText(settings, "Đổi chế độ sau một khoảng thời gian không gõ", "Switch modes after a period without typing"),
                        isOn: $settings.autoSwitchEnabled
                    )
                    McKeySettingsRow(mcKeyText(settings, "Chuyển về", "Switch to")) {
                        Picker(mcKeyText(settings, "Ngôn ngữ", "Language"), selection: $settings.autoSwitchToVietnamese) {
                            Text("EN").tag(false)
                            Text("VI").tag(true)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .disabled(!settings.autoSwitchEnabled)
                    }
                    McKeySettingsRow(mcKeyText(settings, "Thời gian chờ", "Idle delay")) {
                        Picker(mcKeyText(settings, "Thời gian", "Delay"), selection: $settings.autoSwitchDelay) {
                            ForEach([5, 10, 15, 30, 60, 120, 300], id: \.self) { seconds in
                                Text("\(seconds) \(mcKeyText(settings, "giây", "sec"))").tag(seconds)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .disabled(!settings.autoSwitchEnabled)
                    }
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Dữ liệu và sao lưu", "Data and backup")) {
                VStack(spacing: 0) {
                    McKeySettingsActionRow(
                        title: mcKeyText(settings, "Xuất cài đặt", "Export settings"),
                        subtitle: mcKeyText(settings, "Lưu các tùy chọn MćKey thành tệp JSON", "Save MćKey preferences to a JSON file"),
                        icon: "square.and.arrow.up"
                    ) { exportSettings() }
                    McKeySettingsDivider()
                    McKeySettingsActionRow(
                        title: mcKeyText(settings, "Nhập cài đặt", "Import settings"),
                        subtitle: mcKeyText(settings, "Khôi phục tùy chọn từ tệp JSON", "Restore preferences from a JSON file"),
                        icon: "square.and.arrow.down"
                    ) { showingImport = true }
                    McKeySettingsDivider()
                    McKeySettingsActionRow(
                        title: mcKeyText(settings, "Khôi phục mặc định", "Restore defaults"),
                        subtitle: mcKeyText(settings, "Đưa tất cả cài đặt về giá trị ban đầu", "Reset all preferences to their initial values"),
                        icon: "arrow.counterclockwise",
                        destructive: true
                    ) { showingResetConfirmation = true }
                }
            }

            McKeySettingsCard(mcKeyText(settings, "Tiện ích", "Tools")) {
                McKeySettingsActionRow(
                    title: mcKeyText(settings, "Chuyển đổi bảng mã", "Convert text encoding"),
                    subtitle: mcKeyText(settings, "Chuyển văn bản giữa Unicode, TCVN3, VNI…", "Convert text between Unicode, TCVN3, VNI, and other encodings"),
                    icon: "character.textbox"
                ) { showingConvertTool = true }
            }
        }
        .fileExporter(
            isPresented: $showingExport,
            document: McKeySettingsDocument(data: exportData),
            contentType: .json,
            defaultFilename: "mckey-settings.json"
        ) { result in
            if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
                presentError(error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $showingImport, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            importSettings(result)
        }
        .sheet(isPresented: $showingConvertTool) {
            McKeyConvertToolView(settings: settings)
                .frame(minWidth: McKeyTheme.Window.minimumWidth, minHeight: McKeyTheme.Window.minimumHeight)
        }
        .confirmationDialog(
            mcKeyText(settings, "Khôi phục mặc định?", "Restore defaults?"),
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(mcKeyText(settings, "Khôi phục", "Restore defaults"), role: .destructive) {
                settings.resetToDefaults()
                setLaunchAtLogin(false)
                loginError = nil
            }
            Button(mcKeyText(settings, "Hủy", "Cancel"), role: .cancel) {}
        } message: {
            Text(mcKeyText(settings, "Tất cả cài đặt sẽ được đưa về mặc định. Hành động này không thể hoàn tác.", "All settings will be restored to their defaults. This cannot be undone."))
        }
        .alert(mcKeyText(settings, "Không thể hoàn tất", "Unable to complete"), isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled && SMAppService.mainApp.status != .requiresApproval {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            loginAtStartup = SMAppService.mainApp.status == .enabled
            loginError = nil
        } catch {
            loginAtStartup = SMAppService.mainApp.status == .enabled
            loginError = error.localizedDescription
        }
    }

    private func exportSettings() {
        do {
            exportData = try settings.exportJSON()
            showingExport = true
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func importSettings(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let hasScope = url.startAccessingSecurityScopedResource()
            defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
            do {
                try settings.importJSON(Data(contentsOf: url))
                loginAtStartup = SMAppService.mainApp.status == .enabled
            } catch {
                presentError(error.localizedDescription)
            }
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled { presentError(error.localizedDescription) }
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

struct McKeySettingsActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: McKeyTheme.Layout.rowSpacing) {
                Image(systemName: icon).foregroundStyle(destructive ? .red : .secondary)
                VStack(alignment: .leading, spacing: McKeyTheme.Layout.compactSpacing) {
                    Text(title).foregroundStyle(destructive ? .red : .primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, McKeyTheme.Layout.rowVerticalPadding)
        }
        .buttonStyle(.plain)
    }
}

struct McKeySettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
