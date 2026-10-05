"""Build a demo `.cozy_pet` from a shipped companion's frames, under a new id.

Run:
    python tools/make_demo_pack.py --out /tmp/xiaomao.cozy_pet

## Why this exists

The import flow needs a real pack to import. The app can only *export* a pack it
already installed, so the first pack on a fresh device has to come from somewhere
else, and a hand-zipped archive is exactly the kind of thing that is subtly wrong
in a way that looks like an app bug.

So this builds one the way the format says: `manifest.json` at the archive root,
the frames the manifest references, and nothing else.

## What it deliberately does not do

It does not invent geometry. The source manifest's `groundBaseline` and
`centerAnchor` are carried across untouched, because the frames are the same
frames - a demo pack that shifted its own anchors would be testing a pack the app
should refuse, not one it should accept. It does not carry the source's
`generatedFrom` block either: that describes how the shipped art was produced and
would be a lie about a pack the user assembled.
"""

import argparse
import json
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMPANIONS = os.path.join(ROOT, "assets", "companions")


def build(source_dir, pack_id, display_name, species, out_path, actions=None):
    manifest_path = os.path.join(source_dir, "manifest.json")
    if not os.path.exists(manifest_path):
        raise SystemExit(f"no manifest.json in {source_dir}")

    with open(manifest_path, encoding="utf-8") as handle:
        manifest = json.load(handle)

    manifest["companionId"] = pack_id
    manifest["posePack"] = f"{pack_id}_art"
    manifest["displayName"] = display_name
    manifest["species"] = species
    # Not pack data: it describes how the *shipped* art was produced, and this is
    # not the shipped art under its shipped identity.
    manifest.pop("generatedFrom", None)

    if actions is not None:
        # A partial pack, which is what P33 is about: a real user will bring a
        # handful of actions, not thirteen. `idle` is kept because the format
        # requires it - a companion with nothing to draw when it is standing
        # still has no honest answer at all.
        wanted = set(actions) | {"idle"}
        unknown = wanted - set(manifest["actions"])
        if unknown:
            raise SystemExit(f"the source has no such actions: {sorted(unknown)}")
        manifest["actions"] = {
            k: v for k, v in manifest["actions"].items() if k in wanted
        }
        # A fallback or alias pointing at a dropped action would be a promise the
        # pack cannot keep, and the validator refuses it - correctly.
        for key in ("semanticFallback", "drawAliases"):
            if key in manifest:
                manifest[key] = {
                    k: v
                    for k, v in manifest[key].items()
                    if v in manifest["actions"]
                }

    frames = []
    for action in manifest["actions"].values():
        for frame in action["frames"]:
            if frame not in frames:
                frames.append(frame)

    missing = [f for f in frames if not os.path.exists(os.path.join(source_dir, f))]
    if missing:
        raise SystemExit(f"the source is missing frames: {missing}")

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    # Sorted, and the manifest first: the same determinism the app's own exporter
    # uses, so two builds of one pack are comparable.
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr(
            "manifest.json",
            json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True),
        )
        for frame in sorted(frames):
            archive.write(os.path.join(source_dir, frame), frame)

    return manifest, frames


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--from",
        dest="source",
        default="cat",
        help="the shipped companion whose frames to borrow (default: cat)",
    )
    parser.add_argument("--id", default="xiaomao", help="the new companion id")
    parser.add_argument("--name", default="小豆", help="the display name")
    parser.add_argument("--species", default="cat", help="dog, cat or rabbit")
    parser.add_argument("--out", default="build/demo_pack.cozy_pet")
    parser.add_argument(
        "--actions",
        default=None,
        help="comma-separated actions to keep, for a partial pack "
        "(e.g. idle,walk). Omit for the whole set.",
    )
    args = parser.parse_args()
    actions = args.actions.split(",") if args.actions else None

    source_dir = os.path.join(COMPANIONS, args.source)
    if not os.path.isdir(source_dir):
        raise SystemExit(f"no such shipped companion: {args.source}")

    manifest, frames = build(
        source_dir, args.id, args.name, args.species, args.out, actions
    )

    size = os.path.getsize(args.out)
    print(f"wrote {args.out} ({size} bytes)")
    print(f"  companionId : {manifest['companionId']}")
    print(f"  displayName : {manifest['displayName']}")
    print(f"  species     : {manifest['species']}")
    print(f"  canvas      : {manifest['canvas']['width']}x{manifest['canvas']['height']}")
    print(f"  anchors     : {manifest['groundBaseline']}/{manifest['centerAnchor']}")
    print(f"  actions     : {len(manifest['actions'])}")
    print(f"  frames      : {len(frames)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
