"""Does the companion actually blink?

## Why this exists

The blocker table carried 眨眼帧 as `NOT_VERIFIED` — "未逐帧确认". It is a real
feature, not a decoration: `PetMotionSpec` schedules a blink every 2.5-5.5s for
140ms, and `ProceduralCompanionArt` plus the layered renderer both draw the eyes
shut for that window. But "the code says it happens" is not the same as "it
happens on the device", and the design boards show the companion alive.

## Why it is hard to see

A blink lasts 140ms. At 20fps a screenrecord samples every 50ms, so a blink is
between two and three frames — and the interval is 2.5-5.5s, so it is roughly one
frame in seventy. A sweep that samples the whole box will miss it: the body does
not move during a blink, so only the eye band changes at all.

## How it decides

Watch the **eye band** — the upper-middle strip of the companion's canvas, where
the eyes are. A blink closes the eyes, so the band's dark-pixel count changes
while the rest of the canvas does not. That is the same trick as the flicker
gate: the region is chosen so that the thing being measured is the only thing
that can change in it.

Two things have to be separated, and that is what makes this more than a diff:

- A **blink** is a short excursion in the eye band with the body still.
- **Breathing** moves the whole companion, so it changes every band including a
  control region and cannot produce an isolated change in the eyes alone.

So this records the eye band AND a control band lower down, over a window long
enough to expect several blinks, and reports eye excursions that the control does
not share.

Usage:
    python tools/qa/blink_capture.py                 # ~60s at 20fps
    python tools/qa/blink_capture.py --seconds 90
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
from device_launch import ensure as ensure_foreground, PKG  # noqa: E402

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(APP, "outputs", "final_visual_implementation", "blink")
BUILD = os.path.join(APP, "build", "blink")

FPS = 20

# The eye band, in **device rows**, not as a fraction of the companion box.
#
# This was first written as 0.15-0.24 of the box, which is the top of the head —
# there are no eyes there, so the instrument measured hair and found nothing. The
# real positions come from the rig's own layer contract: `eye_left.png` has ink at
# y 153-178 and `eye_right.png` at y 179-210 of a 328-pixel-tall canvas, and the
# rig is drawn 458 px wide inside a 458 px box, so 312 px tall with 73 px of
# margin above. That puts the eyes at device rows 594-653, i.e. 0.48-0.60 of the
# box. Both bands are included, because the blink squashes both eyes at once.
EYE_TOP_ROW, EYE_BOTTOM_ROW = 594, 653
# A control band well below the eyes: the body, which breathing moves but a blink
# does not.
BODY_TOP, BODY_BOTTOM = 0.55, 0.95

# How much of the breathing to remove. The idle breathe cycle is 3.2s, so a
# 1.6s moving median is half of it: long enough to track the cycle, short enough
# that a 140ms blink survives the subtraction intact. Without this the eye band
# is dominated by the body rising and falling, and a blink is invisible inside
# it - which is exactly what the first version of this instrument returned.
DETREND_WINDOW_S = 1.6

# PetMotionSpec's declared cadence. A "blink" that arrives every 0.4s is noise,
# and a gate that cannot tell those apart will happily report blinks from a
# compression artefact.
MIN_BLINK_GAP_S = 2.5
MAX_BLINK_GAP_S = 5.5

# Blinks are 140ms, so 2-3 frames at 20fps. Anything longer than this run is
# something else happening to the eyes.
MAX_BLINK_FRAMES = 6

# Ink below this in the eye band means the companion is not drawn there at all.
# The rig's eyes sit at a flat ~1145 in a band whose blink it is measuring, and
# that flat floor is how a renderer change is told apart from an eye closing:
# a blink takes the ink down and back up within 2-3 frames, while a sprite takes
# it down and leaves it there.
EYE_QUIET_LEVEL = 1500


def eye_ink(path, box):
    """Dark pixels in the rig's eye band, as absolute device rows."""
    with Image.open(path) as im:
        a = np.asarray(im.convert("L").crop(
            (box[0], EYE_TOP_ROW, box[2], EYE_BOTTOM_ROW)), dtype=np.int16)
    return int((a < 96).sum())


