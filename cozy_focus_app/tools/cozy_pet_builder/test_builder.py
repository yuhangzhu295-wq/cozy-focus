"""Negative proofs for the pack builder.

Run: python tools/cozy_pet_builder/test_builder.py

## Why refusals are the thing to prove

A builder that produces a pack from good input is the easy half. What matters is
that it *refuses* the inputs that would produce a pack the app cannot use, or one
that lies about itself - and that it refuses them rather than quietly repairing
them.

The load-bearing one is the geometry proof. `tools/manifest.py` used to derive a
pack's expected anchors from the mean of the frames it had just measured, so a
uniformly drifted set had a manifest and images that agreed with each other while
both were wrong. The fix is that expected geometry comes from a declared contract.
**Uniformly shifting every frame by 40px must still fail** - if it passes, the
contract is being derived from the frames again and this file is decoration.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
sys.path.insert(0, HERE)

import build as builder  # noqa: E402  (path set up above)

ASSETS = os.path.join(ROOT, "assets", "companions")


def source_frames(companion, actions, out_dir, shift=(0, 0), duplicate=False):
    """Copies a shipped pack's frames into a builder input directory.

    [shift] moves every frame by the same amount, which is the sabotage the
    geometry proof needs. [duplicate] replaces every frame after the first with a
    copy of the first, which is the frozen-sprite case.
    """
    manifest = json.load(open(os.path.join(ASSETS, companion, "manifest.json"),
                              encoding="utf-8"))
    for action in actions:
        directory = os.path.join(out_dir, action)
        os.makedirs(directory, exist_ok=True)
        first = None
        for index, frame in enumerate(manifest["actions"][action]["frames"]):
            with Image.open(os.path.join(ASSETS, companion, frame)) as image:
                rgba = image.convert("RGBA")
            if duplicate:
                if first is None:
                    first = rgba
                rgba = first
            if shift != (0, 0):
                moved = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
                moved.paste(rgba, shift)
                rgba = moved
            rgba.save(os.path.join(directory, f"{index:03d}.png"))
    return out_dir


def run_builder(input_dir, pack_id="mimi", species="cat", output=None,
                extra=()):
    """Runs the builder in-process and returns (exit_code, message)."""
    args = [
        "--input", input_dir,
        "--pack-id", pack_id,
        "--name", "咪咪",
        "--species", species,
        "--output", output or os.path.join(input_dir, "..", "out.cozy_pet"),
        *extra,
    ]
    try:
        builder.build(builder.argparse.Namespace(
            input=input_dir, pack_id=pack_id, name="咪咪", species=species,
            output=args[args.index("--output") + 1],
            frames=None, fallbacks=None,
            fallback_to_idle="--fallback-to-idle" in extra,
            source_kind="test_video",
        ))
        return 0, "built"
    except builder.BuildRefused as error:
        return 1, str(error)


def expect_refusal(label, input_dir, needle=None, **kwargs):
    code, message = run_builder(input_dir, **kwargs)
    assert code != 0, f"{label}: the builder accepted it, and it must not"
    if needle:
        assert needle in message, (
            f"{label}: refused, but for the wrong reason - expected {needle!r} "
            f"in {message!r}")
    print(f"  refused: {label}")
    return message


def main():
    work = tempfile.mkdtemp(prefix="cozy_pet_builder_test_")
    failures = []
    try:
        # ── the pack that must build ─────────────────────────────────────────
        good = source_frames("cat", ["idle", "walk"],
                             os.path.join(work, "good"))
        output = os.path.join(work, "good.cozy_pet")
        code, message = run_builder(good, output=output,
                                    extra=["--fallback-to-idle"])
        assert code == 0, f"a valid partial pack was refused: {message}"
        assert os.path.exists(output)
        print("  built: a valid two-action pack")

        # ── THE load-bearing proof ──────────────────────────────────────────
        shifted = source_frames("cat", ["idle", "walk"],
                                os.path.join(work, "shifted"), shift=(40, 40))
        message = expect_refusal("every frame shifted by 40px", shifted,
                                 needle="groundBaseline")
        assert "40px" in message or "off by" in message, (
            f"the refusal should name the deviation, got: {message}")
        print(f"    -> {message.splitlines()[-1].strip()}")

        # ── the rest of the refusals ────────────────────────────────────────
        expect_refusal(
            "every frame after the first is a copy of it",
            source_frames("cat", ["idle"], os.path.join(work, "dup"),
                          duplicate=True),
            needle="same picture")

        single = os.path.join(work, "single", "idle")
        os.makedirs(single, exist_ok=True)
        shutil.copy(os.path.join(good, "idle", "000.png"),
                    os.path.join(single, "000.png"))
        expect_refusal("an action with one frame", os.path.join(work, "single"),
                       needle="still image")

        unpadded = source_frames("cat", ["idle"], os.path.join(work, "unpadded"))
        os.rename(os.path.join(unpadded, "idle", "000.png"),
                  os.path.join(unpadded, "idle", "0.png"))
        expect_refusal("unpadded frame names", unpadded, needle="zero-padded")

        notpng = source_frames("cat", ["idle"], os.path.join(work, "notpng"))
        with open(os.path.join(notpng, "idle", "001.png"), "wb") as fh:
            fh.write(b"this is not a PNG")
        expect_refusal("a frame that is not a PNG", notpng, needle="not a PNG")

        invented = source_frames("cat", ["idle"], os.path.join(work, "invented"))
        os.makedirs(os.path.join(invented, "backflip"), exist_ok=True)
        shutil.copy(os.path.join(invented, "idle", "000.png"),
                    os.path.join(invented, "backflip", "000.png"))
        shutil.copy(os.path.join(invented, "idle", "001.png"),
                    os.path.join(invented, "backflip", "001.png"))
        expect_refusal("an action name the app does not know", invented,
                       needle="not an action the app knows")

        no_idle = source_frames("cat", ["walk"], os.path.join(work, "noidle"))
        expect_refusal("no idle action", no_idle, needle="idle")

        expect_refusal("a built-in pack id", good, pack_id="cat",
                       needle="built-in")
        expect_refusal("an id that could escape the pack root", good,
                       pack_id="../evil", needle="directory name")

        wrong_canvas = source_frames("cat", ["idle"],
                                     os.path.join(work, "small"))
        for name in sorted(os.listdir(os.path.join(wrong_canvas, "idle"))):
            path = os.path.join(wrong_canvas, "idle", name)
            with Image.open(path) as image:
                image.convert("RGBA").crop((0, 0, 256, 256)).save(path)
        expect_refusal("frames that are not on the declared canvas",
                       wrong_canvas, needle="canvas")

        code, message = run_builder(
            good, output=os.path.join(work, "fb.cozy_pet"),
            extra=[])
        assert code == 0, "the same pack without fallbacks must still build"

        args = builder.argparse.Namespace(
            input=good, pack_id="mimi", name="咪咪", species="cat",
            output=os.path.join(work, "fb.cozy_pet"), frames=None,
            fallbacks=json.dumps({"sleep": "celebrate"}), fallback_to_idle=False,
            source_kind="test_video")
        try:
            builder.build(args)
        except builder.BuildRefused as error:
            assert "cannot keep" in str(error), str(error)
            print("  refused: a fallback pointing at an action the pack lacks")
        else:
            raise AssertionError(
                "a fallback pointing at an action the pack does not ship was "
                "accepted, and the importer would refuse the result")

        print("OK: the builder refuses every input that would make a bad pack")
    except AssertionError as error:
        failures.append(str(error))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
