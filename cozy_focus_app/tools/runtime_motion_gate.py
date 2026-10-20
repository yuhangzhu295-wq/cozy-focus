"""Runtime motion gate: does the rendered companion actually animate?

## Why this exists

P16 proved the companion animates by hand: twelve screenshots, two regions, and a
measurement showing the subject changes while a static region does not. That
worked, but it was a one-off — nothing re-ran it, and nothing would have noticed
if the animation stopped.

This is the same measurement as a command.

## Why one screenshot cannot do this

A still cannot distinguish "the companion is animating" from "the companion is
frozen", because both look like a companion. Motion needs **time-separated
frames**, and it needs a **control**: a region that must not change. Without the
control, a difference between two frames proves only that two screenshots differ.

The control is what makes the number mean something. On this app it measures
exactly zero — the capture path has no noise floor — so any difference in the
subject region is the app rendering different content.

## What it does not decide

It does not judge whether the animation is *good*. Frame changes, non-duplicate
frames, anchor stability and loop seams are technical facts. Whether the art
reads well is `OWNER_VISUAL_GATE`, and this tool never returns a verdict on it.

Usage:
    python tools/runtime_motion_gate.py --label idle \\
        --subject 280,480,800,800 --control 100,850,980,1150
"""
import argparse
import json
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image

APP = r"C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app"
OUT = os.path.join(APP, "outputs", "ai_handoff", "android_v1_runtime")
ADB = os.path.join(
    os.environ.get("LOCALAPPDATA", ""),
    "Android", "Sdk", "platform-tools", "adb.exe")

# A frozen still gives 0. Anything above this is the app drawing something else.
MIN_SUBJECT_MOTION = 1.0

# The control must be still. A control that moves means the wrong region was
# chosen, or the screen is scrolling -- either way the measurement is void.
MAX_CONTROL_MOTION = 0.5

# A cycle returns to a pose it has already been in; a one-way drift does not.
# The test is a *repeat*: two frames at least MIN_CYCLE_LAG apart whose distance
# is under half one typical frame step. Comparing against a typical step rather
# than against the peak matters - a linear drift's distance grows with lag, so
# its lag-3 distance is already a third of its peak and a peak-relative test
# passes it.
#
# The previous test anchored on frame 0 and asked whether any later frame came
# back within half the peak distance. That failed the focus screen on 2026-10-21
# on an animation that repeats *exactly* at frames 1/4 and 1/9: the first
# screenshot caught a different pose, so every later frame sat ~16 away from it
# while the loop itself moved by ~7. The anchor was the outlier, not the
# animation.
CYCLE_RETURN_FRACTION = 0.5
MIN_CYCLE_LAG = 3

# Modes. An ambient action cycles in place; a travel moves one way. Asserting the
# wrong one is worse than asserting nothing, so they are separate modes rather
# than one loose check.
MODE_IDLE = "idle"
MODE_TRAVEL = "travel"

# How far the subject must move across the capture for a travel to count as world
# movement. A gait that stayed put would not reach this.
MIN_TRAVEL_DISPLACEMENT = 8.0


