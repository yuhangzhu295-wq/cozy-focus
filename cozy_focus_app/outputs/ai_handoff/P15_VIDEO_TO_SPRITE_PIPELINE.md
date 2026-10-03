# P15 — Flow video → sprite keyframes

A second asset-production path: instead of generating one still per frame, take a
short **video** of the action and derive the sprite frames from it, so the motion
is real and the frames are samples of one continuous movement rather than
independent guesses.

**No business code was touched.** `FocusSessionEngine`, `RewardLedger`,
`Inventory`, `CraftEngine` and the `BehaviorDirector` semantics are untouched —
this is tooling and assets only.

---

## 1. Audit — what was reused, not rebuilt

| Existing | Reused as |
|---|---|
| `tools/productionise.py` | **imported**, not copied. `extract_alpha`, `normalise`, `write_sprite`, `measure` and the canvas constants are the same code the still pipeline runs. |
| `tools/manifest.py` | unchanged; still the step that emits `manifest.json` from the frames |
| `tools/gen_manifest_dart.py` | unchanged |
| `test/support/png_probe.dart` | unchanged; the anchor measurements the integrity suite makes |
| `sprite_animation_asset_integrity_test.dart` | unchanged; the gate the output must satisfy |
| `CompanionSpritePlayer` | unchanged; it loads the same PNGs |

There is exactly **one** implementation of the canvas contract. `video_to_sprite`
orchestrates and adds selection plus QA; it does not re-derive alpha or placement.

The output must satisfy every gate the still pipeline does — 512×512, alpha,
on the baseline, centred on the anchor, no duplicates, a measurable character —
and `load_contract` reads `groundBaseline`, `centerAnchor`, `anchorTolerancePx`
and `canvas` from the companion's `animation_manifest.json`, the same file the
integrity suite reads.

---

## 2. The pipeline

```
video.mp4
  -> ffprobe          validate: video stream, >= 256x256, fps, duration, frame count
  -> ffmpeg -vsync 0  decode every frame to PNG
  -> sharpness        variance of Laplacian, per frame
  -> signature        cropped-to-character grey fingerprint, per frame
  -> selection        reject blurred, then greedily take the most novel frame
  -> stage            write keyframes into .asset_staging/flow/<companion>/<action>/
  -> productionise    the EXISTING normalisation: alpha, canvas, baseline, indexed PNG
  -> QA               9 checks + <action>_QA_REPORT.json
  -> manifest         existing tools
  -> integrity tests  existing suite
```

### Not all the frames

A 2-second clip at 24 fps is 48 frames; an action is 6. The selection is the
whole point, and the two naive approaches are both wrong: every-Nth ignores
content and keeps blurred transitions, and sharpest-N is worse because a held
pose is the sharpest thing in a clip — it returns six copies of one pose.

So: drop frames below `0.5 ×` the clip's median sharpness, then repeatedly take
the frame furthest from everything already chosen (with a small nudge toward
even temporal spread so a long static stretch cannot absorb every slot).

On the validation clip this recovered **exactly the 6 distinct poses** from 48
frames: `[0, 8, 16, 30, 38, 47]`.

### Loop vs once

- **loop** — the seam from last frame back to first must be one step, not zero
  and not a jump. Ratio of seam distance to median step distance, gated to
  `0.15 … 2.0`. Below the floor the last frame repeats the first and wastes a
  slot; above the ceiling the wrap is visible.
- **once** — no closure required. The keyframes are the action's key poses.

### Walk must be in place

`LocomotionController` owns world position; the sprite owns the gait. A clip
where the character also slides inside its own frame composes into double
displacement, so `--expect-in-place` measures lateral drift across the **raw
clip frames** and fails above `10%` of the character's own width.

---

## 3. Three bugs in my own gates, found by testing the gates

Every one of these was a check that looked right and did nothing, or did the
wrong thing. They are recorded because the pattern is the point: **a gate is not
evidence until it has been shown to fire.**

1. **`measure()` on an indexed PNG reads the wrong band.** The shipped frames are
   indexed PNGs, and `PIL.Image.split()[-1]` on an indexed image returns the
   palette *index*, not alpha. The QA reported `bottomY = 511` on every frame and
   failed the baseline check on art that was fine. Fixed by converting to RGBA
   first (`measure_alpha`). `productionise.py` already carried a warning about
   exactly this; the new QA ignored it.

2. **The similarity signature was taken over the whole frame.** A character
   occupying the middle third of a 512×512 canvas is swamped by flat background,
   so two visibly different poses scored `0.005` apart and the duplicate gate
   fired on good art. Fixed by cropping to the character's own bounding box
   first — the background carries no pose information.

3. **The in-place check measured the normalised output.** `normalise` re-centres
   every frame on the anchor, so the output has ~zero lateral drift no matter what
   the clip did. It reported `0.0016` on a clip where the character slid **90 px**
   across the frame — a gate that could never fire. Fixed by measuring the raw
   clip frames: the same clip now reports `0.289` and fails, while a
   non-translating control reports `0.0012` and passes.

Two thresholds were also miscalibrated and were corrected **against art the
project has already approved**, not by taste:

- `DUPLICATE_MAX_DISTANCE` was `0.02`; the closest pair among the dog's six
  shipped `idle` frames differs by `0.0100`, so `0.02` would have rejected
  approved work. Now `0.005`.
