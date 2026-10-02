# Idle batch 1 — dog / Mochi (5 frames to generate)

Phase 3b, batch 1 of 4. **This is the only batch in flight.** `walk`,
`stand_up` and `sit_down` are not started, and cat/rabbit are out of scope.

## What already exists

| frame | status |
|---|---|
| `idle_000` | **exists** — the approved master, from `mochi_master_ref_white.png` |
| `idle_001` … `idle_005` | **to generate** — the five prompts below |

The contract asks for 6. `idle_000` is frame 0, so five more complete the loop.
The gate currently reports `idle 1/6`.

## Why this batch first

`idle` is the pose the player sees most, and it is the one that carries the whole
"is this alive?" impression. It is also the only batch where the loop has to
close on itself, so a mistake here is the most expensive one to find late. Batch
2 (`walk`) is the other high-value one; batches 3 and 4 are transitions.

## Invariant geometry

Every frame must match the contract in `assets/companions/dog/animation_manifest.json`:

| field | value |
|---|---|
| canvas | 1024 × 1024 |
| `groundBaseline` | 919 |
| `centerAnchor` | 511 |
| tolerance | 2 px |

`tools/productionise.py` normalises the subject onto this canvas, so the prompt
does not need to state pixel numbers — it needs to keep the character's **scale
and camera** identical to the master. The gate measures the result and fails a
frame whose feet or centre drift more than 2px.

## The one requirement that cannot be met as written

The brief asks the idle loop to show *breathing, blink, ear movement and sprout
follow-through*.

