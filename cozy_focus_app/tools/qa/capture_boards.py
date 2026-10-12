"""Capture the remaining board screens in one process.

The emulator has been killing the app between tool calls, so a flow split across
calls lands somewhere else. This walks to each screen, verifies the foreground
before every capture (device_launch's guard), and writes the screenshot.

Usage:
    python tools/qa/capture_boards.py
"""
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import device_launch as dl          # noqa: E402
import motion_state as ms           # noqa: E402

OUT = os.path.join(dl.APP, "outputs", "final_visual_implementation")


def shot(name):
    if dl.foreground() != dl.PKG:
        print(f"  REFUSING {name}: foreground is {dl.foreground()!r}")
        return False
    path = os.path.join(OUT, name)
    subprocess.run([dl.ADB, "shell", "screencap", "-p", "/sdcard/_c.png"],
                   capture_output=True)
    subprocess.run([dl.ADB, "pull", "/sdcard/_c.png", path], capture_output=True)
    ok = os.path.exists(path)
    print(f"  {'captured' if ok else 'FAILED'} {name}")
    return ok


def back_to_records():
    """Whatever screen we are on, get to the records hub."""
    for _ in range(4):
        xml = ms.dump()
        labels = [l for _x, _y, l in ms.nodes(xml)]
        if any("记录" in l and "标签" in l for l in labels):
            ms.tap(540, 2263, 5)          # already there or one tab away
            return True
        if ms.tap_label(xml, "返回", 5):
            continue
        ms.tap(180, 2263, 5)              # fall back to the home tab
    return False


def main():
    if dl.ensure(settle=40) != dl.PKG:
        print("REFUSING: CozyFocus is not foreground")
        return 2

    # --- 09 timeline: records -> today plan -> the timeline segment -----------
    back_to_records()
    xml = ms.dump()
    if ms.tap_label(xml, "今日计划", 7):
        xml = ms.dump()
        if ms.tap_label(xml, "时间线", 7):
            shot("09_timeline.png")
        else:
            print("  no 时间线 segment")
        # --- 06 focus review is reached from a finished session; skip here ---
        ms.tap_label(ms.dump(), "返回", 6)

    # --- 16 empty state: the records hub with nothing today ------------------
    back_to_records()
    shot("16_empty_state.png")

    # --- 13 inbox, populated or not ------------------------------------------
    xml = ms.dump()
    if ms.tap_label(xml, "分心箱", 7):
        shot("13_inbox.png")

    print("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
