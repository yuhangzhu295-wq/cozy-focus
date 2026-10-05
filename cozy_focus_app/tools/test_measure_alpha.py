"""Negative proof for the sprite measurement's alpha channel.

Run: python tools/test_measure_alpha.py

## Why this exists

`productionise.measure` and `asset_pipeline.measure` read `png.split()[-1]` as the
alpha channel. On an **indexed** PNG that band is the *palette index*, not alpha,
so measuring the file straight from disk returns a bounding box of the wrong
thing — and returns it plausibly, which is the dangerous part. The sprites this
project ships are indexed PNGs, and `audit_pack_geometry.py` was written because
that mistake was made once already.

Every current call site converts to RGBA first, so nothing is broken today. Both
functions now convert for themselves, which turns a precondition the caller has
to remember into something the function cannot get wrong.

The proof uses **real shipped frames**, not a synthetic fixture: the concern is
about these artifacts, so they are what should be measured. For each frame it
requires that the function agrees with the RGBA measurement, and that reading the
palette index instead would have given a different answer — otherwise the frame
proves nothing and is skipped rather than counted.
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import asset_pipeline  # noqa: E402  (path set up above)
import productionise  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAME_DIRS = [
    os.path.join(ROOT, "assets", "companions", name)
    for name in ("dog", "cat", "rabbit")
]


def frames():
    for directory in FRAME_DIRS:
        if not os.path.isdir(directory):
            continue
        for name in sorted(os.listdir(directory)):
            if name.lower().endswith(".png"):
                yield os.path.join(directory, name)


def main():
    checked = 0
    distinguishing = 0

    for path in frames():
        with Image.open(path) as raw:
            if raw.mode != "P":
                # Not the case this is about; the other frames are covered by the
                # geometry audit.
                continue

            indexed = raw.copy()
            rgba = indexed.convert("RGBA")
            alpha = np.asarray(rgba.split()[-1])
            ys, xs = np.nonzero(alpha > 8)
            if len(xs) == 0:
                continue
            expected_bottom = int(ys.max())
            expected_centre = float((xs.min() + xs.max()) / 2)

            # Both functions, on the indexed file, as a caller would hand it over.
            for fn, name in ((productionise.measure, "productionise"),
                             (asset_pipeline.measure, "asset_pipeline")):
                measured = fn(indexed)
                assert measured["bottomY"] == expected_bottom, (
                    f"{name} on {os.path.basename(path)} measured bottomY "
                    f"{measured['bottomY']}, but the alpha channel says "
                    f"{expected_bottom}"
                )
                assert measured["centerX"] == expected_centre, (
                    f"{name} on {os.path.basename(path)} measured centreX "
                    f"{measured['centerX']}, but the alpha channel says "
                    f"{expected_centre}"
                )
            checked += 1

            # The control. If reading the palette index gave the same answer, this
            # frame would pass whether or not the conversion happened, so it is
            # only evidence when the two differ.
            naive = np.asarray(indexed.split()[-1])
            naive_ys, _ = np.nonzero(naive > 8)
            if len(naive_ys) == 0 or int(naive_ys.max()) != expected_bottom:
                distinguishing += 1

    assert checked > 0, "no indexed frames were found to check"
    assert distinguishing > 0, (
        f"none of the {checked} indexed frames distinguish the palette index from "
        "alpha, so this file proves nothing"
    )

    # A frame with nothing visible in it is a defect, and must say so rather than
    # fail inside numpy with a message about reduction identities.
    empty = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for fn, name in ((productionise.measure, "productionise"),
                     (asset_pipeline.measure, "asset_pipeline")):
        try:
            fn(empty)
        except ValueError:
            pass
        else:
            raise AssertionError(f"{name}.measure accepted an empty frame")

    print(f"OK: measurement reads alpha, not the palette index "
          f"({checked} indexed frames checked, {distinguishing} of them "
          f"distinguish the two channels)")


if __name__ == "__main__":
    main()
