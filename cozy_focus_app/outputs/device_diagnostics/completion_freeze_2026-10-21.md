# The completion screen stops presenting frames for ~1s

## What was measured

`tools/qa/surface_timing.py` clears SurfaceFlinger's latency buffer, drives a
session to completion, and reads the buffer 0.8s after the confirmation tap.
The buffer holds 128 presented frames, so the read window contains the
transition.

| run | buffer window | longest gap | where |
|---|---|---|---|
| 1 | 10.9s, 128 frames | **1249.8 ms** | 9.63s into the buffer, the last event |
| 2 (same script, next completion) | ~10.6s | **998.6 ms** | 9.60s into the buffer, the last event |

Shorter gaps of 100-250ms sit earlier in the same window: those are the
confirmation dialog and the page animations.

## Why this matters

The celebrate recorder loses 1.0-1.5s at exactly the same point. Until now the
gate called that a capture stall. SurfaceFlinger is the compositor, not the
recorder: a 1.2s hole in the frames it *presented* means the app (or the
compositor) produced nothing for 1.2s. **The recording gap is a symptom, not
the cause.** The companion's celebration interior is missing from the clip
because the screen was not drawing, not because the encoder dropped frames.

## What is not proven

- **The cause.** Nothing here says whether the block is the completion write,
  the first build of the completion page, or a shader/raster cost. It has not
  been profiled.
- **Whether it recurs in one process.** Both runs show a ~1s gap, but the
  emulator may have restarted the app between them (`reach_running` handles a
  resume dialog, which implies it sometimes does). If each run is a cold
  process, a first-use cost is still possible.
- **The hardware number.** This emulator renders with SwiftShader on the host
  CPU. A 1.2s freeze here is not a 1.2s freeze on a phone. The defect is that
  the UI thread blocks at all, not the exact duration.

## Status

`COMPLETION_FRAME_STALL = REPORTED_NOT_FIXED`.

The celebrate gate stays `BLOCKED` (`burst_interior_resolved = false`). That is
the honest status: the clip cannot show the interior, and the reason is the app
not presenting frames.
