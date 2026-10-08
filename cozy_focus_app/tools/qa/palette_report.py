"""Report the greens a design board actually uses, across all 16 boards at once.

One sample proves nothing: a single button could be shaded, could sit under a
gradient, or could be the one place the designer picked something different. This
scans every board for the greens that actually appear, weighted by how many
pixels they cover, so a palette can be compared against the app's tokens as a
whole rather than button by button.

Only saturated mid-dark greens are counted, so leaves, the pet's sprout and pale
tints do not drown the result.

Usage:
    python tools/qa/palette_report.py
    python tools/qa/palette_report.py --top 6 --board 05_DISTRACTION_CAPTURE
"""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path

from PIL import Image

BOARDS = Path(
    r"C:\Users\zyu33\ZCodeProject\_devpack_v2\CozyFocus_2_0_Zxode_DevPack_v2"
    r"\01_FINAL_16_DESIGNS"
)

# The app's own greens, for comparison.
TOKENS = {
    "primarySage": "#44714B",
    "primaryDark": "#4A7256",
    "primaryLight": "#EAF2EB",
    "timerInk": "#345C48",
}


def is_brand_green(r: int, g: int, b: int, ceiling: int = 150) -> bool:
    return (
        g > r + 12          # greener than it is red
        and g > b + 12      # greener than it is blue
        and 40 < r < ceiling  # mid-dark, not a pale tint, not near-black
        and 60 < g < ceiling + 40
        and abs(r - b) < 60  # not a teal or an olive
    )


def report(path: Path, top: int, region: tuple[int, int, int, int] | None) -> Counter:
    with Image.open(path) as raw:
        image = raw.convert("RGB")
        if region:
            x, y, w, h = region
            image = image.crop((x, y, x + w, y + h))
        # Boards are 1122x1402 and mostly flat colour, so every pixel is cheap
        # enough and avoids sampling luck.
        counts: Counter = Counter()
        for pixel in image.get_flattened_data():
            if is_brand_green(*pixel):
                counts[pixel] += 1
        total = sum(counts.values())
        where = f" region={region}" if region else ""
        print(f"\n{path.stem}{where}  ({total} brand-green pixels)")
        for (r, g, b), n in counts.most_common(top):
            print(f"  #{r:02X}{g:02X}{b:02X}  {n:7d}  {n / max(total, 1):6.1%}")
        return counts


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--top", type=int, default=4)
    parser.add_argument("--board", help="a single board stem")
    parser.add_argument("--file", help="any image path instead of a board")
    parser.add_argument(
        "--region",
        help="x,y,w,h in image pixels, to look at one part of a board",
    )
    args = parser.parse_args()

    print("app tokens: " + "  ".join(f"{k}={v}" for k, v in TOKENS.items()))

    region = None
    if args.region:
        parts = [int(p) for p in args.region.split(",")]
        if len(parts) != 4:
            raise SystemExit("--region wants x,y,w,h")
        region = (parts[0], parts[1], parts[2], parts[3])

    if args.board or args.file:
        path = Path(args.file) if args.file else BOARDS / f"{args.board}.png"
        if not path.exists():
            raise SystemExit(f"no such image: {path}")
        report(path, args.top, region)
        return

    pooled: Counter = Counter()
    for board in sorted(BOARDS.glob("*.png")):
        pooled.update(report(board, args.top, region))

    total = sum(pooled.values())
    print(f"\n=== pooled across all boards ({total} pixels) ===")
    for (r, g, b), n in pooled.most_common(10):
        print(f"  #{r:02X}{g:02X}{b:02X}  {n:8d}  {n / max(total, 1):6.1%}")


if __name__ == "__main__":
    main()
