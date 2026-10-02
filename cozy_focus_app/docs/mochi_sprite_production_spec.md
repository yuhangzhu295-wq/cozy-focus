# Mochi sprite production spec

The asset contract for the `dog` / `mochi` pack. Everything here is enforced by
`sprite_animation_manifest_parity_test.dart` and
`sprite_animation_asset_integrity_test.dart`; this document explains *why* the
numbers are what they are, so the next batch does not have to rediscover them.

## Scope of this batch

**Dog only. The cat and rabbit packs are untouched.** Producing all three at once
means one camera or palette mistake invalidates three packs instead of one.

The first batch is four animations, 20 frames:

| action     | frames | fps | loop | role       |
|------------|--------|-----|------|------------|
| `idle`     | 6      | 5   | loop | ambient    |
| `walk`     | 6      | 8   | loop | ambient    |
| `sit_down` | 4      | 8   | once | transition |
| `stand_up` | 4      | 8   | once | transition |

`idle` currently ships **1 frame**, which is a still image and not an animation.
`walk`, `sit_down` and `stand_up` ship nothing. Those four are the gap the gate
reports:

```
MOCHI_FIRST_BATCH_PENDING: idle 1/6, walk 0/6, sit_down 0/4, stand_up 0/4
```

`walk` is the one that matters most: without it, moving the companion is a
still image sliding across the room, which is the defect the whole V4.3 pipeline
exists to remove.

## Where the files live

```
.asset_staging/flow/dog/<action>_NNN.png   raw Flow output, any size
        |  tools/productionise.py  (alpha cut, scale, place on canvas)
        v
assets/companions/dog/<action>_NNN.png     1024x1024 RGBA, shipped
assets/companions/dog/manifest.json        runtime manifest (frame paths)
assets/companions/dog/animation_manifest.json  this contract
```

**Do not create `assets/companions/dog/mochi/`.** Flutter does not recurse into
asset subdirectories, so frames placed one level deeper are absent from the
bundle until `pubspec.yaml` names that exact directory — and a missing frame
degrades to an empty box rather than an error, so it fails silently. That is
precisely how the cat pack shipped invisible. `mochi` is the *pose pack id*
(`CompanionProfile.posePack`), not a directory.

## Canvas and anchor contract

| field            | value | measured from the shipped art |
|------------------|-------|-------------------------------|
| canvas           | 1024 × 1024 | every frame |
| `groundBaseline` | 919   | feet land at y = 918–919 |
| `centerAnchor`   | 511   | character centre at x = 511.0–512.0 |
| `anchorTolerancePx` | 2  | the spread above is ≤ 1px |
| background       | transparent | colour type 6 (RGBA) |

The tolerance is 2px on purpose. It absorbs the anti-aliased fringe on a paw
edge, and it is tight enough that a genuinely misplaced frame fails: lowering it
to 0 in a trial immediately caught six frames sitting at 918 instead of 919.

The contract is **measured from pixels**, not read from the manifest. A manifest
can declare 919 while the art has its feet at 500; the integrity suite decodes
each PNG and finds the lowest non-transparent pixel.

`tools/productionise.py` places the subject so its bounding box bottom sits at
`0.90 × canvas = 921`; the visible feet then land at 918–919 once the crop's own
transparent margin is accounted for. If that constant changes, the contract has
to be re-measured rather than assumed.

## What each frame has to show

The character is a white soft puppy with floppy ears, a green sprout, rounded
chibi proportions and a gentle face. Full body, one fixed camera, feet on the
level ground line, plain background, no props, no scene, no second character.

**`idle` — 6 frames, loops.** One full breath. The first and last frames must
connect, or the loop reads as a jump: frame 5 flows back into frame 0. Chest
rises and falls, ears settle a beat behind the body, the sprout sways last. No
weight shift — this is a companion sitting beside someone who is working, not a
character waiting for attention.

**`walk` — 6 frames, loops.** One gait cycle, two footfalls. Frames 0–2 are the
left step, 3–5 the right. The body dips on the contact frames and rises between
them; the head counter-rotates slightly so the walk does not read as a bobble.
The character moves **on the spot** — the room page supplies the travel, so
baking displacement into the frames would double it.

**`sit_down` — 4 frames, plays once.** Standing → seated. Frame 0 must match the
`idle` standing pose closely enough that the transition does not pop, and frame 3
must match the seated pose the work animations start from. The feet do not move;
the body lowers onto them.

**`stand_up` — 4 frames, plays once.** The reverse of `sit_down`. Frame 3 must
match the `idle` standing pose.

A transition is never a destination: the animation layer plays it once and hands
over. A `sit_down` that loops would leave the companion bobbing in place.

## Prompting Flow

Start from `outputs/ai_handoff/flow_asset_prompts/_BASE_PROMPT_TEMPLATE.md`. It
already carries the identity-lock and the negative list; change only the `ACTION`
and `FRAME` sections. Per frame, say which beat of the cycle it is, in words:

```
ACTION:
walk, frame 2 of 6 - left foot planted, weight lowest, body dipped

FRAME:
one frame of a continuous 6-frame walk cycle. Character moves on the spot.
Feet on a level ground line. Same camera, same scale, same canvas placement as
the reference. Full body visible.
```

Generate one action at a time. Reuse the same reference image for every frame of
every action in the batch — the identity drift between two batches is larger
than the drift within one.

**Verify before producing the whole batch.** Generate `walk`'s 6 frames first,
run the integrity suite, and only then do the other 14. Twenty frames generated
against a mis-set camera are twenty wasted frames.

## Importing

```bash
# 1. drop the raw Flow frames in .asset_staging/flow/dog/
# 2. cut alpha, scale to 78% height, place on the 1024 canvas
python tools/productionise.py
# 3. regenerate the runtime Dart mirror from the JSON manifest
python tools/gen_manifest_dart.py
```

Then, by hand:

1. add the frames to `assets/companions/dog/manifest.json` (`frames`, and leave
   `targetFrameCount` alone — it is production intent, not a count of the disk)
2. mirror the same change in `companion_action_manifest_data.dart`, or run the
   generator above
3. run the suite

`sprite_animation_asset_integrity_test.dart` now covers the new frames
automatically: canvas, alpha, ground line, centre and frame count. Nothing in
the test files needs editing when art lands, which is the point.

## What fails, and what it means

| failure | meaning |
|---|---|
| `feet at 918, contract 919` | the production script's baseline constant moved, or a frame was hand-edited |
| `centre at 530, contract 511` | the subject was not centred when it was composited |
| `is not an alpha PNG` | alpha extraction did not run, or Flow returned a JPEG renamed to `.png` |
| `is not on the pack canvas` | a frame was exported at the wrong size |
| `has no visible pixels` | a blank frame — silent at runtime, drawn as an empty box |
| `frames exist beyond the contract` | art landed and the contract was not updated |
| `ships frames but has no contract` | an action was added without a contract row |

## Deliberately not in this batch

`focus_write`, `focus_read`, `focus_think`, `sleep`, `happy`, `sad`, `interact`
keep the frames they already have. Their contracts exist in
`animation_manifest.json`, so their targets are already stated and the same
assertions cover them; they are simply not being re-produced yet. Cat and rabbit
are out of scope entirely.
