# Plan

## P1 — Option: disable word-start shortcuts (directive 20260923)

**Behaviour.** With the option on and the engine at a word beginning (`atWordBeginning()`), a key whose event is `vne_telex_w` (w/W) or `vneMapChar` (`[ ] { }`) is typed as its literal character. Mid-word is unchanged: `tw` → `tư`, `t[` → `tơ`. Default off, which keeps today's behaviour.

**Decided:**
- "First key" means word beginning, i.e. `UkEngine.atWordBeginning()`. Not "anywhere".
- One guard in `UkEngine.process(_:)`, just before `dispatch`, in the `!toEscape` branch: rewrite `ev` with `input.keyCodeToSymbol(keyCode, &ev)` and set `telexWUsedAsMapChar = false`. No edits inside `processTelexW` / `processMapChar`.
- `UkOptions.disableWordStartShortcuts: Bool = false`. KeyTap proxy `disableWordStartShortcuts`. UserDefaults key `"disableWordStartShortcuts"`. `resetToDefaults` sets it false.
- The checkbox goes in "Tùy chọn khác / Other options", under the existing tone checkbox. Label: VI `Tắt gõ tắt w→ư, [→ơ ở đầu từ`, EN `Disable w→ư, [→ơ at word start`. Checked means disabled. The checkbox stays enabled under VNI too, where the option is harmless.
- Layout: the options box grows from 38 to 62 high at the same y=178. `modernCheck` moves to y=30 and the new checkbox sits at y=6. Nothing else moves.
- A literal `w` at word start followed by another `w` gives `wư`. That's accepted.

**Status:** implemented and verified 2026-09-23. Waiting on Son to commit.

## P2 — Idle auto-switch, mode bubble, switch-sound toggle (directive 20261005)

Son's answers on 2026-10-05: the bubble rule is "show after N s away". Both new features are on by default. The label is `VI`, not `VN`. Delays are picked from a preset dropdown.

### Preferences (app-level, not engine)

These are computed properties on `AppDelegate` that read and write `UserDefaults` directly. `UkOptions` and `KeyTap` don't get proxies, because the engine never reads them.

| Property | Key | Type | Default when key absent |
| --- | --- | --- | --- |
| `switchSound` | `"switchSound"` | Bool | `true` |
| `autoSwitchEnabled` | `"autoSwitchEnabled"` | Bool | `true` |
| `autoSwitchToVietnamese` | `"autoSwitchToVietnamese"` | Bool | `false` (= EN) |
| `autoSwitchDelay` | `"autoSwitchDelay"` | Int seconds | `10` (also when stored value ≤ 0) |
| `bubbleEnabled` | `"bubbleEnabled"` | Bool | `true` |
| `bubbleDelay` | `"bubbleDelay"` | Int seconds | `10` (also when stored value ≤ 0) |

"Absent" means `defaults.object(forKey:) == nil`. `resetToDefaults()` calls `removeObject(forKey:)` on all six keys.

### Clocks

All clocks use `ProcessInfo.processInfo.systemUptime` and are touched on the main thread only. The tap is on the main run loop.

- `KeyTap.lastKeyAt` (`var`, starts at init-time uptime). It is set as the first line of `handleKeyDown`, so it covers every real keyDown, including passed-through and ⌘/⌃/⌥ ones. Injected events never reach it, because `handle` filters them first.
- `AppDelegate.lastActivityAt` (starts at launch uptime). It is set on every language switch (menu, chord, auto) and in `ControlPanel.apply()` via `app.noteActivity()`.
- `AppDelegate.lastTextFieldAt` (starts at `-1e9`). It is set whenever a text-field click is detected and whenever the bubble is shown.

### F1 — idle auto-switch

- A 1 s repeating `Timer` is started in `finishStartup()`.
- Each tick: if `autoSwitchEnabled`, `tap.enabled != autoSwitchToVietnamese`, and `now − max(tap.lastKeyAt, lastActivityAt) ≥ autoSwitchDelay`, then switch to the target.
- "Input" means keyboard only. Mouse clicks do not reset the idle clock.
- **Every** switch path must set `lastActivityAt = now`. Otherwise a chord or menu switch after a long idle gets reverted by the next tick.
- One function does the work, `languageDidSwitch()`: set `lastActivityAt`, `savePreferences()`, `playSwitchSound()`, `refresh()`, then the F2 on-switch hook. It is called from the chord callback (after KeyTap toggled), from `toggleEnabled()` (after toggling), and from the auto-switch tick (after setting `tap.enabled = target`). The chord path did not previously call `savePreferences()`. Now it does, which is intended.

