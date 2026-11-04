// Adapted from PHTV's System convert tool
// Copyright © 2026 Phạm Hùng Tiến. Licensed under GNU AGPL v3.0.
import SwiftUI

struct McKeyConvertToolView: View {
    @ObservedObject var settings: McKeySettings
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var options = McKeyTextConversionOptions()

    var body: some View {
        McKeySettingsPage {
            McKeySettingsCard(mcKeyText(settings, "Chuyển đổi bảng mã", "Convert text encoding")) {
                VStack(alignment: .leading, spacing: McKeyTheme.Layout.rowVerticalPadding) {
                    McKeySettingsPickerRow(
                        mcKeyText(settings, "Từ", "From"),
                        selection: $options.fromCode,
                        selectedTitle: codeTable(options.fromCode).title
                    ) {
                        ForEach(McKeyConvertCodeTable.allCases) { table in
                            Text(table.title).tag(table.rawValue)
                        }
                    }
                    Text(mcKeyText(
                        settings,
                        "TCVN3 không lưu hoa/thường cho một số chữ có dấu; khi chuyển sang Unicode, các chữ đó sẽ thành chữ thường.",
                        "TCVN3 does not preserve case for some accented letters; those letters convert to lowercase in Unicode."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    McKeySettingsPickerRow(
                        mcKeyText(settings, "Sang", "To"),
                        selection: $options.toCode,
                        selectedTitle: codeTable(options.toCode).title
                    ) {
                        ForEach(McKeyConvertCodeTable.allCases) { table in
                            Text(table.title).tag(table.rawValue)
                        }
                    }
                    McKeySettingsDivider()

                    Text(mcKeyText(settings, "Văn bản cần chuyển", "Text to convert"))
                        .font(.body)
                    TextEditor(text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: McKeyTheme.ConvertTool.textEditorHeight)
                        .overlay {
                            RoundedRectangle(cornerRadius: McKeyTheme.Layout.compactSpacing)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: McKeyTheme.Layout.controlStrokeWidth)
                        }

                    VStack(spacing: 0) {
                        McKeyToggleRow(
                            title: mcKeyText(settings, "CHỮ HOA", "UPPERCASE"),
                            subtitle: mcKeyText(settings, "Chuyển tất cả ký tự thành chữ hoa", "Convert every character to uppercase"),
                            isOn: optionBinding(.upper)
                        )
                        McKeyToggleRow(
                            title: mcKeyText(settings, "chữ thường", "lowercase"),
                            subtitle: mcKeyText(settings, "Chuyển tất cả ký tự thành chữ thường", "Convert every character to lowercase"),
                            isOn: optionBinding(.lower)
                        )
                        McKeyToggleRow(
                            title: mcKeyText(settings, "Viết hoa đầu câu", "Capitalize sentences"),
                            subtitle: mcKeyText(settings, "Viết hoa sau dấu chấm, hỏi, than và dòng mới", "Capitalize after sentence punctuation and new lines"),
                            isOn: optionBinding(.sentence)
                        )
                        McKeyToggleRow(
                            title: mcKeyText(settings, "Viết Hoa Đầu Từ", "Capitalize each word"),
                            subtitle: mcKeyText(settings, "Viết hoa chữ đầu của mỗi từ", "Capitalize the first letter of every word"),
                            isOn: optionBinding(.words)
                        )
                        McKeyToggleRow(
                            title: mcKeyText(settings, "Bỏ dấu tiếng Việt", "Remove Vietnamese marks"),
                            subtitle: mcKeyText(settings, "Chuyển về ký tự gốc không dấu", "Convert Vietnamese letters to their unmarked base character"),
                            isOn: Binding(get: { options.removeMark }, set: { options.removeMark = $0 })
                        )
                    }

                    Button {
                        outputText = McKeyTextConversionService.convert(inputText, options: options)
                    } label: {
                        Label(mcKeyText(settings, "Chuyển đổi", "Convert"), systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(mcKeyText(settings, "Kết quả", "Result"))
                        .font(.body)
                    TextEditor(text: .constant(outputText))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: McKeyTheme.ConvertTool.textEditorHeight)
                        .overlay {
                            RoundedRectangle(cornerRadius: McKeyTheme.Layout.compactSpacing)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: McKeyTheme.Layout.controlStrokeWidth)
                        }
                        .textSelection(.enabled)
                }
            }
        }
    }

    private enum CaseMode { case upper, lower, sentence, words }

    private func optionBinding(_ mode: CaseMode) -> Binding<Bool> {
        Binding(
            get: {
                switch mode {
                case .upper: options.toAllCaps
                case .lower: options.toAllNonCaps
                case .sentence: options.toCapsFirstLetter
                case .words: options.toCapsEachWord
                }
            },
            set: { value in
                switch mode {
                case .upper:
                    options.toAllCaps = value
                    if value { options.toAllNonCaps = false; options.toCapsFirstLetter = false; options.toCapsEachWord = false }
                case .lower:
                    options.toAllNonCaps = value
                    if value { options.toAllCaps = false; options.toCapsFirstLetter = false; options.toCapsEachWord = false }
                case .sentence:
                    options.toCapsFirstLetter = value
                    if value { options.toAllCaps = false; options.toAllNonCaps = false; options.toCapsEachWord = false }
                case .words:
                    options.toCapsEachWord = value
                    if value { options.toAllCaps = false; options.toAllNonCaps = false; options.toCapsFirstLetter = false }
                }
            }
        )
    }

    private func codeTable(_ rawValue: Int) -> McKeyConvertCodeTable {
        McKeyConvertCodeTable(rawValue: rawValue) ?? .unicode
    }
}
