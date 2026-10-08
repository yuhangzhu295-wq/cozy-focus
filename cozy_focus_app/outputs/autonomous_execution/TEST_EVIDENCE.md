# TEST_EVIDENCE

Raw command results, newest first. Every fix records its own test file and its
reverse proof; every reverse proof records what failed and how.

### Stage 2: the timing claims were re-proved, not inherited

The brief asks that earlier PASS conclusions not be carried forward. Three of them
were re-checked by **removing the guard and confirming the tests go red**, which is
the only version of "verified" that means anything:

| claim | mutation | what happened |
|---|---|---|
| an overrun countdown records its target, not the clock gap | `_endAtForCountdown(...)` → `now` | recorded **1500 → 5640 s**, reward **50 → 960 coins**; 2 red |
| one session settles once | `changes() == 1` → always true | second `settle` returned `true`; coins **150 → 300**, XP **600 → 1200**; 3 red |
| one session writes one memory | (the same mutation) | `companion_memory_test` went red with it |

Idempotence rests on the `reward_ledger` primary key `{sessionId}` plus
`INSERT OR IGNORE` and `SELECT changes()`, not on a comment.

**And one real defect came out of it**: the same duration had three answers
across the report screens. See ledger entry 13.

## 2026-10-09 — after the palette and clock work (HEAD 8ec787c)

```
$ dart format --set-exit-if-changed .
Formatted 441 files (0 changed) in 3.33 seconds.

$ flutter analyze --fatal-infos
Analyzing cozy_focus_app...
No issues found! (ran in 9.8s)

$ flutter test
+1940: All tests passed!        (clean on 4 consecutive full runs)

$ flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk

$ git diff --check
(no whitespace errors)
```

### The suite was NOT green at HEAD before this work

This matters more than the number. At `e8647f33`, before any change in this
window, `flutter test` reported **6 failures**:

- `record_duration_label_test.dart` (3)
- `record_row_mood_test.dart` (3)

They had been red since the calendar day rolled over, because the records screen
drew its "today" from the wall clock while the tests seeded against an injected
one. The `1931/1931` recorded in the previous state file was stale — it was
captured on the day the two clocks happened to agree. Fixed by `96646a2`.

A seventh test in the same file was green throughout for the wrong reason: it
asserts `findsNothing`, which an empty screen satisfies.

### New guards added by this window

| test file | covers | reverse proof |
|---|---|---|
| `test/theme/primary_green_matches_design_test.dart` (6) | the primary green is the design's measured `#44714B`; it is darker than the tint and lighter than the page; white on it clears WCAG AA; the colour scheme, the elevated-button theme and a real `FilledButton` all use it | reverting the token to `#5E8D6D` fails 2, the contrast one reporting `Actual: <3.813527499569987>` against a 4.5 floor |
| `test/presentation/records_screen_uses_the_app_clock_test.dart` (3) | a record on the injected clock's day is shown whatever today really is; the streak counts the injected day; the reports open on the injected week, month and year | reverting the three `DateTime.now()` reads to the wall clock fails 5 assertions |
| `test/presentation/semantics_label_not_doubled_test.dart` (2) | one test re-scans all of `lib/` for a `Semantics` wrapper repeating the text it wraps; the other pumps the capture sheet and reads the chip's semantics node | removing the chip's `excludeSemantics` fails both: the widget test with `Expected: '标签 生活' / Actual: '标签 生活\n'`, the scan naming both files with line numbers |

### The accessibility work needed the device, not the scan

`tools/find_doubled_semantics_labels.py` found 16 wrappers repeating their child's
text. Reading the tree the platform actually receives
(`tools/qa/a11y_dump.py`) then found two more classes the scan is structurally
blind to:

- `BottomNavigationBarItem(icon: Icon(..., semanticLabel: '首页'), label: '首页')`
  — not a `Semantics` wrapper at all, so the scan never looked; the device read
  `首页\n首页\nTab 1 of 3`.
- `label: '专注计时 $displayTime，当前专注中'` over `Text(displayTime)` — the scan
  only recognised `${...}` and not `$identifier`; the device read the figure three
  times.

Device re-verification after the fix: home 34 named nodes with no repeat, growth
27, room 22, focus page 12; the bottom nav reads `成长\nTab 3 of 3`; the room
sub-nav reads `房间` where it read `房间\n房间`.

The clock guard seeds **2001-03-05** deliberately. A guard pinned to a date near
the present would pass or fail depending on when it runs, which is exactly how the
six failures above hid for a day.

### Flake status — resolved, and it was a product defect

`room_placement_toolbar_test.dart` "P7 — a failed placement is surfaced" failed
twice in ten full runs and never in ten runs of its file alone; a fixed 400ms wait
for a `ref.listen` callback was replaced with bounded polling (`b7f011d`). That
was real but it was **not the whole story**: single failures kept appearing, about
three or four in fifteen runs, with **no exception text at all** — just `+2 -1`.

That absence was the clue. Running the suspect file alone reproduced it twice in
ten, and the failure was in `records_screen_uses_the_app_clock_test.dart` reading
`reportsControllerProvider`. The cause was in `ReportsController`: **its
constructor called `loadAllReports()` without awaiting it**, so the query could
land after `tearDown` had closed the in-memory database.

It was also a real redundancy. All three report pages already call
`loadAllReports()` from `initState`, so the constructor's copy meant every visit
ran the whole set of queries twice, the second round belonging to nobody —
nothing awaited it and nothing observed its failure.

Removing the constructor's call took the file from 8/10 clean to **12/12**, and
four consecutive full-suite runs since are clean at 1957.

The lesson is worth keeping: when one symptom has two causes, fixing the first
does not make the symptom go away, and the right response is to change the
hypothesis rather than to lengthen a timeout.

## 2026-10-08 — after bec8026 (the responsive ring)

```
$ dart format --set-exit-if-changed .
Formatted 439 files (0 changed) in 5.24 seconds.

$ flutter analyze --fatal-infos
Analyzing cozy_focus_app...
No issues found! (ran in 13.2s)

$ flutter test
03:35 +1931: All tests passed!

$ flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk     143035781 bytes

$ git diff --check
(no whitespace errors)
```

## Guards added by earlier rounds of this program

| test file | covers | reverse proof |
|---|---|---|
| `test/presentation/focus_ring_test.dart` (4) | the ring exists; a countdown starts full and drains; an open-ended mode draws no fraction; a paused session says so | forcing `remaining: null` fails the first two with `Expected <1.0> / Actual <null>` |
| `test/presentation/focus_active_layout_test.dart` (4) | the controls clear the bottom edge at 360×800, 393×852, 412×915; the ring keeps the design's proportion | reverting `diameterFor` to a fixed 224 fails 360×800 (暂停 at y 805 in an 800pt viewport) and 393×852 (提前结束 at 833 in 852) |

## A process failure worth keeping

`05c0c4c` was committed while the suite was **red** (1926 passed / 1 failed) —
I committed without reading the result. `bec8026` fixed that failure (a test
tapping a control that the taller page had pushed below its 800×600 surface; the
harness now scrolls to it, assertions unchanged) and the suite returned to green.
Recorded because it is exactly the pattern the brief forbids.