### F2 — mode bubble

New file `McKey/ModeBubble.swift`. The project uses a file-system-synchronized group, so no pbxproj edit is needed.

**`final class ModeBubble`**
- A borderless `NSPanel` with `[.borderless, .nonactivatingPanel]`.
- Panel settings: `isOpaque = false`, `.clear` background, `hasShadow = true`, `level = .statusBar`, `ignoresMouseEvents = true`, `hidesOnDeactivate = false`, `isReleasedWhenClosed = false`.
- Collection behaviour: `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`.
- Content is an `NSVisualEffectView` (`.hudWindow`, `.active`) with a layer corner radius of 6. It holds a centered bold 12 pt label reading `VI` or `EN`. Size is 34×22.
- It never becomes key. It is shown only with `orderFrontRegardless()`.
- `show(vietnamese: Bool, caret: NSRect)` takes `caret` in Cocoa global coordinates (bottom-left origin).
  - Origin: `x = caret.minX − 4`, `y = caret.maxY + 6`.
  - If that pokes above the top of the screen containing the caret, place it below instead: `y = caret.minY − 22 − 6`.
  - Clamp x into that screen's `visibleFrame`.
  - Set alpha to 1 and order it front. Hide after 1.5 s with a 0.25 s alpha fade, then `orderOut`.
  - A newer `show` or `update` cancels any pending hide. Use a generation counter or a `DispatchWorkItem`.
- `update(vietnamese: Bool)`: if visible, change the text and restart the 1.5 s hide.
- `var isVisible: Bool`.

**`enum FocusProbe { static func focusedTextCaret() -> NSRect? }`** (same file)
- Returns `nil` immediately if `NSApp.isActive`. AX calls into our own process from the main thread can stall.
- Uses the system-wide element and `kAXFocusedUIElementAttribute`, with the messaging timeout at 0.1 on the focused element.
- It is a text input if the role is `AXTextField`, `AXTextArea` or `AXComboBox`. Failing that, it still counts if `kAXSelectedTextRangeAttribute` exists and `AXUIElementIsAttributeSettable` says it is settable. Otherwise return `nil`.
- Caret: read `kAXSelectedTextRangeAttribute` (a CFRange AXValue), then `kAXBoundsForRangeParameterizedAttribute` with it, giving a CGRect AXValue. Accept the result if its height > 0.
- **Convert from AX coordinates, which have a top-left origin relative to the primary screen.** The primary screen is `NSScreen.screens.first`. Compute `cocoaY = primary.frame.height − ax.origin.y − ax.height`.
- Fallback when the bounds are missing or unusable: `NSRect(x: mouse.x, y: mouse.y − 8, width: 1, height: 16)` with `mouse = NSEvent.mouseLocation`, which is already in Cocoa coordinates. A click puts the caret under the mouse, so this is a good fallback.

**Triggers (AppDelegate)**
- `KeyTap.onMouseDown: (() -> Void)?` is called from the `.leftMouseDown` case, alongside the existing `resetWord()`. The callback must only schedule work. AppDelegate's closure does `DispatchQueue.main.asyncAfter(deadline: .now() + 0.15)`, which lets focus settle first.
- On a click: if `bubbleEnabled` and `FocusProbe.focusedTextCaret()` returns a caret, compute `away = now − max(lastTextFieldAt, tap.lastKeyAt)`. Then set `lastTextFieldAt = now`. If `away ≥ bubbleDelay`, call `bubble.show(vietnamese: tap.enabled, caret:)`.
- On a switch (the hook in `languageDidSwitch()`): if `bubble.isVisible`, call `bubble.update`. Otherwise, if `bubbleEnabled` and the probe returns a caret, call `bubble.show` and set `lastTextFieldAt`. The delay does not apply to switches.

### F3 — sound toggle

`playSwitchSound()` starts with `guard switchSound else { return }`.

### Dashboard

- The window's content height goes from 400 to **576**.
- A new section **VI `Chuyển ngôn ngữ` / EN `Switching`** goes at frame `(12, 276, 336, 140)`.
- `ctrlBox` moves from y=276 to **y=452**. The Other options and System sections, and the bottom row, do not move.
- Rows, in box content coordinates:

