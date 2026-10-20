# Architecture — MćKey

macOS menu-bar Vietnamese IME. No test target; build is `xcodebuild -scheme McKey`.

- `McKey/UKEngine.swift`, `UKInput.swift`, `UKLexi.swift` — port of UniKey's engine. Keep it close to the original; new behaviour goes in as small, option-gated guards, not rewrites.
- `UkOptions` (UKEngine.swift) holds engine options. `KeyTap` proxies them. `AppDelegate` persists them in `UserDefaults` (`loadPreferences` / `savePreferences` / `resetToDefaults`). `ControlPanel.swift` is the dashboard, built in code with hardcoded frames. Every label is bilingual via `L(vi, en)`.
- An **engine** preference touches all four layers, in that order. An **app-level** preference, one the engine never reads, is a computed property on `AppDelegate` over `UserDefaults` plus its `ControlPanel` control. Examples are sound, auto-switch and bubble.
- `ModeBubble.swift` holds the non-activating VI/EN overlay and `FocusProbe` (an AX caret lookup). AX rects have a top-left origin on the primary screen and must be flipped to Cocoa coordinates. Never make AX calls into our own process (`NSApp.isActive`) from the main thread.
- The tap callback runs on the main run loop. It must only record or schedule work, never make AX queries synchronously.
