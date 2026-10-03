# P20 — Golden Business Flow, end to end

One test file walks the whole chain a real user takes and asserts the cardinality
the slice tests cannot see from where they stand.

```
GOLDEN_FLOW = PASS
```

---

## 1. What it covers

`test/integration/golden_flow_test.dart` — the first `test/integration/` in this
repository. Every other suite tests a slice; this one walks the chain:

fresh user → companion selection → focus start → pause → resume → complete →
save → settlement → record → reward → growth → craft → inventory → collection →
room placement → anchor → walk → furniture use → memory → restart → daily routine

**The clock is injected and nothing is waited.** `FocusClock` is overridden, so a
30-minute session advances in microseconds. Nothing in the file sleeps.

**Setup seeds prerequisites, never the outcome.** The flow starts a craft job —
a precondition, because a recipe needs accumulated focus seconds to complete. It
does **not** write the XP, the record, the ledger row, the memory or the inventory
item; those are exactly what the assertions are about, and writing them would make
the test agree with itself.

### The chain, with the numbers it actually produced

A 60-minute plan, 10 minutes run, paused, resumed, 20 more → **1800 s elapsed**:

| Step | Asserted |
|---|---|
| fresh user | pet + progress exist |
| selection | `rabbit` selected and persisted |
| craft precondition | a 30-minute rug job started |
| complete | status `finishing`, and **zero** records yet — this is what the completion page shows |
| save | **1** record (1800 s), **1** ledger row (60 coins / 150 XP) |
| growth | pet holds 150 XP, level 2 |
| craft | job `completed`; inventory contains the rug |
| room | rug placed; the simulation binds an anchor and honours a furniture request |
| memory | two memories — see below |
| restart | selection, room, XP and memories all survive a fresh container |
| daily routine | noon and 23:30 do not produce the same cause |

---

## 2. The negative proof found that a test was passing for the wrong reason

The brief asks that critical gates be shown to fail. Doing that here was the most
useful part of the phase.

**I disabled the idempotency guard** in `FocusSessionEngine._persistRecord` —
the `if (existing == null)` check that stops a second record being written — and
re-ran the suite. **Everything stayed green.**

Two things came out of that:

1. **My recovery test was not testing recovery.** It saved first, and `save`
   leaves the session `saved`; `recoverAbandonedSessions` only considers sessions
   in `finishing`, so it never reached the code I had broken. The test was named
   for a path it did not take. It now completes a session, *abandons* it in
   `finishing`, revives a fresh container over the same database, and recovers
   from there — the state a killed process actually leaves.
2. **The real guarantee is the database, not the Dart check.** The reason the
   suite stayed green is `focus_records_table.dart:22`:

   ```dart
   List<Set<Column>> get uniqueKeys => [
         {sessionId},
       ];
   ```

   The Dart check is an optimisation. The unique index is what makes
   "one session → one record" true, and a test that only exercises the Dart path
   would never notice if the index were dropped.

So the suite now contains a test that **tries to defeat the index** — inserting a
second record for the same session under a different record id, the shape a
duplicate settlement would really take — and asserts it is refused. That is the
negative proof, and it is aimed at the mechanism that actually holds.

The temporary break was restored immediately and verified by hash
(`09089f68…`, matching before and after). Nothing broken was committed.

---

## 3. P14 regression

The brief asks for this explicitly, and it is covered in two places:

- `test/presentation/app_bottom_nav_test.dart` — the **real widget**, tapping the
  actual tab bar with a session in `finishing`.
- `test/integration/golden_flow_test.dart` — the **state contract**: after
  `completeSession` the record count is 0, after the flush `AppBottomNav` performs
  it is 1, and the pet's XP is non-zero, so the destination cannot read a
  pending zero.

---

## 4. Two expectations of mine were wrong, and the product was right

Worth recording, because both looked like failures:

- **`findMemories` returned 2, not 1.** 150 XP both makes this the first settled
  session *and* crosses level 1 → 2, and `CompanionMemory.earnedBy` earns a memory
  for each. Two is correct; my expectation was not.
- **A second `saveSession()` throws `No active session`.** Saving clears the
  in-memory session, so a repeat is a *guarded misuse* rather than a silent second
  write. That is stronger than idempotency, and it is why `AppBottomNav` gates on
  `isCompleted` before flushing — after a save that flag is false, so the double
  call the P14 fix could otherwise make is unreachable. The test now asserts the
  refusal.

---

## 5. Gates

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | **PASS** — 263 files, 0 changed |
| `flutter analyze --fatal-infos --no-pub` | **PASS** — 0 issues |
| `flutter test --no-pub` | **PASS** — **1148 / 1148** (was 1142; +6) |
| `git diff --check` | **PASS** |

---

## 6. Status

```
GOLDEN_FLOW:            PASS
INTEGRATION_TESTS:      6/6   (test/integration/golden_flow_test.dart)
UNIT_TESTS:             1148/1148
FORMAT:                 PASS
ANALYZE:                PASS
```

### What this does not cover

- **The craft job is started directly**, not earned through the collection UI.
  The flow proves settlement drives craft progress and that completion writes
  inventory; it does not walk the collection page's own affordances.
- **Room placement goes through the controller**, not the drag-and-drop surface.
  The placement *rules* are the DAO's and are exercised; the gesture is not.
- **P19 finding 1 is untouched.** The flow asserts that an anchor is bound and a
  furniture request is honoured — not *which sprite plays*. It is deliberately
  neutral on the two-decider question, so it does not depend on the owner's
  answer and will not need rewriting when that is settled.