| y | Control |
| --- | --- |
| 106 | `soundCheck`: VI `Phát âm thanh khi chuyển` / EN `Play sound on switch` |
| 82 | `autoSwitchCheck`: VI `Tự chuyển khi không gõ phím` / EN `Auto-switch when idle` |
| 56 (labels) / 54 (popups) | label x32 w40 `Về:`/`To:` · `autoTargetPopup` x72 w64 `["EN","VI"]` · label x144 w44 `sau`/`after` · `autoDelayPopup` x190 w64 · label x260 w60 `giây`/`sec` |
| 30 | `bubbleCheck`: VI `Hiện VI/EN khi bấm vào ô nhập` / EN `Show VI/EN when clicking a text field` |
| 4 (labels) / 2 (popups) | label x32 w156 `khi rời ô nhập quá`/`when away for` · `bubbleDelayPopup` x190 w64 · label x260 w60 `giây`/`sec` |

- The delay popups have items `["5","10","15","30","60","120","300"]` and are selected by `String(delay)`, falling back to `"10"`.
- `autoTargetPopup` and `autoDelayPopup` have `isEnabled = autoSwitchCheck.state == .on`. `bubbleDelayPopup` has `isEnabled = bubbleCheck.state == .on`. This is set in both `syncFromState()` and `apply()`.
- Every new control has `target = self; action = #selector(apply)`. `apply()` writes all six properties and then calls `app.noteActivity()`.

### Out of scope

- Showing the bubble on app switch or keyboard focus change.
- Chrome/Electron's AX opt-in (`AXManualAccessibility`). Those fall back to the mouse location only when they report a text role, and otherwise show nothing. That is accepted.
- Changing the menu-bar badge, or anything in the engine.

### P2 amendment (2026-10-05, after the first run)

- **No `isVisible` override.** `ModeBubble` subclasses `NSPanel`, so a property named `isVisible` shadows AppKit's own. Rename it to `var isShowing: Bool { generation-tracked flag }`. Set it true in `show`. Set it false only in the fade completion, and only if no newer `show` or `update` happened since the hide was scheduled. Use an `Int` generation counter that each `show`/`update` increments; the completion checks it. `AppDelegate.languageDidSwitch()` uses `bubble.isShowing`.
- **Cancel an in-flight fade.** `show` and `update` set alpha back to 1 through a zero-duration animation group (`NSAnimationContext.runAnimationGroup { $0.duration = 0; animator().alphaValue = 1 }`). That way a running fade cannot finish to 0 after the bubble was refreshed. The fade completion orders out only when the generation is unchanged. Drop the `alphaValue == 0` test.
- **Set the AX messaging timeout on the system-wide element too.** Call `AXUIElementSetMessagingTimeout(systemWide, 0.1)` before the `kAXFocusedUIElementAttribute` read. Otherwise a hung frontmost app blocks the main thread for the default ~6 s.

## P2b — Bubble rework (directive 20261005-bubble-feedback)

**ABANDONED 2026-10-05.** Son stopped it mid-dispatch. The run was killed at init and no source changed. It is superseded by §P2c. Kept for the record; do not implement.

Son confirmed that F1, F3 and P1 work. F2 was unreliable. This section **supersedes the F2 probe, the triggers and the positioning** above. The away rule (`bubbleDelay`), the prefs and the dashboard are unchanged.

**Causes, as diagnosed:**
- Electron (Claude desktop) exposes no AX tree until a client sets `AXManualAccessibility`, so no text field was ever found there.
- The mouse fallback put the bubble at the pointer whenever the caret bounds were missing (Brave).
- Clicks were the only trigger.

**Files:**
- `McKey/ModeBubble.swift` keeps only the panel.
- `FocusProbe` moves to a new `McKey/FocusWatch.swift`, which also holds `FocusWatcher`.

### Caret probe — `FocusProbe.caret() -> CaretInfo?`

The result is `struct CaretInfo { rect: NSRect /* Cocoa global */; method: String; role: String; bundleID: String }`.
- Return nil if `NSApp.isActive`.
- System-wide messaging timeout is 0.1. The focused element's timeout is also 0.1.
- The text-input test is the same as F2: role `AXTextField`/`AXTextArea`/`AXComboBox`, or a settable `kAXSelectedTextRangeAttribute`.
- **The mouse fallback is removed. No caret means no bubble.**
- Try in order and take the first usable rect:
  1. `"collapsed"`: `AXBoundsForRange` on `{sel.location, 0}`.
  2. `"char"`: `AXBoundsForRange` on `{sel.location, 1}`, giving a caret at `rect.minX`. If that fails and `sel.location > 0`, use `{sel.location − 1, 1}`, giving a caret at `rect.maxX`. Either way the result is `NSRect(x: caretX, y: rect.minY, width: 0, height: rect.height)`, computed in AX space before the flip.
  3. `"marker"`: read `"AXSelectedTextMarkerRange"` (an opaque CFTypeRef). Pass it to the parameterized `"AXBoundsForTextMarkerRange"`, which returns a CGRect AXValue. WebKit and Chromium support this.
