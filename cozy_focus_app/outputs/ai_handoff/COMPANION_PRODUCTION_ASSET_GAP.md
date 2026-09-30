# COMPANION_PRODUCTION_ASSET_GAP

Project: COZY_FOCUS
Scope: production companion pose assets (dog / cat / rabbit)
Status: **POSE_ASSET_GAP = YES** — no companion has production pose art
Author: ZCode (single-model round; independent review deferred by owner)

---

## 1. Summary

The runtime is complete and every pose is *semantically* implemented. What does
not exist is **production pose art**. Three facts define the gap:

1. **The dog has one pose, articulated — not a pose pack.** Mochi's art is a
   single sitting illustration decomposed into 7 transparent layers. It can be
   posed, squashed and re-propped, but it cannot become a *different silhouette*,
   because there is only one drawing of the character.
2. **The cat and rabbit have no production art at all.** They are drawn
   procedurally in code as placeholders — correct species, shared pose
   vocabulary, but not painted art.
3. **The pose references exist only inside page and scene compositions.** The
   design packages show poses as part of a full-page illustration. None of them
   is an isolated, transparent, baseline-aligned asset.

Therefore every "pose" the app presents today is either the one approved
silhouette under a different transform, or a code-drawn prop layered onto it.
That is honest and it is visibly not finished art.

**ZCode must not close this gap by generating crude programmer art, and must not
crop poses out of the design pages.** Both are explicitly forbidden by the task.
This document is the specification a human artist works from instead.

---

## 2. What exists today (exact inventory)

### 2.1 Repository assets

| Path | What it is | Usable as a pose? |
|---|---|---|
| `assets/mochi/base/body.png` | 482×328 RGBA, alpha | part of the one rig |
| `assets/mochi/base/face.png` | 482×328 RGBA, alpha | part of the one rig |
| `assets/mochi/base/ear_left.png` | 482×328 RGBA, alpha | part of the one rig |
| `assets/mochi/base/ear_right.png` | 482×328 RGBA, alpha | part of the one rig |
| `assets/mochi/base/eye_left.png` | 482×328 RGBA, alpha | part of the one rig |
| `assets/mochi/base/eye_right.png` | 482×328 RGBA, alpha | part of the one rig |
| `assets/mochi/base/sprout.png` | 482×328 RGBA, alpha | part of the one rig |
| `assets/mochi/base/layers.json` | z-order, pivots, source ROI | — |
| `assets/companion/*.json` | behaviour / profile / room recipes | data, not art |
| `assets/animations/`, `assets/images/`, `assets/sounds/` | empty (`.gitkeep`) | — |

The rig is documented as extracted from V4.1 `designs/pages/10_Mochi成长.png`,
ROI `330,495 560×405`, character crop `482×328`, `feather_px: 3`. It is
**PRODUCTION_READY as a rig**, and it is the only production art in the project.

### 2.2 Design references available

| Source | Contents | Usable as an asset? |
|---|---|---|
| V4.1 `designs/motion/11A–11K` | Idle Breathe, Idle Sway, Blink, Ear Twitch, Tail Wag, Focus Work, Craft, Pause, Celebrate, Sleep, Greeting | **REFERENCE_ONLY** — motion channel specs, not cut-out poses |
| V4.1 `designs/pages/01–10B` | Full page designs | **REFERENCE_ONLY** — compositions, not assets |
| V4.2.1 `designs/motion/20A–20F` | Mochi multi-work-pose ref, Mochi craft ref, cat focus ref, rabbit pet ref, workshop scene, room-inventory interaction ref | **REFERENCE_ONLY** — pose *intent* inside a scene |
| V4.2.1 `designs/pages/01–11E` | Full page designs incl. 03A/03B/04/05/07/08/09/10A/10B/11A–11E | **REFERENCE_ONLY** |

Nothing in either package is an isolated transparent pose with a recorded
baseline. That is the whole of the gap.

---

## 3. Minimum production pose pack (required contract)

