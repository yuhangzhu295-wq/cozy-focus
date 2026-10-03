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

# A cycle returns toward its starting frame; a one-way drift does not. Requiring
# at least one frame to come back inside half the peak distance is what separates
# "animating" from "sliding".
CYCLE_RETURN_FRACTION = 0.5

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

    # Distance of every frame from the first, for the cycle test.
    first = subj[0]
    from_first = [float(np.abs(f - first).mean()) for f in subj]
    peak = max(from_first)
    returned = any(d < peak * CYCLE_RETURN_FRACTION for d in from_first[1:])

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
        "thresholds": {
            "min_subject_motion": MIN_SUBJECT_MOTION,
            "max_control_motion": MAX_CONTROL_MOTION,
            "cycle_return_fraction": CYCLE_RETURN_FRACTION,
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
    sys.exit(main())
