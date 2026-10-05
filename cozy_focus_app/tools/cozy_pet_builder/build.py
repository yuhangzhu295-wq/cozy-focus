"""Build a `.cozy_pet` from action videos or sprite frame directories.

Run:

    python tools/cozy_pet_builder/build.py \
      --input ./pet_source \
      --pack-id mimi --name 咪咪 --species cat \
      --output ./mimi.cozy_pet

The input directory holds one entry per action, either a clip or a directory of
frames:

    pet_source/
      idle.mp4          or   idle/000.png idle/001.png ...
      walk.mp4          or   walk/000.png walk/001.png ...
      sleep.mp4         or   sleep/000.png sleep/001.png ...

## What this is, and what it deliberately is not

It is a *driver*. Every stage it runs already exists:

| stage | the code that does it |
|---|---|
| video → keyframes | `tools/video_to_sprite.py` |
| alpha, normalise, write | `tools/productionise.py` |
| the geometry contract | `tools/manifest.py` |
| measurement | `productionise.measure` (RGBA-safe) |

Nothing here reimplements any of that, and nothing here reimplements the pack
format: the output is the same `.cozy_pet` the P32 importer already reads, judged
by the same validator, and the test that proves it feeds the builder's output
straight into that importer.

## The importer is the authority

The checks in this file are a **pre-flight courtesy**, so a mistake is reported
where the user can act on it rather than at install time. They are not a second
validator, and where the two could disagree the importer wins — which is exactly
what `test/.../pack_builder_consumption_test.dart` exists to keep true.

## Geometry never comes from the frames

The canvas and anchors come from the **declared species profile** —
`assets/companions/<species>/animation_manifest.json`, written before any frames
exist. Measuring the frames and then writing their own mean into the manifest is
the self-certification bug this project already fixed once, and a pack built that
way agrees with itself while both halves are wrong. A pack whose frames do not
sit on the declared template is **refused**, not re-standardised.
"""

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import warnings
import zipfile

from PIL import Image

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)

import manifest as manifest_tool  # noqa: E402  (path set up above)
import productionise as prod  # noqa: E402
import video_to_sprite as v2s  # noqa: E402

ROOT = os.path.dirname(TOOLS)
ASSETS = os.path.join(ROOT, "assets", "companions")

MANIFEST_NAME = "manifest.json"
PACK_FORMAT_VERSION = 1

# The species the format accepts. Kept in step with `CompanionPackInstallRules`
# in Dart by the consumption test, which is what would fail if they drifted.
SPECIES = ("dog", "cat", "rabbit")

# The smallest an action can be. One frame is a still image, not an animation,
# and the player advances by frame index.
MIN_FRAMES_PER_ACTION = 2

VIDEO_SUFFIXES = (".mp4", ".mov", ".m4v", ".webm")
FRAME_SUFFIXES = (".png",)

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

# Two frames this close are the same picture. Measured rather than chosen: an
# identical frame scores exactly 0.0, and nudging one colour channel by three
# levels scores 0.0023. The margin below the smallest real pair in the shipped
# art (the cat's 0.0044) is what makes this a duplicate test rather than a
# similarity test.
EXACT_DUPLICATE_MAX = 0.0005


class BuildRefused(Exception):
    """A refusal the user can act on, as opposed to a crash."""


# ── the action vocabulary ────────────────────────────────────────────────────


def action_vocabulary():
    """The action ids the app has a production contract for.

    The dog's contract is the reference because it is the complete one. A builder
    that accepted arbitrary action names would produce packs full of actions
    nothing can ever ask for, and the honest answer for an action the app does not
    know is to refuse it rather than ship it unused.
    """
    path = os.path.join(ASSETS, "dog", "animation_manifest.json")
    with open(path, encoding="utf-8") as fh:
        raw = json.load(fh)
    return raw["assets"]


def geometry_profile(species):
    """The declared geometry template for [species].

    Through `manifest.load_contract`, so the builder and the audit tooling read
    the contract the same way. A species with no contract is refused rather than
    defaulted: there would be nothing independent to hold the frames to.
    """
    if species not in SPECIES:
        raise BuildRefused(
            f"species {species!r} is not one of {', '.join(SPECIES)}")
    try:
        return manifest_tool.load_contract(species)
    except ValueError as error:
        raise BuildRefused(str(error)) from error


