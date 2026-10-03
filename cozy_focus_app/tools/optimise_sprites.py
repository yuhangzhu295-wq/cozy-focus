"""Re-encode the shipped companion sprites as 255-colour indexed PNGs.

`productionise.py` now writes sprites this way, so any frame produced from here
on is already indexed. This tool exists to bring the frames that were produced
*before* that change to the same state, without re-running the pipeline -- which
would mean regenerating from `.asset_staging/flow/<companion>/`, and the dog's
staging directory holds more source files than the pack has frames.

## What it does and does not do

It touches only the pixel encoding. The image dimensions, the alpha silhouette
and the canvas placement are unchanged: the frames are decoded, re-encoded and
written back at the same size, so `groundBaseline` and `centerAnchor` in the
manifests stay correct and no test that measures a frame changes its answer.

## Why it is safe to run more than once

An already-indexed file is skipped, so a second run is a no-op rather than a
second generation of quantisation loss.

Usage:
    python tools/optimise_sprites.py            # apply
    python tools/optimise_sprites.py --dry-run  # report only
"""
import os
import sys

from PIL import Image

APP = r"C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app"
SPRITES = os.path.join(APP, "assets", "companions")


def optimise(dry_run=False):
    before = after = 0
    changed = skipped = 0
    worst = []

    for companion in sorted(os.listdir(SPRITES)):
        cdir = os.path.join(SPRITES, companion)
        if not os.path.isdir(cdir):
            continue
        for name in sorted(os.listdir(cdir)):
            if not name.endswith(".png"):
                continue
            path = os.path.join(cdir, name)
            size_before = os.path.getsize(path)
            before += size_before

            with Image.open(path) as im:
                if im.mode == "P":
                    # Already indexed -- leave it alone so a second run cannot
                    # quantise an already-quantised frame.
                    skipped += 1
                    after += size_before
                    continue
                rgba = im.convert("RGBA")

            if dry_run:
                # Report the size a quantised copy would take without writing.
                # The suffix must stay `.png` -- PIL picks the encoder from the
                # extension, and a bare `.tmp` has none.
                tmp = path + ".dryrun.png"
                rgba.quantize(colors=255, method=Image.FASTOCTREE).save(
                    tmp, optimize=True)
                size_after = os.path.getsize(tmp)
                os.remove(tmp)
            else:
                rgba.quantize(colors=255, method=Image.FASTOCTREE).save(
                    path, optimize=True)
                size_after = os.path.getsize(path)

            after += size_after
            changed += 1
            worst.append((size_before - size_after, companion, name,
                          size_before, size_after))

    print(f"{'would change' if dry_run else 'changed'}: {changed} frames, "
          f"skipped {skipped} already-indexed")
    print(f"sprites: {before / 1048576:.1f} MB -> {after / 1048576:.1f} MB "
          f"({100 * (before - after) / before:.0f}% smaller)")
    worst.sort(reverse=True)
    print("largest savings:")
    for saved, companion, name, sb, sa in worst[:5]:
        print(f"  {companion}/{name}: {sb // 1024} KB -> {sa // 1024} KB")


if __name__ == "__main__":
    optimise(dry_run="--dry-run" in sys.argv)
