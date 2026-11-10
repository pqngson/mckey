# _ai — record for MćKey

Precedence: `directives/` > `ARCHITECTURE.md` > `PLAN.md` > everything else.

| Read | When | Size |
| --- | --- | --- |
| `META.md`, your `state/<id>.md`, newer `log/` entries | always | META <1 KB; planner state <3 KB; latest log window bounded |
| `PLAN.md` | before writing code | <1 KB — active PHTV plan; previous plan archived verbatim |
| `ARCHITECTURE.md` | touching engine/prefs/UI plumbing, installing | 3,588 bytes |
| `specs/2026-11-04-port-audit.md` | cleanup/control review | 7,202 bytes |
| `specs/2026-11-04-dimensions-extension-prep.md` | merging into `dimensions` as an extension | 7,905 bytes |
| `directives/` | intent unclear | ~1.5 KB |

Owners: `planner` owns PLAN, ARCHITECTURE, META, MEATBAG, directives, agy.conf, `state/planner.md`. `antigravity` (agy) owns `McKey/` source and `state/antigravity.md`. Both append to `log/` (`YYYYMMDD-HHMMZ-<id>.md`, append-only). `MEATBAG.md` is the only list of what's waiting on Son.