def check_pack_id(pack_id):
    """A cheap pre-flight on the id, mirroring the importer's rule.

    Deliberately a *courtesy*, not the authority: the id reaches the filesystem as
    a directory name, so the builder refuses the obvious cases here where the
    message can be useful, and the importer refuses them again where it counts.
    """
    import re

    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", pack_id or ""):
        raise BuildRefused(
            f"pack id {pack_id!r} must match [a-z0-9][a-z0-9_-]{{0,63}} - it "
            "becomes a directory name, so a separator, a dot, a space or a "
            "colon is refused rather than escaped")
    if pack_id in SPECIES:
        raise BuildRefused(
            f"pack id {pack_id!r} is a built-in companion's id; two companions "
            "answering to it would make the selection ambiguous")


# ── discovering the source material ──────────────────────────────────────────


def discover(input_dir):
    """action id -> ('video', path) or ('frames', directory)."""
    if not os.path.isdir(input_dir):
        raise BuildRefused(f"no such input directory: {input_dir}")

    vocabulary = action_vocabulary()
    found = {}
    for name in sorted(os.listdir(input_dir)):
        path = os.path.join(input_dir, name)
        stem, ext = os.path.splitext(name)

        if os.path.isdir(path):
            action, kind = name, "frames"
        elif ext.lower() in VIDEO_SUFFIXES:
            action, kind = stem, "video"
        else:
            # Not silently ignored: a file the user meant as source and this
            # builder does not understand is the worst thing to skip quietly.
            raise BuildRefused(
                f"{name} is neither a directory of frames nor one of "
                f"{', '.join(VIDEO_SUFFIXES)}")

        if action not in vocabulary:
            raise BuildRefused(
                f"{action!r} is not an action the app knows. The vocabulary is "
                f"{', '.join(sorted(vocabulary))}. Action names are not invented "
                "here - an action nothing can ask for is not worth shipping")
        if action in found:
            raise BuildRefused(f"{action} is supplied twice")
        found[action] = (kind, path)

    if "idle" not in found:
        # The importer requires it, and for a good reason: the director hands an
        # ungrounded context `idle`, so a pack without one fails in a way that
        # looks like a rendering bug rather than a missing action.
        raise BuildRefused(
            "the source has no `idle` action. A companion with nothing to draw "
            "while it is standing still has no honest answer at all")
    return found


# ── the frame-directory path ─────────────────────────────────────────────────


