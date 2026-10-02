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

---

# Session 2 — idle completed

## The finding that unblocked this: the cat has its own project

The cat's assets are **not** in `Cozy Focus Companion Production`
(`2f518015-e4b1-495a-9200-dc8ecbd66304`). They are in the project titled
`Oct 01 - 01:20` (`49593efa-15ca-47a4-9967-79892b5f4260`), where every cat asset
is named **"Kitten …"** (`Kitten sitting idle`, `Kitten reading a book`,
`cat_master.jpg`, …).

This is why searching the dog's project for `cat`, `kitten`, `feline`,
`whiskers`, `tabby` or `pink nose` returned **"No assets found"** — the search is
scoped to the open project, and the cat simply is not in that one. Generate cat
frames in the kitten project.

## A wrong reference was caught before it did damage

In the dog's project the tile named *"Character seated in neutral idle"* was
attached as the identity reference. Fetching the attached image's URL and
looking at it showed the **floppy-eared dog/rabbit**, not the cat. The asset
names there are generated descriptions, so the name gives no reliable signal.

**Verify the reference image itself before generating.** The cheap method used
here, which does not depend on the screenshot surface (it times out on this
page):

1. Attach the candidate as an ingredient.
2. Read the ingredient image's `src` from the DOM.
3. `curl` that URL locally and look at it.

In the kitten project the same method confirmed `cat_master.jpg` is the cat, and
its silhouette matched the local `.asset_staging/refs/cat_master.jpg` exactly.

## Accepted this session

| Action | Frame | Reference | Attempts | Notes |
|---|---|---|---|---|
| `idle` | 001 | `cat_master.jpg` | 1 | "Cat starting breath idle pose". Accepted. |
| `idle` | 002 | `cat_master.jpg` | 1 | "Cat breathing pose variation". Accepted. |
| `idle` | 003 | `cat_master.jpg` | 2 | Attempt 1 produced **no tile at all** — the 99% progress bar finished and the tile count went 24 → 23. Attempt 2 ("Cat exhaling animation frame") accepted. |
| `idle` | 004 | `cat_master.jpg` | 1 | "Cat sitting idle exhale pose". Accepted. |
| `idle` | 005 | `cat_master.jpg` | 1 | "Cat returning to resting pose". Accepted; loops back onto frame 000. |

A six-frame contact sheet (000–005) was checked before import: identity, palette,
camera and placement hold across the cycle, and 005 is a near-neighbour of 000
so the loop closes without a jump.

The cat has **open eyes**, unlike the dog's closed happy arcs, so a blink
channel is expressible for this pack. The idle loop deliberately does not carry
one — a 6-frame loop at 5 fps is 1.2 s, which would read as a twitch.

## Also imported

`focus_write` 000–001 were already staged from the earlier session and were
imported alongside the idle frames. The action is 2 of its 4 target frames, so it
still does not satisfy the contract; it is imported because the frames exist and
the manifest reports the true count.

## Pipeline note

`tools/productionise.py` treats **every** directory under
`.asset_staging/flow/<companion>/` as an action. The `_verify/` scratch directory
used for reference checking was therefore imported as three bogus assets
(`_verify_flow.png`, `_verify_sheet.png`, `_verify_ingredient.png`). Keep
verification scratch outside that tree, or delete it before running the import.

## State after this session

cat: **6 actions / 21 frames**. `idle` is complete (6/6). Still missing:
`walk` (0/6), `sit_down` (0/4), `stand_up` (0/4), `craft_work` (0/4),
`focus_write` (2/4), `pet_react` (0/3), `tap_react` (0/3), `sleep` (0/2).

---

# Session 3 — walk completed

## Why walk was the priority

`walk` is the room's core presentation: the companion walks between anchors when
the player places furniture or the simulation picks a new seat. Without it the
cat has no locomotion frames, so it presents as idle while it moves — the
"sliding still image" failure the sprite pipeline exists to remove. It outranks
the remaining actions on player-visible impact.

## A standing master had to come first

The cat's approved master is **seated**, and walk is a standing action. The
archive's own law — a prop- or posture-carrying action must use a master in that
posture, or the model drifts — applies here, so a standing master was generated
first from `cat_master.jpg`:

| Frame | Reference | Attempts | Notes |
|---|---|---|---|
| standing master | `cat_master.jpg` | 1 | "Cat standing in master pose". Identity, palette, camera and scale preserved; the tail's S-curl and the sprout carried over exactly. |

The standing master is now in the kitten project, so subsequent standing actions
should attach **that** tile rather than `cat_master.jpg`. A local copy is kept at
`.asset_staging/refs/cat_standing_master.jpg` for reference.

## Accepted this session

All six walk frames were generated with the **standing master** attached, at
1:1 / x1:

| Frame | Tile name | Attempts |
|---|---|---|
| `walk_000` | Cat walking pose variation | 2 |
| `walk_001` | Cat walking frame two | 1 |
| `walk_002` | Cat walking action pose | 1 |
| `walk_003` | Cat walking walking pose | 1 |
| `walk_004` | Cat walking frame five | 1 |
| `walk_005` | Cat walking pose variation | 1 |

