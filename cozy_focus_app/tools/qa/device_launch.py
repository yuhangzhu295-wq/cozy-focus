"""Put CozyFocus in the foreground, and refuse to act unless it really is.

## Why this exists

Twice in one window, `adb shell am start` reported success and then a screenshot
came back showing **a different app** - `com.goodnight.treehole`, which is also
installed on this AVD. Both rounds were spent comparing the wrong picture against
a CozyFocus board. The instruction that came out of it is blunt: never write
another app's screenshot into CozyFocus's acceptance evidence.

So nothing here screenshots or taps without first reading the resumed activity
and checking the package name. `am start` returning is not evidence that the app
is up; the foreground package is.

## Usage

    python tools/qa/device_launch.py            # ensure foreground, report
    python tools/qa/device_launch.py --shot NAME  # ensure, then screenshot
    python tools/qa/device_launch.py --tap X Y    # ensure, then tap

Exit codes: 0 the app is foreground and any action ran; 2 the app could not be
brought to the foreground (nothing is written, nothing is tapped).
"""
import argparse
import os
import re
import subprocess
import sys
import time

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PKG = "com.yuhangzhu295.cozyfocus"
ACTIVITY = f"{PKG}/.MainActivity"
ADB = os.environ.get(
    "ADB",
    r"C:\Users\zyu33\AppData\Local\Android\Sdk\platform-tools\adb.exe",
)


def adb(*args, timeout=90):
    return subprocess.run(
        [ADB, *args], capture_output=True, text=True, timeout=timeout
    ).stdout


def devices():
    out = adb("devices")
    return [
        line.split()[0]
        for line in out.splitlines()[1:]
        if line.strip().endswith("device")
    ]


def foreground():
    """The resumed package name, or '' if it cannot be read."""
    out = adb("shell", "dumpsys", "activity", "activities")
    m = re.search(r"topResumedActivity=ActivityRecord\{\S+ \S+ ([^\s/]+)/", out)
    return m.group(1) if m else ""


def ensure(settle=45, tries=3):
    """Bring CozyFocus to the foreground. Returns the foreground package."""
    if not devices():
        print("no device attached", file=sys.stderr)
        return ""
    for attempt in range(tries):
        adb("shell", "am", "start", "-n", ACTIVITY)
        waited = 0
        while waited < settle:
            time.sleep(3)
            waited += 3
            fg = foreground()
            if fg == PKG:
                return fg
        print(f"attempt {attempt + 1}: foreground is {fg or 'unknown'!r}, "
              f"not {PKG}", file=sys.stderr)
    return foreground()


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shot", help="screenshot to this path after ensuring")
    ap.add_argument("--tap", nargs=2, type=int, metavar=("X", "Y"))
    ap.add_argument("--settle", type=int, default=45)
    a = ap.parse_args()

    fg = ensure(settle=a.settle)
    if fg != PKG:
        print(f"REFUSING: foreground is {fg or 'unknown'!r}, not {PKG}. "
              "Nothing was captured and nothing was tapped.", file=sys.stderr)
        return 2
    print(f"foreground ok: {fg}")

    if a.tap:
        adb("shell", "input", "tap", str(a.tap[0]), str(a.tap[1]))
        time.sleep(3)
        if foreground() != PKG:
            print("WARNING: the tap left CozyFocus", file=sys.stderr)
            return 2

    if a.shot:
        # `exec-out` is avoided deliberately: CRLF corrupts the PNG on this host.
        remote = "/sdcard/_shot.png"
        adb("shell", "screencap", "-p", remote)
        out = subprocess.run(
            [ADB, "pull", remote, a.shot], capture_output=True, text=True
        )
        if not os.path.exists(a.shot):
            print(f"pull failed: {out.stdout}{out.stderr}", file=sys.stderr)
            return 2
        print(f"captured {a.shot}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
