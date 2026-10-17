# 04 — Independent reviews

**Reviewer:** `architecture-reviewer`, bound to `new-provider-6/cn:glm-5.3` — a
different model **and** a different provider from the implementer. Read-only: it
modified no file and could not self-approve.

**Visual review:** `WAITING_FOR_VISUAL_REVIEW`. No available reviewer accepts
Flutter screenshots (`visual-judge` is scoped to pptx/docx/xlsx/pdf/poster/
chart). This file does not claim one.

---

## Round 1 — FAIL, 12 findings

The first pass reviewed the backup/restore and the room sprite correction.

### P1

1. **DB/pack inconsistency after a failed restore.** The database committed
   before the pack swap; a cleanup failure could leave new packs with the old
   data.
2. **Windows path traversal.** `_safeRelative` split on `/` only, so
   `pack\..\..\target` passed on Windows.
3. **A `finishing` session was not refused.** Its focus time exists only in
   that row.
4. **Race between the live-session check and the restore**, and the focus engine
   kept its old in-memory session across the restore.
5. **Incomplete Riverpod refresh** after restore (missing focus controller,
   engine, reports, task detail family).
6. **The floor anchor got no sprite correction**: `roomAnchor` is null when
   `itemId` is empty, which is exactly the floor position.
7. **The correction was dropped on the cat, rabbit and imported-pack paths.**

### P2

8. Size limits ran after the allocation (Android `readBytes`, base64 decode).
9. Android file-dialog lifecycle: two concurrent requests, null streams treated
   as success/cancel.
10. `sync_outbox` was excluded from the backup but not cleared on restore.
11. The reverse-proof tests did not inject failures, and the "box does not move"
    test compared a constant to itself.
12. The rug test proved a formula, not the painted position.

### What was done

1. Restore was reordered to **stage → journal → swap packs → DB transaction →
   cleanup**. A DB failure swaps the old packs back. (Round 2 then found the
   crash window; see below.)
2. `isSafePackPath` rejects backslashes, `.`/`..`, drive letters and `:` in a
   segment; staging also checks `p.isWithin(stagingRoot, target)`.
3. `hasUnsettledWork` covers live + `finishing` focus sessions and running rests.
4. The check is repeated inside the transaction; the engine and session
   controller are invalidated after a successful restore.
5. Added `focusSessionEngineProvider`, `focusSessionControllerProvider`,
   `reportsControllerProvider`, `taskDetailControllerProvider`.
6. Added an explicit `inRoom` flag to `CompanionAvatar`; the room passes it.
7. Every sprite entry point forwards a correction; the value is computed from
   the pack's own baseline.
8. Kotlin queries `OpenableColumns.SIZE` and reads through a bounded stream;
   base64 is size-checked before decoding; the file count is capped.
9. Single pending request; null streams are errors.
10. `sync_outbox` is cleared on restore and included in the snapshot.
11. Added tests for finishing/rest/running-rest refusal, outbox clearing, six
    path-traversal shapes, and a paw-position assertion across six anchors.
12. Added a pixel test for the rug's mean row.

---

## Round 2 — FAIL, 5 findings

The reviewer re-read the fixes and found what the first round's changes had not
closed.

### P1

1. **Crash atomicity.** A process death between the DB commit and the pack
   rename could leave the two halves disagreeing; the in-memory snapshot could
   not survive it.
2. **Concurrent writes during the snapshot/rollback window.** Re-applying the
   snapshot could delete rows another controller wrote.
3. **Custom packs still used the built-in baseline**, so an imported pack with a
   different canvas could hover or sink.

### P2

4. Activity recreation lost the pending file-dialog result, leaving a Dart
   future hanging.
5. No injected pack-swap failure test.

### What was done

1. Added a persistent journal written **before** the first rename, and an epoch
   written into `app_settings` **inside the data transaction**. On startup,
   `recoverInterruptedRestore` compares them: epoch present → keep the new packs;
   absent → restore the old ones. Called from `main()` before the app opens its
   own connection.
2. Removed the in-memory snapshot entirely. The DB transaction is the last step,
   so there is no post-commit rollback that could overwrite concurrent writes.
3. `spriteFeetTargetFraction` replaces the offset option. Each provider computes
   the offset from **its own** manifest (`groundBaseline / canvasHeight`); an
   imported pack therefore uses its declared line, not the built-in 458/512.
4. `onDestroy` completes a pending result with an `interrupted` error instead of
   leaving it unresolved.
5. **Not done:** a fault-injection hook for the rename itself. The three
   journal-recovery tests cover the states a crash can leave (committed,
   not-committed, before-swap), but they do not make `Directory.rename` throw.
   This is recorded as a residual gap rather than claimed as covered.

---

## Round 3 — FAIL, 2 P1 + 1 P2

The third pass checked only the round-2 P1s.

1. **P1 — first-restore crash.** If there was no pack root before the restore,
   there is no `previous` directory; a crash after the swap and before the
   commit left the new packs with the old data, and recovery could not tell.
2. **P1 — no mutual exclusion with other writers.** The swap happened before the
   transaction, so a controller write could still interleave.
3. **P2 — non-square custom canvases.** `groundBaseline / canvasHeight` is only
   the in-box fraction for a square image; `BoxFit.contain` letterboxes a
   rectangle.

### What was done

1. The journal records `hadLive`; on a non-committed epoch with
   `hadLive == false`, recovery removes the live root. A test covers that state.
2. **The pack swap moved inside the database transaction.** SQLite serialises
   writes on the connection, so no other controller write can land between the
   delete and the commit. A swap failure rolls the transaction back and the
   catch swaps the old packs back.
3. The imported-pack baseline is converted through the `BoxFit.contain` rect
   (scale + vertical letterbox).

**No fourth review round was run.** The two P1s and the P2 above are fixed and
tested, but the reviewer has not re-approved the final code. That is recorded
here rather than claimed.

## What is still not reviewed

- **The visual result.** The screenshots exist and the pixel guards pass; an
  independent visual sign-off does not exist and is not claimed.
- **Business-flow review as a separate role.** The flow evidence is test output,
  not a second reviewer's opinion. The brief allows reusing a reviewer across
  rounds; this round used one reviewer for code and security and did not
  fabricate a second.
- **The candidate room's performance** was not re-measured this round.