def validate_frame_directory(directory, action, contract):
    """The frames in [directory] and notes about them, or a refusal.

    Frames that are already sprites are validated and passed through
    **unchanged**. Re-normalising them would re-encode approved art for no gain
    and could shift it off the anchor it was authored on.
    """
    names = sorted(n for n in os.listdir(directory)
                   if os.path.splitext(n)[1].lower() in FRAME_SUFFIXES)
    if not names:
        raise BuildRefused(f"{action}/ contains no PNG frames")

    # Ordering. Zero-padded numeric names sort the way a human expects; anything
    # else is a directory whose order is a guess, and a guess is how frames end up
    # played out of sequence.
    stems = [os.path.splitext(n)[0] for n in names]
    if not all(s.isdigit() and len(s) == len(stems[0]) for s in stems):
        raise BuildRefused(
            f"{action}/ frame names must be zero-padded numbers of equal width "
            f"(000.png, 001.png ...); found {names[:3]}")

    if len(names) < MIN_FRAMES_PER_ACTION:
        raise BuildRefused(
            f"{action}/ has {len(names)} frame(s); a still image is not an "
            f"animation, so at least {MIN_FRAMES_PER_ACTION} are needed")

    frames = []
    for name in names:
        path = os.path.join(directory, name)
        with open(path, "rb") as fh:
            if fh.read(8) != PNG_SIGNATURE:
                raise BuildRefused(f"{action}/{name} is not a PNG")

        try:
            image = Image.open(path)
            image.load()
        except Exception as error:  # noqa: BLE001 - any decode failure is a refusal
            raise BuildRefused(f"{action}/{name} does not decode: {error}") from error

        if image.size != tuple(contract["canvas"]):
            raise BuildRefused(
                f"{action}/{name} is {image.width}x{image.height}, but the "
                f"{contract['canvas'][0]}x{contract['canvas'][1]} canvas is "
                "declared for this species")

        frames.append((name, path, image))

    # A pack whose frames are all the same picture is not an animation, and the
    # player would show a frozen sprite that looks like a bug. That is the failure
    # this catches - an *identical* frame, which measures 0.0.
    #
    # Deliberately not the video path's `DUPLICATE_MAX_DISTANCE`. That threshold
    # exists to drop redundant samples from a continuous clip, and it was
    # calibrated against the dog's closest pair (0.0100) with headroom. Measured
    # across the shipped packs it is too tight for the rest: the cat's closest
    # `idle` pair is 0.0044 and the rabbit's is 0.0053, both below it. So applying
    # it here would refuse approved art for being subtle - and in a frame
    # directory the user has already chosen which frames to include, so the tool
    # has no business overruling that on taste. It refuses the frame that cannot
    # be an animation, and reports the closest pair for everything else.
    signatures = [v2s.signature(image) for _, _, image in frames]
    notes = []
    closest = None
    for i in range(len(signatures)):
        for j in range(i + 1, len(signatures)):
            distance = v2s.signature_distance(signatures[i], signatures[j])
            if closest is None or distance < closest[0]:
                closest = (distance, frames[i][0], frames[j][0])
            if distance <= EXACT_DUPLICATE_MAX:
                raise BuildRefused(
                    f"{action}/ frames {frames[i][0]} and {frames[j][0]} are the "
                    f"same picture (distance {distance:.4f}); one of them is a "
                    "duplicate, and the action would play as a freeze")
    if closest is not None:
        notes.append(
            f"{action}: closest frame pair {closest[1]} vs {closest[2]} at "
            f"{closest[0]:.4f}")

    # Sharpness, relative to the action's own median - the same rule the video
    # path uses, so a frame directory and a clip are held to one standard.
    sharp = [v2s.sharpness(image) for _, _, image in frames]
    median = sorted(sharp)[len(sharp) // 2]
    if median > 0:
        for (name, _, _), value in zip(frames, sharp):
            if value < median * v2s.SHARPNESS_MIN_RATIO:
                raise BuildRefused(
                    f"{action}/{name} is much softer than the rest of the action "
                    f"(sharpness {value:.1f} against a median of {median:.1f}); "
                    "it is probably a motion-blur or transition frame")

    return [(name, path) for name, path, _ in frames], notes


# ── the video path ───────────────────────────────────────────────────────────


def frames_from_video(video, action, pack_id, species, vocabulary, out_root,
                      target_frames, source_kind):
    """Runs the existing video chain and returns the frames it produced.

    `video_to_sprite.run` does the whole of it - probe, decode, sample, reject
    blurred and duplicated candidates, alpha, normalise, QA against the contract -
    and this passes the *declared profile* as that contract, because the pack's own
    id has no contract of its own.
    """
    spec = vocabulary[action]
    report = v2s.run(
        video,
        pack_id,
        action,
        target_frames or spec["targetFrameCount"],
        spec["loopMode"],
        # `walk` is the one action where the subject is expected to move across
        # the frame; everything else should hold its ground.
        expect_in_place=(action != "walk"),
        out_root=out_root,
        # Classified by the caller rather than assumed. A user's clip is real
        # source material; a clip rendered locally from frames that already ship
        # is a round trip of existing art, and `video_to_sprite` refuses to let
        # the second kind write into the shipped assets. That distinction is
        # enforced there and must not be flattened here.
        source_kind=source_kind,
        # Read through `video_to_sprite`'s own accessor rather than handing it the
        # manifest-shaped dict: `qa_frames` reads `tolerancePx` and a tuple canvas,
        # and the two shapes are how these two tools drifted apart in the first
        # place. One reader, and each consumer gets the shape it reads.
        contract=v2s.load_contract(species),
    )
    if report.get("verdict") != "PASS":
        raise BuildRefused(
            f"{action}: the video did not pass QA - "
            f"{report.get('error') or report.get('qa', {}).get('blocking')}")

    produced = sorted(
        os.path.join(out_root, pack_id, name)
        for name in os.listdir(os.path.join(out_root, pack_id))
        if name.startswith(f"{action}_") and name.endswith(".png")
    )
    if len(produced) < MIN_FRAMES_PER_ACTION:
        raise BuildRefused(
            f"{action}: the video yielded {len(produced)} usable frame(s)")
    return produced


# ── geometry, measured against the declaration ───────────────────────────────


def check_frame_geometry(paths, action, contract):
    """Why [paths] do not sit on [contract], as a list of strings.

    Every frame, not their mean. A mean hides the frame that is wrong on its own,
    and a mean is also what the old self-certifying code computed - so checking
    each frame is both stricter and a different mistake from the one being fixed.
    """
    problems = []
    for path in paths:
        with Image.open(path) as image:
            # The conversion is deliberate and is the whole point: these ship as
            # indexed PNGs, and PIL warns that a palette with byte-string
            # transparency may not survive `convert("RGBA")`. For these sprites it
            # does - `audit_pack_geometry.py` measures the same way and agrees with
            # the contract to within a pixel - so the warning is noise about a
            # lossy case that does not apply.
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                measured = prod.measure(image)
        measured_for_contract = {
            "groundBaseline": measured["bottomY"],
            "centerAnchor": measured["centerX"],
            "canvas": measured["canvas"],
        }
        for problem in manifest_tool.check_geometry(measured_for_contract,
                                                    contract):
            problems.append(f"{action}/{os.path.basename(path)}: {problem}")
    return problems


# ── the pack ─────────────────────────────────────────────────────────────────


def build_manifest(pack_id, display_name, species, contract, actions,
                   fallbacks):
    """The playable manifest, in the shape the runtime already parses."""
    return {
        "packFormatVersion": PACK_FORMAT_VERSION,
        "companionId": pack_id,
        "displayName": display_name,
        "species": species,
        "posePack": f"{pack_id}_art",
        "canvas": {"width": contract["canvas"][0],
                   "height": contract["canvas"][1]},
        "groundBaseline": contract["groundBaseline"],
        "centerAnchor": contract["centerAnchor"],
        "actions": actions,
        **({"semanticFallback": fallbacks} if fallbacks else {}),
    }


def checksum_of(entries):
    """A digest over the pack's names and bytes.

    The same shape as the installer's, so a pack built here and re-imported is
    recognised as the same pack rather than as a conflict. Sorted by name so the
    digest does not depend on directory order.
    """
    digest = hashlib.sha256()
    for name, payload in sorted(entries):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(payload)
    return digest.hexdigest()[:16]


def write_pack(output_path, manifest, frames_by_name):
    """Writes the `.cozy_pet`: the manifest and its frames, and nothing else."""
    entries = [(MANIFEST_NAME,
                json.dumps(manifest, ensure_ascii=False, indent=2,
                           sort_keys=True).encode("utf-8"))]
    for name, payload in sorted(frames_by_name.items()):
        entries.append((name, payload))

    os.makedirs(os.path.dirname(os.path.abspath(output_path)) or ".", exist_ok=True)
    # Deterministic: sorted, and with a fixed timestamp, so building the same
    # source twice produces byte-identical archives and a re-import is
    # recognised as the same pack.
    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, payload in entries:
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, payload)
    return checksum_of(entries)


