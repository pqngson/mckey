import SwiftUI

/// Visual tokens adapted from PHTV SettingsComponents.swift (PHTV, 2026; AGPL-3.0).
enum McKeyTheme {
    enum Window {
        static let width: CGFloat = 900
        static let height: CGFloat = 620
        static let minimumWidth: CGFloat = 780
        static let minimumHeight: CGFloat = 550
        static let pageWidth: CGFloat = 680
    }

    enum Sidebar {
        static let minimumWidth: CGFloat = 200
        static let idealWidth: CGFloat = 240
        static let maximumWidth: CGFloat = 300
    }

    enum Layout {
        static let pagePadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let headerSpacing: CGFloat = 8
        static let cardHorizontalPadding: CGFloat = 12
        static let cardVerticalPadding: CGFloat = 8
        static let cardCornerRadius: CGFloat = 12
        static let rowVerticalPadding: CGFloat = 7
        static let rowColumnWidth: CGFloat = 168
        static let toggleWidth: CGFloat = 54
        static let rowSpacing: CGFloat = 12
        static let compactSpacing: CGFloat = 6
        static let controlHeight: CGFloat = 32
        static let iconSize: CGFloat = 56
        static let cardSurfaceOpacity: Double = 0.035
        static let pillOpacity: Double = 0.08
        static let recorderCornerRadius: CGFloat = 7
        static let smallChipVerticalPadding: CGFloat = 3
        static let smallTextScale: CGFloat = 0.8
        static let consonantInputWidth: CGFloat = 96
        static let editorTopPadding: CGFloat = 2
        static let editorBottomPadding: CGFloat = 8
        static let controlStrokeWidth: CGFloat = 1
        static let metadataLineSpacing: CGFloat = 2
        static let singleLineLimit: Int = 1
    }

    enum Hotkeys {
        static let modifierButtonWidth: CGFloat = 28
        static let modifierSpacing: CGFloat = 6
        static let modifierFontSize: CGFloat = 13
        static let recorderWidth: CGFloat = 140
    }

    enum ConvertTool {
        static let textEditorHeight: CGFloat = 128
    }

    enum AppsPage {
        static let iconSize: CGFloat = 20 // pt
        static let rowSpacing: CGFloat = 12 // pt
        static let rowVerticalPadding: CGFloat = 8 // pt
        static let rowHorizontalPadding: CGFloat = 4 // pt
        static let pickerWidth: CGFloat = 170 // pt
        static let appInfoSpacing: CGFloat = 2 // pt
        static let emptyStateVerticalPadding: CGFloat = 16 // pt
        static let buttonSpacing: CGFloat = 10 // pt
        static let buttonRowVerticalPadding: CGFloat = 8 // pt
        static let buttonSpacerMinLength: CGFloat = 0 // pt
        static let contentSpacing: CGFloat = 0 // pt
        static let singleLineLimit: Int = 1 // lines
        static let hoverBackgroundOpacity: Double = 0.05 // opacity
        static let hoverCornerRadius: CGFloat = 6 // pt
    }
}
