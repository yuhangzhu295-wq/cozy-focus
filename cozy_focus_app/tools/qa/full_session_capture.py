"""Run one full session to the end, saving it, and photograph every board on the way.

## Why one process, and why save

The emulator kills the app between tool calls, so this flow has to be one run. And
the earlier attempt stopped at the completion screen without saving - so no record
was written, which is why the timeline and the inbox could only be photographed
empty and the review screen was never reached at all.

Screens captured, in the order the flow produces them:

  05  分心收集箱   the capture sheet, opened from 记一下 during a live session
  06  专注复盘     the save screen, after the session is finished
  09  时间线       the timeline with a real record on it
  13  分心箱清单   the inbox with a real note in it

Usage:
    python tools/qa/full_session_capture.py
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
TAKEN = []


def shot(name):
    if dl.foreground() != dl.PKG:
        print(f"  REFUSING {name}: foreground is {dl.foreground()!r}")
        return False
    path = os.path.join(OUT, name)
    subprocess.run([dl.ADB, "shell", "screencap", "-p", "/sdcard/_f.png"],
                   capture_output=True)
    subprocess.run([dl.ADB, "pull", "/sdcard/_f.png", path], capture_output=True)
    ok = os.path.exists(path)
    if ok:
        TAKEN.append(name)
    print(f"  {'captured' if ok else 'FAILED'} {name}")
    return ok


def labels():
    return [l for _x, _y, l in ms.nodes(ms.dump())]


def tap_first(*needles, settle=6):
    """Tap the first node whose label contains any of `needles`."""
    xml = ms.dump()
    for x, y, label in ms.nodes(xml):
        for n in needles:
            if n in label:
                ms.tap(x, y, settle)
                return True
    return False


def type_into_field(text):
    """Tap the first text field and type. True if a field was found."""
    xml = ms.dump()
    for m in re.finditer(r"<node[^>]*?/?>", xml):
        s = m.group(0)
        if 'class="android.widget.EditText"' in s or "EditText" in s:
            b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
            if b:
                x1, y1, x2, y2 = (int(g) for g in b.groups())
                ms.tap((x1 + x2) // 2, (y1 + y2) // 2, 3)
                subprocess.run([dl.ADB, "shell", "input", "text", text],
                               capture_output=True)
                time.sleep(2)
                return True
    return False


def goto_home():
    """Get to a screen with the bottom nav, then take the home tab.

    A pushed page (the inbox, the timeline) has no bottom nav, so tapping where the
    home tab would be does nothing - which is how this script's first run ended up
    reading the inbox and reporting 'no start control'.
    """
    for _ in range(6):
        if any("标签" in l for l in labels()):
            ms.tap(180, 2263, 7)
            return True
        # 稍后再说 is the resume dialog's dismiss. Without it the dialog sits on
        # top of everything and every later tap lands on it - which is how this
        # script's second run reported the home page as the inbox.
        if not tap_first("稍后再说", "返回", "取消", "关闭", settle=5):
            ms.tap(180, 2263, 5)
    return False


def main():
    if dl.ensure(settle=40) != dl.PKG:
        print("REFUSING: CozyFocus is not foreground")
        return 2

    # --- start a session -----------------------------------------------------
    goto_home()
    if not tap_first("开始专注", "恢复专注", settle=12):
        print("no start control; screen:", labels()[:10])
        return 2
    time.sleep(8)

    # --- 05: the capture sheet, opened from 记一下 ---------------------------
    if tap_first("记一下", settle=7):
        if shot("05_capture_sheet.png"):
            if type_into_field("buy%smilk"):
                tap_first("记下", "保存", settle=6)
                shot("05_capture_saved.png")
    else:
        print("  no 记一下 on the focus screen")

    # --- finish the session and SAVE it --------------------------------------
    if not tap_first("提前结束", settle=6):
        print("no 提前结束; screen:", labels()[:10])
        return 2
    tap_first("仍然结束", "结束", settle=10)

    # The completion screen, then the save screen.
    shot("06_complete.png")
    if tap_first("保存", "记录", settle=10):
        shot("06_focus_review.png")
        tap_first("保存", "完成", settle=10)

    # --- 09: the timeline, now with a real record ----------------------------
    goto_home()
    ms.tap(540, 2263, 7)                       # the 记录 tab
    if tap_first("今日计划", settle=7):
        if tap_first("时间线", settle=7):
            shot("09_timeline.png")
        tap_first("返回", settle=6)

    # --- 13: the inbox, now with a real note ---------------------------------
    if tap_first("分心箱", settle=7):
        shot("13_inbox.png")

    print("captured:", TAKEN)
    return 0


if __name__ == "__main__":
    sys.exit(main())