- A rect is **usable** when all of these hold:
  - height > 0 and ≤ 200;
  - origin is not exactly `(0, 0)`;
  - after the flip, its centre lies inside some `NSScreen.screens[i].frame`.
- The flip is unchanged: `NSScreen.screens.first`, `y = primaryH − y − h`.

### Making Electron/Chromium expose AX — `FocusWatcher`

- On every frontmost-app activation, and once at startup for the frontmost app, call `AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), "AXManualAccessibility" as CFString, kCFBooleanTrue)`. Ignore the error; non-Electron apps reject it harmlessly.
- Skip our own pid.
- Record `manualAXSetAt[pid] = now`.
- **Do not set `AXEnhancedUserInterface`.** It breaks window animations and window managers.
- Cost, accepted: Electron or Chromium apps build their AX tree while frontmost, which uses more CPU and memory there.

### Triggers — all funnel into `AppDelegate.considerBubble(reason: String)`

| Reason | Source | Delay before probing |
| --- | --- | --- |
| `focus` | An `AXObserver` on the frontmost app for `kAXFocusedUIElementChangedNotification` | 0.05 s |
| `activate` | `didActivateApplicationNotification` (the existing observer; also reinstalls the observer and sets manual AX) | 0.25 s |
| `click` | The existing `KeyTap.onMouseDown` | 0.15 s |

`considerBubble`:
1. If `bubbleEnabled` is false, return.
2. Run the probe. If it returns nil, and `manualAXSetAt[frontPid]` is less than 2 s old, and this is not already a retry, retry once after 0.5 s. Otherwise log and return.
3. Compute `away = now − max(lastTextFieldAt, tap.lastKeyAt)`.
4. Set `lastTextFieldAt = now`.
5. If `away ≥ bubbleDelay`, show the bubble.

The on-switch hook in `languageDidSwitch()` keeps its F2 behaviour (update if showing, else probe and show, with no away rule), but uses the new probe.

`FocusWatcher` owns at most one `AXObserver`:
- On activation it removes the old observer's run-loop source and notification, then creates one for the new pid.
- The source goes on `CFRunLoopGetMain()` in `.defaultMode`.
- The callback is a non-capturing C closure. `refcon` is `Unmanaged.passUnretained(watcher)`, and it calls a Swift closure `onFocusChange`.
- Our own pid is skipped.

### Positioning (`ModeBubble.show`)

- **Centred on the caret:** `x = caret.midX − 17`.
- **Above:** `y = caret.maxY + 4`. If `y + 22` exceeds the containing screen's `visibleFrame.maxY`, put it **below**: `y = caret.minY − 22 − 4`.
- Clamp x to `visibleFrame` as before.

### Diagnostics

- Add `Logger(subsystem: "com.qngson.mckey", category: "bubble")` and write one `.notice` line per `considerBubble` or on-switch probe.
- Fields: reason, bundleID, role, method or `none`, the rect, and the outcome: `shown` / `away-suppressed` / `no-caret` / `not-text` / `disabled` / `retry`.
- **Every interpolation is `privacy: .public`.** The default redacts them as `<private>`.
- **Never log text values** or `kAXValueAttribute`.
- Son or the planner reads it with `log show --last 15m --predicate 'subsystem == "com.qngson.mckey"'`.

## P2c — Click sound replaces the bubble; volume slider (directive 20261005-click-sound)

This supersedes F2 and P2b. F1, F3 and P1 are confirmed working and stay as they are, except where this section says otherwise.

### Removed
- The whole bubble: the `ModeBubble` class, `AppDelegate.bubble`, and the on-switch bubble hook in `languageDidSwitch()`.
- The `bubbleEnabled`/`bubbleDelay` properties, their keys, and `bubbleCheck`/`bubbleDelayPopup`.
- The mouse-location fallback.
- `McKey/ModeBubble.swift` is **renamed** with `mv` to `McKey/FocusProbe.swift`, and now holds only `FocusProbe`. No file is deleted.

### `FocusProbe` (`McKey/FocusProbe.swift`)
- `static func textInputFocused() -> (Bool, role: String, bundleID: String)`.
- Keep: the `NSApp.isActive` → false guard, the 0.1 messaging timeout on **both** the system-wide and the focused element, and the F2 text-input test (role `AXTextField`/`AXTextArea`/`AXComboBox`, or a settable `kAXSelectedTextRangeAttribute`).
- No caret bounds, no rects.
- `static func enableManualAX(pid: pid_t)` sets `AXManualAccessibility = kCFBooleanTrue` on `AXUIElementCreateApplication(pid)` and ignores the error. It is never called for our own pid. **No `AXEnhancedUserInterface`.**

