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

# A burst is a *group* of large steps close together in time, not one. The
# renderer swaps from the celebration sequence back to the ambient pose in a
# single frame, and that hand-over is one of the largest single differences in
# the clip (20-25 against a celebration of 13-25). A sprite sequence runs at
# 5-8fps, so at a 16-60fps capture its swaps are *isolated* large steps too -
# requiring consecutive moving samples would miss the sequence entirely and
# mistake the hand-over for it. What separates them is repetition: a sequence
# produces several large steps within a second, a hand-over produces one.
BURST_MIN_STEPS = 2
BURST_MAX_GAP_S = 0.5

# A burst that starts later than this after the page arrives is not the moment
# the completion screen triggers.
CELEBRATION_WINDOW_S = 1.5

# The recording must resolve the inside of the burst. `screenrecord` on this
# emulator stalls for up to 1.3s (measured), and a stall inside the burst means
# the clip shows the start and the end but not the frames between - so the
# animation is not verified even though it plainly began.
CAPTURE_GAP_S = 0.5


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
    """Tap the node whose label contains `needle`, preferring a clickable one.

    ## Why clickable first

    Container nodes carry the same text as the control inside them - the
    acquisition sheet's whole card reads `... 开始制作 ... 制作工坊 ... 需要专注
    30 分钟 ... 材料需求 ...` in one content-desc, and the real button is a
    separate node whose label is just `开始制作`. Taking the first text match
    taps the card, which is not clickable, and nothing happens - which reads
    exactly like a dead button. The same trap `pet_box` documents for the
    companion: a wrapper that also carries the subject's description.

    Falls back to any matching node only when nothing is clickable, so a label
    that genuinely has no clickable target still resolves rather than silently
    failing.
    """
    tree = xml if xml is not None else dump()
    matches = nodes(tree)
    hit = None
    for x, y, label in matches:
        if needle not in label:
            continue
        if _is_clickable(tree, x, y, label):
            tap(x, y, settle)
            return True
        if hit is None:
            hit = (x, y)
    if hit is not None:
        tap(hit[0], hit[1], settle)
        return True
    return False


def _is_clickable(xml, cx, cy, label):
    """Whether the node at (cx, cy) with this label is itself clickable."""
    for m in re.finditer(r"<node[^>]*?/?>", xml):
        s = m.group(0)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        d = re.search(r'content-desc="([^"]*)"', s)
        if not (b and d):
            continue
        x1, y1, x2, y2 = (int(g) for g in b.groups())
        if (x1 + x2) // 2 != cx or (y1 + y2) // 2 != cy:
            continue
        if label not in d.group(1):
            continue
        c = re.search(r'clickable="([^"]*)"', s)
        return c is not None and c.group(1) == "true"
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


def frame_times(mp4):
    """The recording's own presentation timestamps, in seconds.

    ## Why not count samples at 20fps

    `-vf fps=20` does not make the device record 20 frames a second; it
    duplicates the frames it has. The celebrate clip holds 132 real frames over
    15.96s - about 8fps, with a 1.29s stall in the middle - so a 20fps
    extraction is 315 images of which more than half are copies. Counting
    stillness or motion on those copies invents a timebase the device never
    delivered. This reads the timestamps the encoder actually wrote.
    """
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "frame=pts_time", "-of", "csv=p=0", mp4],
        capture_output=True, text=True)
    times = []
    for line in out.stdout.splitlines():
        try:
            times.append(float(line.strip().rstrip(",")))
        except ValueError:
            continue
    return sorted(times)


def extract(mp4, dest):
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)
    # Passthrough: one PNG per recorded frame, no duplication. The image2
    # muxer warns about non-monotonic dts because screenrecord writes a few
    # frames at the same timestamp; that is harmless here and the count still
    # matches the probe.
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", mp4,
         "-fps_mode", "passthrough", os.path.join(dest, "f_%04d.png")],
        check=True)
    frames = sorted(os.path.join(dest, f) for f in os.listdir(dest)
                    if f.endswith(".png"))
    times = frame_times(mp4)
    if len(times) != len(frames):
        # A mismatch means the two readings disagree about the clip; fall back
        # to an even spread but keep the flag so the report cannot present it as
        # native timing.
        step = (times[-1] - times[0]) / max(1, len(frames) - 1) if times else 0
        times = [i * step for i in range(len(frames))]
        print(f"WARNING: {len(frames)} frames but {len(times)} timestamps; "
              "using an even spread", file=sys.stderr)
        return frames, times, False
    return frames, times, True


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