Per the task, **12 required poses** for each of dog, cat, rabbit:

| # | Pose id | Semantic meaning |
|---|---|---|
| 01 | `idle` | neutral, ambient |
| 02 | `focus_read` | reading — head down, prop forward |
| 03 | `focus_write` | writing — deepest bow, prop at hand |
| 04 | `focus_think` | thinking — head up, thought bubbles |
| 05 | `pause_rest` | resting, eyes lowered |
| 06 | `tap_react` | brief acknowledgement |
| 07 | `pet_react` | long-press response, affectionate |
| 08 | `craft_work` | working on a craft job |
| 09 | `celebrate` | completion |
| 10 | `sleep` | asleep |
| 11 | `room_sit` | sitting on furniture |
| 12 | `room_work` | working at a room anchor |

Optional: `room_read`, `room_sleep`, `greeting`, `growth_showcase`.

### 3.1 Format rules

- **Transparent PNG.** SVG only where the source is genuinely vector-compatible.
- **Never**: cropped full-page UI screenshots, leftover background, leftover
  text, leftover arrows, low-resolution contaminated crops.
- **Never**: a recoloured dog presented as the cat or the rabbit. They are
  different characters with different anatomy (see §5.2).

### 3.2 Artboard coordinate contract

One standard artboard for every pose of every companion, so that **switching a
pose never makes the companion jump**.

| Field | Meaning |
|---|---|
| `canvas` | `width × height` in artboard units — identical for every pose of a companion |
| `visualBounds` | the inked bounding box inside the canvas |
| `groundBaseline` | y of the ground contact line, in canvas units |
| `centerAnchor` | x of the character's vertical centre |
| `headAnchor` | head-group origin, for head-channel rotation |
| `interactionAnchor` | where a tap/pet response visually originates |
| `roomFeetAnchor` | the point that meets furniture when sitting or lying |

