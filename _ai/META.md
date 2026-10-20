# _ai — record for MćKey

Precedence: `directives/` > `ARCHITECTURE.md` > `PLAN.md` > everything else.

| Read | When | Size |
| --- | --- | --- |
| `META.md`, your `state/<id>.md`, newer `log/` entries | always | ~1 KB |
| `PLAN.md` | before writing code | ~22 KB — read §P2c, skip §P2b (abandoned) |
| `ARCHITECTURE.md` | touching engine/prefs/UI plumbing | ~1.3 KB |
| `directives/` | intent unclear | ~1.5 KB |

Owners: `planner` owns PLAN, ARCHITECTURE, META, HUMAN, directives, agy.conf, `state/planner.md`. `antigravity` (agy) owns `McKey/` source and `state/antigravity.md`. Both append to `log/` (`YYYYMMDD-HHMMZ-<id>.md`, append-only). `HUMAN.md` is the only list of what's waiting on Son.