def selftest():
    """The burst classifier's own cases. A gate that cannot be shown to fail
    proves nothing."""
    def series(marks, n=200, dt=1 / 60):
        steps = [0.0] * n
        for i in marks:
            steps[i] = 20.0
        return steps, [dt] * n

    cases = [
        # A 5fps sprite sampled at 60fps: one large step every 12 frames.
        ("sprite sequence at 5fps", [10, 22, 34, 46, 58, 70], 1),
        # One frame swapped back to the ambient pose.
        ("single handover", [10], 0),
        # Two sequences a second apart are two celebrations, not one.
        ("sequence, then another", [10, 22, 34, 110, 122, 134], 2),
        # Two isolated steps 0.6s apart are not a sequence.
        ("isolated steps apart", [10, 46], 0),
        # A sequence with the hand-over adjacent stays one burst.
        ("sequence plus adjacent handover", [10, 22, 34, 46], 1),
    ]
    failed = 0
    for name, marks, want in cases:
        steps, dts = series(marks)
        got = len(find_bursts(steps, dts, CELEBRATION_MIN))
        ok = got == want
        print(f"{'PASS' if ok else 'FAIL'} {name}: got {got}, want {want}")
        if not ok:
            failed += 1
    return 1 if failed else 0


def display_size():
    out = adb("shell", "wm", "size")
    m = re.search(r"(\d+)x(\d+)", out)
    return (int(m.group(1)), int(m.group(2))) if m else (1080, 2400)


def scale_box(box, scale):
    return tuple(int(round(v * scale)) for v in box)


def find_arrival(frames, control=CONTROL):
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
    ctrl = [region(p, control) for p in frames]
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


def find_bursts(steps, dts, threshold, min_steps=BURST_MIN_STEPS,
                max_gap_s=BURST_MAX_GAP_S):
    """Groups of at least `min_steps` large steps, each group within
    `max_gap_s` of the next.

    `dts[i]` is the time between frame i and frame i+1, so it is the duration
    of step i. The gap between two steps is the time between the end of the
    earlier one and the start of the later one.
    """
    big = [i for i, s in enumerate(steps) if s > threshold]
    groups = []
    cur = []
    for i in big:
        if cur:
            gap = sum(dts[cur[-1] + 1:i])
            if gap > max_gap_s:
                groups.append(cur)
                cur = []
        cur.append(i)
    if cur:
        groups.append(cur)
    return [g for g in groups if len(g) >= min_steps]


