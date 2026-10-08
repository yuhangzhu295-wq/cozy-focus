"""Crop a region out of a design board so a detail can be measured, not eyeballed.

The boards are 1122x1402: a phone mockup with annotation callouts around it, so
the region has to be given in board pixels. Output is scaled up so small type is
legible when read back.

Usage:
    python tools/qa/crop_board.py 05_DISTRACTION_CAPTURE 340 740 460 480 --scale 2
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

BOARDS = Path(
    r"C:\Users\zyu33\ZCodeProject\_devpack_v2\CozyFocus_2_0_Zxode_DevPack_v2"
    r"\01_FINAL_16_DESIGNS"
)
REPO = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("board", help="board stem, e.g. 05_DISTRACTION_CAPTURE")
    parser.add_argument("x", type=int)
    parser.add_argument("y", type=int)
    parser.add_argument("w", type=int)
    parser.add_argument("h", type=int)
    parser.add_argument("--scale", type=float, default=2.0)
    parser.add_argument(
        "--out",
        default="outputs/final_product_qa/_crops",
        help="output directory relative to the repo root",
    )
    args = parser.parse_args()

    source = BOARDS / f"{args.board}.png"
    if not source.exists():
        raise SystemExit(f"no such board: {source}")

    out_dir = (REPO / args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(source) as image:
        box = (args.x, args.y, args.x + args.w, args.y + args.h)
        crop = image.crop(box)
        if args.scale != 1.0:
            crop = crop.resize(
                (int(crop.width * args.scale), int(crop.height * args.scale)),
                Image.LANCZOS,
            )
        target = out_dir / (
            f"{args.board}_{args.x}_{args.y}_{args.w}x{args.h}"
            f"@{args.scale:g}x.png"
        )
        crop.save(target, optimize=True)
        # The read tool refuses to inline anything over ~200KB, and a scaled-up
        # crop of a busy board goes past that easily. Re-save as JPEG when it
        # does, rather than handing back an opaque artifact.
        if target.stat().st_size > 180_000:
            target = target.with_suffix(".jpg")
            crop.convert("RGB").save(target, quality=88, optimize=True)
        print(f"{target} ({target.stat().st_size} bytes, {crop.size})")


if __name__ == "__main__":
    main()
