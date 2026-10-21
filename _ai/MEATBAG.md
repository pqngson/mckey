# Waiting on Son

- Try P2c in a real app:
  - The Switching section's layout: sound, then the volume slider, then the indented click-sound sub-option and its delay, then auto-switch.
  - Untick sound: the slider and the sub-option should grey out.
  - Drag the volume slider: one preview sound on release.
  - Wait more than 10 s, then click into a text field in Claude, Brave and TextEdit. You should hear Tink (VI) or Pop (EN).
  - If Claude stays silent, run `log show --last 10m --predicate 'subsystem == "com.qngson.mckey"'` (or let the planner read it).
- `McKey.xcodeproj/project.pbxproj` changed outside any agent: the product reference path went from `ḾcKey.app` to `MćKey.app`, probably Xcode. Keep it or `git checkout` it. It's not in the proposed commit.
- Commit P1 + P2 (the command is in the 05:33Z planner log entry).
