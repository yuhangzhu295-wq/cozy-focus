"""Drive the app to a state, find the companion, and run the motion gate - in one process.

## Why one process

The emulator has been killing the app between tool calls, so a flow split across
calls kept landing on the resume dialog instead of the screen it was aiming for.
Everything here happens inside one run: bring the app up, tap through to the
target state, read the companion's bounds from the accessibility tree, then hand
those bounds to `runtime_motion_gate.py`.

Usage:
    python tools/qa/motion_state.py rest
    python tools/qa/motion_state.py focus
"""
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from device_launch import ensure as ensure_foreground  # noqa: E402

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PKG = "com.yuhangzhu295.cozyfocus"
ACTIVITY = f"{PKG}/.MainActivity"
ADB = os.environ.get(
    "ADB", r"C:\Users\zyu33\AppData\Local\Android\Sdk\platform-tools\adb.exe")
GATE = os.path.join(APP, "tools", "runtime_motion_gate.py")

# A region that must not change while the companion moves. The title block is the
# same on every screen here and holds no timer.
# Per-state: the control has to be static on THAT screen. The title block works on
# the focus screen but not on the rest screen, where it sits over the countdown.
CONTROL_FOR = {
    "rest": "150,190,930,290",
    "celebrate": "150,190,930,290",
    "focus": "250,300,830,430",
}
CONTROL = "250,300,830,430"


def adb(*args, timeout=120):
    return subprocess.run([ADB, *args], capture_output=True, text=True,
                          timeout=timeout).stdout


def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/_ms.xml")
    local = os.path.join(APP, "build", "_ms.xml")
    subprocess.run([ADB, "pull", "/sdcard/_ms.xml", local],
                   capture_output=True, text=True)
    with open(local, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def nodes(xml):
    """(centre_x, centre_y, label) for every labelled node."""
    out = []
    for m in re.finditer(r"<node[^>]*?/?>", xml):
        s = m.group(0)
        d = re.search(r'content-desc="([^"]*)"', s)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        if not (d and b and d.group(1).strip()):
            continue
        x1, y1, x2, y2 = (int(g) for g in b.groups())
        out.append(((x1 + x2) // 2, (y1 + y2) // 2, d.group(1)))
    return out


def tap(x, y, settle=5):
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(settle)


def tap_label(xml, needle, settle=5):
    """Tap the first labelled node containing `needle`. True if it found one."""
    for x, y, label in nodes(xml):
        if needle in label:
            tap(x, y, settle)
            return True
    return False


def pet_box(xml):
    """The companion's bounds as x1,y1,x2,y2, or None."""
    for m in re.finditer(r"<node[^>]*?/?>", xml):
        s = m.group(0)
        d = re.search(r'content-desc="([^"]*)"', s)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        if not (d and b):
            continue
        if "点一下" in d.group(1):
            return ",".join(b.groups())
    return None


def dismiss_resume():
    """The resume dialog blocks navigation; dismiss it if it is up."""
    xml = dump()
    if "已恢复专注状态" in xml:
        print("resume dialog up; dismissing")
        if not tap_label(xml, "稍后再说", 6):
            tap_label(xml, "恢复专注", 6)


def main():
    state = (sys.argv[1] if len(sys.argv) > 1 else "rest").lower()
    # The guard, not a bare am start. Twice now this script tapped through to the
    # wrong app because `am start` returned while the foreground was something
    # else - the last time onto a crisis-help screen belonging to another app.
    if ensure_foreground(settle=40) != PKG:
        print("REFUSING: CozyFocus is not foreground", file=sys.stderr)
        return 2
    dismiss_resume()

    if state == "rest":
        # Leave the running session's screen, then take the home page's rest row.
        xml = dump()
        if "番茄钟" in xml:
            tap_label(xml, "返回", 6)
        dismiss_resume()
        tap(180, 2263, 7)                      # the 首页 tab
        dismiss_resume()
        xml = dump()
        if not tap_label(xml, "放松一下", 7):
            print("could not find 放松一下; screen was:", file=sys.stderr)
            for _x, _y, _l in nodes(xml)[:14]:
                print("   ", _l[:50].replace(chr(10), " "), file=sys.stderr)
            return 2
        # The rest page's own start control, if it is asking.
        xml = dump()
        tap_label(xml, "开始休息", 7)
    elif state == "celebrate":
        # End whatever is running, run a fresh session, then finish it early: the
        # completion screen is where the companion celebrates.
        xml = dump()
        tap_label(xml, "结束休息", 7)
        dismiss_resume()
        # Ending a rest lands on the rest SETUP screen, which has no bottom nav.
        xml = dump()
        tap_label(xml, "返回", 6)
        dismiss_resume()
        tap(180, 2263, 7)
        dismiss_resume()
        xml = dump()
        if not tap_label(xml, "开始专注", 12):
            tap_label(xml, "恢复专注", 12)
        time.sleep(8)
        xml = dump()
        if not tap_label(xml, "提前结束", 6):
            print("could not end the session; screen:", file=sys.stderr)
            for _x, _y, _l in nodes(xml)[:12]:
                print("   ", _l[:50].replace(chr(10), " "), file=sys.stderr)
            return 2
        xml = dump()
        tap_label(xml, "结束", 10)      # the confirmation's affirmative
    else:
        tap(180, 2263, 7)
        xml = dump()
        if not tap_label(xml, "开始专注", 10):
            tap_label(xml, "恢复专注", 10)

    time.sleep(3)
    xml = dump()
    box = pet_box(xml)
    if not box:
        print("no companion on screen", file=sys.stderr)
        return 2
    print(f"state={state} companion={box}")
    out = subprocess.run([sys.executable, GATE, "--label", state,
                          "--subject", box, "--control", CONTROL_FOR.get(state, CONTROL)],
                         capture_output=True, text=True)
    tail = out.stdout[-900:] or out.stderr[-900:]
    print(tail)
    return 0


if __name__ == "__main__":
    sys.exit(main())
