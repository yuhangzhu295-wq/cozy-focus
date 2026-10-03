"""Negative verification for the video->sprite gates.

## Why this exists

A gate that never fires is indistinguishable from a gate that cannot fire. Every
check in `video_to_sprite.qa_frames` is only worth having if it rejects the fault
it names, so this deliberately breaks the art in four ways and asserts the
matching check fails. Then it throws the broken copies away.

## What it does not do

It never touches `assets/companions/`. Every fault is injected into a temporary
directory, because the point is to prove the gate works, not to ship a broken
frame and hope the suite notices.

Usage:
    python tools/video_to_sprite_negative_check.py
"""
import os
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import video_to_sprite as v2s  # noqa: E402

# A known-good set to corrupt. Produced by the pipeline from a clip and already
# passing every gate, so a failure below is caused by the injection alone.
GOOD = os.path.join(v2s.APP, ".asset_staging", "video", "out", "dog")


def _load(paths):
    return [Image.open(p).convert("RGBA") for p in paths]


def fault_blur(imgs):
    """One frame smeared, as a motion-blur or transition frame would be."""
    out = [im.copy() for im in imgs]
    out[2] = out[2].filter(ImageFilter.GaussianBlur(6))
    return out


def fault_baseline(imgs):
    """One frame lifted off the ground line, as a misaligned export would be."""
    out = [im.copy() for im in imgs]
    im = out[3]
    shifted = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shifted.alpha_composite(im, (0, -14))
    out[3] = shifted
    return out


def fault_duplicate(imgs):
    """A repeated frame, which would waste one of the six slots."""
    out = [im.copy() for im in imgs]
    out[4] = out[3].copy()
    return out


def fault_missing(imgs):
    """A frame that is simply not there."""
    out = [im.copy() for im in imgs]
    out[5] = None
    return out


FAULTS = [
    ("blur", fault_blur, "sharp"),
    ("baseline", fault_baseline, "baseline"),
    ("duplicate", fault_duplicate, "no_duplicates"),
    ("missing", fault_missing, "frames_present"),
]


def main():
    good = sorted(
        os.path.join(GOOD, f) for f in os.listdir(GOOD)
        if f.startswith("idle_") and f.endswith(".png"))
    if not good:
        print(f"FAIL: no known-good frames under {GOOD}")
        print("      run the pipeline first, e.g.")
        print("      python tools/video_to_sprite.py --video <clip> --companion dog "
              "--action idle --frames 6 --loop loop --out-root .asset_staging/video/out")
        return 1

    contract = v2s.load_contract("dog")
    imgs = _load(good)

    # The control: the unmodified set must PASS, or a failure below proves
    # nothing about the gate.
    tmp = tempfile.mkdtemp(prefix="v2s_neg_")
    rows = []
    try:
        control_dir = os.path.join(tmp, "control")
        os.makedirs(control_dir)
        control = []
        for i, im in enumerate(imgs):
            p = os.path.join(control_dir, f"idle_{i:03d}.png")
            im.save(p)
            control.append(p)
        base = v2s.qa_frames(control, loop=True, expect_in_place=False,
                             contract=contract)
        rows.append(("control (unmodified)", base["verdict"], "-", "-"))
        if base["verdict"] != "PASS":
            print("FAIL: the unmodified set does not pass, so this check is "
                  "meaningless")
            print("      blocking:", base["blocking"])
            return 1

        for name, inject, expected_check in FAULTS:
            d = os.path.join(tmp, name)
            os.makedirs(d)
            paths = []
            for i, im in enumerate(inject(imgs)):
                if im is None:
                    # Deliberately absent: the gate must notice the hole.
                    paths.append(os.path.join(d, f"idle_{i:03d}.png"))
                    continue
                p = os.path.join(d, f"idle_{i:03d}.png")
                im.save(p)
                paths.append(p)
            rep = v2s.qa_frames(paths, loop=True, expect_in_place=False,
                                contract=contract)
            fired = expected_check in rep["blocking"]
            rows.append((name, rep["verdict"], expected_check,
                         "fired" if fired else "DID NOT FIRE"))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print(f"{'fault':24s} {'verdict':8s} {'expected check':16s} result")
    print("-" * 68)
    ok = True
    for name, verdict, check, result in rows:
        print(f"{name:24s} {verdict:8s} {check:16s} {result}")
        if name != "control (unmodified)" and result != "fired":
            ok = False

    print()
    print("NEGATIVE_CHECK:", "PASS" if ok else "FAIL")
    print("no faulty asset was written to assets/companions/")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
