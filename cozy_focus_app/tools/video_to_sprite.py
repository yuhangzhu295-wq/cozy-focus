"""Flow video -> sprite keyframes.

## What this replaces, and what it does not

The pack was built by generating one still per frame: attach a reference, ask
for a pose, download, repeat. That works but it is slow, it costs one generation
per frame, and nothing guarantees the frames belong to one continuous motion.

This tool takes a short **video** of the action and derives the sprite frames
from it, so the motion is real and the frames are samples of it rather than
independent guesses.

It deliberately does **not** re-implement normalisation. Background removal,
canvas placement, baseline alignment and the indexed-PNG write all live in
`tools/productionise.py` and are imported here, so there is exactly one
implementation of the canvas contract and one place to change it.

## What it is not

Not a video player. A 3-second clip at 24 fps is ~72 frames; a sprite action is
6. The tool's job is to choose the ~6 frames that *carry the motion* and throw
the rest away. That selection is the whole point — see `select_keyframes`.

## The canvas contract it must satisfy

Everything the existing gates already assert, because the output is the same
kind of asset:

- 512x512, alpha, character on the ground baseline, centred on the anchor,
  no duplicate frames, a measurable character in every frame.
  See `sprite_animation_asset_integrity_test.dart`.

Usage:
    python tools/video_to_sprite.py --video clip.mp4 --companion dog \\
        --action idle --frames 6 --loop loop
    python tools/video_to_sprite.py --video clip.mp4 --companion dog \\
        --action walk --frames 6 --loop loop --expect-in-place

Add `--qa-only` to re-run the report over frames already staged.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# Reused, not re-implemented: the one normalisation path in this repo.
import productionise as prod  # noqa: E402

APP = prod.APP
STAGE = prod.STAGE            # .asset_staging/flow/<companion>/<action>/
ASSETS = os.path.join(APP, "assets", "companions")  # the real output + contract
CANVAS = prod.CANVAS
SUBJECT_H = prod.SUBJECT_H
BASELINE_Y = prod.BASELINE_Y

# ── QA thresholds ────────────────────────────────────────────────────────────
#
# Every one of these is a *chosen default*, recorded here so it can be argued
# with rather than buried in a comparison. The report prints the measured value
# beside each verdict so a human can overrule the threshold with evidence.

# Sharpness is the variance of a Laplacian response. Absolute values depend on
# the image scale and content, so the gate is relative to the clip's own median:
# a frame less than half as sharp as typical is a motion-blur or transition
# frame, whatever the absolute number.
SHARPNESS_MIN_RATIO = 0.5

# Two frames are "the same picture" when their signatures differ by less than
# this. Calibrated against art that is already approved rather than chosen: the
# closest pair among the dog's six shipped `idle` frames differs by 0.0100, so
# any threshold above that would reject work the project has already accepted.
# 0.005 sits below it with 2x headroom.
DUPLICATE_MAX_DISTANCE = 0.005

# A loop seam is visible when the wrap from last frame to first is much bigger
# than a normal step. The ratio is seam distance / median step distance.
LOOP_SEAM_MAX_RATIO = 2.0
# ...and a seam of ~0 means the last frame is a duplicate of the first, which
# wastes one of the six slots.
LOOP_SEAM_MIN_RATIO = 0.15

# Walk must be animated *in place*: `LocomotionController` owns world position,
# the sprite owns the gait. If the character actually translates across the
# video, the two compose into double displacement. Tolerance is a fraction of
# the character's own width.
IN_PLACE_MAX_DRIFT = 0.10

SIGNATURE_SIZE = 64


# ── ffmpeg / ffprobe ─────────────────────────────────────────────────────────

def _run(cmd):
    """Runs a command, raising with its stderr when it fails."""
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(
            f"{cmd[0]} failed ({p.returncode}):\n{p.stderr.strip()[:2000]}")
    return p.stdout


def ffprobe(path):
    """Returns the first video stream plus format info, or raises."""
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    out = _run(["ffprobe", "-v", "error", "-print_format", "json",
                "-show_streams", "-show_format", path])
    info = json.loads(out)
    streams = [s for s in info.get("streams", [])
               if s.get("codec_type") == "video"]
    if not streams:
        raise RuntimeError(f"{path} has no video stream")
    s = streams[0]
    # ffprobe reports "0/0" for some containers; fall back to the format.
    def _rate(v):
        if not v or v == "0/0":
            return 0.0
        num, _, den = v.partition("/")
        try:
            return float(num) / float(den) if float(den) else 0.0
        except ValueError:
            return 0.0
    fps = _rate(s.get("avg_frame_rate")) or _rate(s.get("r_frame_rate"))
    duration = float(s.get("duration") or info["format"].get("duration") or 0)
    return {
        "codec": s.get("codec_name"),
        "width": int(s["width"]),
        "height": int(s["height"]),
        "fps": round(fps, 3),
        "duration_s": round(duration, 3),
        "nb_frames": int(s.get("nb_frames") or round(fps * duration)),
    }


def extract_frames(video, outdir):
    """Decodes every frame to PNG. Returns the paths in presentation order."""
    os.makedirs(outdir, exist_ok=True)
    _run(["ffmpeg", "-v", "error", "-i", video, "-vsync", "0",
          os.path.join(outdir, "f_%05d.png")])
    paths = sorted(
        os.path.join(outdir, f) for f in os.listdir(outdir) if f.endswith(".png"))
    if not paths:
        raise RuntimeError("ffmpeg produced no frames")
    return paths


# ── measurement ──────────────────────────────────────────────────────────────

def sharpness(img):
    """Variance of the Laplacian response, as a focus measure.

    Higher is sharper. An out-of-focus or motion-smeared frame loses high
    frequencies and this collapses toward zero.
    """
    g = np.asarray(img.convert("L"), dtype=np.float64)
    lap = (-4 * g[1:-1, 1:-1] + g[:-2, 1:-1] + g[2:, 1:-1]
           + g[1:-1, :-2] + g[1:-1, 2:])
    return float(lap.var())


def measure_alpha(img):
    """`productionise.measure`, but on an image whose last band is really alpha.

    The shipped frames are indexed PNGs. `PIL.Image.split()` on an indexed image
    returns the palette *index* band, so `measure`'s `split()[-1]` silently reads
    indices rather than alpha and reports nonsense -- every frame measured
    `bottomY = 511` and the baseline gate failed on correct art. Converting to
    RGBA first makes the last band alpha again.
    """
    return prod.measure(img.convert("RGBA"))


def signature(img):
    """A small grey fingerprint of the *character*, for similarity comparison.

    Cropped to the character's own bounding box before downscaling, and that is
    the whole point. Taken over the full 512x512 frame, a character occupying
    the middle third is swamped by flat background: two visibly different poses
    scored 0.005 apart and the duplicate gate fired on art that was fine. The
    background carries no information about the pose, so it must not be part of
    the measurement.

    Composited on mid-grey rather than white so a transparent margin does not
    read as a bright edge.
    """
    rgba = img.convert("RGBA")
    bb = rgba.getchannel("A").getbbox()
    if bb:
        rgba = rgba.crop(bb)
    flat = Image.new("RGBA", rgba.size, (128, 128, 128, 255))
    flat.alpha_composite(rgba)
    small = flat.convert("L").resize((SIGNATURE_SIZE, SIGNATURE_SIZE),
                                     Image.LANCZOS)
    return np.asarray(small, dtype=np.float64) / 255.0


def signature_distance(a, b):
    """Mean absolute difference between two signatures, in 0..1."""
    return float(np.abs(a - b).mean())


# ── keyframe selection ───────────────────────────────────────────────────────

def select_keyframes(paths, target, loop):
    """Chooses [target] frames that carry the motion.

    The naive choices are both wrong. Taking every Nth frame ignores content and
    happily keeps a blurred transition; taking the sharpest N keeps six frames
    of the same pose, because a held pose is the sharpest thing in the clip.

    So: score every frame, drop the blurred ones, then walk the survivors and
    take the most *novel* frame at each step -- the one furthest from everything
    already chosen. That spreads the picks across the motion instead of
    clustering them where the character happens to be stillest.

    Returns (chosen_indices, rejected) where rejected explains every drop, so a
    short clip reports *why* it could not fill the request rather than silently
    returning fewer frames.
    """
    if not paths:
        raise RuntimeError("no frames to select from")

    images = [Image.open(p) for p in paths]
    sharp = [sharpness(im) for im in images]
    sigs = [signature(im) for im in images]

    # Relative sharpness: a frame much softer than this clip's median.
    median_sharp = float(np.median(sharp))
    rejected = []
    keep = []
    for i, s in enumerate(sharp):
        if median_sharp > 0 and s < median_sharp * SHARPNESS_MIN_RATIO:
            rejected.append({"index": i, "reason": "blurred",
                             "sharpness": round(s, 2),
                             "median": round(median_sharp, 2)})
        else:
            keep.append(i)
    if not keep:
        raise RuntimeError("every frame was rejected as blurred")

    if len(keep) <= target:
        chosen = keep
    else:
        # First pick: the sharpest frame, so the sequence opens on a clean one.
        chosen = [max(keep, key=lambda i: sharp[i])]
        while len(chosen) < target:
            best, best_score = None, -1.0
            for i in keep:
                if i in chosen:
                    continue
                # Novelty: distance from the nearest frame already chosen.
                nearest = min(signature_distance(sigs[i], sigs[c])
                              for c in chosen)
                # ...and a nudge toward even temporal spacing, so a long static
                # stretch cannot absorb every slot.
                span = max(1, len(paths) - 1)
                spread = min(abs(i - c) / span for c in chosen)
                score = nearest + 0.25 * spread
                if score > best_score:
                    best, best_score = i, score
            chosen.append(best)
        chosen.sort()

    # A loop wraps last -> first, so those two must be one step apart. If the
    # first and last picks landed on the same pose the wrap is a wasted frame;
    # if they landed far apart the seam shows.
    if loop and len(chosen) > 2:
        seam = signature_distance(sigs[chosen[-1]], sigs[chosen[0]])
        steps = [signature_distance(sigs[chosen[i]], sigs[chosen[i + 1]])
                 for i in range(len(chosen) - 1)]
        median_step = float(np.median(steps)) if steps else 0.0
        if median_step > 0:
            ratio = seam / median_step
            if ratio > LOOP_SEAM_MAX_RATIO:
                rejected.append({
                    "reason": "loop_seam_too_large", "ratio": round(ratio, 3),
                    "max": LOOP_SEAM_MAX_RATIO,
                    "note": "last frame does not flow back into the first"})
            elif ratio < LOOP_SEAM_MIN_RATIO:
                rejected.append({
                    "reason": "loop_seam_duplicate", "ratio": round(ratio, 3),
                    "min": LOOP_SEAM_MIN_RATIO,
                    "note": "last frame repeats the first; one slot is wasted"})

    return chosen, rejected


# ── staging + normalisation ──────────────────────────────────────────────────

def stage_keyframes(paths, chosen, companion, action):
    """Writes the chosen frames into the existing staging layout.

    Deliberately the same place `productionise.py` already reads from, so the
    normalisation, manifest and gate steps downstream are the existing ones and
    not a second path that could drift.
    """
    dest = os.path.join(STAGE, companion, action)
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)
    written = []
    for n, i in enumerate(chosen):
        out = os.path.join(dest, f"{action}_{n:03d}.png")
        Image.open(paths[i]).convert("RGB").save(out)
        written.append(out)
    return dest, written


# ── QA over the final, normalised frames ─────────────────────────────────────

def load_contract(companion):
    """Reads the anchor contract the integrity tests use.

    Deliberately the same numbers, from the same file. An earlier version of
    this QA compared against `int(CANVAS * BASELINE_Y)` -- a value invented here
    -- and reported a 3px baseline failure on frames that the real gate accepts,
    because the contract declares `groundBaseline: 458` while the constant
    implied 460. A second implementation of the contract is a second thing to
    drift, so this one reads it.
    """
    # Always the real assets directory, never the redirected output root: the
    # contract is an *input* the art must satisfy, so redirecting where output
    # goes must not also move the thing it is measured against.
    path = os.path.join(ASSETS, companion, "animation_manifest.json")
    with open(path, encoding="utf-8") as fh:
        c = json.load(fh)
    canvas = c["canvas"]
    return {
        "canvas": (int(canvas["width"]), int(canvas["height"])),
        "groundBaseline": int(c["groundBaseline"]),
        "centerAnchor": int(c["centerAnchor"]),
        "tolerancePx": int(c["anchorTolerancePx"]),
    }


def in_place_drift(raw_paths):
    """Lateral drift of the character across the RAW clip frames, as a fraction
    of its own width.

    Measured **before** normalisation, and that is not a detail. `normalise`
    re-centres every frame on the anchor, so the normalised output has ~zero
    lateral drift no matter what the clip did. An earlier version of this gate
    measured the normalised frames and reported 0.0016 drift on a clip where the
    character slid 90px across the frame -- a check that could never fire.
    """
    centres, widths = [], []
    for p in raw_paths:
        rgba, _ = prod.extract_alpha(p)
        m = prod.measure(rgba)
        centres.append(m["centerX"])
        widths.append(m["visualWidth"])
    median_w = float(np.median(widths)) if widths else 0.0
    if median_w <= 0:
        return 0.0
    return (max(centres) - min(centres)) / median_w


def qa_frames(frame_paths, loop, expect_in_place, contract, raw_drift=None):
    """Checks the shipped frames against the canvas contract and reports.

    Runs on the *normalised* PNGs rather than the video frames, because those
    are what the app loads: a fault introduced by normalisation must be caught
    here, not assumed away.
    """
    checks = {}
    details = {}

    missing = [p for p in frame_paths if not os.path.exists(p)]
    checks["frames_present"] = not missing
    details["missing"] = missing

    if missing:
        return {"checks": checks, "details": details,
                "verdict": "FAIL", "blocking": ["frames_present"]}

    bounds, sharp, sigs, sizes = [], [], [], []
    for p in frame_paths:
        with Image.open(p) as im:
            sizes.append(im.size)
            bounds.append(measure_alpha(im))
            sharp.append(sharpness(im))
            sigs.append(signature(im))

    # Canvas + alpha. `measure_alpha` reads the alpha channel, so a frame with
    # no alpha measures the whole canvas and the size check below catches it.
    checks["canvas"] = all(s == contract["canvas"] for s in sizes)
    details["sizes"] = [f"{w}x{h}" for w, h in sizes]

    has_alpha = []
    for p in frame_paths:
        with Image.open(p) as im:
            has_alpha.append("A" in im.getbands() or im.mode == "P")
    checks["alpha"] = all(has_alpha)

    # Baseline and centre, against the contract the integrity tests use.
    tol = contract["tolerancePx"]
    drift = [abs(b["bottomY"] - contract["groundBaseline"]) for b in bounds]
    checks["baseline"] = all(d <= tol for d in drift)
    details["baseline_drift_px"] = drift
    details["ground_baseline"] = contract["groundBaseline"]
    details["tolerance_px"] = tol

    centre_off = [abs(b["centerX"] - contract["centerAnchor"]) for b in bounds]
    checks["centred"] = all(o <= tol for o in centre_off)
    details["centre_offset_px"] = [round(o, 1) for o in centre_off]
    details["center_anchor"] = contract["centerAnchor"]

    # A measurable character: a blank frame is not art.
    checks["has_character"] = all(
        b["visualWidth"] > 0 and b["visualHeight"] > 0 for b in bounds)

    # Duplicates.
    dupes = []
    for i in range(len(sigs)):
        for j in range(i + 1, len(sigs)):
            d = signature_distance(sigs[i], sigs[j])
            if d < DUPLICATE_MAX_DISTANCE:
                dupes.append({"a": i, "b": j, "distance": round(d, 4)})
    checks["no_duplicates"] = not dupes
    details["duplicates"] = dupes

    # Sharpness, relative to this action's own median.
    median_sharp = float(np.median(sharp))
    soft = [i for i, s in enumerate(sharp)
            if median_sharp > 0 and s < median_sharp * SHARPNESS_MIN_RATIO]
    checks["sharp"] = not soft
    details["sharpness"] = [round(s, 1) for s in sharp]
    details["soft_frames"] = soft

    if loop:
        seam = signature_distance(sigs[-1], sigs[0])
        steps = [signature_distance(sigs[i], sigs[i + 1])
                 for i in range(len(sigs) - 1)]
        median_step = float(np.median(steps)) if steps else 0.0
        ratio = (seam / median_step) if median_step > 0 else 0.0
        checks["loop_seam"] = LOOP_SEAM_MIN_RATIO <= ratio <= LOOP_SEAM_MAX_RATIO
        details["loop_seam_ratio"] = round(ratio, 3)

    if expect_in_place:
        # Walk must not translate inside the frame: LocomotionController owns
        # world position, so drift here would compose into double displacement.
        # The value comes from the raw clip frames -- see `in_place_drift`.
        drift_frac = float(raw_drift or 0.0)
        checks["in_place"] = drift_frac <= IN_PLACE_MAX_DRIFT
        details["lateral_drift_fraction"] = round(drift_frac, 4)
        details["in_place_max"] = IN_PLACE_MAX_DRIFT
        details["in_place_measured_on"] = "raw clip frames (pre-normalisation)"

    blocking = [k for k, v in checks.items() if not v]
    return {"checks": checks, "details": details,
            "verdict": "FAIL" if blocking else "PASS", "blocking": blocking}


# ── orchestration ────────────────────────────────────────────────────────────

def run(video, companion, action, target, loop_mode, expect_in_place,
        keep_temp=False, out_root=None):
    """Runs the whole chain and returns the report.

    [out_root] redirects the normalised output. It exists so the pipeline can be
    validated end to end -- and deliberately sabotaged, for the negative checks --
    without touching the approved art in `assets/companions/`. The default is the
    real output directory, which is what production runs want.
    """
    report = {"companion": companion, "action": action,
              "video": os.path.basename(video),
              "requested_frames": target, "loop_mode": loop_mode}

    info = ffprobe(video)
    report["source"] = info
    if info["width"] < 256 or info["height"] < 256:
        report["verdict"] = "FAIL"
        report["error"] = f"source is {info['width']}x{info['height']}; too small to sample"
        return report

    tmp = tempfile.mkdtemp(prefix="v2s_")
    original_prod = prod.PROD
    try:
        frames = extract_frames(video, tmp)
        report["decoded_frames"] = len(frames)

        chosen, rejected = select_keyframes(frames, target, loop_mode == "loop")
        report["selected_indices"] = chosen
        report["selection_notes"] = rejected

        dest, staged = stage_keyframes(frames, chosen, companion, action)
        report["staged_dir"] = os.path.relpath(dest, APP)

        # Hand off to the existing pipeline for normalisation: one
        # implementation of the canvas contract, shared with the still pipeline.
        if out_root:
            prod.PROD = os.path.abspath(out_root)
        report["output_root"] = os.path.relpath(prod.PROD, APP) \
            if prod.PROD.startswith(APP) else prod.PROD
        prod.productionise(companion)

        final = [os.path.join(prod.PROD, companion, f"{action}_{i:03d}.png")
                 for i in range(len(chosen))]
        report["final_frames"] = [os.path.basename(p) for p in final]

        raw_drift = in_place_drift(staged) if expect_in_place else None
        qa = qa_frames(final, loop_mode == "loop", expect_in_place,
                       load_contract(companion), raw_drift)
        report["qa"] = qa
        report["verdict"] = qa["verdict"]

        qa_path = os.path.join(prod.PROD, companion, f"{action}_QA_REPORT.json")
        with open(qa_path, "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2, ensure_ascii=False)
        report["qa_report"] = qa_path
        return report
    finally:
        prod.PROD = original_prod
        if not keep_temp:
            shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--video", required=True)
    ap.add_argument("--companion", required=True)
    ap.add_argument("--action", required=True)
    ap.add_argument("--frames", type=int, default=6)
    ap.add_argument("--loop", default="loop", choices=["loop", "once", "pingpong"])
    ap.add_argument("--expect-in-place", action="store_true",
                    help="fail if the character translates across the frame "
                         "(required for walk)")
    ap.add_argument("--out-root", default=None,
                    help="write normalised frames here instead of "
                         "assets/companions/ (used to validate without touching "
                         "approved art)")
    ap.add_argument("--keep-temp", action="store_true")
    a = ap.parse_args()

    rep = run(a.video, a.companion, a.action, a.frames, a.loop,
              a.expect_in_place, a.keep_temp, a.out_root)
    print(json.dumps(rep, indent=2, ensure_ascii=False))
    return 0 if rep.get("verdict") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
