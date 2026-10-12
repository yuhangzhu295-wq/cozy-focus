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

## The fault this self-heals

`am start` was reporting `Activity class does not exist` for an app that
`pm list packages` still listed, and the foreground then stayed on whatever was
last used - which on this AVD is `com.goodnight.treehole`, so screenshots came
back showing another app.

The evidence, gathered rather than assumed:

    pm path com.yuhangzhu295.cozyfocus   -> the APK is there, 144444467 bytes,
                                            byte-identical to the built one
    df -h /data                          -> 53% used, 4.5G free
    dumpsys package <pkg>                -> "Activity Resolver Table:" EMPTY
    cmd package resolve-activity --brief -> "No activity found"

So the APK is intact and the disk is fine; it is the package manager's *parsed
state* that is missing the activities. `uninstall` + `install` restores it, and
the same table comes back populated. The emulator here has been shut down
abruptly several times, which is the plausible cause: a package scan that never
finished committing.

Reinstalling by hand every time is not a fix, so this does it when it is needed
and only then. It is not "restart until it works": it checks a specific, readable
piece of state and repairs exactly that.

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


APK = os.path.join(APP, "build", "app", "outputs", "flutter-apk", "app-debug.apk")


def resolvable():
    """True when the package manager knows this package's main activity."""
    out = adb("shell", "cmd", "package", "resolve-activity", "--brief", PKG)
    return f"{PKG}/.MainActivity" in out


def repair_if_unresolvable():
    """Reinstall when the resolver has lost the activity, and only then."""
    if resolvable():
        return True
    print("activity not resolvable; the package manager lost it - reinstalling",
          file=sys.stderr)
    if not os.path.exists(APK):
        print(f"no APK to install at {APK}", file=sys.stderr)
        return False
    adb("uninstall", PKG)
    adb("install", APK, timeout=600)
    ok = resolvable()
    print(f"after reinstall: resolvable={ok}")
    return ok


def ensure(settle=45, tries=3):
    """Bring CozyFocus to the foreground. Returns the foreground package."""
    if not devices():
        print("no device attached", file=sys.stderr)
        return ""
    if not repair_if_unresolvable():
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


def drawn(min_nodes=6, timeout=90):
    """True once the app has painted something, not just come to the foreground.

    Being the resumed activity is not the same as being drawn: the app shows its
    splash while Flutter boots, and a screenshot taken then is a Flutter logo with
    the right package name behind it. A settings screenshot came back as the
    splash for exactly this reason.
    """
    waited = 0
    while waited < timeout:
        adb("shell", "uiautomator", "dump", "/sdcard/_drawn.xml")
        out = adb("shell", "cat", "/sdcard/_drawn.xml")
        if out.count("<node") >= min_nodes and "Flutter" not in out[:400]:
            return True
        time.sleep(4)
        waited += 4
    return False


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
    if not drawn():
        print("REFUSING: the app is foreground but has not painted anything",
              file=sys.stderr)
        return 2

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
