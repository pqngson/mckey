# Waiting on the meatbag

- Authorize GUI drive/capture in the pending chat question, or perform the following checks on the current build.
- Review all five settings pages in Vietnamese and English, including resizing, sidebar search, restore-mode labels, and Dock behavior after closing settings.
- In a disposable TextEdit document, verify Telex `aas` → `ấ`, VNI `a61` → `ấ`, Esc restoration, configured switch chords, hold-to-pause, and deletion/retyping across all five output code tables. VNI/CP1258 Backspace should remove the full encoded logical letter.
- Check switch-to-English and lock-English rules across two apps: manual VI allowed for switch-only; blocked for lock; leave/remove rule restores the prior mode; unrelated settings and entry renames preserve manual selection.
- Untick switch sound: volume and click-sound controls disable. Release the volume slider: one preview. Verify Tink for VI, Pop for EN; after more than 10 seconds away, click text fields in TextEdit, Claude and Brave and check click feedback.
- Verify idle target/delay, including suppression of a VI idle target in an English-locked app.
- Check converter results and selectable output, settings export/import, and login-item status/error handling. Review UI feel and actual audio on the Mac.
- Review and commit the current uncommitted PHTV port and cleanup changes in `mckey`.
- Confirm whether to extract an embeddable extension controller in `mckey` first (decoupling `KeyTap`/`McKeySettings`/SwiftUI pages from standalone `AppDelegate`/`NSStatusItem`/`SMAppService.mainApp`) or merge the repo history directly into `dimensions` as-is.
