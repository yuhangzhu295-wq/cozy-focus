# FLOW ASSET PROMPTS — cat

Archive of every Google Flow generation attempt for the cat sprite pack.

## Project and settings

Same Flow project as the dog (`Cozy Focus Companion Production`), same model
(Nano Banana 2), same 1:1 / x1 output, same cost policy: **max 3 attempts per
requested frame, then `ASSET_GENERATION_BLOCKED`**.

## Identity reference

`cat_master.jpg` — the approved cat master, uploaded once and re-attached as the
identity reference for every cat action. It is a genuine cat, not a recoloured
Mochi: short triangular ears, whiskers, a small pink nose and a slim curved tail,
in the same soft rounded geometry and warm low-saturation palette, with the shared
green sprout kept so the companions read as one universe.

## Accepted frames

| Action | Frame | Reference | Attempts | Output | Notes |
|---|---|---|---|---|---|
| `idle` | 000 | `cat_master.jpg` (self) | 1 | `idle_000.jpg` | The master. First attempt. |
| `focus_read` | 000 | `cat_master.jpg` | 1 | `read_000.jpg` | Accepted. |
| `focus_read` | 001 | `read_000.jpg` (edit base) | 1 | `read_001.jpg` | Accepted once the technique changed — see below. |
| `focus_read` | 002 | `read_000.jpg` (edit base) | 1 | `read_002.jpg` | Accepted. |
| `focus_think` | 000 | `cat_master.jpg` | 1 | `think_000.jpg` | Accepted. |
| `focus_think` | 001 | `cat_master.jpg` | 1 | `think_001.jpg` | Accepted. |
| `focus_think` | 002 | `cat_master.jpg` | 2 | `think_002.jpg` | Attempt 1 was byte-identical to frame 001 — rejected by the duplicate-frame test. Regenerated with the opposite head tilt. |

## The technique that fixed the book colour

Three attempts at regenerating the cat's reading pose all returned a **blue** book
cover against the reference's warm brown. Fur, pose and identity held every time;
only the prop drifted. Regenerating gave the model freedom to reinterpret the
prop, and it took that freedom.

The fix: attach the **approved first frame as the edit base** instead of the
character master, and ask only for the eye movement, with an explicit
do-not-change list naming the book, the palette and the canvas. Both remaining
frames then came out correct on the first attempt.

**Use this for any action that carries a prop.** It is the default technique for
the rest of the pack.

## Rejected

| Action | Frame | Attempts | Reason |
|---|---|---|---|
| `focus_read` | 001 | 3 | Book cover rendered blue instead of warm brown, twice. Rejected for flashing: at 5 fps between two brown-book frames it would read as a flicker, which the acceptance criteria forbid. |
| `focus_read` | 001 | 1 | An "edit the attached image" attempt returned a completely different tortoiseshell cat with a different book. Rejected outright. |
| `focus_think` | 002 | 1 | Byte-identical to frame 001, so the return beat would not have read as movement. |

## Blocked

| Action | Frame | Attempts | Reason |
|---|---|---|---|
| `pause_rest` | 000 | 3 | `ASSET_GENERATION_BLOCKED`. Every attempt returned Flow's soft rate limit ("We noticed some unusual activity"), not charged. The limit persisted across a wait of several minutes and a fresh page load. |
| `focus_write` | all | 0 | Not attempted; generation was already blocked. |
| `tap_react` | all | 0 | Not attempted; generation was already blocked. |
| `pet_react` | all | 0 | Not attempted; generation was already blocked. |
| `celebrate` | all | 0 | Not attempted; generation was already blocked. |
| `sleep` | all | 0 | Not attempted; generation was already blocked. |

## Reproducing a frame

1. Open the project and add the identity reference (or, for a prop-carrying action,
   the approved first frame) as an ingredient: `+ → search the asset name → Add to prompt`.
2. Paste the prompt with the action and frame sections filled in.
3. Generate at 1:1, x1, then download at **1K Original size**.
4. Stage under `.asset_staging/flow/cat/<action>/<action>_<index>.jpg`.
5. Run `python tools/productionise.py cat`, then `tools/manifest.py cat` and
   `tools/gen_manifest_dart.py`.