The cycle is contact → passing → opposite contact → passing → return → close,
with the tail trailing and the sprout leaning back.

## The shadow defect, and a process lesson

The first `walk_000` came back with a **grey drop shadow** under the paws. The
contract requires a clean isolated character on pure white, and
`tools/productionise.py` would have carried that shadow into the game as a grey
blob. It was caught by building a contact sheet of the whole cycle and looking at
it, and regenerated with an explicit no-shadow clause:

```
CRITICAL: absolutely no shadow of any kind. No drop shadow, no ground shadow,
no contact shadow, no grey ellipse under the paws, no grey smudge on the ground
line. The background must be pure flat white with nothing but the character on it.
```

That clause is worth carrying on every future prompt.

**The lesson:** the first contact sheet included the standing master as its first
cell, which shifted every later index by one, and the shadow was attributed to
`walk_001` instead of `walk_000`. `walk_001` was regenerated needlessly. **Index
the sheet to match the frame filenames exactly, or the frame you fix is not the
frame that is broken.**

A numeric shadow probe (darkest pixel in the lower band) did **not** discriminate:
the character's own dark outline sits in that band on every frame, so the test
always reported a dark pixel. Looking at the sheet is what worked.

## Pipeline note

`_standing_master.jpg` was initially left inside
`.asset_staging/flow/cat/walk/`, where `productionise.py` would have imported it
as a seventh walk frame. Keep reference images out of the per-action staging
directory — `.asset_staging/refs/` is the place for them.

## State after this session

cat: **7 actions / 27 frames**. Complete: `idle` (6/6), `walk` (6/6),
`celebrate` (5/5), `focus_read` (3/3), `focus_think` (3/3), `pause_rest` (2/2).
Partial: `focus_write` (2/4). Missing: `sit_down` (0/4), `stand_up` (0/4),
`craft_work` (0/4), `pet_react` (0/3), `tap_react` (0/3), `sleep` (0/2).

---

# Session 4 — sit_down and stand_up

## Why these two

The animation state machine's posture hops depend on them. Without
`sit_down`/`stand_up` the cat hard-cuts between standing and seated: a walk that
ends on a seat snaps, and a seat that becomes a walk pops. They are the pair
that makes `walk` usable rather than merely present.

## Accepted this session

**sit_down** — frames 1–3 generated from the **standing master**, frame 4 from
the **seated master**:

| Frame | Reference | Attempts |
|---|---|---|
| `sit_down_000` | standing master | 1 |
| `sit_down_001` | standing master | 1 |
| `sit_down_002` | standing master | 1 |
| `sit_down_003` | `cat_master.jpg` (seated) | 1 |

Frame 4 deliberately uses the seated master, not frame 3, because the animation
hands over from `sit_down` to `idle` — the last transition frame has to match the
pose it hands over to, not the frame before it.

**stand_up** — frames 1–3 from the **seated master**, frame 4 from the
**standing master**:

| Frame | Reference | Attempts |
|---|---|---|
| `stand_up_000` | `cat_master.jpg` (seated) | 2 |
| `stand_up_001` | `cat_master.jpg` (seated) | 1 |
| `stand_up_002` | `cat_master.jpg` (seated) | 1 |
| `stand_up_003` | standing master | 2 |

Symmetric rule: the first frame matches the pose it comes from, the last frame
matches the pose it hands over to.

## Two failures worth recording

**Silent no-tile failures.** `stand_up` frame 1 attempt 1 finished its progress
bar and produced **no tile at all** — the same failure mode as `idle` frame 3
attempt 1. A retry succeeded. The check that catches this is comparing the newest
tile's image id against the previous one; the progress bar disappearing is not
evidence of success.

**A search that returned my own output.** The search box matches generated tile
names. After the first `stand_up` frames existed, searching **"standing"**
returned *my own* `stand_up` frame rather than the standing master, and the
wrong reference was attached. The resulting frame 4 came back with the tail
raised and straight instead of the master's curled S — a continuity break
against `walk` and `idle`-standing.

The fix has two parts, and both are worth keeping:

1. Search by a term only the master carries. **"master pose"** finds
   *Cat standing in master pose*; "standing" no longer does.
2. Verify the attached image id against the master's known id before generating.
   The ingredient `src` carries a stable UUID — `bc6ad0f6…` for the standing
   master — so the check is exact, not a judgement call.

Frame 4 was regenerated with an explicit tail clause:

```
CRITICAL: the tail must keep the exact curled S shape it has in the attached
reference. Do not lift it, straighten it or raise it behind the body.
```

## State after this session

cat: **9 actions / 35 frames**. Complete: `idle` (6/6), `walk` (6/6),
`sit_down` (4/4), `stand_up` (4/4), `celebrate` (5/5), `focus_read` (3/3),
`focus_think` (3/3), `pause_rest` (2/2). Partial: `focus_write` (2/4).
Missing: `craft_work` (0/4), `pet_react` (0/3), `tap_react` (0/3), `sleep` (0/2).
