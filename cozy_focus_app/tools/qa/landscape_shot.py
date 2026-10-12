"""Rotate the device and photograph the screens that landscape was never checked on.

## Why this exists

`test/presentation/screen_size_and_text_sweep_test.dart` found that
`/records/tasks` overflowed by 65px at 800x360 - the empty state is a ~305dp
column and the landscape viewport leaves it about 248. The widget test is what
proves the layout, but the manifest carries no `screenOrientation` lock, so the
question "does the app actually survive a rotation on the device" is a device
question, and this is the device answer.

## Order matters

Navigation happens in portrait and the rotation is applied after. Rotating first
would move every tap target: the panel goes from 1080x2400 to 2400x1080 and the
coordinates this script reads off the accessibility tree would be portrait ones.

Usage:
    python tools/qa/landscape_shot.py            # task list, both filters
    python tools/qa/landscape_shot.py --restore  # put the device back upright
"""
import argparse
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from device_launch import ensure as ensure_foreground, drawn, foreground, PKG  # noqa: E402

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(APP, "outputs", "final_visual_implementation")
ADB = os.environ.get(
    "ADB", r"C:\Users\zyu33\AppData\Local\Android\Sdk\platform-tools\adb.exe")

ROTATION_LANDSCAPE = "1"   # 90 degrees
ROTATION_PORTRAIT = "0"


def adb(*args, timeout=120):
    return subprocess.run([ADB, *args], capture_output=True, text=True,
                          timeout=timeout).stdout


def rotate(value):
    """Freeze the rotation and set it. Auto-rotate has to be off or the setting
    is ignored - the sensor keeps overriding it."""
    adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
    adb("shell", "settings", "put", "system", "user_rotation", value)
    time.sleep(4)


def unfreeze_rotation():
    adb("shell", "settings", "put", "system", "accelerometer_rotation", "1")
    time.sleep(2)


def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/_ls.xml")
    local = os.path.join(APP, "build", "_ls.xml")
    subprocess.run([ADB, "pull", "/sdcard/_ls.xml", local],
                   capture_output=True, text=True)
    with open(local, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def nodes(xml):
    """(centre_x, centre_y, label) for every labelled node.

    content-desc first and text only as a fallback. Flutter puts these labels in
    content-desc and leaves `text` empty, and a single alternation regex matched
    the empty `text=""` attribute that comes first in the element - so every node
    was read as unlabelled and the whole screen looked blank.
    """
    out = []
    for m in re.finditer(r"<node[^>]*?/?>", xml):
        s = m.group(0)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        if not b:
            continue
        label = ""
        for attr in ("content-desc", "text"):
            d = re.search(rf'{attr}="([^"]*)"', s)
            if d and d.group(1).strip():
                label = d.group(1)
                break
        if not label:
            continue
        x1, y1, x2, y2 = (int(g) for g in b.groups())
        out.append(((x1 + x2) // 2, (y1 + y2) // 2, label))
    return out


def tap(x, y, settle=4):
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(settle)


def tap_label(needle, settle=4, exact=False):
    """Tap the first node whose text or description matches. True if tapped."""
    for x, y, label in nodes(dump()):
        if (label == needle) if exact else (needle in label):
            tap(x, y, settle)
            return True
    return False


def shot(name):
    """Screenshot only while CozyFocus is really the foreground.

    The guard is the whole point: a screenshot of another app must never land in
    CozyFocus's acceptance evidence, and on this AVD it has.
    """
    fg = foreground()
    if fg != PKG:
        print(f"REFUSING to capture {name}: foreground is {fg or 'unknown'!r}",
              file=sys.stderr)
        return None
    dest = os.path.join(OUT, name)
    remote = "/sdcard/_ls.png"
    adb("shell", "screencap", "-p", remote)
    subprocess.run([ADB, "pull", remote, dest], capture_output=True, text=True)
    if not os.path.exists(dest):
        print(f"pull failed for {name}", file=sys.stderr)
        return None
    size = adb("shell", "wm", "size").strip().replace("\n", " ")
    print(f"captured {name}  ({size})")
    return dest


def goto_nav_screen():
    """Back out until the bottom nav is on screen.

    The previous session left the app on the schedule page, so tapping 记录 found
    nothing: the bottom nav is only on the three top-level screens. Walking back
    is what makes this script independent of where the last run stopped.

    The nav is detected by its tab suffix, not by the bare names. Each tab's
    description is multi-line - `首页\\n第 1 个标签，共 3 个` - so an equality test
    against `首页` never matches and the loop walked the app back forever while
    the nav was on screen the whole time.
    """
    for _ in range(6):
        labels = [l for _x, _y, l in nodes(dump())]
        if any("个标签，共" in l for l in labels):
            return True
        if not tap_label("返回", settle=4):
            # A modal with no back affordance: dismiss it and try again.
            if not tap_label("稍后再说", settle=4) and not tap_label("取消", settle=4):
                return False
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--restore", action="store_true",
                    help="put the device back upright and re-enable auto-rotate")
    ap.add_argument("--prefix", default="17_landscape_task_list",
                    help="output name stem; used to keep the before/after pair "
                         "apart")
    a = ap.parse_args()

    if a.restore:
        rotate(ROTATION_PORTRAIT)
        unfreeze_rotation()
        print("rotation restored to portrait, auto-rotate on")
        return 0

    if ensure_foreground(settle=45) != PKG:
        print("REFUSING: CozyFocus is not foreground", file=sys.stderr)
        return 2
    if not drawn():
        print("REFUSING: the app has not painted", file=sys.stderr)
        return 2

    # Portrait navigation first: see the module docstring for why.
    if not goto_nav_screen():
        print("could not get back to a screen with the bottom nav; it showed:",
              file=sys.stderr)
        for _x, _y, l in nodes(dump())[:16]:
            print("   ", l[:50].replace(chr(10), " "), file=sys.stderr)
        return 2
    tap_label("记录", settle=5)
    if not tap_label("任务", settle=5):
        print("could not reach the task list; screen had:", file=sys.stderr)
        for _x, _y, l in nodes(dump())[:16]:
            print("   ", l[:50].replace(chr(10), " "), file=sys.stderr)
        return 2

    rotate(ROTATION_LANDSCAPE)
    if not drawn():
        print("REFUSING: nothing painted after rotating", file=sys.stderr)
        return 2
    shot(f"{a.prefix}_today.png")

    # The other filter, in case the list is not empty.
    tap_label("已完成", settle=5)
    shot(f"{a.prefix}_done.png")

    # The empty state now scrolls rather than overflowing, so the second button
    # sits below the fold. Swiping proves the page really is scrollable on the
    # device and not just clipped - a clipped button and a scrollable one look
    # the same in a single frame.
    adb("shell", "input", "swipe", "1200", "900", "1200", "400", "300")
    time.sleep(3)
    shot(f"{a.prefix}_done_scrolled.png")

    rotate(ROTATION_PORTRAIT)
    unfreeze_rotation()
    print("rotation restored")
    return 0


if __name__ == "__main__":
    sys.exit(main())
