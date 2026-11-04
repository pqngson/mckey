# _ai — record for MćKey

Precedence: `directives/` > `ARCHITECTURE.md` > `PLAN.md` > everything else.

| Read | When | Size |
| --- | --- | --- |
| `META.md`, your `state/<id>.md`, newer `log/` entries | always | META <1 KB; planner state <3 KB; latest log window bounded |
| `PLAN.md` | before writing code | <1 KB — active PHTV plan; previous plan archived verbatim |
| `ARCHITECTURE.md` | touching engine/prefs/UI plumbing | 2,278 bytes |
| `directives/` | intent unclear | ~1.5 KB |

Owners: `planner` owns PLAN, ARCHITECTURE, META, MEATBAG, directives, agy.conf, `state/planner.md`. `antigravity` (agy) owns `McKey/` source and `state/antigravity.md`. Both append to `log/` (`YYYYMMDD-HHMMZ-<id>.md`, append-only). `MEATBAG.md` is the only list of what's waiting on Son.
