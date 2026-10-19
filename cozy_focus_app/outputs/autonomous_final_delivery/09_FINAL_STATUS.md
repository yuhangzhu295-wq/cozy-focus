# 09 — Final status

**ENGINEERING_COMPLETE = YES for the scope below.**
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
| Full suite | **2173/2173** |
| Analyze / format / APK / AAB | 0 issues, 0 changed, 32.1 MB, 50.7 MB |
| Full gate (`--with-device`) | **13 PASS / 5 BLOCKED / 0 FAIL** (report at `531fa22`; DEVICE_MATRIX is one of the five — see below) |
| Device screenshots | `device/` — backup flow, candidate home/room/focus, shipped home/room |

## This round: five review rounds on the same fixture

The QA fixture that produces the screenshot data was reviewed five times. Each
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

Every fix carries a test and a reverse proof (the old behaviour restored makes
that test fail). `CompanionMemory.idFor` is now public so the fixture and
settlement share one definition of a memory id.

**The device measurement is now guarded, and currently blocked.** Across this
session the same build measured p50 2906 µs / p90 8578 µs on a quiet host and
p50 4251 µs / p90 20316 µs inside the gate on a host down to 1.4 GB free — a
spread that tracks the host, not the code. The gate therefore reads free
physical memory before it measures, polls for a minute, and reports BLOCKED
rather than FAIL when the host has less than the AVD's own 2 GB (`hw.ramSize=2G`):

> the host has only 1806 MB free after a minute of settling, and the AVD's guest
> RAM alone is 2048 MB (hw.ramSize=2G), so the emulator is being paged.

This host (16 GB, WSL and the IDE resident, emulator running) cannot currently
give a valid frame-time measurement. **BLOCKED is not a pass and not a
regression claim.** The last valid measurements at this build family were
p50 2906 / p90 8578 (standalone) and p50 3279 / p90 6886 (full gate), both
inside the criterion; they were taken when the host had headroom, and they are
quoted as history, not as this run's result.

The device phase now runs first in the gate, before the six test suites: run
after them it measured p50 3877 with 1.7 GB free, and nothing else the gate does
should be contention the harness reports as the app's problem.

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