### Electron exposure (AppDelegate)
- `focusChanged()` already runs on `didActivateApplicationNotification`. It keeps `tap.resetWord()`, and additionally calls `FocusProbe.enableManualAX` for `userInfo[NSWorkspace.applicationUserInfoKey]`'s `processIdentifier` and records `manualAXSetAt = now`.
- Do the same once in `finishStartup()` for `NSWorkspace.shared.frontmostApplication`.

### Click sound (AppDelegate)
- The `onMouseDown` closure keeps its `asyncAfter(0.15)` and calls `handleMouseDown(retry: false)`. `handleMouseDown`:
  1. If `switchSound` and `clickSound` are not both on, return.
  2. If `FocusProbe.textInputFocused()` returns false: if `!retry` and `now − manualAXSetAt < 2`, call `handleMouseDown(retry: true)` again after 0.5 s. Either way, log and return.
  3. Compute `away = now − max(lastTextFieldAt, tap.lastKeyAt)`.
  4. Set `lastTextFieldAt = now`.
  5. If `away ≥ clickSoundDelay`, call `playModeSound()`.
- **Sound functions.** `playModeSound()`:
  - fetches `NSSound(named: tap.enabled ? "Tink" : "Pop")`;
  - calls `stop()` on it (the named instance is shared, and `play()` on one already playing does nothing);
  - sets `volume = Float(soundVolume)`;
  - calls `play()`.
  `playSwitchSound()` becomes `guard switchSound else { return }; playModeSound()`.
- **Diagnostics.** Add `Logger(subsystem: "com.qngson.mckey", category: "click")` and write one `.notice` per `handleMouseDown` that gets past step 1.
  - Fields: bundleID, role, text yes/no, retry, away (s), and the outcome: `played` / `away-suppressed` / `not-text` / `retry-scheduled`.
  - All interpolations are `privacy: .public`. **No AX values or text.**

### Preferences (computed on AppDelegate, same pattern as F1–F3)

| Property | Key | Type | Default when absent |
| --- | --- | --- | --- |
| `clickSound` | `"clickSound"` | Bool | `true` |
| `clickSoundDelay` | `"clickSoundDelay"` | Int s | `10`, also when ≤ 0 |
| `soundVolume` | `"soundVolume"` | Double | `1.0`. Stored values are clamped to 0…1. |

- `resetToDefaults()` removes these three keys, plus F1/F3's keys as before. It no longer touches `bubble*`.
- Stale `bubbleEnabled`/`bubbleDelay` values in Son's defaults are left orphaned, which is harmless.

### Dashboard: the Switching section is re-laid out
- Frame `(12, 276, 336, 158)`.
- `ctrlBox` moves to **y=470**. The window content height is **594**.
- Other options, System and the bottom row do not move.
- Rows, in box content coordinates:

| y | Control |
| --- | --- |
| 132 | `soundCheck` x12: VI `Phát âm thanh khi chuyển` / EN `Play sound on switch` |
| 108 (label) / 106 (slider) | label x32 w70 `Âm lượng:`/`Volume:` · `volumeSlider` x104 w200 h22, `NSSlider` 0…1, `isContinuous = false` |
| 82 | `clickSoundCheck` **x32** (sub-option): VI `Cả khi bấm vào ô nhập` / EN `Also when clicking a text field` |
| 56 (labels) / 54 (popup) | label **x52 w136** `khi rời ô nhập quá`/`when away for` · `clickSoundDelayPopup` x190 w64 (the same 7 presets) · label x260 w60 `giây`/`sec` |
| 30 | `autoSwitchCheck` x12 (label unchanged) |
| 4 (labels) / 2 (popups) | the auto row, unchanged: `Về:` x32 · `autoTargetPopup` x72 · `sau` x144 · `autoDelayPopup` x190 · `giây` x260 |

- **Dependent enabling** is set in both `syncFromState()` and `apply()`:
  - `volumeSlider` and `clickSoundCheck` follow `soundCheck`;
  - `clickSoundDelayPopup` needs `soundCheck` **and** `clickSoundCheck`;
  - the auto popups follow `autoSwitchCheck`, as before.
- `apply()` writes `clickSound` and `clickSoundDelay`.
- The slider gets its own action, `volumeChanged`, which sets `app.soundVolume = volumeSlider.doubleValue` and then calls `app.playModeSound()` as a preview. `playModeSound` is therefore internal, not private. `syncFromState()` sets the slider from `app.soundVolume`.
