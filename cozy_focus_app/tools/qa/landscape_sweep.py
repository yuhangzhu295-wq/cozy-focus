"""Capture every main screen in landscape, on the device.

## Why

`test/presentation/screen_size_and_text_sweep_test.dart` lays all eight screens
out at three landscape sizes and answers "does anything overflow". It cannot
answer "does it look right", and the brief is explicit that a component-level
pass is not a substitute for looking at the device. This is the looking.

Landscape navigation is done **by accessibility label**, not by coordinate. The
panel goes from 1080x2400 to 2400x1080 when it rotates, so any coordinate read in
portrait is wrong afterwards; label bounds are read fresh from the tree on each
step and are correct in either orientation.

Usage:
    python tools/qa/landscape_sweep.py
"""
import argparse
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import landscape_shot as L  # noqa: E402
from device_launch import ensure as ensure_foreground, drawn, foreground, PKG  # noqa: E402

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(APP, "outputs", "final_visual_implementation", "landscape")

# screen -> (nav path of labels, a string only that screen draws)
SCREENS = {
    "01_home": (["首页"], "选择专注时长"),
    "02_records": (["记录"], "今天的专注"),
    "03_growth": (["成长"], "成长属性"),
    "04_tasks": (["记录", "任务"], "新建任务"),
    "05_today": (["记录", "今日计划"], "时间线"),
    "06_inbox": (["记录", "分心箱"], "分心箱清单"),
    "07_settings": (["首页", "设置"], "设置"),
    "08_collection": (["成长", "图鉴"], "图鉴"),
}


def guard(settle=40):
    """CozyFocus must be foreground and painted before anything is read/tapped."""
    if foreground() != PKG and ensure_foreground(settle=settle) != PKG:
        return False
    return drawn()


def labels_now():
    return [l for _x, _y, l in L.nodes(L.dump())]


def go_home():
    """Back out to the home tab, guarded at every step."""
    for _ in range(8):
        if not guard():
            continue
        labels = labels_now()
        if any("个标签，共" in l for l in labels):
            return True
        if not L.tap_label("返回", settle=3):
            if not L.tap_label("稍后再说", settle=3) and not L.tap_label(
                    "取消", settle=3):
                return False
    return False


def scroll_down(step=220):
    """One small step down.

    Small on purpose. A full-viewport swipe moves the records page straight past
    its three entries, so a search that stepped a whole page at a time never saw
    them at all and reported them unreachable when they were one short scroll
    away.
    """
    L.adb("shell", "input", "swipe", "1200", str(600 + step),
          "1200", str(600 - step), "400")
    time.sleep(0.8)


def scroll_up(step=220):
    L.adb("shell", "input", "swipe", "1200", str(600 - step),
          "1200", str(600 + step), "400")
    time.sleep(0.8)


def find_label(needle, tries=4):
    """Tap a label, scrolling to look for it.

    In landscape a page is only 1080 tall, so most of a screen's content starts
    below the fold - and `uiautomator` only reports nodes that are on screen. The
    records page in landscape shows its title, its tabs and a summary card, and
    nothing else until it is scrolled.
    """
    # From the top, then down: a page keeps its scroll position between visits, so
    # a search that only scrolled down could start below the entry it was looking
    # for and walk further away from it.
    for _ in range(12):
        scroll_up()
    for _ in range(14):
        if L.tap_label(needle, settle=4):
            return True
        scroll_down()
    return False


def find_entry(needle):
    """Tap an entry inside the records page.

    The records page keeps the tab you last looked at, and 今日计划/任务/分心箱
    only exist under the 今日 tab. A sweep that ran after a report run therefore
    started on 报告 - which has none of them - and scrolled the whole page
    without ever finding them. Selecting the tab first is what makes the sweep
    independent of what the last run left the page on.
    """
    for _ in range(4):
        if any(needle in l for l in labels_now()):
            return find_label(needle)
        if not L.tap_label("今日", settle=5, exact=True):
            return False
    return find_label(needle)


def marker_visible(marker, tries=4):
    """Whether the marker is on screen, scrolling to look for it."""
    for _ in range(14):
        if any(marker in l for l in labels_now()):
            return True
        scroll_down()
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default=None,
                    help="capture only this screen key")
    a = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    if not guard(settle=45):
        print("REFUSING: CozyFocus is not foreground and painted",
              file=sys.stderr)
        return 2

    L.rotate(L.ROTATION_LANDSCAPE)
    if not drawn():
        print("REFUSING: nothing painted after rotating", file=sys.stderr)
        return 2

    captured, missing = [], []
    for name, (path, marker) in SCREENS.items():
        if a.only and a.only not in name:
            continue
        if not guard():
            print(f"{name}: lost the foreground; skipping", file=sys.stderr)
            missing.append(name)
            continue
        if not go_home():
            print(f"{name}: could not get back to the nav", file=sys.stderr)
            missing.append(name)
            continue
        ok = True
        for label in path:
            # The first hop is a bottom-nav tab and is always on screen. A hop
            # that follows 记录 is an entry inside that page, so it needs the tab
            # reset above before it can be found at all.
            if label == "记录":
                finder = L.tap_label
            elif "记录" in path[:path.index(label)]:
                finder = find_entry
            else:
                finder = find_label
            if not finder(label):
                print(f"{name}: no '{label}' on screen", file=sys.stderr)
                ok = False
                break
        if not ok:
            missing.append(name)
            continue
        time.sleep(1)
        # The marker proves the screen actually rendered, the same reason the
        # widget sweep asserts one: a screenshot of the wrong page is worse than
        # no screenshot. Scrolled for, because on a 1080-tall landscape viewport
        # most of a page is below the fold.
        on_screen = marker_visible(marker)
        dest = L.shot(f"{name}.png")
        if dest is None:
            missing.append(name)
            continue
        print(f"{name}: marker {'found' if on_screen else 'NOT FOUND'} "
              f"({marker!r})")
        if not on_screen:
            missing.append(f"{name} (marker missing)")
        else:
            captured.append(name)

    L.rotate(L.ROTATION_PORTRAIT)
    L.unfreeze_rotation()
    print(f"\ncaptured {len(captured)}: {', '.join(captured)}")
    if missing:
        print(f"missing: {', '.join(missing)}", file=sys.stderr)
    return 0 if not missing else 1


if __name__ == "__main__":
    sys.exit(main())