def _adb(serial, *args):
    cmd = [ADB, "-s", serial, *args]
    p = subprocess.run(cmd, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed: {p.stderr.decode()[:400]}")
    return p.stdout


def capture(serial, dest):
    raw = _adb(serial, "exec-out", "screencap", "-p")
    with open(dest, "wb") as fh:
        fh.write(raw)
    return dest


def region(path, box):
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB").crop(box), dtype=np.int16)


def steps(frames):
    return [float(np.abs(frames[i] - frames[i + 1]).mean())
            for i in range(len(frames) - 1)]


def cycle_evidence(frames, min_lag=MIN_CYCLE_LAG):
    """(returned, repeat_distance, repeat_pair, typical_step).

    A repeat is the closest pair of frames at least `min_lag` apart. Comparing
    it with the median adjacent step is what separates a loop (which revisits a
    pose exactly) from a drift (whose frames only get further apart).
    """
    n = len(frames)
    best = None
    for i in range(n):
        for j in range(i + 1, n):
            if j - i < min_lag:
                continue
            d = float(np.abs(frames[i] - frames[j]).mean())
            if best is None or d < best[0]:
                best = (d, i, j)
    adjacent = steps(frames)
    typical = float(np.median(adjacent)) if adjacent else 0.0
    returned = (best is not None and typical > 0 and
                best[0] < CYCLE_RETURN_FRACTION * typical)
    return returned, best, typical


def selftest():
    """Synthetic sequences: a loop must pass and a drift, a freeze and a
    one-shot-then-hold must fail."""
    def frames_from(values):
        out = []
        for v in values:
            f = np.zeros((8, 8, 3), dtype=np.int16)
            f[:, :, 0] = v
            out.append(f)
        return out

    cases = [
        ("loop", [10, 20, 30, 10, 20, 30], True),
        ("drift", [0, 10, 20, 30, 40, 50], False),
        ("freeze", [5, 5, 5, 5, 5, 5], False),
        ("one shot then hold", [0, 20, 40, 40, 40, 40], False),
    ]
    failed = 0
    for name, values, want in cases:
        got, best, typical = cycle_evidence(frames_from(values))
        ok = got == want
        print(f"{'PASS' if ok else 'FAIL'} {name}: got {got}, want {want} "
              f"(repeat {best[0]:.1f} at {best[1]}/{best[2]}, step {typical:.1f})")
        if not ok:
            failed += 1
    return 1 if failed else 0


def run(serial, label, subject, control, count, interval, out_dir,
        mode=MODE_IDLE):
    os.makedirs(out_dir, exist_ok=True)
    shots = []
    for i in range(count):
        shots.append(capture(serial, os.path.join(out_dir, f"{label}_{i:02d}.png")))
        if i < count - 1:
            time.sleep(interval)

    subj = [region(p, subject) for p in shots]
    ctrl = [region(p, control) for p in shots]

    subj_steps = steps(subj)
    ctrl_steps = steps(ctrl)

    # Distance of every frame from the first, kept for the travel check and for
    # the report. It is not the cycle test: frame 0 is an arbitrary anchor and
    # can be the outlier.
    first = subj[0]
    from_first = [float(np.abs(f - first).mean()) for f in subj]
    returned, repeat, typical_step = cycle_evidence(subj)

    checks = {
        "subject_animates": max(subj_steps) > MIN_SUBJECT_MOTION,
        "control_is_static": max(ctrl_steps) <= MAX_CONTROL_MOTION,
    }
    if mode == MODE_IDLE:
        # An ambient action stays where it is and breathes.
        checks["cycles_rather_than_drifts"] = returned
    else:
        # A travel must actually go somewhere. A sprite that animated its legs
        # but never left would pass the motion check and still be wrong, so this
        # is the assertion that makes the walk gate mean "world movement".
        checks["moves_in_world"] = from_first[-1] >= MIN_TRAVEL_DISPLACEMENT
    blocking = [k for k, v in checks.items() if not v]

    report = {
        "label": label,
        "mode": mode,
        "frames": count,
        "interval_s": interval,
        "subject_box": list(subject),
        "control_box": list(control),
        "subject_steps": [round(s, 3) for s in subj_steps],
        "control_steps": [round(s, 3) for s in ctrl_steps],
        "distance_from_first": [round(d, 3) for d in from_first],
        "repeat_distance": round(repeat[0], 3) if repeat else None,
        "repeat_pair": [repeat[1], repeat[2]] if repeat else None,
        "typical_step": round(typical_step, 3),
        "thresholds": {
            "min_subject_motion": MIN_SUBJECT_MOTION,
            "max_control_motion": MAX_CONTROL_MOTION,
            "cycle_return_fraction": CYCLE_RETURN_FRACTION,
            "min_cycle_lag": MIN_CYCLE_LAG,
        },
        "checks": checks,
        "technical_visual_gate": "FAIL" if blocking else "PASS",
        "blocking": blocking,
        "owner_visual_gate": "REQUIRED",
        "note": (
            "owner_visual_gate is REQUIRED and is never decided here: whether "
            "the art reads well is not a measurement."
        ),
    }
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--serial", default="emulator-5554")
    ap.add_argument("--label", required=True)
    ap.add_argument("--subject", required=True,
                    help="x0,y0,x1,y1 of the companion region")
    ap.add_argument("--control", required=True,
                    help="x0,y0,x1,y1 of a region that must not change")
    ap.add_argument("--mode", default=MODE_IDLE, choices=[MODE_IDLE, MODE_TRAVEL],
                    help="idle requires a cycle; travel requires one-way world "
                         "movement")
    ap.add_argument("--frames", type=int, default=12)
    ap.add_argument("--interval", type=float, default=0.6)
    ap.add_argument("--out-dir", default=None)
    a = ap.parse_args()

    box = lambda s: tuple(int(v) for v in s.split(","))  # noqa: E731
    out_dir = a.out_dir or os.path.join(OUT, "motion", a.label)

    rep = run(a.serial, a.label, box(a.subject), box(a.control),
              a.frames, a.interval, out_dir, a.mode)

    report_path = os.path.join(out_dir, f"{a.label}_MOTION_REPORT.json")
    with open(report_path, "w", encoding="utf-8") as fh:
        json.dump(rep, fh, indent=2)

    print(json.dumps(rep, indent=2))
    print(f"\nreport: {report_path}")
    return 0 if rep["technical_visual_gate"] == "PASS" else 1


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    sys.exit(main())
