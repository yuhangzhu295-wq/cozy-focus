"""Measure the shipped packs against their declared geometry.

Run: python tools/audit_pack_geometry.py

## Why

`tools/manifest.py` used to write a pack's `groundBaseline` and `centerAnchor` as
the mean of the frames it had just measured, so it certified whatever the frames
happened to be. That is now fixed - the contract is the source and the frames are
checked against it - but the built-in packs were produced by the old code, so
their declared 458/255 has never actually been compared to their frames.

This measures them. It is read-only: it opens the shipped PNGs, measures the alpha
bounding box, and reports the deviation. It changes nothing.

## The measurement is not `productionise.measure`

That helper reads `png.split()[-1]` as the alpha channel. The sprites ship as
indexed PNG, and on an indexed image the last band is the *palette index*, not
alpha - so it would measure the wrong thing and, worse, do so plausibly. The image
is converted to RGBA first here, which is the same correction the sprite tooling
already had to make once.
"""

import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets", "companions")


def alpha_bounds(path):
    """The alpha bounding box of a PNG, converted to RGBA first.

    Returns (bottomY, centerX, width, height) or None when the image has no
    visible pixels at all.
    """
    with Image.open(path) as img:
        rgba = img.convert("RGBA")
        alpha = np.asarray(rgba.split()[-1])
        ys, xs = np.nonzero(alpha > 8)
        if len(xs) == 0:
            return None
        return (
            int(ys.max()),
            float((xs.min() + xs.max()) / 2),
            int(rgba.width),
            int(rgba.height),
        )


def contract_for(companion):
    path = os.path.join(ASSETS, companion, "animation_manifest.json")
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        raw = json.load(fh)
    canvas = raw.get("canvas") or {}
    return {
        "groundBaseline": int(raw["groundBaseline"]),
        "centerAnchor": int(raw["centerAnchor"]),
        "canvas": [int(canvas.get("width", 0)), int(canvas.get("height", 0))],
        "anchorTolerancePx": int(raw.get("anchorTolerancePx", 0)),
    }


def main():
    failures = []
    for companion in sorted(os.listdir(ASSETS)):
        pack = os.path.join(ASSETS, companion, "manifest.json")
        if not os.path.exists(pack):
            continue
        with open(pack, encoding="utf-8") as fh:
            manifest = json.load(fh)

        contract = contract_for(companion)
        print(f"\n=== {companion} ===")
        if contract is None:
            print("  no geometry contract, so nothing to check against")
            continue
        print(f"  contract: baseline {contract['groundBaseline']} "
              f"centre {contract['centerAnchor']} "
              f"canvas {contract['canvas']} "
              f"tolerance {contract['anchorTolerancePx']}px")

        baselines, centres, missing = [], [], 0
        worst_baseline, worst_centre = 0, 0.0
        for action, spec in manifest.get("actions", {}).items():
            for frame in spec.get("frames", []):
                path = os.path.join(ASSETS, companion, frame)
                if not os.path.exists(path):
                    missing += 1
                    continue
                bounds = alpha_bounds(path)
                if bounds is None:
                    failures.append(f"{companion}/{frame} has no visible pixels")
                    continue
                bottom, centre, _, _ = bounds
                baselines.append(bottom)
                centres.append(centre)
                worst_baseline = max(
                    worst_baseline, abs(bottom - contract["groundBaseline"]))
                worst_centre = max(
                    worst_centre, abs(centre - contract["centerAnchor"]))

        if not baselines:
            print("  no frames measured")
            continue

        mean_baseline = round(sum(baselines) / len(baselines))
        mean_centre = round(sum(centres) / len(centres))
        tolerance = contract["anchorTolerancePx"]
        print(f"  frames measured: {len(baselines)}"
              + (f"  MISSING: {missing}" if missing else ""))
        print(f"  mean baseline {mean_baseline}  worst deviation {worst_baseline}px")
        print(f"  mean centre   {mean_centre}  worst deviation {worst_centre:.1f}px")

        if abs(mean_baseline - contract["groundBaseline"]) > tolerance:
            failures.append(
                f"{companion} mean baseline {mean_baseline} is off by "
                f"{abs(mean_baseline - contract['groundBaseline'])}px")
        if abs(mean_centre - contract["centerAnchor"]) > tolerance:
            failures.append(
                f"{companion} mean centre {mean_centre} is off by "
                f"{abs(mean_centre - contract['centerAnchor'])}px")
        if worst_baseline > tolerance:
            failures.append(
                f"{companion} worst frame baseline is {worst_baseline}px off, "
                f"beyond the {tolerance}px tolerance")
        if missing:
            failures.append(f"{companion} references {missing} frame(s) that do "
                            "not exist")

    print()
    if failures:
        print("FAIL")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("PASS: every shipped pack's frames match its declared geometry")
    return 0


if __name__ == "__main__":
    sys.exit(main())
