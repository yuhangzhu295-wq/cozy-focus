# CHECKPOINT — where to resume

**Read this first.** It is the resume point, and it is only true as of the timestamp
below; re-verify the git state before acting on it.

```
at           2026-10-09T01:10:00+08:00
branch       recovery/v4.2.1-rebuild
HEAD         (advanced by this window — run `git log --oneline -6` and read it)
remote HEAD  origin/recovery/v4.2.1-rebuild
```

The previous checkpoint recorded `e8647f33a58cf4206499157cfd44298f7fadce0b`. This
window added commits on top of it. **Do not reset to any recorded SHA** — read the
log and continue from wherever HEAD actually is.

## What this window did

1. Finished `outputs/autonomous_execution/` (all seven files) and registered a
   recurring continuation schedule. `MASTER_STATE.json` → `continuation` states
   plainly what this environment can and cannot do about continuing.
2. Audited **design 05** (分心收集箱) against the running app on the emulator, wrote
   the row into `01_VISUAL_MATRIX.md`, and registered five differences.
3. Found and fixed a **global palette defect**: the primary green was `#5E8D6D`, a
   colour the designs essentially do not contain — 1,468 px of anti-aliasing
   across all sixteen boards — where the design's primary `#44714B` covers
   125,256 px. One token changed; white-on-green contrast went 3.81 → 5.66, so the
   old value was also failing WCAG AA on every filled button.
4. Found and fixed a **split clock**: `RecordsController`, `ReportsController` and
   the records page read `DateTime.now()` while the rest of the app reads
   `FocusClock`. This is why six tests were already red at HEAD, and why one more
   was passing vacuously. Three guard tests use an ancient date so the calendar
   rolling over cannot defeat them.
5. De-flaked the one intermittently red test (`room_placement_toolbar` P7).

## The one thing to do next

**Stage 3, the capture sheet's five registered differences** (`TASK_QUEUE.json`
S3.05a–S3.05e), because design 05's audit is fresh and its evidence is in hand:

- the four category chips all draw the same tag icon, while `TaskCategory.iconName`
  (home/book/briefcase/more) is declared and rendered nowhere;
- the selected chip uses the category colour where the design draws brand green;
- the `n/100` counter sits below the input box, the design puts it inside;
- the input is about two lines tall, the design draws about four;
- the chip's accessible name says `标签 生活` and then `生活` again.

Then design 06, then 07 through 16.

## What is already done and must not be redone

- The dev pack is extracted **outside the repo** at `_devpack_v2/`, with 16 boards,
  16 auto-crops (`screens/`) and 16 downscaled boards (`small/`). The **boards** are
  the reference of record; the auto-crop is unreliable on about half of them
  (`DECISION_LOG.md`, D1).
- Designs 01–06 are audited and their rows are in the matrix.
- The running screen's ring (`05c0c4c`) and its responsive sizing (`bec8026`) —
  built, reverse-proved, device-verified.
- The palette question is answered in one command:
  `python tools/qa/palette_report.py`.
- The clock unification is guarded by
  `test/presentation/records_screen_uses_the_app_clock_test.dart`.
- Do not reintroduce a mock catalog on the dress page, and do not add a 白噪音
  control: both are contract violations (`DECISION_LOG.md`, D6).
- Five QA deliverables exist with real content (01, 04, 07, 08, 09).

## Device state to re-check before any visual work

The emulator (`emulator-5554`, AVD `GoodnightPixel7Api34`) is running at
**1080×2400 @ 420dpi = 411×914 dp**, the size the designs target. Confirm with
`wm size` and `wm density` first — a leftover override silently changes every
screenshot's scale.

It was restarted with `-gpu swiftshader_indirect` because the AVD has
`hw.gpu.enabled=no`, and software rendering was starving SystemUI into repeated
`Process system isn't responding` ANRs. That fixed it. If ANRs return, check the
GPU flag before blaming the app.

- Capture helper: `python tools/qa/device_shot.py <name> --dir <dir>`.
  Do **not** use `adb exec-out screencap -p > file` — CRLF corrupts the PNG.
- `adb input text` cannot send Chinese; device data uses ASCII titles.
- The app is installed, with real task and focus-session history on it.

## Two traps this window hit, so the next one does not

- Writing files with bash heredocs silently truncated one of four files, and the
  three that succeeded made it look fine. Use the Write tool.
- `flutter test > f 2>&1` is the correct order. `2>&1 > f` sends stderr to the
  terminal and hides the exception, which cost time chasing the flaky test.
