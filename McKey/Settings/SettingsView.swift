// Adapted from PHTV UI/SettingsView.swift
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import AppKit
import SwiftUI

enum McKeySettingsTab: String, CaseIterable, Identifiable {
    case typing
    case hotkeys
    case apps
    case system
    case about

    var id: String { rawValue }

    func title(vietnamese: Bool) -> String {
        switch self {
        case .typing: vietnamese ? "Bộ gõ" : "Typing"
        case .hotkeys: vietnamese ? "Phím tắt" : "Hotkeys"
        case .apps: vietnamese ? "Ứng dụng" : "Apps"
        case .system: vietnamese ? "Hệ thống" : "System"
        case .about: vietnamese ? "Thông tin" : "About"
        }
    }

    func matches(_ query: String, vietnamese: Bool) -> Bool {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return true }
        let terms: [String]
        switch self {
        case .typing:
            terms = ["telex", "vni", "input method", "code table", "unicode", "spelling", "orthography", "restore word", "quick consonant", "phụ âm", "chính tả", "bảng mã", "kiểu gõ", "khôi phục"]
        case .hotkeys:
            terms = ["shortcut", "hotkey", "switch", "restore", "pause", "sound", "volume", "click", "Tink", "Pop", "phím tắt", "chuyển", "hoàn tác", "tạm dừng", "âm thanh", "âm lượng"]
        case .apps:
            terms = ["app", "english", "lock", "ứng dụng", "tiếng anh", "khoá"]
        case .system:
            terms = ["system", "startup", "login", "dock", "top", "idle", "auto switch", "backup", "import", "export", "convert", "license", "khởi động", "thanh menu", "tự chuyển", "sao lưu", "nhập", "xuất", "chuyển đổi"]
        case .about:
            terms = ["about", "version", "source", "license", "PHTV", "AGPL", "GPL", "thông tin", "phiên bản", "mã nguồn", "giấy phép"]
        }
        return title(vietnamese: vietnamese).localizedStandardContains(search)
            || terms.contains { $0.localizedStandardContains(search) || search.localizedStandardContains($0) }
    }

    var icon: String {
        switch self {
        case .typing: "keyboard.fill"
        case .hotkeys: "command.circle.fill"
        case .apps: "square.grid.2x2.fill"
        case .system: "gearshape.fill"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class McKeySettingsNavigator: ObservableObject {
    @Published var selectedPage: McKeySettingsTab = .typing
}

struct McKeySettingsWindowView: View {
    @ObservedObject var settings: McKeySettings
    @ObservedObject var navigation: McKeySettingsNavigator
    let previewSwitchSound: () -> Void
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selectedPage) {
                if McKeySettingsTab.allCases.contains(where: { $0.matches(searchText, vietnamese: settings.vietnameseUI) }) {
                    Section(mcKeyText(settings, "Cài đặt", "Settings")) {
                        ForEach(McKeySettingsTab.allCases.filter { $0.matches(searchText, vietnamese: settings.vietnameseUI) }) { page in
                            Label(page.title(vietnamese: settings.vietnameseUI), systemImage: page.icon)
                                .tag(page)
                        }
                    }
                } else {
                    Text(mcKeyText(settings, "Không có kết quả", "No results"))
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(
                min: McKeyTheme.Sidebar.minimumWidth,
                ideal: McKeyTheme.Sidebar.idealWidth,
                max: McKeyTheme.Sidebar.maximumWidth
            )
        } detail: {
            detail
                .navigationTitle(navigation.selectedPage.title(vietnamese: settings.vietnameseUI))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, prompt: mcKeyText(settings, "Tìm nhanh cài đặt…", "Search settings…"))
        .frame(
            minWidth: McKeyTheme.Window.minimumWidth,
            idealWidth: McKeyTheme.Window.width,
            minHeight: McKeyTheme.Window.minimumHeight,
            idealHeight: McKeyTheme.Window.height
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.selectedPage {
        case .typing: TypingSettingsView(settings: settings)
        case .hotkeys: HotkeySettingsView(settings: settings, previewSwitchSound: previewSwitchSound)
        case .apps: AppsSettingsView(settings: settings)
        case .system: SystemSettingsView(settings: settings)
        case .about: AboutView(settings: settings)
        }
    }
}

