"""Capture a real device screenshot into the QA evidence tree.

Why this exists rather than `adb exec-out screencap -p > file`: under Git Bash on
Windows that redirect rewrites LF as CRLF and corrupts the PNG, and `/sdcard/...`
arguments get path-mangled unless `MSYS_NO_PATHCONV` is set. So this goes through
`adb shell screencap` to a device file, then `adb pull`.

It also writes a downscaled copy, because the raw 1080x2400 capture is over the
tool's inline image limit and would only come back as an opaque artifact.

Usage:
    python tools/qa/device_shot.py 05_sheet_open
    python tools/qa/device_shot.py 05_sheet_open --dir outputs/final_product_qa/02_BEFORE_AFTER
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image

ADB = Path(
    r"C:\Users\zyu33\AppData\Local\Android\Sdk\platform-tools\adb.exe"
)
DEVICE_PATH = "/sdcard/_qa_shot.png"
REPO = Path(__file__).resolve().parents[2]


def adb(*args: str) -> str:
    env = dict(os.environ, MSYS_NO_PATHCONV="1")
    result = subprocess.run(
        [str(ADB), *args],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stdout + result.stderr)
        raise SystemExit(f"adb {' '.join(args)} failed")
    return result.stdout


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("name", help="file stem, e.g. 05_sheet_open")
    parser.add_argument(
        "--dir",
        default="outputs/final_product_qa/02_BEFORE_AFTER",
        help="directory relative to the repo root",
    )
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument(
        "--max-bytes",
        type=int,
        default=180_000,
        help="target size for the readable copy",
    )
    args = parser.parse_args()

    out_dir = (REPO / args.dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    adb("-s", args.serial, "shell", "screencap", "-p", DEVICE_PATH)
    full = out_dir / f"{args.name}.png"
    adb("-s", args.serial, "pull", DEVICE_PATH, str(full))
    adb("-s", args.serial, "shell", "rm", "-f", DEVICE_PATH)

    with Image.open(full) as image:
        image = image.convert("RGB")
        readable = out_dir / f"{args.name}.readable.png"
        for scale in (0.6, 0.5, 0.42, 0.36, 0.3, 0.25):
            resized = image.resize(
                (int(image.width * scale), int(image.height * scale)),
                Image.LANCZOS,
            )
            resized.save(readable, optimize=True)
            if readable.stat().st_size <= args.max_bytes:
                break

    print(f"full     {full} ({full.stat().st_size} bytes)")
    print(f"readable {readable} ({readable.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