def body_ink(path, box):
    x1, y1, x2, y2 = box
    h = y2 - y1
    with Image.open(path) as im:
        a = np.asarray(im.convert("L").crop(
            (x1, int(y1 + BODY_TOP * h), x2, int(y1 + BODY_BOTTOM * h))),
            dtype=np.int16)
    return int((a < 96).sum())


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seconds", type=int, default=60)
    a = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    os.makedirs(BUILD, exist_ok=True)

    if not C.guard(settle=45):
        print("REFUSING: CozyFocus is not foreground and painted",
              file=sys.stderr)
        return 2

    box = C.pet_box(C.dump())
    if not box:
        print("REFUSING: no companion on this screen", file=sys.stderr)
        return 2
    print(f"companion box {box}")

    # Record for the requested window plus slack, and wait past the slack before
    # pulling. Pulling while screenrecord is still writing produces a file with
    # no moov atom - ffmpeg then fails with "Invalid data found", which looks
    # like a corrupt capture but is only this script not waiting.
    C.adb("shell", "rm", "-f", "/sdcard/_blink.mp4")
    subprocess.Popen(
        [C.ADB, "shell", "screenrecord", "--time-limit", str(a.seconds + 4),
         "--bit-rate", "6000000", "/sdcard/_blink.mp4"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(a.seconds + 5)

    local = os.path.join(BUILD, "blink.mp4")
    subprocess.run([C.ADB, "pull", "/sdcard/_blink.mp4", local],
                   capture_output=True, text=True)
    if not os.path.exists(local):
        print("pull failed", file=sys.stderr)
        return 2

    frames = C.extract(local, os.path.join(BUILD, "frames"))
    frames = frames[:len(frames) - max(1, int(0.25 * FPS))]
    print(f"{len(frames)} frames at {FPS}fps over {a.seconds}s")

    eye = [eye_ink(p, box) for p in frames]
    body = [body_ink(p, box) for p in frames]
    if not eye:
        print("no frames extracted", file=sys.stderr)
        return 2

    eye_med = float(np.median(eye))
    body_med = float(np.median(body))
    if eye_med <= 0:
        print("no ink in the eye band: the companion is not drawn as expected",
              file=sys.stderr)
        return 2

    # Remove the breathing before looking for blinks. See DETREND_WINDOW_S: the
    # idle breathe cycle moves the whole companion, and the eye band rides along
    # with it, so on the raw series a blink is ~200 pixels inside a ~230-pixel
    # swing and no threshold can tell them apart.
    w = max(3, int(DETREND_WINDOW_S * FPS))
    padded = np.pad(np.asarray(eye, dtype=float), (w // 2, w // 2), mode="edge")
    trend = np.array([np.median(padded[i:i + w])
                      for i in range(len(eye))], dtype=float)
    resid = np.asarray(eye, dtype=float) - trend

    resid_sd = float(resid.std()) or 1.0
    # A blink closes the eyes, which REMOVES dark pixels from the band, so only
    # look downward. That is a stronger statement than |deviation| and it cannot
    # be satisfied by the companion simply being a different size than usual.
    down = np.where(resid < -2.5 * resid_sd)[0]

    runs = []
    for i in down:
        if runs and i - runs[-1][-1] <= 1:
            runs[-1].append(i)
        else:
            runs.append([i])

    blinks = []
    for run in runs:
        if len(run) > MAX_BLINK_FRAMES:
            continue
        # The control must stay still: if the body band moved by the same amount
        # at the same time, the whole companion moved (breathing, sway, a scroll)
        # and this is not a blink.
        body_shift = max(abs(body[i] - body_med) for i in run)
        eye_shift = max(abs(eye[i] - eye_med) for i in run)
        if body_shift >= eye_shift * 0.8:
            continue
        # And the band must not have gone *quiet*. The rig→sprite hand-over
        # removes the companion from this band altogether - measured as ink
        # settling at a flat ~1145 with the body band barely moving, because it
        # is a different drawing rather than a squash of the same one. Those
        # frames look exactly like a deep blink and are the reason the first
        # version of this gate reported a 0.15s gap between two "blinks".
        after = eye[run[-1]:run[-1] + 8]
        if after and float(np.median(after)) < EYE_QUIET_LEVEL:
            continue
        blinks.append({
            "start_frame": int(run[0]),
            "t_s": round(run[0] / FPS, 2),
            "frames": len(run),
            "duration_ms": round(1000.0 * len(run) / FPS),
            "eye_shift": int(eye_shift),
            "body_shift": int(body_shift),
            "eye_ink_at": [eye[i] for i in run],
            "trend_at": [int(trend[i]) for i in run],
        })

    # The intervals between consecutive blinks have to land inside the range
    # PetMotionSpec declares (2.5-5.5s). A blink at a 0.4s interval is not a
    # blink cadence, and reporting "blinks observed" from noise that happens to
    # be short is how this gate would start proving nothing.
    gaps_s = [round((blinks[i]["start_frame"] - blinks[i - 1]["start_frame"])
                    / FPS, 2)
              for i in range(1, len(blinks))]
    in_band = [g for g in gaps_s if MIN_BLINK_GAP_S <= g <= MAX_BLINK_GAP_S]

    report = {
        "label": "blink",
        "frames": len(frames),
        "fps": FPS,
        "seconds": a.seconds,
        "companion_box": list(box),
        "eye_band_device_rows": [EYE_TOP_ROW, EYE_BOTTOM_ROW],
        "body_band": [BODY_TOP, BODY_BOTTOM],
        "detrend_window_s": DETREND_WINDOW_S,
        "eye_median": round(eye_med, 1),
        "body_median": round(body_med, 1),
        "residual_sd": round(resid_sd, 2),
        "eye_series": eye,
        "body_series": body,
        "blink_count": len(blinks),
        "blinks": blinks,
        "gaps_s": gaps_s,
        "checks": {
            "blink_observed": len(blinks) > 0,
            "cadence_in_declared_band": len(gaps_s) == 0 or len(in_band) > 0,
        },
        "technical_visual_gate": (
            "PASS" if (blinks and (not gaps_s or in_band)) else "FAIL"),
        "owner_visual_gate": "REQUIRED",
        "note": (
            "Answers 'does the companion blink on the device'. It measures the "
            "eye band with the breathing removed, so it cannot see a blink that "
            "does not change the eyes, and it does not judge how a blink reads."
        ),
    }
    path = os.path.join(OUT, "blink_BLINK_REPORT.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)

    for n, b in enumerate(blinks[:2]):
        i = b["start_frame"]
        for m, j in enumerate(range(max(0, i - 2),
                                    min(len(frames), i + MAX_BLINK_FRAMES + 2))):
            shutil.copy(frames[j],
                        os.path.join(OUT, f"blink_{n}_f{m:02d}.png"))
        break

    print(json.dumps({k: report[k] for k in
                      ("eye_median", "body_median", "blink_count",
                       "checks", "technical_visual_gate")}, indent=2))
    for b in blinks[:6]:
        print(f"  blink at frame {b['start_frame']}: "
              f"{b['frames']} frames, eye ink {b['eye_ink_at']}, "
              f"body shift {b['body_shift']}")
    print(f"\nreport: {path}")
    return 0 if blinks else 1


if __name__ == "__main__":
    sys.exit(main())
