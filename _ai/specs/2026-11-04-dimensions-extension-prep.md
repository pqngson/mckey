# Dimensions extension merge preparation (2026-11-04)

Handoff spec for Claude after building and installing the signed standalone `Release` build of MćKey.

## 1. Signed Release & Installation Status

- **Installed bundle:** `/Users/qngson/Applications/MćKey.app`
- **Signing details:** `Apple Development: Son Pham (5389U46Y92)`, `TeamIdentifier=GR6X5BCD3Q`, hardened runtime (`flags=0x10000(runtime)`), universal binary (`arm64` + `x86_64`), `CDHash=796cea1fe4492e443b455573444d352eaadffe86`. Signing with a real Apple Development identity (rather than `CODE_SIGNING_ALLOWED=NO` + ad-hoc `--sign -`) preserves macOS TCC / Accessibility trust across rebuilds.
- **Verification completed before install:**
  - `git diff --check` → clean
  - `~/.ai/capped 30 ./scripts/test-engine.sh` → 25 passed
  - `~/.ai/capped 30 ./scripts/test-conversion.sh` → 7 passed (including 620 code-table combinations)
  - `~/.ai/capped 30 ./scripts/test-runtime.sh` → 12 passed
  - `codesign --verify --deep --strict /Users/qngson/Applications/MćKey.app` → rc 0

## 2. File Classification for Merging into `dimensions`

### Embeddable Extension Core & Settings UI (include in `dimensions` extension target)
- `McKey/Engine/` (`PHTVEngineCore.swift`, `PHTVVietnameseData.swift`, `PHTVInputEngine.swift`, `PHTVCustomConsonants.swift`, `McKeyTextConversionService.swift`)
- `McKey/Resources/Dictionaries/` (`en_words.bin`, `vi_words.bin`) and `McKey/Resources/Sounds/` (if custom sound files are bundled; system `Tink`/`Pop` use `NSSound(named:)`)
- `McKey/KeyTap.swift` (CGEventTap keyboard/mouse hook, hotkey/pause/restore reducers, synthetic backspace/text injection)
- `McKey/McKeySettings.swift` (observable settings model, UserDefaults persistence, JSON import/export)
- `McKey/EnglishApps.swift` (`EnglishAppRuleController` per-app switch-to-English / lock-English state machine)
- `McKey/FocusProbe.swift` (AX caret/focus probe and `ModeBubble` non-activating overlay)
- `McKey/Theme.swift` (centralized layout/visual tokens under `McKeyTheme`)
- `McKey/Settings/` (`McKeySettingsRootView.swift`, `TypingSettingsView.swift`, `HotkeySettingsView.swift`, `AppsSettingsView.swift`, `SystemSettingsView.swift`, `AboutSettingsView.swift`, `McKeyConvertToolView.swift`, `SettingsComponents.swift`)

### Standalone App Shell (exclude from `dimensions` target or keep only for standalone `McKey` scheme)
- `McKey/main.swift` (`NSApplication.shared` entry point)
- `McKey/AppDelegate.swift` (currently mixes standalone `NSApplicationDelegate` / `NSStatusItem` / Dock policy with runtime coordination — see Section 3)
- `McKey/ControlPanel.swift` (standalone `NSWindow` wrapper hosting `McKeySettingsRootView`; `dimensions` will likely host `McKeySettingsRootView` directly in its own settings container or window)
- `Info.plist`, `McKey.entitlements`, `McKey/McKey.icon/`

## 3. Concrete Coupling Points to Decouple for Extension Hosting

From the control inventory (`_ai/specs/2026-11-04-port-audit.md`), five coupling points tie the runtime or SwiftUI views to standalone app assumptions:

1. **Runtime coordinator mixed into `AppDelegate` (`McKey/AppDelegate.swift`):**
   - `AppDelegate` currently owns `KeyTap`, `EnglishAppRuleController`, workspace app-activation observer (`applyEnglishAppRule`), switch/click sound playback (`playSwitchSound`, `playModeSound`, `handleMouseDown`), and the idle auto-switch timer (`autoSwitchEnabled`, `autoSwitchToVietnamese`, `autoSwitchDelay`).
   - **Fix for extension hosting:** Extract a host-agnostic `McKeyRuntimeController` (or `McKeyExtensionController`) that owns `KeyTap`, `McKeySettings`, `EnglishAppRuleController`, sound playback, and the idle timer. `AppDelegate` becomes a thin standalone shell (`NSStatusItem` menu bar badge, `ControlPanel` window management, `NSApp.setActivationPolicy`).
