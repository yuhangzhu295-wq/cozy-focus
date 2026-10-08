"""Find the bars in a design's chart, so a bucket count is measured not guessed.

Counting bars by eye off a rendered board is unreliable — anti-aliased edges look
like gaps and two adjacent bars look like one. This scans a horizontal line
through the chart and reports the runs of chart-coloured pixels, which gives the
bar count and their spacing exactly.

Usage:
    python tools/qa/chart_bars.py 01_HOME_OPTIMIZED --y 1040 --x 590 1075
    python tools/qa/chart_bars.py 01_HOME_OPTIMIZED --y 1040 --x 590 1075 --bands 1000 1050
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

BOARDS = Path(
    r"C:\Users\zyu33\ZCodeProject\_devpack_v2\CozyFocus_2_0_Zxode_DevPack_v2"
    r"\01_FINAL_16_DESIGNS"
)


def is_chart_green(r: int, g: int, b: int) -> bool:
    """A bar is a green that is clearly greener than the cream card behind it."""
    return g > r + 6 and g > b + 6


def runs_on_line(image: Image.Image, y: int, x0: int, x1: int) -> list[tuple[int, int]]:
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for x in range(x0, x1):
        r, g, b = image.getpixel((x, y))[:3]
        if is_chart_green(r, g, b):
            if start is None:
                start = x
        elif start is not None:
            runs.append((start, x - 1))
            start = None
    if start is not None:
        runs.append((start, x1 - 1))
    return runs


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("board")
    parser.add_argument("--y", type=int, required=True)
    parser.add_argument("--x", type=int, nargs=2, required=True)
    parser.add_argument(
        "--bands",
        type=int,
        nargs=2,
        help="y range to find each run's top, for a bar-height comparison",
    )
    args = parser.parse_args()

    source = BOARDS / f"{args.board}.png"
    if not source.exists():
        raise SystemExit(f"no such board: {source}")

    with Image.open(source) as raw:
        image = raw.convert("RGB")
        runs = runs_on_line(image, args.y, args.x[0], args.x[1])

        print(f"y={args.y}  x={args.x[0]}..{args.x[1]}")
        print(f"{len(runs)} run(s):")
        for start, end in runs:
            width = end - start + 1
            top = ""
            if args.bands:
                for y in range(args.bands[0], args.bands[1]):
                    r, g, b = image.getpixel(((start + end) // 2, y))[:3]
                    if is_chart_green(r, g, b):
                        top = f"  top y={y}"
                        break
            print(f"  x {start:4d}..{end:4d}  width {width:3d}{top}")

        if len(runs) > 1:
            gaps = [
                runs[i + 1][0] - runs[i][0] for i in range(len(runs) - 1)
            ]
            print(f"  spacing between starts: {gaps}")


if __name__ == "__main__":
    main()
