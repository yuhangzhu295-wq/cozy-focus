# FLOW ASSET PROMPTS — dog / Mochi

Archive of every Google Flow generation attempt for the companion sprite packs.

## Why this file exists

The brief forbids relying on browser history alone: a generation that produced an
accepted frame has to be reproducible, and a rejected one has to say *why* so the
same attempt is not repeated blindly. Flow's own project is the working surface;
this is the record.

## Project

| Field | Value |
|---|---|
| Flow project | `Cozy Focus Companion Production` |
| Project id | `2f518015-e4b1-495a-9200-dc8ecbd66304` |
| Browser | user's Chrome Google session (already authenticated) |
| Image model | Nano Banana 2 (Nano Banana Pro was tried first) |
| Image default | 1:1, x1 output |
| Confirm before generating | Always (no automatic credit spend) |
| Cost policy | max 3 attempts per requested frame, then `ASSET_GENERATION_BLOCKED` |

## Identity reference

The character reference is **not** a cropped design page. It is the approved V4.1
Mochi rig — the seven transparent layers under `assets/mochi/base/` — composited
into one square master reference by
`tools/make_master_reference.py`:

| Field | Value |
|---|---|
| Source | `assets/mochi/base/{body,ear_left,ear_right,sprout,face,eye_left,eye_right}.png` |
| Composite size | 482 × 328 RGBA |
| Output | 1024 × 1024, character at 70% of canvas height, centred |
| Uploaded as | `mochi_master_ref_white.png` |

Using the rig keeps Mochi's identity exact and avoids the forbidden route of
cropping a pose out of a full-page design (which would carry scene background and
UI text by construction).

## Base prompt

Every generation uses this skeleton, adapting only the `ACTION` and `FRAME`
sections:

```text
Use the attached reference image as the exact character. Preserve its identity,
proportions, line quality, colour palette, facial features and accessory
placement exactly.

Create only a pose variation for a 2D mobile companion game.

Full body visible. Same fixed camera. Same canvas placement. Same body scale.
Clean isolated character. No text. No arrows. No UI. No additional characters.
No environment. No scene. No dramatic perspective. No redesign.

ACTION: <semantic action>
<frame description, including the prop's invariant geometry>

The image must visually connect with the previous and next frames of this action.
Plain pure white background, no shadow, no scene, no furniture.
```

The background is requested **white**, not transparent, because Flow exports
opaque JPEG at 1K. Alpha is produced locally instead — see
`tools/productionise.py` — and verified rather than assumed.

## Accepted frames

| Companion | Action | Frame | Master reference | Attempts | Accepted output | Notes |
|---|---|---|---|---|---|---|
| dog | `idle` | 000 | `mochi_master_ref_white.png` | 3 | `idle_000.jpg` | Master. First two attempts failed server-side; the third, issued after the agent chat panel was bypassed, succeeded. |
| dog | `focus_read` | 000 | `idle_000` (approved master) | 2 | `read_000.jpg` | Attempt 1 had a cream-white book; regenerated with an explicit invariant book description. |
| dog | `focus_read` | 001 | `idle_000` | 1 | `read_001.jpg` | Accepted. |
| dog | `focus_read` | 002 | `idle_000` | 1 | `read_002.jpg` | Accepted. |
| dog | `focus_write` | 000 | `idle_000` | 2 | `write_000.jpg` | Attempt 1 placed the notebook on the ground; regenerated with the notebook held at the chest. |
| dog | `focus_write` | 001 | `idle_000` | 1 | `write_001.jpg` | Accepted. |
| dog | `focus_write` | 002 | `idle_000` | 1 | `write_002.jpg` | Accepted. |
| dog | `focus_write` | 003 | `idle_000` | 1 | `write_003.jpg` | Accepted. |
| dog | `focus_think` | 000 | `idle_000` | 1 | `think_000.jpg` | Accepted. |
| dog | `focus_think` | 001 | `idle_000` | 1 | `think_001.jpg` | Accepted. Head tilt and ear lift. |
| dog | `focus_think` | 002 | `idle_000` | 1 | `think_002.jpg` | Accepted. |
| dog | `pause_rest` | 000 | `idle_000` | 1 | `pause_000.jpg` | Accepted. |
| dog | `pause_rest` | 001 | `idle_000` | 1 | `pause_001.jpg` | Accepted. |
| dog | `tap_react` | 000 | `idle_000` | 1 | `tap_000.jpg` | Accepted. |
| dog | `pet_react` | 000 | `idle_000` | 1 | `pet_000.jpg` | Accepted. |
| dog | `pet_react` | 001 | `idle_000` | 2 | `pet_001.jpg` | Attempt 1 produced an unrelated character: the reference ingredient had not attached, so the model had no identity to preserve. Regenerated with the chip verified present. |
| dog | `pet_react` | 002 | `idle_000` | 3 | `pet_002.jpg` | Attempt 1 duplicated frame 1; attempt 2 stood the character up and added a ground shadow, breaking continuity. Attempt 3 pinned the seated posture explicitly. |

## Rejected / blocked generations

| Companion | Action | Frame | Attempts | Reason |
|---|---|---|---|---|
| dog | — | — | 2 | `Failed: Sorry, this image failed to generate.` with Nano Banana **Pro**, twice. No credit charged. The agent chat panel was the failing path. |
| dog | — | — | 1 | Same failure with Nano Banana **2** while the agent panel was still driving the request. |
| dog | `tap_react` | 001, 002 | 1 each | `We noticed some unusual activity` — Flow's soft rate limit, reached after ~14 generations in one session. Not charged. Retried later; recovery confirmed. |