2. **Resource bundle lookup (`McKey/Engine/` and `McKey/Settings/AboutSettingsView.swift`):**
   - Dictionary loading (`en_words.bin`, `vi_words.bin`) and About metadata use `Bundle.main`.
   - **Fix for extension hosting:** Introduce a small `McKeyBundle` helper that checks the module/class bundle first (`Bundle(for: ...)` or `#if SWIFT_PACKAGE Bundle.module`) and falls back to `Bundle.main`, so dictionaries resolve whether compiled into the main app, a framework/extension bundle, or an SPM target inside `dimensions`.
3. **Standalone-only controls on `SystemSettingsView` (`McKey/Settings/SystemSettingsView.swift`):**
   - `loginAtStartup` calls `SMAppService.mainApp.register()` / `unregister()`.
   - `showDockIcon` toggles `NSApp.setActivationPolicy(.regular / .accessory)`.
   - `showDialogAtStart` and `alwaysOnTop` control the standalone `ControlPanel` window.
   - **Fix for extension hosting:** Pass a lightweight host configuration/capabilities struct (e.g. `McKeyHostContext(isStandaloneApp: Bool)`) or environment value into `McKeySettingsRootView` / `SystemSettingsView` so standalone app lifecycle rows (`Launch at login`, `Show icon in Dock`, `Show settings at startup`, `Always on top`) are hidden when hosted as an extension inside `Dimensions`.
4. **`UserDefaults` key namespace (`McKey/McKeySettings.swift`):**
   - When hosted inside `dimensions`, `UserDefaults.standard` is `dimensions`'s app domain rather than `com.qngson.mckey`.
   - **Fix for extension hosting:** Allow `McKeySettings` to accept a dedicated `UserDefaults(suiteName: "com.qngson.mckey")` (or prefix keys / migrate existing `com.qngson.mckey` defaults) so existing user preferences carry over seamlessly when `mckey` runs inside `dimensions`.
5. **Licensing notice (`McKey/LICENSE-AGPL-3.0.txt`, `THIRD_PARTY_NOTICES.md`):**
   - The PHTV engine core (`McKey/Engine/PHTVEngineCore.swift`, `PHTVVietnameseData.swift`) is AGPLv3. Merging `mckey` into `dimensions` brings AGPLv3 engine code into the combined distribution unless isolated or distributed under compatible terms; preserve `LICENSE-AGPL-3.0.txt` and `THIRD_PARTY_NOTICES.md`.

## 4. Prior `codex-advice` Ruling on `DimensionsDesk` `DeskExtension`

Per `_ai/log/20261103-1554Z-codex-advice.md` and `_ai/state/codex-advice.md`:
- `DimensionsDesk`'s `DeskExtension.swift` contract provides `settings`, `menuSection`, `start`, and `stop` hooks.
- **Ruling (`20261103-1554Z-codex-advice.md`):** Consolidate user-facing controls (`McKeySettingsRootView` in `DeskExtension.settings` and mode/status items in `DeskExtension.menuSection`) while deciding whether keyboard execution (`KeyTap` + `PHTVInputEngine`) runs in an independent helper process (so restarting `Dimensions.app` does not interrupt Vietnamese typing or reset TCC `CGEventTap` permissions) or in-process via `McKeyRuntimeController` started/stopped by `DeskExtension.start` / `stop`.

## 5. Recommended Handoff Sequence for Claude

1. **Have Penn commit the current working tree in `mckey`** (all PHTV cleanup, startup fix, hotkey layout fix, and `_ai/` records) so the standalone signed Release state is cleanly anchored on `main`.
2. **Decide with Penn whether to:**
   - **Option A (Helper boundary per `codex-advice`):** Keep `MćKey` as a background keyboard helper executable (using shared `UserDefaults(suiteName: "com.qngson.mckey")` + DistributedNotificationCenter/XPC) while `DimensionsDesk`'s `DeskExtension` hosts `McKeySettingsRootView`, `menuSection`, and `start`/`stop` lifecycle control; or
   - **Option B (In-process `DeskExtension`):** Extract `McKeyRuntimeController` (Section 3 items 1–4) and run `KeyTap` directly inside `Dimensions`'s `DeskExtension` `start`/`stop` hooks.
3. **Subtree merge command into `dimensions`:**
   ```sh
   git subtree add --prefix=Extensions/McKey /Users/qngson/Developer/Projects/qngson/apps/mckey main
   ```