- The baseline gate compared against `int(512 × 0.90) = 460` — a number invented
  in the QA — while the contract declares `458`. Approved frames measure `459`
  (1 off, pass) and the video-derived frames measure `457` (1 off, pass). Now the
  contract is read rather than approximated.

---

## 4. Negative verification

`tools/video_to_sprite_negative_check.py` breaks the art four ways in a temporary
directory and asserts the matching check fails. It never writes a faulty asset
into `assets/companions/`.

| fault | verdict | expected check | result |
|---|---|---|---|
| control (unmodified) | PASS | — | — |
| blur | FAIL | `sharp` | **fired** |
| baseline | FAIL | `baseline` | **fired** |
| duplicate | FAIL | `no_duplicates` | **fired** |
| missing | FAIL | `frames_present` | **fired** |

```
NEGATIVE_CHECK: PASS
no faulty asset was written to assets/companions/
```

Plus the walk rule, verified the same way: a clip where the character translates
90 px **fails** `in_place` (0.289 > 0.10); a non-translating control **passes**
(0.0012).

---

## 5. First validation — DOG / IDLE

There was no Flow clip available (§6), so the pipeline was validated against a
clip built from the dog's **approved** idle art: the 6 shipped frames composited
on white at 24 fps with each pose held 8 frames — 48 frames, 2.0 s. Video carries
no alpha, so compositing on a plain background is exactly what a Flow clip looks
like, and the pipeline has to re-derive alpha from scratch.

| | measured |
|---|---|
| source | h264 512×512, 24 fps, 48 frames, 2.0 s |
| selected | `[0, 8, 16, 30, 38, 47]` — one per held pose |
| baseline drift | **1 px** on all six (contract 458, tolerance 2) |
| centre offset | 0.0 – 0.5 px (anchor 255) |
| loop seam ratio | **1.276** (gate 0.15 – 2.0) |
| duplicates | none |
| **verdict** | **PASS, 9/9 checks** |

Recovered frames are visually identical to the approved originals, including the
subtle wink in frame 4. Mean per-pixel difference ≈ 3.8/255, entirely from the
alpha edge being re-derived — which is expected, because the source video has no
alpha to preserve.

---

## 6. Flow status — BLOCKED

Video generation is **not reachable** in the current Flow session. Evidence, in
order:

1. Flow's own banner on the project list:
   *"Flow is currently experiencing high demand, affecting video generation.
   Requests may need to be retried at a later time."*
2. The dog project opens, and the prompt box offers exactly one model:
   **🍌 Nano Banana 2** — an image model.
3. Clicking the settings trigger (the model chip) opens **no panel**; no overlay,
   menu or listbox appears.
4. No element anywhere in the DOM mentions a video model (`veo`, `omni`, video
   duration or frame controls) — only CSS and JSON-LD noise.

Per the task's own rule — at most 3 generation attempts, then
`ASSET_GENERATION_BLOCKED`, and do not burn quota — no attempt was made against a
mode the UI does not offer. The browser session is **already logged in**; no
password, 2FA or cookie was requested at any point.

---

## 7. Status

```
VIDEO_TO_SPRITE_PIPELINE: PASS
FLOW_GENERATION:          BLOCKED   (no video surface reachable; Flow banner reports degradation)

IDLE_VIDEO:               BLOCKED   (no Flow clip available)
IDLE_FRAMES:              6/6       (recovered from a real 48-frame clip)
IDLE_LOOP:                PASS      (seam ratio 1.276, gate 0.15-2.0)

WALK_VIDEO:               BLOCKED
WALK_FRAMES:              0/6
WALK_IN_PLACE:            PASS      (gate proven to fire: 0.289 fail / 0.0012 pass)

ANCHOR_GATE:              PASS      (baseline 1px, centre <=0.5px, against the contract)
SHARPNESS_GATE:           PASS      (and proven to fire on an injected blur)
DUPLICATE_GATE:           PASS      (threshold calibrated on approved art)
ALPHA_GATE:               PASS      (alpha re-derived from a video with none)
MANIFEST:                 NOT_RUN   (no new art to declare)
RUNTIME:                  NOT_RUN   (no new art to run)

VISUAL_OWNER_REVIEW:      REQUIRED
```

### What PASS and BLOCKED mean here, precisely

- **`VIDEO_TO_SPRITE_PIPELINE: PASS`** means the chain works end to end on a real
  48-frame clip and its gates reject injected faults. It does **not** mean a Flow
  clip has been through it, because none exists.
- **`IDLE_FRAMES: 6/6`** means six frames were recovered and passed every gate.
  The clip they came from was built from art this project already approved, so
  this validates the *pipeline*, not new art.
- **`WALK_IN_PLACE: PASS`** means the rule is enforced and the gate is
  non-vacuous. It is not a claim that a walk clip has been produced.
- **`MANIFEST` / `RUNTIME` are `NOT_RUN`** rather than failed: there is no new
  art to declare or to run. The existing suite is green (68/68 in the animation
  directory) and `assets/companions/` is byte-identical to `HEAD`.

### To unblock

Flow needs to offer video generation again. When it does, the first two
validations are one command each:

```
python tools/video_to_sprite.py --video <idle clip>  --companion dog \
    --action idle --frames 6 --loop loop
python tools/video_to_sprite.py --video <walk clip>  --companion dog \
    --action walk --frames 6 --loop loop --expect-in-place
```

then `tools/manifest.py dog`, `tools/gen_manifest_dart.py`, and the integrity
suite. `--out-root` is available to rehearse without touching approved art.
