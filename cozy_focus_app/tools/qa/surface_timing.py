"""Did the display receive frames during the completion transition?

## Why

The celebrate recording loses about 1.0s exactly as the completion screen
appears, and the gate cannot tell whether the app stopped drawing or the
recorder dropped frames. `dumpsys gfxinfo` is not usable here: on this emulator
it reported four frames in eight seconds for a screen that is plainly
animating, so it does not see Flutter's SurfaceView.

SurfaceFlinger does. `--latency` reports the presentation timestamp of every
buffer the display actually showed. A hole of ~1s in the window that contains
the transition means the app (or the compositor) produced nothing; a continuous
timeline means the buffers existed and only `screenrecord` missed them.

The buffer holds 128 frames, so the read has to happen within about two seconds
of the transition. Reading four seconds later measures the settle and says
nothing about the window the recorder loses.

Usage:
    python tools/qa/surface_timing.py
"""
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import celebrate_capture as C  # noqa: E402

APP = C.APP
OUT = os.path.join(APP, "outputs", "device_diagnostics")

JANK_GAP_MS = 500.0


def layer_name():
    """The app's SurfaceView layer, with its current id.

    The id changes when the activity is recreated, so it is read fresh rather
    than hard-coded.
    """
    out = C.adb("shell", "dumpsys", "SurfaceFlinger", "--list")
    for line in out.splitlines():
        line = line.strip()
        if "SurfaceView[" in line and "cozyfocus" in line and "(BLAST)" in line:
            return line
    return None


def sf(*args):
    """One shell string, with the layer quoted.

    `adb shell` re-parses its arguments on the device, so passing the layer
    name as a separate argv element splits it at the space and the shell trips
    on the parentheses. The whole command has to arrive as one string.
    """
    quoted = " ".join(f"'{a}'" if " " in a or "(" in a else a for a in args)
    return C.adb("shell", f"dumpsys SurfaceFlinger {quoted}")


def clear_latency(layer):
    sf("--latency-clear", layer)


def latency(layer):
    """Presentation timestamps in seconds, ascending, zeros dropped."""
    out = sf("--latency", layer)
    stamps = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) != 3:
            continue
        try:
            actual = int(parts[1])
        except ValueError:
            continue
        # 0 means an unused slot; 9223372036854775807 is the "pending" sentinel.
        if actual <= 0 or actual >= 2 ** 62:
            continue
        stamps.append(actual / 1e9)
    stamps.sort()
    return stamps


def analyse(stamps):
    if len(stamps) < 2:
        return {"frames": len(stamps), "verdict": "NO_FRAMES"}
    gaps = [(b - a) * 1000 for a, b in zip(stamps, stamps[1:])]
    max_gap = max(gaps)
    return {
        "frames": len(stamps),
        "window_s": round(stamps[-1] - stamps[0], 3),
        "max_gap_ms": round(max_gap, 1),
        "gaps_over_100ms": [round(g, 1) for g in gaps if g > 100],
        # Where each long gap sits in the buffer, so the completion transition
        # can be told apart from the dialog before it.
        "long_gaps": [
            {"at_ms": round((stamps[i] - stamps[0]) * 1000, 1),
             "ms": round(g, 1)}
            for i, g in enumerate(gaps) if g > 100
        ],
        "jank": max_gap > JANK_GAP_MS,
        "verdict": "APP_STALLED" if max_gap > JANK_GAP_MS else "APP_KEPT_DRAWING",
    }


def main():
    os.makedirs(OUT, exist_ok=True)
    if not C.guard(settle=45):
        print("REFUSING: CozyFocus is not foreground and painted",
              file=sys.stderr)
        return 2
    layer = layer_name()
    if not layer:
        print("REFUSING: no SurfaceView layer for the app", file=sys.stderr)
        return 2
    print(f"layer {layer}")

    if not C.reach_running():
        print("REFUSING: no running session could be reached", file=sys.stderr)
        return 2

    clear_latency(layer)
    if not C.tap_label("提前结束", settle=3):
        print("could not find 提前结束", file=sys.stderr)
        return 2
    if not C.tap_label("仍然结束", settle=1):
        print("could not find 仍然结束", file=sys.stderr)
        return 2
    # The latency buffer holds 128 frames - about 2.1s at 60fps. Reading later
    # than that measures the settle, not the transition, which is the window the
    # recorder loses. 0.8s after the tap keeps the transition inside the buffer.
    time.sleep(0.8)

    rep = analyse(latency(layer))
    path = os.path.join(OUT, "completion_surface_timing.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(rep, fh, indent=2)
    print(json.dumps(rep, indent=2))
    print(f"\nreport: {path}")
    return 0 if rep["verdict"] == "APP_KEPT_DRAWING" else 1


if __name__ == "__main__":
    sys.exit(main())
