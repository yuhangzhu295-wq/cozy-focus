"""Read the accessibility tree the platform actually receives, and flag repeats.

## Why this exists rather than a source scan

A source scan looks for shapes it knows. This project's scan missed at least two
real cases: the bottom navigation, where an `Icon(semanticLabel:)` duplicates the
`BottomNavigationBarItem.label` beside it, and any doubling produced by nesting
rather than by a repeated `Text`. Both were visible immediately in the tree the
device is handed.

The lesson is the same one that produced the unnamed-IconButton fix: what matters
is not what the widget code looks like but what the platform is told. So this
dumps `uiautomator` and reports the nodes whose announced name repeats itself.

A name is reported when, split on newlines, two or more non-empty segments are
equal. That is exactly the shape Flutter produces when a label and a child's own
text merge: `首页\n首页\nTab 1 of 3`.

Usage:
    python tools/qa/a11y_dump.py                 # pull from the device
    python tools/qa/a11y_dump.py --xml /tmp/ui.xml
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ADB = Path(r"C:\Users\zyu33\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DEVICE_XML = "/sdcard/_a11y_dump.xml"
# A Windows path, not `/tmp`: adb is a Windows binary and Python resolves a
# leading `/` against the current drive, so the two disagreed and the pull
# landed somewhere this could not read.
LOCAL_XML = Path(tempfile.gettempdir()) / "_a11y_dump.xml"


def pull(serial: str) -> Path:
    env = dict(os.environ, MSYS_NO_PATHCONV="1")
    for args in (
        ["-s", serial, "shell", "uiautomator", "dump", DEVICE_XML],
        ["-s", serial, "pull", DEVICE_XML, str(LOCAL_XML)],
    ):
        result = subprocess.run(
            [str(ADB), *args], capture_output=True, text=True, env=env, check=False
        )
        if result.returncode != 0:
            sys.stderr.write(result.stdout + result.stderr)
            raise SystemExit(f"adb {' '.join(args)} failed")
    return LOCAL_XML


def segments(value: str) -> list[str]:
    return [part.strip() for part in value.split("\n") if part.strip()]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--xml", help="an existing dump instead of pulling one")
    parser.add_argument("--all", action="store_true", help="list every named node")
    args = parser.parse_args()

    path = Path(args.xml) if args.xml else pull(args.serial)
    root = ET.parse(path).getroot()

    named = 0
    offenders: list[tuple[str, str, str]] = []
    for node in root.iter("node"):
        for attribute in ("content-desc", "text"):
            value = node.get(attribute) or ""
            parts = segments(value)
            if not parts:
                continue
            named += 1
            if args.all:
                print(f"  [{attribute}] {value!r}")
            seen: list[str] = []
            for part in parts:
                if part in seen:
                    offenders.append((attribute, value, part))
                    break
                seen.append(part)

    print(f"\n{named} named node attribute(s) on screen")

    if not offenders:
        print("no node repeats itself")
        return

    print(f"{len(offenders)} node(s) announce the same words more than once:\n")
    for attribute, value, repeated in offenders:
        print(f"  {attribute}: {value!r}")
        print(f"      {repeated!r} appears twice")


if __name__ == "__main__":
    main()