def build(args):
    check_pack_id(args.pack_id)
    contract = geometry_profile(args.species)
    vocabulary = action_vocabulary()
    sources = discover(args.input)

    fallbacks = json.loads(args.fallbacks) if args.fallbacks else {}
    if args.fallback_to_idle:
        # Explicitly requested, and only for actions the pack does not ship: a
        # fallback for an action that *is* present would be a lie about it.
        for action in sorted(vocabulary):
            if action not in sources:
                fallbacks.setdefault(action, "idle")
    for action, target in fallbacks.items():
        if target not in sources:
            raise BuildRefused(
                f"the declared fallback {action} -> {target} points at an action "
                "this pack does not ship, which is a promise it cannot keep")

    staging = tempfile.mkdtemp(prefix="cozy_pet_build_")
    try:
        frames_by_name = {}
        actions = {}
        problems = []
        notes = []

        for action in sorted(sources):
            kind, path = sources[action]
            if kind == "video":
                produced = frames_from_video(
                    path, action, args.pack_id, args.species, vocabulary,
                    os.path.join(staging, "video"), args.frames,
                    args.source_kind)
                pairs = [(f"{action}_{i:03d}.png", p)
                         for i, p in enumerate(produced)]
            else:
                validated, action_notes = validate_frame_directory(path, action,
                                                                   contract)
                # Renamed into the pack's own namespace. A frame directory numbers
                # its frames `000.png`, `001.png`, and every action numbers them
                # the same way - so keeping the source names would collide, and
                # the second action would silently overwrite the first action's
                # frames. Both would then play the same pictures, and nothing
                # downstream would notice: the validator checks that an action's
                # frames exist and are not repeated *within* it, not that two
                # actions differ.
                pairs = [(f"{action}_{i:03d}.png", p)
                         for i, (_, p) in enumerate(validated)]
                notes.extend(action_notes)

            problems.extend(check_frame_geometry([p for _, p in pairs], action,
                                                 contract))

            spec = vocabulary[action]
            actions[action] = {
                "frames": [name for name, _ in pairs],
                "fps": spec["fps"],
                "loopMode": spec["loopMode"],
            }
            for name, source_path in pairs:
                with open(source_path, "rb") as fh:
                    frames_by_name[name] = fh.read()

        if problems:
            raise BuildRefused(
                "the frames do not sit on the declared "
                f"{args.species} template:\n  " + "\n  ".join(problems))

        manifest = build_manifest(args.pack_id, args.name, args.species,
                                  contract, actions, fallbacks)
        checksum = write_pack(args.output, manifest, frames_by_name)

        return {
            "pack_id": args.pack_id,
            "display_name": args.name,
            "species": args.species,
            "output": args.output,
            "bytes": os.path.getsize(args.output),
            "checksum": checksum,
            "actions": {a: len(actions[a]["frames"]) for a in sorted(actions)},
            "frames": len(frames_by_name),
            "geometry": contract,
            "fallbacks": fallbacks,
            "vocabulary": sorted(vocabulary),
            "notes": notes,
        }
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", required=True,
                        help="directory of action videos or frame directories")
    parser.add_argument("--pack-id", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--species", required=True, choices=list(SPECIES),
                        help="the geometry template to hold the frames to")
    parser.add_argument("--output", required=True, help="the .cozy_pet to write")
    parser.add_argument("--frames", type=int, default=None,
                        help="target frames per action for video input; "
                             "defaults to the contract's count")
    parser.add_argument("--fallbacks", default=None,
                        help="JSON object of semanticFallback entries, e.g. "
                             "'{\"sleep\": \"pause_rest\"}'")
    parser.add_argument("--source-kind", default=v2s.SOURCE_FLOW_VIDEO,
                        choices=list(v2s.SOURCE_KINDS),
                        help="how to classify video input. A clip rendered "
                             "locally from frames that already ship is "
                             "'test_video' and is refused a production write")
    parser.add_argument("--fallback-to-idle", action="store_true",
                        help="declare semanticFallback -> idle for every action "
                             "the pack does not ship")
    args = parser.parse_args(argv)

    # Narrowly, and by message: PIL warns that a palette with byte-string
    # transparency may not survive `convert("RGBA")`. For these sprites it does -
    # the geometry comes out inside a 2px tolerance of the declared contract - so
    # the warning is noise about a lossy case that does not apply, and it is not
    # silenced for anything else.
    warnings.filterwarnings(
        "ignore", message="Palette images with Transparency.*")

    try:
        report = build(args)
    except BuildRefused as error:
        print(f"REFUSED: {error}", file=sys.stderr)
        return 1

    print(f"wrote {report['output']} ({report['bytes']} bytes)")
    print(f"  pack id   : {report['pack_id']}")
    print(f"  name      : {report['display_name']}")
    print(f"  species   : {report['species']}")
    print(f"  geometry  : canvas {report['geometry']['canvas']} "
          f"baseline {report['geometry']['groundBaseline']} "
          f"centre {report['geometry']['centerAnchor']} "
          f"tolerance {report['geometry']['anchorTolerancePx']}px")
    print(f"  actions   : {len(report['actions'])} of "
          f"{len(report['vocabulary'])} in the app's vocabulary")
    for action, count in report["actions"].items():
        print(f"      {action:12} {count} frames")
    if report["fallbacks"]:
        print(f"  fallbacks : {report['fallbacks']}")
    for note in report["notes"]:
        print(f"  note      : {note}")
    print(f"  checksum  : {report['checksum']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
