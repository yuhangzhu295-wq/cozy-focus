# P21 — Visual / Motion Runtime Gate

Two gates, deliberately kept apart:

- **`TECHNICAL_VISUAL_GATE`** — measurable facts. Automated, and it can fail.
- **`OWNER_VISUAL_GATE`** — whether the art reads well. **Never decided here.**

The brief is explicit that aesthetics must not be auto-passed, and every report
this phase produces carries `owner_visual_gate: REQUIRED` as a fixed field rather
than a conclusion.

---

## 1. `TECHNICAL_VISUAL_GATE` — asset level

`test/presentation/companion/animation/sprite_motion_gate_test.dart`, 7 tests,
no device required.

| Check | What it asserts |
|---|---|
| no action is a single picture repeated | every shipped action's frames span a perceptual range ≥ **0.008** |
| a loop wraps without a visible jump | a `loop` action's last→first seam is ≤ **2.0×** its median step |
| a once-action is not required to close | asserted by counting both modes, so the skip above proves something |
| stand_up ends where sit_down begins | `stand_up`'s last frame resembles `sit_down`'s **first**, not its last |
| **negative proof** — frozen sequence | six copies of one frame fall below the range threshold |
| **negative proof** — out-of-scale seam | a wrap made of another action's frame exceeds the ratio threshold |

### The thresholds are calibrated, and the calibration is in the suite

A `calibration` test prints every action's measured range and seam ratio, and
stays in the suite because those numbers are the evidence for the thresholds.

**A per-step threshold would have been wrong.** The smallest step between two
shipped frames is **0.0033** (`rabbit/celebrate`, frames 3→4) — a deliberate hold
at the end of a one-shot, not a defect. So the gate measures each action's total
*range*, not its steps, and the lowest range that ships is **0.0127**
(`cat/focus_read`). Threshold 0.008.

### The negative proof found a real weakness in the gate

The first version of the seam check divided by the action's **largest** step. The
negative proof swapped in a frame from another action — and the gate reported a
ratio of **0.99** on a loop whose wrap was an entirely different character pose.

The reason: the injected frame *became* the largest step, which raised the
denominator and hid the very seam the gate exists to catch. A maximum is not
robust to an outlier.

Normalising against the **median** instead fixed it. Re-measured:

| | value |
|---|---|
| worst shipped `loop` ratio | **1.63** |
| injected fault ratio | **2.847** |
| threshold | **2.0** |

Between the two, with room on both sides. This is the second time in this program
that writing the negative proof changed the code rather than confirming it — the
first was P20, where disabling the Dart idempotency guard showed the real
guarantee was the database index.

---

## 2. `TECHNICAL_VISUAL_GATE` — runtime

`tools/runtime_motion_gate.py` turns the P16 hand-measurement into a command.

The brief's rule — *one screenshot does not prove motion* — is why this needs
**time-separated frames** and a **control region that must not change**. Without
the control, a difference between two screenshots proves only that two screenshots
differ. On this app the control measures **exactly 0.0**, so the capture path has
no noise floor and any difference in the subject is the app drawing something else.

Two modes, because asserting the wrong one is worse than asserting nothing:

| Mode | Requires |
|---|---|
| `idle` | the subject animates, the control is static, and the motion **cycles** |
| `travel` | the subject animates, the control is static, and it **moves in world space** |

### Results, on the release build

| | idle (home) | travel (room) |
|---|---|---|
| subject animates | ✓ peak **22.8** | ✓ step **31.5** |
| control static | ✓ **0.0** | ✓ **0.0** |
| cycles / moves | ✓ returns to 8.0 and 4.9 | ✓ displacement **31.9** |
| **gate** | **PASS** | **PASS** |

The travel trace is the whole story in one line — the companion sits on the rug
at ~1.9, jumps to **31.5** when it walks, then holds ~31.8 on the sofa:

```
0.0, 1.8, 1.9, 0.2, 1.8, 0.0, 31.5, 31.2, 31.8, 31.8, ... , 31.9, 27.9, 29.7
```

### The runtime checks have been seen to fail

Both were observed failing during this phase, on real runs:

- **`control_is_static` failed** when the control region was the vitals panel. It
  legitimately changes when a furniture action applies an effect — so the gate
  correctly flagged a *measurement setup* error, not a product fault. The tab-chip
  row replaced it and measures 0.0.
- **`moves_in_world` failed** on a run where the trigger tap missed (the rug's
  single-action panel puts its button at a different height than the sofa's
  three-action panel), so no travel occurred. The gate reported the absence rather
  than passing on the animation alone.

That second one is worth keeping: a sprite that animated its legs but never left
would pass a pure motion check and still be wrong. `moves_in_world` is the
assertion that makes the walk gate mean *world movement*.

---

## 3. What this does not cover

- **No double displacement** is verified *by construction* — P17 established that
  the gait is in-place while screen position advances — but it is not a separate
  automated assertion here. The `travel` mode proves the position changes; it does
  not independently prove the sprite stays planted within its own frame.
- **Asset decode and alpha** are covered by
  `sprite_animation_asset_integrity_test.dart`, not restated here.
- **Anchor stability** is likewise the integrity suite's, per frame, against the
  contract.
- The runtime gate needs a device and a human-chosen region. It is re-runnable but
  not self-configuring; the regions are arguments, not discovered.

---

## 4. `OWNER_VISUAL_GATE`

**REQUIRED, and not decided.** Nothing in this phase returns a verdict on whether
the art reads well. The reports state it as a field:

```json
"owner_visual_gate": "REQUIRED",
"note": "owner_visual_gate is REQUIRED and is never decided here: whether the
         art reads well is not a measurement."
```

The evidence a human would review: `p16_walk_gait.png` (P17's four-frame gait),
the `motion/idle` and `motion_gate/walk` frame sets, and the running app.

Device screenshots from this phase live in
`outputs/ai_handoff/android_v1_runtime/` alongside the other phase evidence:
`p21_home.png`, `p21_room.png`, `p21_after_tap.png`, `p21_sofa_panel.png` and
`p21_rug_panel.png`. The two panel shots are also the visual record of the
open `BEHAVIOR_AUTHORITY` finding — they show the room naming an action the
avatar does not necessarily present (see `P27_FINAL_RC_GATE.md` §3, P25 D5).

---

## 5. Gates

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | **PASS** |
| `flutter analyze --fatal-infos --no-pub` | **PASS** — 0 issues |
| `flutter test --no-pub` | **PASS** — 1155 / 1155 (was 1148; +7) |
| `git diff --check` | **PASS** |

---

## 6. Status

```
TECHNICAL_VISUAL_GATE:      PASS
  asset level               7/7 automated, both negative proofs fire
  runtime idle              PASS
  runtime travel            PASS
OWNER_VISUAL_GATE:          REQUIRED
```

Both runtime checks have been observed to fail on real runs, so the gate is not
vacuous — and one of those failures was my own measurement setup, which is the
kind of thing a control region exists to catch.
