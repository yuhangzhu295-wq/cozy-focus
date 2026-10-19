# 09 — Final status

**ENGINEERING_COMPLETE = YES for the scope below — this is a claim about the work, not the review. The review rounds are recorded further down, and the last recorded round's verdict is the authority on whether engineering defects remain.**
**STORE_RELEASE_READY = NO.**
**OWNER_VISUAL_APPROVED = NO — not claimed.**

## Done

| Item | Evidence |
|---|---|
| Room sprite ground correction | `b9e19ee`; 8 tests; box does not move; room-only |
| Hand-drawn room candidate, V1–V3 | `599099a`; 4 pixel/contract tests, reverse-proved |
| Candidate rug plane | `b068495`; device walk found it, static contract test |
| Local backup + restore | `df811ca`; 11 isolated tests; device walk |
| Backup UI in 数据与同步 | two real actions, preview, explicit confirmation |
| FLOW-01/02/04 gaps | `b068495`; 3 tests on the real engine |
| Full suite | **2181/2181** |
| Analyze / format / APK / AAB | 0 issues, 0 changed, 32.1 MB, 50.7 MB |
| Full gate (`--with-device`) | **14 PASS / 4 BLOCKED / 0 FAIL** (report at `4baaa2e`) |
| Device screenshots | `device/` — backup flow, candidate home/room/focus, shipped home/room |

## This round: eight review rounds on the same fixture

The QA fixture that produces the screenshot data has been through eight review rounds. Each
round found a real defect, including ones introduced by the previous fix:

1. It wrote ledger rows and XP by hand. Settlement also writes the memories, the
   happiness bump and the craft progress, so the fixture showed a week of play
   with no memory of it.
2. That fix left `reset()` unable to delete the memories settlement wrote, and
   its two cleanups were an either/or.
3. `reset()` used `like 'qa_demo_sess_%'` — `_` is a SQL wildcard — and every
   session settled at one instant, so two 50-minute sessions shared a memory id
   and one was silently dropped.
4. Sessions settled in reverse chronological order, so the pet remembered its
   newest session as its first and reached Lv.2 before Lv.13.
5. Memories were deleted by (pet, moment), which also removed a real memory that
   happened to share the moment; and `reset()` left the tasks, plans and notes
   the same seed created.
6. `reset()` left `qa_craft_job` behind (re-seeding craftActive collided), and
   `deleteMemoriesWithIdPrefix` still matched `qa_` with a SQL wildcard.
7. Overwriting scenarios were not undone: `lateGrowth → reset` left the pet at
   Lv.20 forever and `highMood → reset` turned a real 40% happiness into 100%.
   The craft rollback also subtracted the recipe's `output_quantity` while
   settlement adds exactly one unit.
8. That fix snapshotted progress when the *overwriting scenario* ran, which is
   after `demoDay` had awarded the week. `demoDay → highMood → reset → demoDay`
   then restored the post-demo snapshot after unwinding it, and the second seed
   doubled the week (2550 XP / 510 minutes; reproduced across processes on the
   emulator). The snapshot is taken once, after adoption and before the
   scenario runs. Fixture inventory rows are now deleted rather than zeroed, so
   `seed → reset → seed` leaves the same rows as a single seed.

Every fix carries a test and a reverse proof (the old behaviour restored makes
that test fail). `CompanionMemory.idFor` is now public so the fixture and
settlement share one definition of a memory id.

**The device measurement is now guarded, and the guard is what made it valid.** Across this
session the same build measured p50 2906 µs / p90 8578 µs on a quiet host and
p50 4251 µs / p90 20316 µs inside the gate on a host down to 1.4 GB free — a
spread that tracks the host, not the code. The gate therefore reads free
physical memory before it measures, polls for a minute, and reports BLOCKED
rather than FAIL when the host has less than the AVD's own 2 GB (`hw.ramSize=2G`):

Run with the device phase first, the same gate measured **p50 2809 µs /
p90 7800 µs, 2 late frames, host free memory 2153 MB** — inside the criterion.
An earlier run, taken after the test suites with 1806 MB free, reported BLOCKED
instead of a number. Both outcomes come from the same guard: it either has the
headroom to measure or it says it does not. **BLOCKED is not a pass and not a
regression claim**, and the headroom now travels in every evidence line so the
two cannot be confused.

The device phase now runs first in the gate, before the six test suites: run
after them it measured p50 3877 with 1.7 GB free, and nothing else the gate does
should be contention the harness reports as the app's problem.

**One unit-test run failed and did not reproduce.** The gate's first run after
the seventh-round fixes reported `UNIT_TESTS 808 passed, 1 failed`, while the
same command run directly reported 2178/2178 and the immediate re-run of the
whole gate reported 2178/2178. The failing test's name was not in the evidence,
which is why the gate now appends the `[E]` lines to any failing test row: a
count without a name cannot be reproduced or told from a flake. This is recorded
as an **unreproduced flake, not as a pass** — if it recurs, the report will name
the test.

## Not done, with the reason

| Item | Status | Reason |
|---|---|---|
| Release signing | BLOCKED | No keystore; the owner must generate and store it. No private key was written. |
| Launcher icon | BLOCKED | Candidate exists; approval not given; `android/` untouched. |
| Owner visual gate | BLOCKED | Required, and not run: no image-capable reviewer channel exists on this machine. See `05_VISUAL_COMPARISON.md`. |
| Independent visual review | WAITING | No available reviewer accepts Flutter screenshots. |
| Physical-GPU frame time | NOT MEASURED | Emulator uses swiftshader; raster numbers are not transferable. |
| TalkBack walk | NOT MEASURED | Not run this round. |
| Cloud sync / white noise / notifications / dress | NOT IMPLEMENTED | Product decisions; the UI says so honestly. |
| FLOW-10 keyboard/loading/failure states | CLOSED | `flow10_keyboard_and_retry_test.dart`; the remaining PARTIAL items are device-only (resume visual state, live companion-switch smoothness). |
| Candidate promotion | NOT DONE | Requires the owner's choice. |

## Evidence gaps that are not hidden

- The **board-level visual review** is not an independent pass. The screenshots
  and per-element comparisons exist; the sign-off does not.
- The **candidate performance** numbers are from the previous round. This round
  did not re-run them, and no new number is claimed.
- **FLOW-06's animation smoothness on a live switch** was not re-recorded this
  round; the renderer-swap blank has a device instrument from earlier rounds and
  a widget-level guard.
- The **device walk** covered FLOW-08 fully and parts of A/D/F. It is not a
  substitute for the full regression suite, and the suite is not a substitute
  for the walk.
- **One review P2 is still open**: there is no fault-injection hook for the pack
  rename itself. The three crash-recovery states (committed, not committed,
  before swap) are tested, but `Directory.rename` is never made to throw. It is
  recorded in `04_SUBAGENT_REVIEWS.md` rather than claimed as covered.
- **The independent reviewer returned FAIL twice.** All P1 findings from both
  rounds were fixed; the verdicts and the fix list are in
  `04_SUBAGENT_REVIEWS.md`. A third full review round was not run, so the final
  code has not been re-approved by that reviewer.

## The minimal list that needs the owner

1. Approve or reject the launcher icon candidate.
2. Generate and back up the release keystore.
3. Choose the room: shipped or candidate (and, if candidate, whether the shelf
   crop and soft window are the first fixes).
4. The visual gate.
5. Whether data export/restore needs encryption or a merge mode — V1 replaces,
   and says so.

Nothing above is blocked on engineering.
