"""Read the accessibility tree the platform actually receives, and flag repeats.

## Why this exists rather than a source scan

A source scan looks for shapes it knows. This project's scan missed at least two
real cases: the bottom navigation, where an `Icon(semanticLabel:)` duplicates the
`BottomNavigationBarItem.label` beside it, and any doubling produced by nesting
rather than by a repeated `Text`. Both were visible immediately in the tree the
device is handed.

The lesson is the same one that produced the unnamed-IconButton fix: what matters
is not what the widget code looks like but what the platform is told.

## Telling a defect from data

The first version of this tool flagged any word that appeared twice in a node, and
that was wrong. Sweeping the timeline it reported 专注任务 twice — two sessions
that happen to share a task name — and sweeping the statistics card it reported
1 小时 42 分钟 twice, which is the week's total and the only task's 100% share.
Both are data. Flagging them would have sent me to "fix" a screen that was right.

Two shapes are defects, and they are the ones this now looks for:

* **a superstring** — one part contains another, because a `Semantics` wrapper
  wrote the same information again in its own words:
  `专注计时 24:47，当前专注中 / 24:47 / 专注中`.
* **an adjacent equal pair** — the wrapper's label and the child's text are the
  same string and sit next to each other: `首页 / 首页 / Tab 1 of 3`.

A repeat that is neither is data, and is left alone. `--self-test` runs the rule
over the cases that must be caught and the cases that must not, so the
discriminator is proved rather than assumed.

Usage:
    python tools/qa/a11y_dump.py
    python tools/qa/a11y_dump.py --all          # list every named node
    python tools/qa/a11y_dump.py --self-test
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

# (announced text, is it a defect). The first four were found on the device; the
# last three are the false positives that made this rule necessary.
SELF_TEST: list[tuple[str, bool]] = [
    ("标签 生活\n生活", True),
    ("首页\n首页\nTab 1 of 3", True),
    ("Mochi 庆祝中\nMochi 庆祝中", True),
    ("专注计时 24:47，当前专注中\n24:47\n专注中", True),
    (
        "任务\n专注\n12:26\n专注任务\n0 分钟\n12:29\n专注任务\n1 分钟\n"
        "14:00\nWrite the product spec\n25 分钟 · 工作",
        False,
    ),
    (
        "10 月 5 日 - 10 月 11 日\n1 小时 42 分钟\n专注总时长\n6\n专注次数\n"
        "17 分钟\n平均时长\n专注任务\n1 小时 42 分钟\n100%",
        False,
    ),
    ("25 分钟", False),
    ("", False),
]


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


def repeats_itself(parts: list[str]) -> str | None:
    """The words this node says more than once, or None when it is just data.

    Only **neighbouring** segments are compared, and that is the whole trick. A
    merged label sits immediately in front of the text it repeats, so the two are
    adjacent; two rows of a list that happen to share a task name are not. An
    earlier version compared every pair and flagged the legend's `专注` because it
    is a substring of the row below it, `专注任务`.
    """
    for i in range(len(parts) - 1):
        first, second = parts[i], parts[i + 1]
        if first == second:
            return first
        if len(first) > len(second) and second in first:
            return second
        if len(second) > len(first) and first in second:
            return first
    return None


def self_test() -> int:
    failures = 0
    for value, expected in SELF_TEST:
        got = repeats_itself(segments(value)) is not None
        mark = "ok  " if got == expected else "FAIL"
        if got != expected:
            failures += 1
        print(f"  {mark} expected {expected!s:5s} got {got!s:5s}  {value[:60]!r}")
    print(f"\n{len(SELF_TEST) - failures}/{len(SELF_TEST)} self-test cases agree")
    return 1 if failures else 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--xml", help="an existing dump instead of pulling one")
    parser.add_argument("--all", action="store_true", help="list every named node")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        raise SystemExit(self_test())

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
            repeated = repeats_itself(parts)
            if repeated is not None:
                offenders.append((attribute, value, repeated))

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