The app already has the two corrections this prevents, measured and tested:
`MochiLayerAssets.feetInsetFraction` (how far the feet sit above the square
box's bottom edge) and `PetSeatPlacement.feetY`. A production pack must carry
these as data so the same arithmetic is not re-derived per companion.

### 3.3 Asset manifest (proposed layout)

```
assets/companions/
  dog/
    manifest.json
    idle.png
    focus_read.png
    ...
  cat/
  rabbit/
```

Each `manifest.json` records, per pose: `companionId`, `poseId`, `path`,
`canvas`, `baseline`, `visualBounds`, `microMotionCompatibility`,
`roomAnchorMetadata`.

### 3.4 Integration cost when the art lands

The architecture already supports asset-backed providers. Adding the pack should
require **only**:

1. the asset files,
2. a profile/manifest update,
3. one `CompanionVisualProvider` per companion (already the extension point).

**No page changes.** If integrating production art turns out to require editing
pages, that is an architecture regression and must be reported as one — the
fourth-companion contract test exists precisely to catch that class of drift.

---

## 4. Classification of existing material

| Material | Classification |
|---|---|
| Mochi 7-layer rig | **PRODUCTION_READY** (as a rig — one pose only) |
| V4.1 `11A–11K` motion designs | **REFERENCE_ONLY** |
| V4.1 page designs | **REFERENCE_ONLY** |
| V4.2.1 `20A–20F` motion/scene designs | **REFERENCE_ONLY** |
| V4.2.1 page designs | **REFERENCE_ONLY** |
| Cat / rabbit | **MISSING** — nothing at all |
| Any isolated transparent pose | **MISSING** |

---

## 5. Gap table

`STATUS` is one of `READY` / `NEEDS_CLEANUP` / `MISSING`.

### 5.1 Dog (Mochi)

| POSE | REFERENCE_DESIGN | CURRENT_RUNTIME_IMPLEMENTATION | PRODUCTION_ASSET | STATUS | REQUIRED_ACTION |
|---|---|---|---|---|---|
| `idle` | V4.1 11A/11B; rig from 10_Mochi成长 | 7-layer rig, breathe + sway + blink + ear + sprout channels | the rig itself | **READY** | none — this is the one production-ready pose |
| `focus_read` | V4.2.1 20A, 03A | rig + head bow + narrowed eyes + code-drawn open book | none | **MISSING** | author a reading silhouette (book held, distinct outline) |
| `focus_write` | V4.2.1 20A, 03A | rig + deepest bow + code-drawn notebook + pencil | none | **MISSING** | author a writing silhouette (notebook at hand, prop-free outline) |
| `focus_think` | V4.2.1 20A | rig + head up + code-drawn thought bubbles | none | **MISSING** | author a thinking silhouette (head up, paw to chin) |
| `pause_rest` | V4.2.1 04 | rig + lowered eyes + code-drawn resting marks | none | **MISSING** | author a resting silhouette (settled, eyes closed) |
| `tap_react` | V4.2.1 20D family | rig + code-drawn exclamation mark | none | **MISSING** | author a startle/acknowledge silhouette |
| `pet_react` | V4.2.1 20D | rig + code-drawn heart | none | **MISSING** | author a contented/affectionate silhouette |
| `craft_work` | V4.2.1 20B, 20E | rig + bow + code-drawn mallet and spark | none | **MISSING** | author a making silhouette (tool in paw) |
| `celebrate` | V4.1 11I; V4.2.1 05 | rig + upward posture + code-drawn confetti | none | **MISSING** | author a celebratory silhouette (up on paws, distinct outline) |
| `sleep` | V4.1 11J; V4.2.1 11E | rig + closed eyes + code-drawn Z marks | none | **MISSING** | author a sleeping silhouette (curled, lying) |
| `room_sit` | V4.1 09; V4.2.1 09 | rig at a resolved seat anchor | none | **MISSING** | author a seated silhouette with a recorded feet anchor |
| `room_work` | V4.2.1 09, 20E | rig at a `work` anchor | none | **MISSING** | author a desk-working silhouette with a recorded feet anchor |

Dog: **1 / 12 READY**, 11 MISSING.

### 5.2 Cat

| POSE | REFERENCE_DESIGN | CURRENT_RUNTIME_IMPLEMENTATION | PRODUCTION_ASSET | STATUS | REQUIRED_ACTION |
|---|---|---|---|---|---|
| `idle` | V4.2.1 20C, 08 | procedural: triangle ears, whiskers, slender tail; breathe + blink | none | **MISSING** | author the character; anatomy must differ from the dog |
| `focus_read` | V4.2.1 20C | procedural + open-book prop | none | **MISSING** | author |
| `focus_write` | V4.2.1 20C (computer) | procedural + notebook prop | none | **MISSING** | author; the reference shows a *computer*, not a notebook — product decision |
| `focus_think` | V4.2.1 20C | procedural + thought bubbles | none | **MISSING** | author |
| `pause_rest` | V4.2.1 04 (dog ref) | procedural + lowered eyes | none | **MISSING** | author a cat-specific rest |
| `tap_react` | — | procedural + exclamation | none | **MISSING** | author |
| `pet_react` | V4.2.1 20D (rabbit ref) | procedural + heart | none | **MISSING** | author a cat-specific response |
| `craft_work` | V4.2.1 20E (scene) | procedural + mallet | none | **MISSING** | author |
| `celebrate` | — | procedural + confetti | none | **MISSING** | author |
| `sleep` | V4.2.1 11E | procedural + Z marks | none | **MISSING** | author |
| `room_sit` | V4.2.1 09 | procedural at seat anchor | none | **MISSING** | author |
| `room_work` | V4.2.1 20E | procedural at work anchor | none | **MISSING** | author |

Cat: **0 / 12 READY**, 12 MISSING.

### 5.3 Rabbit

| POSE | REFERENCE_DESIGN | CURRENT_RUNTIME_IMPLEMENTATION | PRODUCTION_ASSET | STATUS | REQUIRED_ACTION |
|---|---|---|---|---|---|
| `idle` | V4.2.1 20D, 08 | procedural: long ears, puff tail; breathe + blink | none | **MISSING** | author the character |
| `focus_read` | — | procedural + open-book prop | none | **MISSING** | author |
| `focus_write` | — | procedural + notebook prop | none | **MISSING** | author |
| `focus_think` | — | procedural + thought bubbles | none | **MISSING** | author |
| `pause_rest` | — | procedural + lowered eyes | none | **MISSING** | author |
| `tap_react` | — | procedural + exclamation | none | **MISSING** | author |
| `pet_react` | V4.2.1 20D | procedural + heart | none | **MISSING** | author; 20D is the one rabbit-specific reference |
| `craft_work` | V4.2.1 20E (scene) | procedural + mallet | none | **MISSING** | author |
| `celebrate` | — | procedural + confetti | none | **MISSING** | author |
| `sleep` | V4.2.1 11E | procedural + Z marks | none | **MISSING** | author |
| `room_sit` | — | procedural at seat anchor | none | **MISSING** | author |
| `room_work` | — | procedural at work anchor | none | **MISSING** | author |

Rabbit: **0 / 12 READY**, 12 MISSING.

### 5.4 Totals

| Companion | READY | NEEDS_CLEANUP | MISSING | Required |
|---|---|---|---|---|
| dog | 1 | 0 | 11 | 12 |
| cat | 0 | 0 | 12 | 12 |
| rabbit | 0 | 0 | 12 | 12 |
| **total** | **1** | **0** | **35** | **36** |

`POSE_ASSET_GAP = YES`

---

## 6. Product decisions this raises

These are the owner's to make; they change the art brief, not the code.

1. **Cat `focus_write`.** The V4.2.1 reference (20C) shows the cat at a
   *computer*, not a notebook. The runtime currently gives it the shared
   notebook prop. Either author a computer pose, or accept the notebook.
2. **How distinct must the 12 poses be per companion?** 36 assets is the full
   contract. A cheaper brief — 4 silhouettes per companion (idle, work, rest,
   celebrate) plus shared props — would cover the visible states at a third of
   the art cost.
3. **Cat and rabbit anatomy.** They must be authored as their own characters.
   The current placeholders define the intended silhouettes (triangle ears +
   whiskers + slender tail; long ears + puff tail), and those should be treated
   as the brief rather than replaced with recoloured dogs.
4. **Whether to keep the procedural placeholders** as the shipping fallback
   until real art lands. They are honest, tested, and animated.

---

## 7. What ZCode did not do, and why

- **Did not generate the pose art.** The task forbids producing crude
  programmer art to turn `ASSET_GAP` into `PASS`. A procedurally drawn cat is
  acceptable as a *technical placeholder*; 36 of them presented as finished
  production art would be a lie.
- **Did not crop poses out of the design pages.** Explicitly forbidden: no
  full-page screenshots, no leftover background/text/arrows, no low-resolution
  contaminated crops. The designs are also scene compositions, so a crop would
  carry background and text by construction.
- **Did not recolour the dog.** The cat and rabbit have different anatomy; a
  recoloured Mochi would be exactly the substitution the brief forbids.
- **Did not create a production keystore.** Out of scope for this round; see
  the release-signing blocker in the main gate report.

---

## 8. How to close this gap

1. An artist authors the 36 poses against §3.2's artboard contract.
2. Each companion gets a `manifest.json` per §3.3.
3. A `CompanionVisualProvider` per companion reads the manifest and reports the
   poses it really has in `productionPoses` — which is what turns `ASSET_GAP`
   into `READY` *truthfully*, per pose, rather than per companion.
4. `CompanionAssetResolver` already reports the gap per `(companion, pose)`, so
   a partial pack lands as a partial improvement with no code change.

Until then the runtime keeps reporting `ASSET_GAP`, which is the correct answer.