## Unattributed frames in the project

The Flow project contains 21 character tiles, several of which are unnamed
variations produced while the agent panel was still in the loop. They are
**not** used as production assets: a frame only becomes an asset when this
archive names its action, its frame index and its accepted output. They remain in
the Flow project as rejects and are not downloaded into the pack.

## Reproducing a frame

1. Open `Cozy Focus Companion Production` in Flow.
2. Add the approved master for that companion as an ingredient
   (`+ → All → <master tile> → Add to prompt`).
3. Paste the base prompt with the action and frame sections filled in.
4. Generate at 1:1, x1.
5. Open the result and download at **1K Original size**.
6. Stage it under `.asset_staging/flow/<companion>/<action>/<action>_<index>.jpg`.
7. Run `python tools/productionise.py <companion>` to extract alpha and normalise
   the canvas, then `python tools/manifest.py <companion>` and
   `python tools/gen_manifest_dart.py`.


## Batch 1 — idle 001-002 (generated, awaiting visual review)

V4.3 Phase 3b, batch 1. Prompts are in `idle_batch1.md`; the ingredient for
every frame is `idle_000` (the tile labelled *Character seated in neutral idle*),
not the rig and not the previous frame.

| Companion | Action | Frame | Master reference | Attempts | Staged output | Notes |
|---|---|---|---|---|---|---|
| dog | `idle` | 001 | `idle_000` | 2 | `idle_001.jpg` | First Start click was ignored; the second submitted. Tile appears as *Character breathing idle pose va…* |
| dog | `idle` | 002 | `idle_000` | 2 | `idle_002.jpg` | Submitted after a page reload. Tile appears as *Character idle animation frame*. The project grid does not show a new tile until it is reloaded. |
| dog | `idle` | 003 | `idle_000` | 1 | `idle_003.jpg` | Submitted by the user's own click in the browser; automation could not submit it. Tile appears as *Character performing idle pose*. |

Both frames were measured through `tools/productionise.py`'s own
`extract_alpha` / `normalise` / `measure` before being accepted into the pack:

| frame | visual bounds | centre | bottom | contract |
|---|---|---|---|---|
| `idle_001` | (93,124)-(929,919) | 511.0 | 919 | within 2px |
| `idle_002` | (101,124)-(922,919) | 511.5 | 919 | within 2px |
| `idle_003` | (102,123)-(921,919) | 511.5 | 919 | within 2px |

`idle_001`'s bounds are identical to the shipped `idle_000`, which is the
expected result: `normalise` scales the subject to 78% of canvas height and
centres it, so a frame drawn at a different raw scale still lands on the same
contract.

They are **not** in the pack yet. `idle`'s loop mode is `loop`, so two or three
frames would alternate faster than a breath — a flicker, which is worse than the
current still. The sequence ships when all six exist.

### Blocked: frames 004-005

`Start generation` stops accepting input after two generations in a session.
The prompt and ingredient are set up correctly and the button reports
`disabled: false`, but the Angular handler does not fire. Tried: `cua` coordinate
click, a full synthetic sequence (`pointerdown`/`mousedown`/`pointerup`/
`mouseup`/`click`), Enter in the prompt box, hover-then-click, a neutral click to
take focus first, and repeated page reloads. Frame 002 needed a reload to
submit; frames 004-005 did not submit across four reload-and-retry
cycles each.

Frame 003 is the useful data point: the same prompt and ingredient submitted
first time from the user's own click in the pane. So the request is valid and
Flow accepts it; what fails is the synthetic gesture. Two of five frames
submitted from automation, three did not, and the pattern does not track prompt
content or length.

This matches the soft rate limit already recorded above ("We noticed some
unusual activity", reached after roughly 14 generations). It may also be that
the button requires a trusted gesture the automation cannot produce.

## Batch 2 — walk: blocked, the character will not stand up

Three attempts at `walk_000`, all with `idle_000` as the ingredient.

| attempt | prompt | result |
|---|---|---|
| 1 | the shared pose-variation skeleton | silhouette IoU 0.850 against the seated reference |
| 2 | same, plus "CRITICAL: must be STANDING, not sitting... a seated pose is wrong" | IoU 0.846 |
| 3 | reordered — leads on the posture change, uses the reference for identity only | submitted; not returned |

### The check that caught it

Anchors, alpha and byte-identity all pass on these frames: they are correctly
sized, correctly placed and genuinely different from one another. None of that
notices that the character is still sitting down.

Silhouette IoU against the reference does. Both attempts land at ~0.85, and a
genuinely different posture should be well below 0.60. The two frames are the
same seated shape with the outline nudged, not a standing walk.

This is worth keeping as a gate: it is the only mechanical check here that can
tell "a different pose" from "the same pose, moved". It cannot judge whether a
pose is *good*, which remains P4B's job.

### Why this blocks more than walk

The pack's only identity reference is a seated master, and `walk`, `stand_up`
and `sit_down` all require the character to be standing. Batches 2, 3 and 4
therefore share one blocker, and the cause is not the prompts: the shared base
template opens with "preserve its identity, proportions ... create only a pose
variation", which anchors the posture as hard as it anchors the identity.

Two routes out, and the choice is a product call:

1. **Produce a standing master first** — one image of the character upright, then
   use it as the ingredient for walk, stand_up and sit_down. This keeps the
   identity mechanism intact and is what the pipeline is shaped for.
2. **Drop the ingredient for these actions** and prompt the character from text.
   Cheaper, but identity fidelity is exactly what the ingredient exists to
   guarantee, so it trades the thing the pipeline was built to protect.
