# TEST_EVIDENCE

Raw command results, newest first. Every visual fix records its own test file and
its reverse proof; every reverse proof records what failed and how.

## 2026-10-08T23:20 — after bec8026 (the responsive ring)

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

## New guards added by this program

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
