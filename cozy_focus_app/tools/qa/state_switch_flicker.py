"""Does the companion vanish for a frame when its state changes?

## What this adds

`test/presentation/route_transition_flicker_test.dart` measures route
transitions in a widget test and says what it cannot see: "a frame that draws the
right *amount* of content but the wrong content - a stale page, a doubled image,
a pose that snaps mid-transition". That is the companion's own state switch, and
on a device nothing had looked at it.

## How it decides

The self-calibrating measure is the companion's **ink**: pixels in its box
clearly darker than the pale backdrop it sits on. A frame in which the companion
is missing has almost none. So the question "did it disappear for a frame"
becomes "did the ink collapse", which needs no colour theory and no reference
image - the same trick the route test uses, applied to the pet instead of the
page.

A collapse is only a defect if it is a *dip*: one or two frames with almost no
ink between frames that have plenty. A companion that is legitimately absent (a
page without one) has no ink for the whole window, and that is reported as such
rather than as a flicker.

Usage:
    python tools/qa/state_switch_flicker.py            # tap the companion
    python tools/qa/state_switch_flicker.py --tab 记录  # switch pages instead
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import celebrate_capture as C  # noqa: E402
from device_launch import ensure as ensure_foreground, drawn, foreground, PKG  # noqa: E402

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(APP, "outputs", "final_visual_implementation", "flicker")
BUILD = os.path.join(APP, "build", "flicker")

FPS = 20
RECORD_SECONDS = 10

# Ink is the companion's own dark outline: a pixel darker than luma 64.
#
# This threshold used to be 205, calibrated against the *old* room - a pale cream
# the companion's white body sat above. The room was then retuned to the board's
# measured brown, and luma 128-160 now covers 46% of the pet's box, so that
# threshold started counting wall pixels as ink. The same run reported ink ~121000
# where pre-retune runs reported ~15000: an 8x jump with nothing to do with the
# companion, because the instrument had stopped measuring the pet and started
# measuring the wall. A PASS on those numbers would have been evidence of nothing.
#
# 64 is the separation the current room actually gives. The companion is drawn
# white with dark outlines, so its outline sits well below 64; the room's dominant
# band starts at 128. Measured on the device: the same box on a page with the
# companion counts 5417 outline pixels, and on the 记录 page - which has no
# companion at all - counts zero. That zero is what makes the number mean
# something, and it is the instrument's own control.
INK_LEVEL = 64

# A frame counts as a dip when it holds under this share of the window's median
# ink. The companion is either drawn or it is not; there is no middle.
DIP_SHARE = 0.25


def ink_count(path, box):
    with Image.open(path) as im:
        a = np.asarray(im.convert("L").crop(box), dtype=np.int16)
    return int((a < INK_LEVEL).sum())


def reach_home():
    """Back out to the home tab, guarded at every step.

    The nav is detected by its tab suffix: each tab's description is multi-line
    (`首页\\n第 1 个标签，共 3 个`), so an equality test against `首页` never
    matches and a loop that used one would walk the app back forever.
    """
    for _ in range(8):
        if not C.guard():
            continue
        labels = [l for _x, _y, l in C.nodes(C.dump())]
        if any("个标签，共" in l for l in labels):
            C.tap_label("首页", settle=5)
            return True
        C.tap_label("返回", settle=3)
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tab", default=None,
                    help="switch to this bottom-nav tab instead of tapping the "
                         "companion")
    ap.add_argument("--taps", type=int, default=1,
                    help="how many times to tap the companion. Two taps is the "
                         "discriminating experiment: the second switch reuses "
                         "frames that are already decoded, so a cold-cache "
                         "cause blanks only the first time and a structural "
                         "cause blanks both")
    ap.add_argument("--fps", type=int, default=20,
                    help="sampling rate for the extracted frames. A blank that "
                         "lasts one 60Hz vsync can fall between 20fps samples, "
                         "so 60 is the stricter run")
    a = ap.parse_args()
    global FPS
    FPS = a.fps
    C.FPS = a.fps

    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)

    if not C.guard(settle=45):
        print("REFUSING: CozyFocus is not foreground and painted",
              file=sys.stderr)
        return 2

    # A screen with the companion on it, and with the bottom nav so the tab
    # variant works.
    if not reach_home():
        print("REFUSING: could not reach a screen with the bottom nav",
              file=sys.stderr)
        return 2

    box = C.pet_box(C.dump())
    if not box:
        print("REFUSING: no companion on this screen", file=sys.stderr)
        return 2
    print(f"companion box {box}")

    # Room for every tap plus the settle between them.
    duration = RECORD_SECONDS + 4 * max(0, a.taps - 1)

    C.adb("shell", "rm", "-f", "/sdcard/_flick.mp4")
    subprocess.Popen(
        [C.ADB, "shell", "screenrecord", "--time-limit", str(duration),
         "--bit-rate", "6000000", "/sdcard/_flick.mp4"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2)

    if a.tab:
        if not C.tap_label(a.tab, settle=3):
            print(f"could not find the {a.tab} tab", file=sys.stderr)
            return 2
        label = f"tab_{a.tab}"
    else:
        cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
        for n in range(a.taps):
            C.tap(cx, cy, settle=1)
            if n < a.taps - 1:
                # Let the overlay finish and the pose settle before the next
                # tap, so the two switches are separate events rather than one
                # long overlay.
                time.sleep(3)
        label = "tap_companion" if a.taps == 1 else f"tap_companion_x{a.taps}"

    time.sleep(RECORD_SECONDS)

    local = os.path.join(BUILD, "flicker.mp4")
    subprocess.run([C.ADB, "pull", "/sdcard/_flick.mp4", local],
                   capture_output=True, text=True)
    if not os.path.exists(local):
        print("pull failed", file=sys.stderr)
        return 2

    frames = C.extract(local, os.path.join(BUILD, "frames"))
    # Drop the tail: a screenrecord stops mid-frame and the last sample is
    # partial. Same reason as the celebrate instrument.
    frames = frames[:len(frames) - max(1, int(0.25 * FPS))]
    print(f"{len(frames)} frames at {FPS}fps")

    inks = [ink_count(p, box) for p in frames]
    median = float(np.median(inks))
    print(f"ink: median {median:.0f}, min {min(inks)}, max {max(inks)}")

    if median <= 0:
        report = {
            "label": label,
            "frames": len(frames),
            "ink_median": median,
            "verdict": "NO_COMPANION",
            "note": "no ink anywhere in the window: the companion is not on "
                    "this screen, so there is nothing to flicker",
        }
        print(json.dumps(report, indent=2))
        with open(os.path.join(OUT, f"{label}_FLICKER_REPORT.json"), "w",
                  encoding="utf-8") as fh:
            json.dump(report, fh, indent=2)
        return 0

    # A dip is a frame holding under DIP_SHARE of the median, with real ink on
    # both sides. A run of low ink at the very start or end is the companion
    # legitimately absent (a page without one), not a flicker.
    dips = [i for i, v in enumerate(inks) if v < median * DIP_SHARE]
    interior = [i for i in dips if 0 < i < len(inks) - 1]

    # ...and interior is not enough on its own. Switching to a page that has no
    # companion drops the ink to nothing *and leaves it there*: 5867, 5867, ...
    # 0, 0, 0, 2801, 2801. That is the intended result of a tab change, and
    # calling the six frames where it settles a flicker means the `--tab` control
    # run reports FAIL for behaving correctly. So a low run is only a flicker when
    # ink **returns** to its previous level afterwards. The companion being gone
    # for the rest of the window is a page change, and is reported as such.
    def returns_after(i):
        tail = inks[i + 1:]
        before = inks[:i]
        if not tail or not before:
            return False
        return (max(tail) >= median * 0.6 and
                max(before) >= median * 0.6)

    flicker = sorted({i for i in interior if returns_after(i)})

    report = {
        "label": label,
        "frames": len(frames),
        "companion_box": list(box),
        "ink_median": median,
        "ink_min": min(inks),
        "ink_max": max(inks),
        "dip_frames": interior,
        "flicker_frames": flicker,
        "ink_series": inks,
        "thresholds": {"ink_level": INK_LEVEL, "dip_share": DIP_SHARE},
        "checks": {"no_flicker": len(flicker) == 0},
        "technical_visual_gate": "FAIL" if flicker else "PASS",
        "owner_visual_gate": "REQUIRED",
        "note": (
            "Answers 'did the companion vanish for a frame'. It cannot see a "
            "frame that draws the right amount of content but the wrong "
            "content, and it does not judge whether the transition reads well."
        ),
    }
    path = os.path.join(OUT, f"{label}_FLICKER_REPORT.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)

    # Keep the frames around any flicker, or the transition itself when clean.
    keep = flicker[:1] or interior[:1] or [len(frames) // 2]
    for n, i in enumerate(range(max(0, keep[0] - 3),
                                min(len(frames), keep[0] + 5))):
        shutil.copy(frames[i], os.path.join(OUT, f"{label}_f{n:02d}.png"))

    print(json.dumps({k: report[k] for k in
                      ("ink_median", "dip_frames", "flicker_frames",
                       "checks", "technical_visual_gate")}, indent=2))
    print(f"\nreport: {path}")
    return 0 if report["technical_visual_gate"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
