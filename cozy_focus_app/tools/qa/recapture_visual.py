"""Drive the running app by accessibility label and capture screenshots.

Why not fixed coordinates: the emulator is 1080x2400 and the pages scroll, so a
hard-coded tap lands on whatever happens to be there after the previous step.
This reads the uiautomator tree, finds the node whose text or content-desc
matches, and taps its centre.

Usage:
    python tools/qa/recapture_visual.py dump
    python tools/qa/recapture_visual.py tap 记录
    python tools/qa/recapture_visual.py shot 01_home
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ADB = r"C:\Users\zyu33\AppData\Local\Android\Sdk\platform-tools\adb.exe"
PKG = "com.yuhangzhu295.cozyfocus"
REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "outputs" / "final_visual_implementation" / "current_2026-10-18"
ENV = dict(os.environ, MSYS_NO_PATHCONV="1")


def adb(*args: str) -> str:
    return subprocess.run(
        [ADB, *args], capture_output=True, text=True, env=ENV, check=False
    ).stdout


def nodes() -> list[tuple[str, tuple[int, int, int, int]]]:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    local = Path(tempfile.gettempdir()) / "cozy_ui.xml"
    adb("pull", "/sdcard/ui.xml", str(local))
    text = local.read_text(encoding="utf-8", errors="replace")
    found = []
    for match in re.finditer(r"<node[^>]*>", text):
        node = match.group(0)
        label = re.search(r'text="([^"]*)"', node)
        desc = re.search(r'content-desc="([^"]*)"', node)
        bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
        name = (label.group(1) if label else "") or (desc.group(1) if desc else "")
        if name.strip() and bounds:
            found.append(
                (
                    name,
                    tuple(int(bounds.group(i)) for i in range(1, 5)),  # type: ignore[arg-type]
                )
            )
    return found


def tap(label: str, contains: bool = True) -> bool:
    for name, (x1, y1, x2, y2) in nodes():
        if (label in name) if contains else (name == label):
            x, y = (x1 + x2) // 2, (y1 + y2) // 2
            adb("shell", "input", "tap", str(x), str(y))
            print(f"tapped {name!r} at {x},{y}")
            time.sleep(1.2)
            return True
    print(f"NOT FOUND: {label!r}")
    return False


def shot(name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / name
    adb("shell", "screencap", "-p", "/sdcard/_shot.png")
    adb("pull", "/sdcard/_shot.png", str(target))
    print(f"captured {target} ({target.stat().st_size} bytes)")


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "dump"
    if cmd == "dump":
        for name, bounds in nodes():
            print(repr(name), bounds)
    elif cmd == "tap":
        tap(sys.argv[2], contains="--exact" not in sys.argv)
    elif cmd == "shot":
        shot(sys.argv[2])
    else:
        raise SystemExit(f"unknown command {cmd}")


if __name__ == "__main__":
    main()
