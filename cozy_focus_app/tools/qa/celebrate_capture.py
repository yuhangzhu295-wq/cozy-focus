"""Catch the celebrate burst, which a polling gate cannot.

## Why a recording and not the frame gate

`runtime_motion_gate.py` samples 12 screenshots at 0.6s and takes about seven
seconds to do it. That is the right instrument for an ambient loop - idle,
focus, pause and rest all measured PASS with it - but `celebrate` is a **one
shot**: `PetMotionSpec.celebrateCycle` is 1200ms, and
`_onCelebrateStatusChanged` sets `_celebrateSettled` the moment it completes, so
afterwards the companion falls back to ambient micro-motion. Two earlier attempts
opened the window after the page had already arrived and measured a settled pet;
both were recorded as NOT_VERIFIED rather than claimed.

A one-shot needs a recording, so this drives the flow to the completion screen
with `screenrecord` already running and finds the burst in the extracted frames.

## The transition problem

The recording starts before the completion screen exists, so its first frames are
the running focus screen - which has a countdown in it, so a single control
region cannot span the whole clip. The clip is therefore split at the page
change, detected as the largest whole-frame difference, and only the frames after
it are measured. The control is then a region that must be still *on the
completion screen*.

Usage:
    python tools/qa/celebrate_capture.py
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from device_launch import (  # noqa: E402
    ensure as ensure_foreground, drawn, foreground, PKG)

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(APP, "outputs", "final_visual_implementation", "celebrate")
BUILD = os.path.join(APP, "build", "celebrate")
ADB = os.environ.get(
    "ADB", r"C:\Users\zyu33\AppData\Local\Android\Sdk\platform-tools\adb.exe")

RECORD_SECONDS = 18
FPS = 20

# The lag used to decide whether anything is moving, in seconds. Half a second is
# long enough that a slow breath shows and short enough that a genuine hold does
# not.
SLOW_LAG_S = 0.5
SLOW_LAG = int(SLOW_LAG_S * FPS)

# The bottom navigation bar. On the completion screen it is the one region that
# genuinely never changes: the title block fades in over a couple of seconds and
# moved its own region by up to 2.5, which failed the control check on runs where
# the companion had done nothing wrong. The nav is well clear of the companion
# (which sits at y 288-619) and is not animated.
CONTROL = (100, 2200, 980, 2330)

# The companion's accessibility description is its name plus its current state,
# and the state word changes with the state: the running screen says 专注中, the
# completion screen says 庆祝中. Matching only 点一下 found the companion on the
# running screen and on the modal, and then failed outright on the completion
# screen - which is the one screen this tool exists for.
#
# `休息中`, not `休息`: the bare word also matches the home page's 放松一下
# button, whose description reads 放松一下，累了就休息一会儿吧. That node is
# smaller than the companion, so the "smallest match" rule picked it and every
# measurement was taken of a button.
PET_MARKERS = ("点一下", "庆祝中", "专注中", "空闲", "休息中", "陪伴中", "工作中",
               "在房间")

# A frozen still scores 0. The ambient layer alone stays far below this; the
# celebrate burst has to clear it.
MIN_BURST = 1.0
# The control must be far quieter than the subject, not literally still.
#
# The original value was 0.5, calibrated on the home page where the capture path
# measured exactly zero. The completion screen's title fades in over a couple of
# seconds and moves its own region by up to about 1.2, which failed a control
# that was doing its job perfectly well: the companion was moving by 25, so the
# motion being measured was plainly the companion's. The margin that matters is
# the ratio, and 2.0 keeps it above an order of magnitude.
MAX_CONTROL_MOTION = 2.0

# What separates the celebration from the ambient idle that follows it. A
# celebration measured around 18; the idle settle stays under 7. So a step above
# this is the moment itself, not the companion simply being alive.
CELEBRATION_MIN = 10.0

# The longest stretch the companion may hold one frame, in seconds. The
# celebration's hold is 1-2s and the idle it settles into loops, so a real
# settle leaves gaps well under this. Before the defect-41 fix the same
# measurement read 11.2s.
MAX_STILL_RUN_S = 3.0


def adb(*args, timeout=180):
    return subprocess.run([ADB, *args], capture_output=True, text=True,
                          timeout=timeout).stdout


def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/_cb.xml")
    local = os.path.join(BUILD, "_cb.xml")
    subprocess.run([ADB, "pull", "/sdcard/_cb.xml", local],
                   capture_output=True, text=True)
    with open(local, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def nodes(xml):
    """(centre_x, centre_y, label). content-desc first, text as the fallback -
    Flutter writes these labels into content-desc and leaves `text` empty, and a
    single alternation regex matches the empty attribute that comes first."""
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


def tap(x, y, settle=3):
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(settle)


def tap_label(needle, settle=3, xml=None):
    for x, y, label in nodes(xml if xml is not None else dump()):
        if needle in label:
            tap(x, y, settle)
            return True
    return False


def pet_box(xml):
    """The companion's bounds as x0,y0,x1,y1, or None.

    The smallest matching node, not the first. The accessibility tree wraps the
    whole page in a container that also carries the companion's description, so
    taking the first match returned `0,136,1080,2337` - the entire screen. The
    subject region then contained the control region, and the control could not
    possibly be static.
    """
    best = None
    for m in re.finditer(r"<node[^>]*?/?>", xml):
        s = m.group(0)
        d = re.search(r'content-desc="([^"]*)"', s)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        if not (d and b and any(m in d.group(1) for m in PET_MARKERS)):
            continue
        box = tuple(int(g) for g in b.groups())
        w, h = box[2] - box[0], box[3] - box[1]
        # The companion is drawn in a square box. Requiring one is a cheap second
        # guard against a text node that happens to contain a state word.
        if w <= 0 or h <= 0 or not (0.75 <= w / h <= 1.35):
            continue
        area = w * h
        if best is None or area < best[0]:
            best = (area, box)
    return best[1] if best else None


def extract(mp4, dest):
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", mp4,
         "-vf", f"fps={FPS}", os.path.join(dest, "f_%04d.png")],
        check=True)
    return sorted(os.path.join(dest, f) for f in os.listdir(dest)
                  if f.endswith(".png"))


def region(path, box):
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB").crop(box), dtype=np.int16)


def whole(path):
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB").resize((160, 90)), dtype=np.int16)


def guard(settle=40):
    """CozyFocus must be foreground and painted before anything is read or tapped.

    One check at the start of the run is not enough. The emulator reclaims the
    app under memory pressure - the host has 3.3 GB free - and a run that checked
    only at the start navigated straight into `com.goodnight.treehole`, which
    happened to be the next thing in the task list. A dump taken then is another
    app's tree and every coordinate in it is another app's coordinate.

    The cheap check comes first, and `ensure_foreground` is the escalation. It
    always calls `am start`, and `am start` on a session that is already running
    re-shows the resume dialog - so calling it unconditionally on every step put
    the dialog back on screen each iteration and the loop never saw the running
    screen underneath it.
    """
    if foreground() != PKG and ensure_foreground(settle=settle) != PKG:
        return False
    return drawn()


def reach_running():
    """Get to the running focus screen - the one with 提前结束 on it.

    Three states have to be handled, and the first run only handled the last:
    a session may already be running, the resume dialog may be covering it (the
    app was reclaimed mid-session and offered to restore), or the app may be
    sitting on a tab with the bottom nav. Tapping 返回 at a dialog does nothing,
    so a loop that only knew how to go back never got past it.
    """
    for _ in range(10):
        if not guard():
            continue
        xml = dump()
        labels = [l for _x, _y, l in nodes(xml)]
        if any("提前结束" in l for l in labels):
            return True
        if any("已恢复专注状态" in l for l in labels):
            tap_label("稍后再说", settle=4, xml=xml)
            continue
        if any("个标签，共" in l for l in labels):
            tap_label("首页", settle=4, xml=xml)
            tap_label("恢复专注", settle=6)
            tap_label("开始专注", settle=8)
            time.sleep(8)
            continue
        tap_label("返回", settle=3, xml=xml)
    return False


def find_arrival(frames):
    """Where the completion screen has arrived: just after the control stops moving.

    Anchored on the **control region**, not on the whole frame and not on distance
    from the settled appearance. Both of those were tried and both cut the window
    in the wrong place: the page fades in over many small steps, while the
    celebration is a large change confined to the companion - so "far from the
    settled look" is true of the celebration too, and the window opened *after*
    it. Two runs in a row then reported `celebration_played: false` on a
    companion that had plainly celebrated.

    The control is the one region that moves when the page changes and is still
    otherwise, which makes it exactly the right signal - and it is the same
    region the control check uses, so the two cannot disagree about where the
    measurement starts.
    """
    ctrl = [region(p, CONTROL) for p in frames]
    steps = [float(np.abs(ctrl[i] - ctrl[i + 1]).mean())
             for i in range(len(ctrl) - 1)]
    if not steps:
        return 0

    # The page transition is the *largest* control movement, and the arrival is
    # the end of the run it belongs to. Taking "the last frame the control moved
    # at all" was the previous version and it was too literal: the title block
    # keeps twitching by a few tenths of a unit for a while afterwards - enough
    # to cross a 0.5 threshold once - and the arrival was pushed past the
    # celebration, so the gate reported no celebration on a companion that had
    # just celebrated.
    peak = max(steps)
    peak_at = steps.index(peak)
    floor = max(peak * 0.2, MAX_CONTROL_MOTION)
    lo = peak_at
    while lo > 0 and steps[lo - 1] > floor:
        lo -= 1
    hi = peak_at
    while hi < len(steps) - 1 and steps[hi + 1] > floor:
        hi += 1
    # Then past whatever is left of the transition. The run test above uses a
    # fraction of the peak, so the last frame or two of the fade can sit under it
    # and land inside the window - where a control step of 20 would fail the
    # control check for a reason that has nothing to do with the companion.
    while hi < len(steps) - 1 and steps[hi] > MAX_CONTROL_MOTION:
        hi += 1
    return hi + 1


def analyse(frames, box, source):
    """Measure the post-arrival window. Returns the report dict."""
    # Drop the tail of the clip. A screenrecord stops mid-frame, so the last
    # sample is a partial one - it moved the control region by 0.74 all by
    # itself, which was enough to push the settled-window search to the final
    # frame and leave nothing to measure. It is also the anchor frame for the
    # arrival test, so trimming it makes that reading steadier too.
    frames = frames[:len(frames) - max(1, int(0.25 * FPS))]

    start = find_arrival(frames)
    after = frames[start:]
    print(f"{len(frames)} frames at {FPS}fps; control settled at frame {start}; "
          f"measuring {len(after)} frames")

    subj = [region(p, box) for p in after]
    ctrl = [region(p, CONTROL) for p in after]

    steps = [float(np.abs(subj[i] - subj[i + 1]).mean())
             for i in range(len(subj) - 1)]
    ctrl_steps = [float(np.abs(ctrl[i] - ctrl[i + 1]).mean())
                  for i in range(len(ctrl) - 1)]
    first = subj[0]
    from_first = [float(np.abs(f - first).mean()) for f in subj]

    peak = max(steps) if steps else 0.0
    peak_at = steps.index(peak) if steps else -1

    # Motion episodes: runs of moving frames separated by at least three still
    # ones.
    moving = [i for i, s in enumerate(steps) if s > MIN_BURST]
    episodes = 0
    longest_still = 0
    run = 0
    last = None
    for i in moving:
        if last is None or i - last >= 4:
            episodes += 1
        last = i
    # The longest stretch with nothing moving, in seconds - the direct measure of
    # "is the companion frozen".
    #
    # Measured over half a second rather than frame to frame, and that matters:
    # the two renderers move on completely different time scales. A sprite
    # sequence swaps a whole frame at 5-8fps, so consecutive 20fps samples differ
    # a lot; the layered rig breathes slowly and continuously, so consecutive
    # samples differ by almost nothing while the companion is plainly alive.
    # Frame-to-frame made the rig look frozen - it read 3-6s of "stillness" on a
    # companion that was breathing the whole time.
    slow = [float(np.abs(subj[i] - subj[i + SLOW_LAG]).mean())
            for i in range(len(subj) - SLOW_LAG)]
    longest_still = 0
    still = 0
    for s in slow:
        if s > MIN_BURST:
            still = 0
        else:
            still += 1
            longest_still = max(longest_still, still)

    # The celebration, measured as the *window* in which the companion does not
    # yet look settled rather than as a count of large steps.
    #
    # Counting steps conflated two different things: the celebration, and the
    # single frame where the renderer hands over from the celebration sequence to
    # whatever follows. That hand-over is one big frame-to-frame difference and it
    # was being counted as a second celebration - the gate said "two" while the
    # device had celebrated once. Distance from the *settled* appearance separates
    # them cleanly: during the celebration the companion is nowhere near its final
    # look, and after it, it is.
    # The celebration is the opening burst; everything after it should be the
    # settle.
    #
    # Earlier versions tried to locate the celebration by how far the companion
    # was from its settled appearance. That does not work on this screen: the rig
    # breathes, so the settle wanders as far from its own final frame as 12.5,
    # while the celebration reaches 22-25 - and a threshold that separates those
    # on one run merges them on another. The opening/tail split needs no
    # calibration at all: the celebration is at the start by construction, and
    # the question is only whether anything as large happens after it.
    opening_s = 2.0
    cut = int(opening_s * FPS)
    opening = steps[:cut]
    later = steps[cut:]
    window_s = len(subj) / FPS

    checks = {
        # The moment played: a celebration-sized change in the opening seconds.
        "celebration_played": bool(opening) and max(opening) > CELEBRATION_MIN,
        "control_is_static": (max(ctrl_steps) if ctrl_steps else 0.0)
        <= MAX_CONTROL_MOTION,
        # And it played once. A second one is the companion looping its own
        # celebration, which is not a celebration - it is what the device
        # measured as four celebrations in five seconds before the
        # once-per-completion rule.
        "no_further_celebration": (max(later) if later else 0.0)
        <= CELEBRATION_MIN,
        # The settle is alive rather than a held frame.
        "no_long_freeze": longest_still / FPS < MAX_STILL_RUN_S,
    }
    blocking = [k for k, v in checks.items() if not v]

    return {
        "label": "celebrate",
        "source": source,
        "fps": FPS,
        "frames_total": len(frames),
        "arrival_frame": start,
        "frames_measured": len(after),
        "companion_box": list(box),
        "control_box": list(CONTROL),
        "peak_step": round(peak, 3),
        "peak_at_frame": peak_at,
        "peak_at_seconds": round(peak_at / FPS, 3),
        "opening_max_step": round(max(opening) if opening else 0.0, 3),
        "later_max_step": round(max(later) if later else 0.0, 3),
        "window_s": round(window_s, 3),
        "longest_still_run_s": round(longest_still / FPS, 3),
        "subject_steps": [round(s, 3) for s in steps],
        "control_steps": [round(s, 3) for s in ctrl_steps],
        "distance_from_first": [round(d, 3) for d in from_first],
        "thresholds": {"min_burst": MIN_BURST,
                       "celebration_min": CELEBRATION_MIN,
                       "max_control_motion": MAX_CONTROL_MOTION,
                       "max_still_run_s": MAX_STILL_RUN_S},
        "checks": checks,
        "technical_visual_gate": "FAIL" if blocking else "PASS",
        "blocking": blocking,
        "owner_visual_gate": "REQUIRED",
        "note": (
            "celebrateCycle is 1200ms and one-shot. This asserts the moment "
            "plays once and the companion then settles into something alive. "
            "Whether it reads well is OWNER_VISUAL_GATE and is never decided "
            "here."
        ),
    }, start


def run(analyse_only=False):
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)

    local_mp4 = os.path.join(BUILD, "celebrate.mp4")
    box_path = os.path.join(BUILD, "companion_box.json")

    if analyse_only:
        if not os.path.exists(local_mp4):
            print("no recording to analyse", file=sys.stderr)
            return 2
        with open(box_path, encoding="utf-8") as fh:
            box = tuple(json.load(fh))
        frames = extract(local_mp4, os.path.join(BUILD, "frames"))
        return finish(frames, box, local_mp4)

    if not guard(settle=45):
        print("REFUSING: CozyFocus is not foreground and painted",
              file=sys.stderr)
        return 2

    # The whole flow is retried, not just the tap. If the app is reclaimed during
    # a session the session is gone with it, so 提前结束 cannot be found and the
    # only recovery is to start again.
    reached = False
    for attempt in range(3):
        if reach_running():
            reached = True
            break
        print(f"attempt {attempt + 1}: could not reach the running screen",
              file=sys.stderr)
    if not reached:
        print("REFUSING: no running session could be reached", file=sys.stderr)
        for _x, _y, l in nodes(dump())[:14]:
            print("   ", l[:50].replace(chr(10), " "), file=sys.stderr)
        return 2

    # The guard that matters: the session has to still be there, and it has to
    # still be CozyFocus showing it, before the recording starts.
    if not guard():
        print("REFUSING: lost the foreground before recording", file=sys.stderr)
        return 2

    # Recording starts BEFORE the tap that produces the completion screen: the
    # burst begins when the screen appears, so a recording started after arrival
    # has already missed it.
    adb("shell", "rm", "-f", "/sdcard/_celebrate.mp4")
    subprocess.Popen(
        [ADB, "shell", "screenrecord", "--time-limit", str(RECORD_SECONDS),
         "--bit-rate", "6000000", "/sdcard/_celebrate.mp4"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2)

    if not tap_label("提前结束", settle=4):
        print("could not find 提前结束; screen had:", file=sys.stderr)
        for _x, _y, l in nodes(dump())[:14]:
            print("   ", l[:50].replace(chr(10), " "), file=sys.stderr)
        return 2
    # 仍然结束, named in full. Asking for 结束 matched 提前结束 - the button behind
    # the modal is still in the tree - and tapping behind a modal does nothing, so
    # the dialog stayed up for the whole recording and every frame after the
    # arrival cut was the dialog sitting still.
    if not tap_label("仍然结束", settle=4):
        print("no confirmation affirmative; screen had:", file=sys.stderr)
        for _x, _y, l in nodes(dump())[:14]:
            print("   ", l[:50].replace(chr(10), " "), file=sys.stderr)
        return 2

    # Read the companion's bounds NOW, while the app is certainly still
    # foreground. Reading them after the recording finished was wrong: the
    # emulator had reclaimed CozyFocus by then and the dump came back as another
    # app's tree, so the "companion box" was that app's whole screen.
    box = pet_box(dump())
    if not box:
        print("no companion on the completion screen", file=sys.stderr)
        return 2
    print(f"companion box {box}")
    with open(box_path, "w", encoding="utf-8") as fh:
        json.dump(list(box), fh)

    # Let the recording run out; it holds the burst and the settle afterwards.
    time.sleep(RECORD_SECONDS)

    subprocess.run([ADB, "pull", "/sdcard/_celebrate.mp4", local_mp4],
                   capture_output=True, text=True)
    if not os.path.exists(local_mp4):
        print("pull failed", file=sys.stderr)
        return 2
    print(f"recorded {os.path.getsize(local_mp4)} bytes")

    frames = extract(local_mp4, os.path.join(BUILD, "frames"))
    if len(frames) < 20:
        print(f"only {len(frames)} frames extracted", file=sys.stderr)
        return 2
    return finish(frames, box, local_mp4)


def finish(frames, box, local_mp4):
    report, start = analyse(frames, box, os.path.relpath(local_mp4, APP))
    path = os.path.join(OUT, "celebrate_MOTION_REPORT.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)

    # Keep a strip of frames from arrival onwards as the visual evidence.
    strip = frames[start:start + int(2.0 * FPS):2]
    for i, p in enumerate(strip):
        shutil.copy(p, os.path.join(OUT, f"burst_{i:02d}.png"))

    print(json.dumps({k: report[k] for k in
                      ("peak_step", "peak_at_seconds", "opening_max_step",
                       "later_max_step", "longest_still_run_s", "checks",
                       "technical_visual_gate")},
                     indent=2))
    print(f"\nreport: {path}")
    return 0 if report["technical_visual_gate"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(run(analyse_only="--analyze-only" in sys.argv))
