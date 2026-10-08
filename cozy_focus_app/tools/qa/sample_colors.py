"""Sample pixel colours from an image, so a match is measured, not guessed.

Reading a hex value off a rendered board or a device screenshot by eye is how a
palette drifts: two greens that look the same on screen are 20 apart in RGB.
This prints the actual value at given coordinates plus a small neighbourhood, so
a fill can be told apart from the anti-aliased edge of a border.

Boards are looked up by stem in the design pack; anything else can be given as a
path with --file.

Usage:
    python tools/qa/sample_colors.py 05_DISTRACTION_CAPTURE \
        "sel_fill=390,905" "btn_fill=500,1130"
    python tools/qa/sample_colors.py --file shot.png "btn=542,1408"
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

BOARDS = Path(
    r"C:\Users\zyu33\ZCodeProject\_devpack_v2\CozyFocus_2_0_Zxode_DevPack_v2"
    r"\01_FINAL_16_DESIGNS"
)


def hexof(pixel: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*pixel[:3])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("board", nargs="?", help="board stem, or omit with --file")
    parser.add_argument(
        "points",
        nargs="+",
        help="name=x,y in image pixels",
    )
    parser.add_argument("--file", help="any image path instead of a design board")
    parser.add_argument("--radius", type=int, default=0)
    args = parser.parse_args()

    if args.file:
        source = Path(args.file)
    elif args.board:
        source = BOARDS / f"{args.board}.png"
    else:
        raise SystemExit("give a board stem or --file")
    if not source.exists():
        raise SystemExit(f"no such image: {source}")

    with Image.open(source) as raw:
        image = raw.convert("RGB")
        print(f"# {source.name}  {image.size[0]}x{image.size[1]}")
        for point in args.points:
            name, _, coords = point.partition("=")
            x_str, _, y_str = coords.partition(",")
            x, y = int(x_str), int(y_str)
            if args.radius:
                box = (
                    x - args.radius,
                    y - args.radius,
                    x + args.radius + 1,
                    y + args.radius + 1,
                )
                region = image.crop(box)
                pixels = list(region.get_flattened_data())
                # The most common value in the neighbourhood: a border edge is
                # mostly background, so the modal colour is the fill.
                common = max(set(pixels), key=pixels.count)
                print(
                    f"{name:16s} ({x:4d},{y:4d}) modal {hexof(common)}"
                    f"  centre {hexof(image.getpixel((x, y)))}"
                )
            else:
                print(f"{name:16s} ({x:4d},{y:4d}) {hexof(image.getpixel((x, y)))}")


if __name__ == "__main__":
    main()
