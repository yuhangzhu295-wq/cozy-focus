# P34 — Local Companion Pack Builder

Pack-first roadmap (`P31_P40_PACK_FIRST_ROADMAP.md`). Branch
`recovery/v4.2.1-rebuild`.

**Status: COMPLETE, and its output was walked onto the device.**
1456/1456 tests, format clean, analyze clean, all tooling proofs passing.
Latest slice `01b4e86`.

```
BUILDER:                  PASS
VIDEO_INPUT:              PASS
FRAME_INPUT:              PASS
PARTIAL_PACK:             PASS
FULL_PACK:                PASS
IMPORTER_ACCEPTS_OUTPUT:  PASS
GEOMETRY_INDEPENDENT:     PASS
NEGATIVE_GEOMETRY_PROOF:  PASS
ROUND_TRIP:               PASS
DEVICE:                   PASS
```

## What it is

`tools/cozy_pet_builder/build.py`, one CLI:

```
python tools/cozy_pet_builder/build.py \
  --input ./pet_source \
  --pack-id mimi --name 咪咪 --species cat \
  --output ./mimi.cozy_pet [--fallback-to-idle]
```

The input directory holds one entry per action — `idle.mp4` or `idle/000.png
idle/001.png` — and the output is the same `.cozy_pet` the P32 importer already
reads.

It is a **driver**, not an implementation. Every stage already existed:
`video_to_sprite` does the video chain, `productionise` does alpha and
normalisation, `manifest` owns the geometry contract. Nothing was reimplemented,
and the pack format was not forked.

## The two paths are deliberately different

| input | what happens |
|---|---|
| a clip | **derived**: probe → decode → sample → reject blurred and duplicated candidates → alpha → normalise → QA |
| a frame directory | **validated and passed through unchanged** |

The asymmetry is the point. Re-normalising frames that are already sprites
re-encodes approved art for no gain and can shift it off the anchor it was
authored on.

## Geometry comes from a declaration, never from the frames

The canvas and anchors come from the **species profile** —
`assets/companions/<species>/animation_manifest.json`. A pack whose frames do not
sit on the template is refused, not re-standardised. Every frame is checked, not
their mean: a mean hides the frame that is wrong on its own, and a mean is also
what the old self-certifying code computed.

The load-bearing proof is unchanged and still fails as it must: **shift every
frame by 40px and the build is refused**, naming the deviation
(`centerAnchor measured 295.0 against a declared 255 (off by 40px, tolerance 2px)`).

## The importer is the authority

The builder's checks are a pre-flight courtesy so a mistake is reported where the
user can act on it. `pack_builder_consumption_test.dart` runs the real builder as
a subprocess and hands the bytes to the real reader, validator and install rules.
That test found two things worth keeping.

### 1. The frame path silently merged two actions

It kept the source names, so `idle/000.png` and `walk/000.png` collided and the
second action overwrote the first. **Both actions would have played the same
pictures**, and the importer accepted it — because the validator checks that an
action's frames exist and are not repeated *within* it, not that two actions
differ. Frames are now namespaced per action, and the two-action test asserts 12
distinct frames rather than 6.

### 2. Two tools read the contract file into two different shapes

`video_to_sprite.load_contract` returned `tolerancePx` and a tuple canvas;
`manifest.load_contract` returns `anchorTolerancePx` and a list. Handing one
tool's contract to the other raised `KeyError: 'tolerancePx'`.
`video_to_sprite` now delegates to the single reader and adapts the names
locally — which is what its own docstring had claimed all along ("a second
implementation of the contract is a second thing to drift").

## A threshold that was calibrated against one pack

`DUPLICATE_MAX_DISTANCE` was 0.005, justified by the dog's closest `idle` pair
(0.0100) with "2x headroom". Measured across all three packs:

| pack | closest pair per action |
|---|---|
| dog | idle 0.0100 · sleep 0.1028 · walk 0.0231 · focus_read 0.0274 |
| cat | idle **0.0044** · sleep 0.0495 · walk 0.0221 · focus_read **0.0048** |
| rabbit | idle **0.0053** · sleep 0.0204 · walk 0.0296 · focus_read 0.0111 |

The old value sat **above** the cat's and the rabbit's closest pairs, so the video
QA refused two thirds of the approved art for being subtle. It surfaced when the
builder's video path would not produce an `idle` action from the cat's own
frames. The threshold is now 0.002 — below the smallest real pair with over 2x
headroom, and well above an identical frame (0.0) and a three-level colour nudge
(0.0023).

## Negative proofs

`tools/cozy_pet_builder/test_builder.py`, twelve refusals, all passing:

a uniform 40px shift · identical duplicate frames · a one-frame action ·
unpadded frame names · a frame that is not a PNG · an action name the app does
not know · no `idle` · a built-in pack id · an id that could escape the pack root ·
frames off the declared canvas · a fallback pointing at an action the pack lacks ·
an unsupported species.

Plus, in Dart: a pack id unusable as a directory name, and an unsupported species
— both asserting that a refused build leaves **no pack behind**.

## Verified on the device

CLI-built pack `doudou` (豆豆, species rabbit, actions idle/walk/sleep, 3 of 13),
pushed to the emulator and imported through the real system file picker:

- preview reads **动作 3 / 13**, 帧 14, 画布 512×512, with the rabbit drawn from
  the pack's own bytes and the name and species read from the manifest;
- installed, and the record file shows `species: "rabbit"` — the species the CLI
  was told, not one inferred;
- selected without a restart;
- **after a cold start the home page reads 和 豆豆 一起专注吧！** with the rabbit,
  and the footer quote names it.

## What P34 deliberately did not do

- **No new production art.** The source material is the shipped packs' frames, used
  as a tooling proof. `--source-kind test_video` keeps a locally rendered clip from
  ever being written over `assets/companions/`, which `video_to_sprite` enforces.
- **No second validator, no second asset pipeline, no second contract reader.**
- **No action names invented.** The vocabulary is the app's own production action
  list; an action nothing can ask for is refused rather than shipped unused.

## Environment note

The Android-level tap (`adb shell input tap` at device coordinates) **does** reach
Material buttons, even though it does not reach the room's gesture detectors. When
a CUA click on a button appears dead, the scaled device coordinate is worth trying
before concluding the button is broken — that is what unblocked the install step
here. The device is 1080×2400 and the emulator raster 561×1280, so the scale is
about 1.925.

## Carried forward to P35

- The furniture panel's *offer* is gated on the pack's real capabilities, but the
  room's decision loop still records and applies a furniture effect before the
  director sees the committed action. P35 owns it.
- `room_sit` still has no art of its own, so nothing may pretend it exists —
  including autonomous routine decisions, not only the player-facing panel.
- `docs/companion_assets.md` is still stale (1024×1024 / 919 / 511 claimed;
  512×512 / ~458 / 255 real).
