# planner — PHTV port, 2026-11-04 03:27Z

- Seat: Codex continuing Claude's handoff. Tree at e430487 + uncommitted port. Penn's Info.plist/workspace edits untouched.
- Active plan: plans/2026-11-03-phtv-engine.md. Directives: 20261103-phtv-port, 20261103-agy-execution, 20261104-no-double-space, 20261104-no-capitalization, 20261104-english-apps.
- Done: double-space and capitalization removed; English-apps (switch/lock, Ứng dụng page) built. Rename regression fixed by agy-202611040324-8d3f: activation deduplication ignores display name; tests cover rename, behavior change and removal. Seat reran engine 24, conversion 4, runtime 12 successfully.
- No active lanes.
- Build blocker cleared: unsigned Debug and Release builds pass outside Codex sandbox, including final rename change. Sandbox build failed because Swift macro subprocess sandboxing was denied. Logs: /private/tmp/mckey-debug-build.log and /private/tmp/mckey-release-build.log. No app installed or launched.
- Remaining review scope from Claude: deletion sync across legacy encodings; TCVN3 converter canonicalization; page-control inventory vs live behaviour. These were not resolved this turn.
- Not done: GUI/typing/sound/idle-switch/English-apps checks — Penn on device.