def analyse(frames, times, box, source, native_timing=True, control=CONTROL):
    """Measure the post-arrival window. Returns the report dict and the cut."""
    # Drop the final frame: a screenrecord stops mid-frame, so it is partial.
    # It is also the anchor frame for the arrival test, so trimming it makes
    # that reading steadier too.
    frames = frames[:-1]
    times = times[:-1]

    start = find_arrival(frames, control)
    after = frames[start:]
    t0 = times[start]
    aft = [t - t0 for t in times[start:]]
    print(f"{len(frames)} recorded frames over {times[-1] - times[0]:.2f}s; "
          f"arrival at frame {start} ({t0 - times[0]:.2f}s into the clip); "
          f"measuring {len(after)} frames / {aft[-1]:.2f}s")

    subj = [region(p, box) for p in after]
    ctrl = [region(p, CONTROL) for p in after]

    steps = [float(np.abs(subj[i] - subj[i + 1]).mean())
             for i in range(len(subj) - 1)]
    ctrl_steps = [float(np.abs(ctrl[i] - ctrl[i + 1]).mean())
                  for i in range(len(ctrl) - 1)]
    dts = [aft[i + 1] - aft[i] for i in range(len(aft) - 1)]
    first = subj[0]
    from_first = [float(np.abs(f - first).mean()) for f in subj]

    # The celebration is the opening burst, and a burst is a *run* of moving
    # samples. Everything after it should be the settle; the renderer hand-over
    # is a single frame swap and does not qualify.
    bursts = find_bursts(steps, dts, CELEBRATION_MIN)
    first_burst = bursts[0] if bursts else None
    if first_burst:
        lo, hi = first_burst[0], first_burst[-1]
        burst_start_s = aft[lo]
        # The last step of the group ends at frame `hi + 1`.
        burst_span_s = aft[hi + 1] - aft[lo]
        burst_gap_s = max(dts[lo:hi + 1])
        celebration_step = max(steps[i] for i in first_burst)
        celebration_at_s = aft[first_burst[
            [steps[i] for i in first_burst].index(celebration_step)] + 1]
    else:
        burst_start_s = burst_span_s = burst_gap_s = celebration_step = None
        celebration_at_s = None

    in_burst = set()
    for group in bursts:
        in_burst.update(group)
    handover_step = max([s for i, s in enumerate(steps)
                         if i not in in_burst] or [0.0])

    # Half-second lag: the sprite swaps whole frames at 5-8fps while the rig
    # breathes slowly, so a frame-to-frame test made the rig look frozen. A
    # frame counts as "still" when it has not changed by MIN_BURST against the
    # frame at least SLOW_LAG_S earlier.
    slow = []
    for i in range(len(aft)):
        j = i
        while j < len(aft) and aft[j] - aft[i] < SLOW_LAG_S:
            j += 1
        if j < len(aft):
            slow.append((i, j, float(np.abs(subj[j] - subj[i]).mean())))

    longest_still = 0.0
    still_from = None
    for i, j, d in slow:
        if d > MIN_BURST:
            still_from = None
        else:
            if still_from is None:
                still_from = i
            longest_still = max(longest_still, aft[j] - aft[still_from])

    # The raw frame-to-frame hold, reported separately: it is what the encoder
    # saw, but it overstates a freeze on the slowly breathing rig.
    longest_hold = 0.0
    hold = 0.0
    for i, s in enumerate(steps):
        if s > MIN_BURST:
            hold = 0.0
        else:
            hold += dts[i]
            longest_hold = max(longest_hold, hold)

    window_s = aft[-1]
    raw_gaps = [b - a for a, b in zip(times, times[1:])]
    raw_max_gap = max(raw_gaps) if raw_gaps else 0.0

    checks = {
        # The moment played: a burst that starts as the screen arrives.
        "celebration_played": (first_burst is not None and
                               burst_start_s <= CELEBRATION_WINDOW_S),
        "control_is_static": (max(ctrl_steps) if ctrl_steps else 0.0)
        <= MAX_CONTROL_MOTION,
        # And it played once. A second burst is the companion looping its own
        # celebration, which is not a celebration - it is what the device
        # measured as four celebrations in five seconds before the
        # once-per-completion rule.
        "no_further_celebration": len(bursts) <= 1,
        # The settle is alive rather than a held frame.
        "no_long_freeze": longest_still < MAX_STILL_RUN_S,
    }
    blocking = [k for k, v in checks.items() if not v]

    # Whether the clip can support the claim at all. A stall inside the burst
    # leaves the animation's interior unrecorded: the start and the end are
    # visible, the frames between are not.
    burst_interior_resolved = (first_burst is not None and
                               burst_gap_s <= CAPTURE_GAP_S)

    return {
        "label": "celebrate",
        "source": source,
        "frames_measured": len(after),
        "arrival_frame": start,
        "companion_box": list(box),
        "control_box": list(control),
        "native_timing": native_timing,
        "raw_frames": len(frames),
        "raw_duration_s": round(times[-1] - times[0], 3),
        "raw_max_gap_s": round(raw_max_gap, 3),
        "burst_count": len(bursts),
        "bursts_s": [[round(aft[g[0]], 3), round(aft[g[-1] + 1], 3)]
                     for g in bursts],
        "burst_max_step": round(celebration_step, 3)
        if celebration_step is not None else None,
        "burst_max_at_s": round(celebration_at_s, 3)
        if celebration_at_s is not None else None,
        "burst_span_s": round(burst_span_s, 3) if burst_span_s is not None else None,
        "burst_gap_s": round(burst_gap_s, 3) if burst_gap_s is not None else None,
        "burst_interior_resolved": burst_interior_resolved,
        "largest_step_outside_burst": round(handover_step, 3),
        "window_s": round(window_s, 3),
        "longest_still_run_s": round(longest_still, 3),
        "longest_hold_run_s": round(longest_hold, 3),
        "subject_steps": [round(s, 3) for s in steps],
        "subject_dts": [round(d, 3) for d in dts],
        "control_steps": [round(s, 3) for s in ctrl_steps],
        "distance_from_first": [round(d, 3) for d in from_first],
        "slow_lag_steps": [round(d, 3) for _i, _j, d in slow],
        "thresholds": {"min_burst": MIN_BURST,
                       "celebration_min": CELEBRATION_MIN,
                       "burst_min_steps": BURST_MIN_STEPS,
                       "celebration_window_s": CELEBRATION_WINDOW_S,
                       "capture_gap_s": CAPTURE_GAP_S,
                       "max_control_motion": MAX_CONTROL_MOTION,
                       "max_still_run_s": MAX_STILL_RUN_S},
        "checks": checks,
        "capture_blocking": ([] if burst_interior_resolved
                             else ["burst_interior_not_captured"]),
        "technical_visual_gate": ("FAIL" if blocking else
                                  ("BLOCKED" if not burst_interior_resolved
                                   else "PASS")),
        "blocking": blocking,
        "owner_visual_gate": "REQUIRED",
        "note": (
            "celebrateCycle is 1200ms and one-shot. This asserts the moment "
            "plays once and the companion then settles into something alive. "
            "Whether it reads well is OWNER_VISUAL_GATE and is never decided "
            "here. A burst is at least two consecutive moving samples, so the "
            "single-frame hand-over back to the ambient pose is not counted as "
            "a second celebration. The gate is BLOCKED, not PASS, when the "
            "recording stalls inside the burst: the clip then shows the start "
            "and the end but not the frames between."
        ),
    }, start