**Blink is not expressible here.** The approved Mochi has closed happy-arc eyes
(see `mochi_layered_renderer.dart`: "the approved eyes are closed happy arcs, so
the blink channel reads as an eye twitch rather than a full eyelid close"). A
6-frame loop at 5 fps is 1.2 s, so even if an eyelid close could be drawn, it
would fire every 1.2 s — which reads as a twitch, not as life. Blink therefore
stays a separate micro-motion channel, and the loop carries the other three.

What I have done instead: one frame carries a **subtle cheek/eye-arc settle**,
which is the closest honest equivalent. If you would rather the loop carry no
eye movement at all, drop the phrase from frame 003 and say so — that is a
product call, not a technical one.

## Continuity

The loop must close: frame `005` flows back into `000`. That means `000` and
`005` are **near-neighbours**, not a start and an end. Concretely, across the six
frames the chest rises and falls **once**, and the ears and sprout trail the
body by roughly one frame.

Use `idle_000` (the approved master) as the ingredient for every frame in this
batch — not the rig, and not each other. Chaining frame-to-frame compounds drift;
the existing `focus_*` frames all reference `idle_000` for the same reason.

## How to generate

1. Open `Cozy Focus Companion Production` in Flow (`2f518015-e4b1-495a-9200-dc8ecbd66304`).
2. `+ → All → idle_000 → Add to prompt`.
3. Paste one prompt below.
4. Generate at **1:1, x1**.
5. Download at **1K Original size**.
6. Stage at `.asset_staging/flow/dog/idle/idle_<index>.jpg`.

Cost policy from the existing archive: max 3 attempts per frame, then stop and
report. Confirm before spending.

Then run the import (see `docs/mochi_sprite_production_spec.md`):

```bash
python tools/productionise.py dog
python tools/manifest.py dog
python tools/gen_manifest_dart.py
flutter test
```

`python tools/gen_manifest_dart.py` mirrors the JSON into Dart; skipping it fails
the parity test. The anchor and frame-count checks then cover the new frames
with no test edit.

---

## Frame 001 — inhale begins

```text
Use the attached reference image as the exact character. Preserve its identity,
proportions, line quality, colour palette, facial features and accessory
placement exactly.

Create only a pose variation for a 2D mobile companion game.

Full body visible. Same fixed camera. Same canvas placement. Same body scale.
Clean isolated character. No text. No arrows. No UI. No additional characters.
No environment. No scene. No dramatic perspective. No redesign.

ACTION: idle, frame 1 of 6 — the breath beginning to rise
The character stays seated in exactly the posture of the reference. The chest
lifts very slightly, no more than a few percent of body height. The body has not
yet moved at the ears or the sprout. Front paws stay planted where they are in
the reference. This is the first moment of a slow breath, not a stretch and not
a weight shift.

The image must visually connect with the previous and next frames of this action.
Plain pure white background, no shadow, no scene, no furniture.
```

## Frame 002 — peak inhale

```text
Use the attached reference image as the exact character. Preserve its identity,
proportions, line quality, colour palette, facial features and accessory
placement exactly.

Create only a pose variation for a 2D mobile companion game.

Full body visible. Same fixed camera. Same canvas placement. Same body scale.
Clean isolated character. No text. No arrows. No UI. No additional characters.
No environment. No scene. No dramatic perspective. No redesign.

ACTION: idle, frame 2 of 6 — the top of the breath
The character stays seated in exactly the posture of the reference. The chest is
at its highest point for this cycle — still a small, calm movement, not a puff or
a sigh. The head is a fraction higher than the reference. The ears have begun to
settle downward, trailing the body by about one frame. The sprout is still
upright. Front paws unchanged.

The image must visually connect with the previous and next frames of this action.
Plain pure white background, no shadow, no scene, no furniture.
```

## Frame 003 — exhale begins

```text
Use the attached reference image as the exact character. Preserve its identity,
proportions, line quality, colour palette, facial features and accessory
placement exactly.

Create only a pose variation for a 2D mobile companion game.

Full body visible. Same fixed camera. Same canvas placement. Same body scale.
Clean isolated character. No text. No arrows. No UI. No additional characters.
No environment. No scene. No dramatic perspective. No redesign.

ACTION: idle, frame 3 of 6 — the breath releasing, a soft eye settle
The character stays seated in exactly the posture of the reference. The chest is
lowering back toward the reference height. The ears have settled to their lowest
point of the cycle. The sprout tips very slightly. The eye arcs relax a touch
softer than the reference — a settle, not a blink, and the eyes are not closed
any further than they already are in the reference. Front paws unchanged.

The image must visually connect with the previous and next frames of this action.
Plain pure white background, no shadow, no scene, no furniture.
```

## Frame 004 — bottom of the breath

```text
Use the attached reference image as the exact character. Preserve its identity,
proportions, line quality, colour palette, facial features and accessory
placement exactly.

Create only a pose variation for a 2D mobile companion game.

Full body visible. Same fixed camera. Same canvas placement. Same body scale.
Clean isolated character. No text. No arrows. No UI. No additional characters.
No environment. No scene. No dramatic perspective. No redesign.

ACTION: idle, frame 4 of 6 — the bottom of the breath
The character stays seated in exactly the posture of the reference. The chest is
at its lowest point for this cycle, a small and calm movement. The ears are
rising back from their settle, following the body. The sprout is beginning to
sway back the other way, still behind the ears. The expression is the reference's
gentle closed-mouth smile. Front paws unchanged.

The image must visually connect with the previous and next frames of this action.
Plain pure white background, no shadow, no scene, no furniture.
```

## Frame 005 — returning to neutral

```text
Use the attached reference image as the exact character. Preserve its identity,
proportions, line quality, colour palette, facial features and accessory
placement exactly.

Create only a pose variation for a 2D mobile companion game.

Full body visible. Same fixed camera. Same canvas placement. Same body scale.
Clean isolated character. No text. No arrows. No UI. No additional characters.
No environment. No scene. No dramatic perspective. No redesign.

ACTION: idle, frame 5 of 6 — settling back to the reference pose
The character is almost exactly the reference pose again. The chest has returned
to the reference height. The ears are still carrying a very small amount of
follow-through and have not quite reached rest. The sprout has swayed back and is
settling. This frame must read as the frame immediately before the reference
image, so that the loop closes without a jump. Front paws unchanged.

The image must visually connect with the previous and next frames of this action.
Plain pure white background, no shadow, no scene, no furniture.
```

---

## What the gate will check once these land

| check | expectation |
|---|---|
| frames exist | 6 files in `assets/companions/dog/` |
| alpha PNG | colour type 6 |
| canvas | 1024 × 1024, all six identical |
| ground line | lowest visible pixel within 2px of 919 |
| centre | visible centre within 2px of 511 |
| frame uniqueness | no two consecutive frames byte-identical |
| frame count | `idle 6/6`, so `MOCHI_FIRST_BATCH_PENDING` drops `idle` |
| parity | the JSON and the Dart mirror agree |

A frame that is byte-identical to its neighbour fails: a repeated frame is a
stutter, and the whole point of this batch is that the companion is not a still
image.

## After this batch passes

Batch 2 (`walk`, 6 frames) is the other high-value one — it is what makes moving
the companion stop looking like a still image sliding. Batches 3 and 4
(`stand_up`, `sit_down`) are transitions and are only visible at the start and
end of a journey.

Do not start batch 2 until this one passes the gate: a camera or scale mistake
found here costs 5 frames, the same mistake found in batch 4 costs 20.
