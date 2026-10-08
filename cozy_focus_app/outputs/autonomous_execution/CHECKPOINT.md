# CHECKPOINT — where to resume

**Read this first.** It is the resume point, and it is only true as of the timestamp
below; re-verify the git state before acting on it.

```
at           2026-10-09T04:15:00+08:00
branch       recovery/v4.2.1-rebuild
HEAD         (advanced by this window — run `git log --oneline -12` and read it)
remote HEAD  origin/recovery/v4.2.1-rebuild
tests        1957/1957 green, analyze clean, format clean, APK builds
```

The previous checkpoint recorded `e8647f33a58cf4206499157cfd44298f7fadce0b`. This
window added commits on top of it. **Do not reset to any recorded SHA** — read the
log and continue from wherever HEAD actually is.

## What this window did (ten commits)

1. Finished `outputs/autonomous_execution/` (all seven files) and registered a
   recurring continuation schedule. `MASTER_STATE.json` → `continuation` states
   plainly what this environment can and cannot do about continuing.
2. **Global palette defect.** The primary green was `#5E8D6D`, a colour the designs
   essentially do not contain — 1,468 px of anti-aliasing across all sixteen boards
   — where the design's primary `#44714B` covers 125,256 px. One token changed; it
   also fixed white-on-green contrast (3.81 → 5.66, so the old value was below
   WCAG AA on every filled button). Device-verified at pixel level.
3. **Split clock.** `RecordsController`, `ReportsController` and the records page
   read `DateTime.now()` while the rest of the app reads `FocusClock`. This is why
   **six tests were already red at HEAD**, and why a seventh was passing vacuously.
   Three guard tests seed an ancient date so the calendar cannot defeat them.
4. **21 doubled announcements.** Screen readers said the same words twice. One was
   found on the device; a scan found sixteen more; reading the platform's own tree
   found two further classes the scan is blind to (the bottom nav and the timer).
5. **Design 05 closed** — four differences fixed and device-verified.
6. **Design 01's current-task card** built and device-verified.
7. Designs 07 and 09 audited (structural).
8. One flaky test de-flaked.

## The one thing to do next

**Design 01's hourly focus chart** (`TASK_QUEUE.json` S3.04). The data is already
on hand: `DayProgressSummary` carries the day's records, so this is a chart widget
and a bucketing rule rather than a new query. The board's axis is labelled
6/9/12/15/18/21.

Then S3.03a, the duration selector: the board draws the selected duration as a
solid dark-green card with a leaf above the number, where the app draws a light
outlined pill.

## Two open items that must not be quietly closed

- **The flake.** Three single full-suite failures across roughly fifteen runs, and
  the test is still unidentified — the hunt was stopped to spend the time on fixes.
  Hunt it on a frozen tree. Until then the suite is **not** recorded as
  deterministically green, and both `TEST_EVIDENCE.md` and `MASTER_STATE.json` say so.
- **S1.09a.** Design 09's timeline shows 08:00 起床 / 12:00 午休 / 18:00 自由时间 and
  names five kinds where `TimelineKind` models four. Nothing in the repo represents
  a meal or a life event. Two readings, both needing a product decision; marked
  `NOT_VERIFIED` rather than guessed at.

## What is already done and must not be redone

- The dev pack is extracted **outside the repo** at `_devpack_v2/`. The **boards**
  are the reference of record; the auto-crop is unreliable on about half of them.
- Designs 01–07 and 09 are audited; 01, 05 and 06 are built or closed.
- The palette, clock and accessibility questions are all answered by tools:
  `tools/qa/palette_report.py`, `tools/qa/a11y_dump.py`, and
  `tools/find_doubled_semantics_labels.py`. Run them before re-deriving anything.
- Do not reintroduce a mock catalog on the dress page, and do not add a 白噪音
  control: both are contract violations (`DECISION_LOG.md`, D6).

## Device state

Emulator `emulator-5554` (AVD `GoodnightPixel7Api34`) is running at **1080×2400 @
420dpi = 411×914 dp**, the size the designs target. It was started with
`-gpu swiftshader_indirect` because the AVD has `hw.gpu.enabled=no` and software
rendering was starving SystemUI into repeated ANRs; that fixed it.

- Capture: `python tools/qa/device_shot.py <name> --dir <dir>`. Do **not** use
  `adb exec-out screencap -p > file` — CRLF corrupts the PNG.
- Accessibility tree: `python tools/qa/a11y_dump.py` (add `--all` to list names).
- `adb input text` cannot send Chinese; device data uses ASCII titles.
- The app has real data: one task (`Write the product spec` / 工作 / 25 分钟, planned
  for today) and a day of focus records.

## Traps this window hit, so the next one does not

- **Bash heredocs silently truncate.** Four files written that way: three landed,
  the fourth stopped mid-sentence. Use the Write tool.
- **`flutter test > f 2>&1` is the correct order.** `2>&1 > f` sends stderr to the
  terminal and hides the exception, which cost real time chasing the flake.
- **A script that prints success may have done nothing.** One import-fixing script
  reported "import added" while its anchor string never matched. Check the result,
  not the log line.
- **A test viewport is not a phone.** `physicalSize 1080×2400` at
  `devicePixelRatio 1.0` is a 1080pt-wide viewport, not the design's 411dp; a
  proportion measured that way was a third of what it should be.
