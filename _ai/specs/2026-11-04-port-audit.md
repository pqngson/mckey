# PHTV port cleanup and control audit

Reviewed working tree based on e430487. This is a source-wiring audit; it does not establish actual GUI, audio or target-editor behavior. Raw settings retrieval was recovered from the agy transcript after its oversized report write was refused; the following is the seat's review.

## Control inventory

All persistent fields below flow through McKeySettings.changed/save and AppDelegate.applySettings. Typing options reach KeyTap.apply, then the serialized PHTV runtime snapshot. UI tuning remains in McKey/Theme.swift.

| Page / controls | State or action | Consumer / effect |
| --- | --- | --- |
| Typing: input method; code table | engine.inputType; engine.codeTable | PHTVRuntimeAdapter input/layout accessors; PHTVInputEngine decoding |
| Spell checking; orthography | engine.checkSpelling; engine.modernOrthography | PHTVEngineCore spelling and tone placement |
| Automatic word restoration; mode | engine.autoRestoreEnglishWord; engine.autoRestoreEnglishWordMode | Core restore decisions and built-in dictionary bridges |
| Quick Telex | engine.quickTelex | Core expansion |
| Custom consonants toggle, add, remove, defaults | engine.allowCustomConsonants; engine.customConsonants | PHTVCustomConsonants rows; editor validates length, alphabet, duplicates and limit |
| Quick initial; quick final consonants | engine.quickStartConsonant; engine.quickEndConsonant | Core boundary expansion |
| Disable word-start shortcuts | engine.disableWordStartShortcuts | Core w/bracket guard |
| Hotkeys: primary recording and modifiers | primaryHotkey; isRecordingHotkey | KeyTap activeHotkeys / reducer; recording suppresses switch recognition |
| Secondary add/remove, recording, modifiers | secondaryHotkeyEnabled; secondaryHotkey | Same reducer; disabled secondary excluded |
| Restore toggle and Esc/Option/Control selection | engine.restoreOnEscape; restoreKey | KeyTap Esc path and modifier-release restore |
| Hold-to-pause toggle and key | pauseEnabled; pauseKey | KeyTap pause reducer; overlapping switch chords excluded; UI warns |
| Sound toggle; click sound; away delay | switchSound; clickSound; clickSoundDelay | AppDelegate.playSwitchSound / handleMouseDown |
| Volume slider and release preview | soundVolume; previewSwitchSound | ControlPanel closure -> AppDelegate.playModeSound -> NSSound volume |
| Apps: application picker and running-app menu | englishApps append | NSOpenPanel / NSWorkspace; bundle identity deduplicates entries |
| Apps: behavior and removal | englishApps update/remove | AppDelegate.applyEnglishAppRule -> rule state -> tap.enabled / englishLocked |
| Interface language | vietnameseUI | SwiftUI text, sidebar, menu rebuild |
| Keep settings above other apps | alwaysOnTop | AppDelegate panel window level |
| Dock visibility | showDockIcon | AppDelegate activation policy, including when settings close |
| Settings at startup | showDialogAtStart | AppDelegate.finishStartup |
| Launch at login | local loginAtStartup / SMAppService | register/unregister with displayed errors and approval status; not JSON-backed |
| Idle switch toggle, target and delay | autoSwitchEnabled; autoSwitchToVietnamese; autoSwitchDelay | AppDelegate timer; English lock prevents VI target |
| Export; import | exportJSON; importJSON | SwiftUI file panels, scoped URL read, validated settings batch |
| Restore defaults | resetToDefaults; setLaunchAtLogin(false) | Confirmation; persistent batch notification re-applies and resets engine |
| Convert sheet launcher | showingConvertTool | McKeyConvertToolView sheet |
| Convert source/target; text input | local options.fromCode/toCode; inputText | McKeyTextConversionService.convert on Convert action |
| Convert upper/lower/sentence/word case | local mutually exclusive case flags | Conversion service case transforms |
| Remove marks; Convert; result | options.removeMark; convert action; outputText | Conversion service; selectable output |
| About version, icon and links | Bundle metadata; SwiftUI Link | Read-only information and external source/license links |
| Sidebar selection and search | navigator.selectedPage; searchText | SettingsView page selection/filtering |

No visible control maps to a constant no-op bridge. freeMark and restoreIfWrongSpelling are internal/importable options, deliberately not additional controls. Macro, custom-dictionary, automatic typing capitalization and double-space hooks are disabled service boundaries. Converter case transformations remain independent of removed typing capitalization.

Findings corrected by the settings cleanup lane: restore-mode choices lacked English localization; Dock copy incorrectly implied settings-only scope; TypingSettingsView retained an unused appName helper. The snapshot spelling setter is internal core state, not evidence of a user-setting persistence bug: no UI control calls the temporary core command.

## Encoding decision and prior art (2026-11-04, before first cleanup patch)

Problem: the core deletes one logical letter while native Backspace can delete only one of two visible characters emitted by a legacy encoding. Keeping a truncated rendered item then permits core/editor drift on subsequent deletions and accents.

Studied two shipped platform implementations from OpenKey (972 stars at review, GPL-3.0), both pinned to c2a1f990280e3c28bc9e4f417fadb2c6928b9b40, 2024-12-11:

| Candidate | Source | Design |
| --- | --- | --- |
| OpenKey macOS | [OpenKey.mm:698](https://github.com/tuyenvm/OpenKey/blob/c2a1f990280e3c28bc9e4f417fadb2c6928b9b40/Sources/OpenKey/macOS/ModernKey/OpenKey.mm#L698) | Records per-item output lengths and supplements deletion for double-code output; compound behavior adapts to editors |
| OpenKey Windows | [OpenKey.cpp:589](https://github.com/tuyenvm/OpenKey/blob/c2a1f990280e3c28bc9e4f417fadb2c6928b9b40/Sources/OpenKey/win32/OpenKey/OpenKey/OpenKey.cpp#L589) | Same per-item length stack and supplemental deletion |

Shared design: remove the entire encoded logical item when the engine removes it. Follow that policy using McKey's existing renderedItems and grapheme-count synthetic-delete contract; do not copy GPL implementation code or add a second stack. Extend the policy to CP1258, which also emits two visible characters. Unicode Composite is one Swift grapheme and uses native single-grapheme deletion. No post-2024 API port is required. Retire partial-item reinsertion on unhandled deletion. Editor-specific deletion semantics still require actual app checks.

TCVN3 reuses accented bytes across cases. Reverse lookup deliberately chooses lowercase for ambiguous values and preserves unique values. Explicit uppercase conversion recovers uppercase output. Seat's independent exhaustive probe covered 620 character/table combinations without failure. This is a format limitation; no converter mapping change is needed. The converter already displays the case-loss notice.

## Manual verification boundary

GUI drive/capture authorization was requested in chat for settings, typing and app-switch checks. It must arrive before using GUI tools. Actual audio quality and UI judgment remain Penn's. The actionable checklist is maintained only in MEATBAG.md.
