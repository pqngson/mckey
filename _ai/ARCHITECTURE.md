# Architecture — MćKey

macOS menu-bar Vietnamese IME. No test target; build is `xcodebuild -scheme McKey`.

## PHTV port in progress (2026-11-03)
The active plan's accepted scope supersedes the legacy implementation notes below. Penn accepted AGPLv3 code and requested PHTV's engine and four settings pages. Engine sources live under McKey/Engine; McKeySettings is the observable persistent settings model; ControlPanel hosts the adapted SwiftUI pages. McKey's existing sound profile (Tink=VI, Pop=EN), status badge/menu and idle auto-switch remain app-owned. UI tuning literals belong in McKey/Theme.swift, grouped by component. No PHTV clipboard/emoji/updater managers are part of this port.

## Verification tiers
- Run: compile engine harness uncapped, execute under 30-second wall cap with per-case limits; build app separately without test cap.
- Batch: full headless engine/runtime suites under 45-second wall caps, build separately.
- Milestone: unsigned Debug and Release app builds; Penn reviews actual app UI and typing. GUI tooling requires separate chat authorization.

## Port audit & Dimensions extension prep
- [Control wiring, encoding policy and prior art](specs/2026-11-04-port-audit.md) tracks the November cleanup. Native Backspace removes one complete logical encoded item; VNI/CP1258 may need two synthetic deletions, while Unicode Composite uses one grapheme deletion.
- TCVN3 ambiguous accented bytes decode to lowercase by default; explicit uppercase conversion is supported. The converter displays this format limitation.
- [Dimensions extension merge preparation](specs/2026-11-04-dimensions-extension-prep.md) documents the signed Release installation, standalone vs. extension file boundaries, and the 5 decoupling points (`McKeyRuntimeController`, `McKeyBundle`, standalone `SystemSettingsView` flags, `UserDefaults` suite, AGPLv3 notices) for Claude.

## Legacy implementation notes (before port)

Historical only: the removed UK engine and AppDelegate-owned preferences below no longer describe the active port. Use the PHTV section and audit above for current code.

- `McKey/UKEngine.swift`, `UKInput.swift`, `UKLexi.swift` — port of UniKey's engine. Keep it close to the original; new behaviour goes in as small, option-gated guards, not rewrites.
- `UkOptions` (UKEngine.swift) holds engine options. `KeyTap` proxies them. `AppDelegate` persists them in `UserDefaults` (`loadPreferences` / `savePreferences` / `resetToDefaults`). `ControlPanel.swift` is the dashboard, built in code with hardcoded frames. Every label is bilingual via `L(vi, en)`.
- An **engine** preference touches all four layers, in that order. An **app-level** preference, one the engine never reads, is a computed property on `AppDelegate` over `UserDefaults` plus its `ControlPanel` control. Examples are sound, auto-switch and bubble.
- `ModeBubble.swift` holds the non-activating VI/EN overlay and `FocusProbe` (an AX caret lookup). AX rects have a top-left origin on the primary screen and must be flipped to Cocoa coordinates. Never make AX calls into our own process (`NSApp.isActive`) from the main thread.
- The tap callback runs on the main run loop. It must only record or schedule work, never make AX queries synchronously.
