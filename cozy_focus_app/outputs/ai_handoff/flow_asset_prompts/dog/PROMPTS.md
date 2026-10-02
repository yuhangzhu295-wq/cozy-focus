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

### Standing master — four strategies, none of them stood the character up

Route 1 from the section above, attempted. Every attempt used `idle_000` as the
ingredient and asked, in a different way, for the character upright.

| attempt | prompt | IoU vs the seated reference |
|---|---|---|
| A | the shared pose-variation skeleton | 0.850 |
| B | A plus "CRITICAL: must be STANDING, not sitting... a seated pose is wrong" | 0.846 |
| C | posture-first: "ignore its posture completely... fully upright on its legs" | — |
| D | x4 batch of C, first candidate measured | 0.892 |

All four land at 0.85-0.89. A genuinely standing pose would be well below 0.60.
The reference image dominates the posture so completely that an explicit
"ignore its posture" clause changes nothing, and one attempt scored *higher*
than the plain pose-variation prompt.

Six tiles in the project carry standing-ish labels ("Puppy standing up",
"Puppy walking standing up", and so on). The one that could be measured is the
same seated shape; the rest could not be opened reliably enough to measure,
because clicking a tile from the grid does not consistently switch the editor to
that tile and two of them share a label, so the fetch returned the previously
opened image.

### What this means

`walk`, `stand_up` and `sit_down` all need a standing pose, and the pack has
none. The blocker is the reference art, not the prompts and not the pipeline:
the gate passed every one of these frames on canvas, anchor and frame-to-frame
difference, because none of those checks can see posture.

A text-only attempt (no ingredient, the character described in words) is staged
in the prompt box as the last untried route. It trades the identity guarantee
the ingredient exists to provide, which is why it was route 2 and not route 1.

### Standing master — route 1 works, and how it was missed

The x4 batch of strategy C **did contain a standing pose**. It was missed because
only the first candidate was measured and the other three could not be opened:
clicking a tile from the grid does not reliably switch the editor, and two tiles
share the label "Puppy standing up", so the fetch returned the previously opened
image — two files came back byte-identical before that was noticed.

Measured across all four:

| candidate | IoU vs seated ref | aspect | verdict |
|---|---|---|---|
| cand_a (grid idx 0) | 0.892 | 1.024 | seated |
| s1 (grid idx 1) | **0.632** | **0.785** | **standing** |
| s2 (grid idx 2) | 0.724 | 0.852 | changed |
| s3 (grid idx 3) | 0.890 | 1.024 | seated |

The seated reference is 1.049 wide-to-tall; s1 is 0.785, a 25% narrower
silhouette, which is what a standing quadruped looks like next to a seated one.
`s1` is kept as `standing_master.jpg` and is the identity reference for the
standing actions.

**Measure every candidate before concluding.** The first attempt concluded "the
character will not stand up" from one of four samples.

### walk with the standing master

`walk_000` used it and came out standing, contract-compliant:

| comparison | IoU |
|---|---|
| walk_000 vs seated reference | 0.638 |
| walk_000 vs standing master | 0.857 |

aspect 0.776, bottom 919, centre delta 0.5.

### The picker cannot be selected by position

`walk_001` and `walk_002` drifted back to the seated shape (aspect 0.996 and
0.982). The cause was the ingredient picker: it was being selected by a
hard-coded y coordinate, and the picker list grows as tiles are added, so the
same y pointed at a different image in each call. Two tiles also share the label
"Puppy standing up", so the label alone is ambiguous.

Selection must be by a **unique label**. `walk_000`'s own label ("Character
walking contact pose...") is unique and it is a standing walk pose, so the
remaining walk frames use it as the ingredient rather than the standing master.

### Submission is rate-limited

`Start generation` accepts roughly two submissions and then stops responding.
A ~100 second quiet period followed by a single click usually works; a second
immediate click does not, and rapid retries make it worse. Roughly a quarter of
the attempts in this batch needed a second quiet period.

## Working recipe (verified end to end)

Everything below was established by doing it, not by reading. Follow it exactly;
each step exists because skipping it failed.

**1. Ingredient: select by unique label, never by position.**
The picker list grows as tiles are added, so a hard-coded y coordinate points at
a different image on the next call — that is what made walk_001 and walk_002
drift back to the seated shape. Two tiles also share the label "Puppy standing
up", so that label is ambiguous too. Use `walk_000`'s label
("Character walking contact pose"), which is unique and is itself a standing
walk pose. For the standing master the reliable handle is `s1`'s grid position,
measured before use.

**2. Submit: one quiet period, then one click.**
`Start generation` accepts about two submissions and then stops responding. Wait
90-100 seconds with no clicks at all, then click once. Rapid retries make it
worse, not better. Roughly a quarter of attempts need a second quiet period.

**3. Open a tile with a dispatched click.**
Neither a coordinate click nor a double-click reliably switches the editor.
Dispatch `pointerdown`/`mousedown`/`pointerup`/`mouseup`/`click` on the tile's
`img`, then `click()` the card. Verify the URL now contains `/edit/` **before**
fetching; without that check the fetch returns the previously opened image, and
two files came back byte-identical before this was caught.

**4. Verify every frame, every time.**
Fetch the 1024 image and measure silhouette IoU against both references plus the
aspect ratio and the anchor. A frame is accepted only when it is close to the
standing reference, far from the seated one, and inside the 2px contract.

## Batch 2 status

| frame | vs seated | vs standing | aspect | anchor | verdict |
|---|---|---|---|---|---|
| walk_000 | 0.638 | 0.857 | 0.776 | 919 | standing |
| walk_001 | 0.613 | 0.860 | 0.772 | 919 | standing |
| walk_002 | 0.662 | 0.822 | 0.785 | 919 | standing |
| walk_003 | 0.632 | 0.822 | 0.767 | 919 | standing |
| walk_004 | — | — | — | — | prompt staged; submission refused across three quiet periods |
| walk_005 | — | — | — | — | not started |

