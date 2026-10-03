# P22 — Persistence / Recovery / Migration

```
P22_PERSISTENCE: PASS
P22_MIGRATION:   PASS
```

`test/integration/persistence_recovery_test.dart` — 14 tests.

---

## 1. Why this suite uses a real file

Every other suite runs on `NativeDatabase.memory()`. That is right for speed and
**wrong for this**: with an in-memory database the connection never closes, so
nothing ever has to be read back from disk and a "restart" is a fiction. Every
survival assertion would pass for free.

So the database here is a **file** in a temp directory, and dying means genuinely
closing the connection *and* the container, then opening both again. A negative
proof asserts the harness really is file-backed by reading the row back with a
**separate raw `sqlite3` connection** — if it were in memory, the file would not
have it.

## 2. The process-death matrix

Death at each of the six points the brief names, with what has to survive:

| Killed during | Asserted to survive |
|---|---|
| **active focus** | the session returns with its **plan** (1500 s), not just its existence |
| **pause** | the **open pause interval** — without it, the elapsed time would silently absorb the break |
| **finishing** | recovery settles it **exactly once**, and a second recovery adds nothing |
| **craft job** | the job *and its accumulated seconds* (900 s) — losing progress loses real focus time |
| **room edit** | both placements, so a restart cannot reset the room |
| **room movement** | the **moved** position, scale and visibility — not the original |

The pause and craft cases are the ones worth having: both would pass a naive
"is the row still there" check while losing the part a user would actually notice.

## 3. The five facts, and the four "no"s

One test drives a full lifecycle — choose a companion, own and place furniture,
settle a real 12-minute session — then restarts and checks all five: companion,
inventory, room position, growth and memory.

A second test takes the same state and restarts **three times**, each launch
running both recovery and restore, because a launch hook that fires twice is the
realistic way a duplicate appears. It then asserts:

- **no data loss** — every count is unchanged
- **no duplicate settlement** — one record, one ledger row
- **no duplicate memory**
- **no room reset**
- and XP is not re-awarded on launch

## 4. Migration

The app is at schema **v4** with three documented upgrade steps. Only v3→v4 had
coverage before this phase; all of it is now covered, plus the full chain.

| From | What the migration does | Asserted |
|---|---|---|
| v1 → v2 | adds `task_name` / `mood` | rows survive; the new columns exist and are **empty**, which is honest rather than a fabricated value |
| v2 → v3 | adds `progress_seconds`, **seeds recipes on upgrade** | the running job survives at progress 0; all 8 recipes appear |
| v3 → v4 | dedupes duplicate session rows **preserving entered details**, then creates the unique index | covered by the pre-existing `focus_record_migration_test.dart` |
| v1 → v4 | the whole chain | every row survives with its note and duration intact; the index exists |

### The negative proof that matters

`v3 → v4` deletes duplicate rows **before** creating the unique index on
`session_id`. Without that ordering the index creation fails and the upgrade
aborts — taking the user's database with it.

The proof attempts to create a unique index over a table that still has
duplicates and asserts SQLite **refuses**; then dedupes and asserts it succeeds.
That is the migration's shape, and it establishes that the dedup step is
load-bearing rather than decorative.

### The fixtures had to be real

Three tests failed on the first run, and every failure was my fixture rather than
the migration:

- **My "v1" database had only the focus tables.** A real v1 database has all four,
  and the chain runs `v1→v2` *and* `v2→v3` (which adds a column to `craft_jobs`
  and seeds recipes) — so the migration correctly failed on a table my fixture had
  omitted.
- **My "v2" database used the v1 shape.** A real v2 already has the columns
  `v1→v2` added, and `v3→v4` reads `duplicate.task_name`. The fixture described a
  database that never existed.
- **I expected `running`, got `restored`.** The engine distinguishes a session
  started in this process from one read back from disk, and the player is told
  which. `restored` is the design; my expectation was wrong.

The lesson is the one the brief's own rule points at: a migration test is only
worth anything if the fixture is a database that could actually have existed.

## 5. Gates

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | **PASS** — 265 files, 0 changed |
| `flutter analyze --fatal-infos --no-pub` | **PASS** — 0 issues |
| `flutter test --no-pub` | **PASS** — **1169 / 1169** (was 1155; +14) |
| `git diff --check` | **PASS** |

## 6. What this does not cover

- **No real process kill.** "Death" is a closed connection and a disposed
  container, not `SIGKILL` mid-transaction. A crash *during* a write is a
  different failure mode — SQLite's WAL gives atomicity there, and the app relies
  on that rather than re-implementing it, but it is not tested here.
- **No on-device restart.** The P14 and P18 work restarted the real app; this
  suite restarts a container over a file. The two agree on the schema, not on the
  platform's own lifecycle behaviour.
- **No forward migration.** There is no v5, so nothing tests what a *future*
  upgrade would do to a v4 database.
