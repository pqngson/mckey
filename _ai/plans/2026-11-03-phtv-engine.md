# PHTV composition engine port

## Accepted scope amendment (Penn, 2026-11-03)
Execution routing: Penn stopped Luna and explicitly directed agy for today's work. Resume from the existing working tree, with separate engine and settings/runtime file scopes; do not restart or discard the port. Root remains planner/reviewer and independently verifies results.

Penn accepted the license and requested PHTV's Bộ gõ, Phím tắt, Hệ thống and Thông tin pages and underlying engine. This supersedes the composition-only restrictions below: implement the typing page's engine features, including dictionary auto-restore and quick consonants. Preserve McKey's Tink when Vietnamese is enabled and Pop when disabled, click sound/volume preferences, existing status badge and dropdown, and idle auto-switch behavior. Adapt System/About to McKey; omit PHTV-specific distribution infrastructure and unrelated clipboard/emoji features unless Penn requests otherwise (optional clarification pending).

### Implementation boundaries
- Double-space period removed entirely (directives/20261104-no-double-space.md).
- Engine lane owns McKey/Engine/, McKey/Resources/Dictionaries/, Tests/Engine/, scripts/test-engine.sh and PHTV source/license provenance files. Expose PHTVOptions (Codable/Equatable), PHTVInputEngine.options, reset(), process(keyCode: UInt16, shift: Bool, capsLock: Bool, characters: String, vietnamese: Bool) -> PHTVResult, restoreRaw() -> PHTVResult. Result has handled Bool, backspaces Int, output String. No event injection or UI in this lane.
- Settings lane owns replacement ControlPanel.swift, McKey/Settings/, McKey/Theme.swift. Four pages use PHTV's actual card/sidebar structure adapted to McKey, centralized literal tokens, bindings to McKeySettings. No AppDelegate/KeyTap writes.
- Integration lane owns McKeySettings.swift, KeyTap.swift, AppDelegate.swift, project settings and integration tests. Shared persistent settings model uses engine options and retains McKey preferences. Settings UI and runtime must share one source of truth.
- UI page control inventory is tracked in the implementation brief and must map to live behavior; no placeholder controls.
- Engine new public options: inputType Int (0...3), codeTable Int (0...4), checkSpelling Bool, modernOrthography Bool, upperCaseFirstChar Bool, autoRestoreEnglishWord Bool, autoRestoreEnglishWordMode Int, quickTelex Bool, allowCustomConsonants Bool, customConsonants [String], quickStartConsonant Bool, quickEndConsonant Bool, restoreOnEscape Bool, disableWordStartShortcuts Bool. Add freeMark and restoreIfWrongSpelling if required internally. Defaults preserve existing McKey orthography and shortcuts; new feature defaults should match PHTV where sensible.
- Configurable primary/secondary switching chords, restore Esc/Option/Control and hold-to-pause are real runtime features. Preserve existing Fn+Shift and Ctrl+Shift as initial defaults.
- No GUI capture/actuation. Seat builds and runs headless tests; Penn reviews appearance/typing.

## Goal
Use PHTV's Vietnamese composition engine in McKey without importing PHTV's unrelated app features.

## Historical initial architecture (superseded by accepted scope above)
Inspected McKey working tree at e430487 and local PHTV at 0a42ef4. PHTV source root: /Users/qngson/Developer/Repositories/PHTV/Apps/macOS/PHTV.

- Extract Engine/PHTVEngineCore.swift (3,135 lines) and Engine/PHTVVietnameseData.swift (712 lines), preserving source headers and provenance. These alone are not a standalone library.
- Supply a McKey-owned runtime adapter for the core's phtvRuntime accessors and custom-consonant rows. Review Models/CustomConsonants.swift for required helpers.
- Disable dictionary auto-restore, macros, native text replacement, quick consonants, automatic capitalization and double-space punctuation in the initial port. Provide explicit no-op service boundaries rather than importing PHTV managers.
- Keep KeyTap's event injection, language switching, navigation handling, focus resets, AppDelegate and ControlPanel behavior.
- Core takes Mac virtual key codes, not the Unicode scalar currently sent by KeyTap. Decode marked output using Engine/PHTVEngineDataBridge.swift as reference. Verify replacement order and whether the trigger key is included for every hook state.
- Keep current Telex/VNI preferences, modernStyle semantics (currently true selects the second vowel for oa/oe/uy), and disableWordStartShortcuts. Confirm mapping behavior by tests rather than equating similarly named options.
- Keep the old engine until the adapter has passed composition and event-output tests; avoid shipping two active composition engines.

## Historical initial spec (superseded by accepted scope above)
Port composition only. No PHTV UI, clipboard history, emoji, GIF services, updater, dictionaries or bundled app managers.

PHTV is AGPLv3; McKey carries GPLv3. A combined distribution must preserve applicable AGPL terms and notices, not describe the imported code as GPL-only. User preference is pending. Reference: https://www.gnu.org/licenses/license-compatibility.en.html . Review engine lineage notices referencing UniKey and OpenKey before distribution.

## Global constraints
No state-changing git, GUI or installation. Preserve existing Info.plist and Xcode workspace edits. Executor writes feature code; seat verifies.

## Tasks
- [x] Inspect source boundary, formats, tests and licenses
- [x] Resolve Penn's AGPL preference before copying code (accepted 2026-11-03)
- [x] Extract core and minimal settings/output adapter with provenance and license notices
- [ ] Add headless regression harness covering Telex/VNI, tones, uppercase, repeated modifiers, punctuation, bracket/w word-start suppression, backspace, reset/focus boundaries and unsupported Unicode/layout input
- [ ] Test hook-state decoding against rendered output, including word breaks and deletions; adapt relevant cases from PHTV Tests/EngineRegressionTests.swift without its hosted-app dependencies
- [x] Integrate adapter with KeyTap; preserve existing preferences and app behavior (headless verification; actual app checks pending)
- [ ] Seat runs build and bounded headless tests; Penn judges typing behavior on device

## Verification
Build separately with xcodebuild -scheme McKey -configuration Debug CODE_SIGNING_ALLOWED=NO build (use temporary derived-data location if sandbox requires). Headless tests need per-case limits and a 30-second Run / 45-second Batch wall cap. Unsigned Debug/Release builds and engine/converter/runtime suites passed on 2026-11-04. The cleanup audit is in specs/2026-11-04-port-audit.md; actual app checks remain pending.
