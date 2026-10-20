# The completion screen presents no new frames for ~1s — what that does and does not mean

## Retraction first

An earlier version of this file called this `COMPLETION_FRAME_STALL` and
reported a ~1s app freeze. **That interpretation is withdrawn.** A gap between
presented frames does not distinguish a blocked thread from a static screen:
Flutter submits nothing when nothing changes, so a design that holds a pose for
a second looks exactly like a freeze in this timeline. There is no independent
evidence of a blocked UI thread, and the product defect was never demonstrated.

## What is measured

`tools/qa/surface_timing.py` clears SurfaceFlinger's latency buffer, drives a
session to completion, and reads the buffer 0.8s after the confirmation tap.
The buffer holds 128 presented frames, so the read window contains the
transition.

| run | buffer window | longest inter-frame gap | where |
|---|---|---|---|
| 1 | 10.9s, 128 frames | **1249.8 ms** | 9.63s into the buffer |
| 2 (next completion) | ~10.6s | **998.6 ms** | 9.60s into the buffer |

Shorter gaps of 100-250ms sit earlier: those are the confirmation dialog and
the page animations.

## Why it is not a freeze

The celebrate sequence is **5 frames at 8fps (625ms), one-shot**
(`assets/companions/*/animation_manifest.json`). After the fifth frame the
player holds the last pose until the 1.2s completion cycle hands back to idle.
The screencap series taken during the same window
(`build/celebrate/caps/`) shows the whole screen pixel-identical for ~1.2s and
then one change — the hand-over. That is the held pose, not a stuck thread.

The 1.0-1.5s hole in the `screenrecord` clip sits in the same window, for the
same reason: no new content, no new frames to encode. **The recorder is not
losing frames the app drew.**

## What this means for the celebrate gate

`burst_interior_resolved` stays `false` and the gate stays `BLOCKED`, but for a
different reason than "the capture failed": the burst's interior is a **hold**,
and a hold has no interior to capture. The five-frame sequence is covered by
`test/presentation/companion/animation/sprite_motion_gate_test.dart` at the
asset level and by the three swaps visible at the start of the clip; what the
clip cannot show is the last two swaps, because the screen stopped changing.

## What would settle the freeze question

A content capture faster than the hold, or a Dart timeline (`flutter run
--profile` + `dart:developer` Timeline). Neither was run. Nothing here should be
read as "the completion screen is smooth" either: the 100-250ms gaps around the
dialog are slow, and the emulator renders with SwiftShader, so the absolute
numbers are not hardware numbers.
