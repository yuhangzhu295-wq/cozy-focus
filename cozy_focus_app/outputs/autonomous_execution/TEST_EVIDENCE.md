# TEST_EVIDENCE

Raw command results, newest first. Every fix records its own test file and its
reverse proof; every reverse proof records what failed and how.

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

### Flake status

`room_placement_toolbar_test.dart` "P7 — a failed placement is surfaced" failed
twice in ten full runs and never in ten runs of its file alone; the cause was a
fixed 400ms wait for a `ref.listen` callback that can arrive a frame later under
CPU contention. The wait is now bounded polling and the assertion is unchanged
(`b7f011d`).

One further single failure was observed in a gate run immediately after four
consecutive clean runs. Its identity was not captured, because that run's output
was redirected in the wrong order (`2>&1 > file` sends stderr to the terminal and
hides the exception). A hunt is running to identify it; **the suite is not
recorded as deterministically green until that is resolved.**

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
