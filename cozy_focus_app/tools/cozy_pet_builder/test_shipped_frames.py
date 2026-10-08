"""Measure every shipped frame against the builder's admission rule.

`build.py` refuses a frame whose sharpness is below half the median of its own
action, which is how it catches a motion-blur or interpolated frame. Four of the
147 shipped frames do not pass it:

    dog/stand_up_000.png      2582 against a median of 5900   (44%)
    dog/tap_react_002.png     2481 against a median of 5272   (47%)
    rabbit/celebrate_000.png  2225 against a median of 5696   (39%)
    rabbit/celebrate_002.png  2090 against a median of 5696   (37%)

They are recorded rather than fixed - replacing a frame is artwork, and
placeholder art is out of bounds - so this is a **ratchet, not an approval**. It
exists so the list cannot grow unnoticed: a fifth soft frame, or a shipped pack
whose art is regenerated softer, fails here rather than being discovered by
whoever tries to rebuild that pack and is refused.

Run: `python tools/cozy_pet_builder/test_shipped_frames.py`
"""

import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
APP = HERE.parent.parent
sys.path.insert(0, str(APP / "tools"))
sys.path.insert(0, str(HERE))

import video_to_sprite as v2s  # noqa: E402
from PIL import Image  # noqa: E402

PACKS = ("dog", "cat", "rabbit")

# frame -> sharpness as a fraction of its action's median, rounded to a percent.
KNOWN_SOFT = {
    "dog/stand_up/stand_up_000.png": 44,
    "dog/tap_react/tap_react_002.png": 47,
    "rabbit/celebrate/celebrate_000.png": 39,
    "rabbit/celebrate/celebrate_002.png": 37,
}


def measure():
    """Every frame below the floor, as `pack/action/frame.png` -> percent."""
    below = {}
    measured = 0
    for pack in PACKS:
        directory = APP / "assets" / "companions" / pack
        manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
        for action, spec in manifest["actions"].items():
            values = []
            for name in spec["frames"]:
                with Image.open(directory / name) as raw:
                    values.append((name, v2s.sharpness(raw.convert("RGBA"))))
            measured += len(values)
            median = sorted(v for _, v in values)[len(values) // 2]
            floor = median * v2s.SHARPNESS_MIN_RATIO
            for name, value in values:
                if value < floor:
                    below["%s/%s/%s" % (pack, action, name)] = round(
                        100 * value / median
                    )
    return below, measured


def main():
    below, measured = measure()
    failures = []

    if measured == 0:
        failures.append("no frames were measured, so this proves nothing")
    elif measured < 100:
        failures.append("only %d frames measured; the packs look incomplete" % measured)

    for frame, percent in sorted(below.items()):
        if frame not in KNOWN_SOFT:
            failures.append(
                "%s is newly below the builder's floor (%d%% of its action's "
                "median). Either fix the frame or add it to KNOWN_SOFT with a "
                "reason." % (frame, percent)
            )
        elif abs(KNOWN_SOFT[frame] - percent) > 5:
            failures.append(
                "%s measures %d%% now and was recorded at %d%%; the art changed."
                % (frame, percent, KNOWN_SOFT[frame])
            )

    for frame in sorted(KNOWN_SOFT):
        if frame not in below:
            failures.append(
                "%s is no longer below the floor - the list is stale, remove it."
                % frame
            )

    if failures:
        print("FAIL: the shipped art moved against the builder's rule")
        for line in failures:
            print("  " + line)
        return 1

    print("OK: %d shipped frames measured, %d known-soft, none new"
          % (measured, len(below)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
