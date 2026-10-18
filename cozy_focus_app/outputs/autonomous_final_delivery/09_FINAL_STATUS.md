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
| Full suite | **2158/2158** |
| Analyze / format / APK / AAB | 0 issues, 0 changed, 32.1 MB, 50.7 MB |
| Full gate (`--with-device`) | **14 PASS / 3 BLOCKED / 1 DEFERRED / 0 FAIL** |
| Device screenshots | `device/` — backup flow, candidate home/room/focus, shipped home/room |

## Not done, with the reason

| Item | Status | Reason |
|---|---|---|
| Release signing | BLOCKED | No keystore; the owner must generate and store it. No private key was written. |
| Launcher icon | BLOCKED | Candidate exists; approval not given; `android/` untouched. |
| Owner visual gate | DEFERRED | Never decided by measurement. |
| Independent visual review | WAITING | No available reviewer accepts Flutter screenshots. |
| Physical-GPU frame time | NOT MEASURED | Emulator uses swiftshader; raster numbers are not transferable. |
| TalkBack walk | NOT MEASURED | Not run this round. |
| Cloud sync / white noise / notifications / dress | NOT IMPLEMENTED | Product decisions; the UI says so honestly. |
| FLOW-10 keyboard/loading/failure states | PARTIAL | Named in `02_BUSINESS_FLOW_MATRIX.md`; not asserted. |
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
