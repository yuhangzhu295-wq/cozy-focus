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