def run(analyse_only=False):
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)

    local_mp4 = os.path.join(BUILD, "celebrate.mp4")
    box_path = os.path.join(BUILD, "companion_box.json")

    # A smaller recording is the only lever on the encoder stall. `screenrecord`
    # drops 0.75-1.3s exactly as the completion screen appears, which is inside
    # the burst; encoding fewer pixels is cheaper, so `--size 720x1600` may get
    # through it. The boxes are in device pixels, so they scale with the clip.
    size = None
    for i, a in enumerate(sys.argv):
        if a == "--size" and i + 1 < len(sys.argv):
            size = sys.argv[i + 1]
        elif a.startswith("--size="):
            size = a.split("=", 1)[1]
    base_w, _ = display_size()
    scale = 1.0
    if size:
        scale = int(size.lower().split("x")[0]) / base_w

    if analyse_only:
        if not os.path.exists(local_mp4):
            print("no recording to analyse", file=sys.stderr)
            return 2
        with open(box_path, encoding="utf-8") as fh:
            saved = json.load(fh)
        if isinstance(saved, dict):
            box = tuple(saved["box"])
            scale = saved.get("scale", 1.0)
        else:
            box = tuple(saved)
        frames, times, native = extract(local_mp4, os.path.join(BUILD, "frames"))
        return finish(frames, times, box, local_mp4, native, scale)

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
    record = [ADB, "shell", "screenrecord", "--time-limit", str(RECORD_SECONDS),
              "--bit-rate", "6000000"]
    if size:
        record += ["--size", size]
    subprocess.Popen(record + ["/sdcard/_celebrate.mp4"],
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
    print(f"companion box {box} (record scale {scale:.3f})")
    with open(box_path, "w", encoding="utf-8") as fh:
        json.dump({"box": list(scale_box(box, scale)), "scale": scale}, fh)

    # Let the recording run out; it holds the burst and the settle afterwards.
    time.sleep(RECORD_SECONDS)

    subprocess.run([ADB, "pull", "/sdcard/_celebrate.mp4", local_mp4],
                   capture_output=True, text=True)
    if not os.path.exists(local_mp4):
        print("pull failed", file=sys.stderr)
        return 2
    print(f"recorded {os.path.getsize(local_mp4)} bytes")

    frames, times, native = extract(local_mp4, os.path.join(BUILD, "frames"))
    if len(frames) < 20:
        print(f"only {len(frames)} frames extracted", file=sys.stderr)
        return 2
    return finish(frames, times, scale_box(box, scale), local_mp4, native,
                  scale)


def finish(frames, times, box, local_mp4, native_timing=True, scale=1.0):
    control = scale_box(CONTROL, scale)
    report, start = analyse(frames, times, box,
                            os.path.relpath(local_mp4, APP), native_timing,
                            control)
    report["record_scale"] = round(scale, 3)
    path = os.path.join(OUT, "celebrate_MOTION_REPORT.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)

    # Keep a strip of frames from arrival onwards as the visual evidence.
    strip = frames[start:start + 16:2]
    for i, p in enumerate(strip):
        shutil.copy(p, os.path.join(OUT, f"burst_{i:02d}.png"))

    print(json.dumps({k: report[k] for k in
                      ("raw_frames", "raw_duration_s", "raw_max_gap_s",
                       "burst_count", "bursts_s", "burst_max_step",
                       "burst_max_at_s", "largest_step_outside_burst",
                       "burst_interior_resolved", "longest_still_run_s",
                       "longest_hold_run_s", "checks",
                       "technical_visual_gate")},
                     indent=2))
    print(f"\nreport: {path}")
    return 0 if report["technical_visual_gate"] == "PASS" else 1


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    sys.exit(run(analyse_only="--analyze-only" in sys.argv))