Four of six, all verified. The seated reference measures 1.049 wide-to-tall and
the standing frames measure 0.77-0.79, so they are unambiguously a different
posture rather than the seated shape moved.

## What is shipped

`idle` is complete: six frames, in the pack, in the APK, 1018/1018 tests. The
walk frames are staged and **not** in the pack — a partial walk cycle would be
worse than none, for the same reason a partial idle was.

`stand_up` and `sit_down` are not started. Both need the standing reference, and
both are contracted in `tools/manifest.py`.

## Batch 3 — stand_up: complete

Four frames, shipped. Frame 000 uses the seated master as its ingredient and
001-003 use `walk_000`, which is both a standing pose and the pose stand_up
hands over to, so the transition ends where the walk cycle begins.

| frame | vs seated | vs standing | aspect |
|---|---|---|---|
| stand_up_000 | 0.975 | 0.633 | 1.055 |
| stand_up_001 | 0.755 | 0.795 | 0.834 |
| stand_up_002 | 0.638 | 0.965 | 0.771 |
| stand_up_003 | 0.638 | 0.953 | 0.773 |

The seated reference measures 1.049 wide-to-tall and the standing one 0.776. The
aspect walks 1.055 -> 0.834 -> 0.771 -> 0.773 across the four frames, so the
transition genuinely happens rather than being four variations of one pose.
That is the check the anchor, alpha and byte-difference gates cannot make.

## Batch 4 — sit_down: 1 of 4

`sit_down_000` generated ("Character starting sitting down"), staged and
measured at aspect 1.055 with the seated reference as its ingredient.

`sit_down_001`'s prompt is staged and its submission was refused across three
quiet periods, so the rate limit is again the binding constraint rather than the
method.

## Where the batch set stands

| batch | frames | state |
|---|---|---|
| idle | 6 | shipped, in the APK |
| walk | 6 | shipped, in the APK |
| stand_up | 4 | shipped, in the APK |
| sit_down | 4 | 1 staged, 3 not generated |

Seventeen of twenty frames are in the pack. `MOCHI_FIRST_BATCH_PENDING` reports
`sit_down 0/4`.

## Batch 4 — sit_down: generated, but the transition does not transition

All four frames are generated and staged, and all four pass the anchor, alpha and
distinctness checks. The measurement shows the sequence is still wrong:

| frame | vs seated | vs standing | aspect |
|---|---|---|---|
| sit_down_000 | 0.640 | 0.978 | 0.775 |
| sit_down_001 | 0.984 | 0.633 | 1.050 |
| sit_down_002 | 0.973 | 0.642 | 1.048 |
| sit_down_003 | 0.984 | 0.639 | 1.044 |

Frame 000 is the standing shape and 001-003 are all the seated shape. The
sequence is a one-frame cut from standing to sitting, not a descent: frames 001
and 002 are indistinguishable from 003 in aspect and in IoU.

The cause is the same one that made walk drift, and it is worth stating plainly
because it is the single most useful thing this batch taught:

**The ingredient reference dominates the prompt.** Frames 001-003 used the seated
master as their ingredient, so the model returned seated poses no matter how the
prompt described the movement. Compare stand_up, where frames 001-003 used the
standing reference and frame 001 landed at aspect 0.834 - a genuine midpoint.

The fix is to mirror stand_up: anchor the *early* frames of sit_down to the
standing reference and only the final frame to the seated one, so the model is
not pre-committed to the destination.

`sit_down_001` was regenerated with the standing reference and the submission was
refused across two quiet periods, so the batch is not yet correct in the pack.
**It is deliberately not shipped.** A four-frame "sit down" that cuts straight to
seated is the same class of defect as a single-frame idle: it passes every
mechanical gate and still looks wrong.

### sit_down: the midpoint cannot be generated from either endpoint

Three attempts at `sit_down_001`, each with a different reference and a different
strength of wording:

| ingredient | wording | resulting aspect | reading |
|---|---|---|---|
| seated master | "lowering... clearly not yet seated" | 1.050 | fully seated |
| standing ref | "still mostly upright, only the first hint of a fold" | 0.780 | fully standing |
| standing ref | "already dropped well below standing height, haunches close to the ground" | 1.246 | neither - wider than seated, IoU 0.463 to standing |

The seated reference produces seated. The standing reference with cautious
wording produces standing. The standing reference with forceful wording produces
a distorted pose that is wider than either endpoint.

**The reference determines the pose and the prompt only moves it off that pose in
a different direction; it does not interpolate between the two.** That is why
`stand_up` worked - its frames 001-003 were anchored to standing and its frame
001 happened to land at aspect 0.834, between the endpoints - and why `sit_down`
has not.

Two honest routes, and both are product calls rather than technical ones:

1. **Reverse `stand_up`.** It already contains a genuine midpoint (0.834) and a
   real descent when read backwards: 003 -> 002 -> 001 -> 000 is standing -> mid
   -> mid -> seated. Reusing a verified sequence in reverse is ordinary practice
   for a four-frame 2D transition, but the art was authored for rising, and
   whether it reads correctly as lowering cannot be judged without eyes on it.
2. **Declare `sit_down` as a two-frame cut** in the contract and ship it as one.
   Honest, and visibly a cut.

`sit_down` is not shipped. A four-frame sit-down that cuts straight to seated
passes every mechanical gate - canvas, anchor, alpha, distinctness - and still
looks wrong, which is the same class of defect as the single-frame idle.
