# FLOW_DRIVEN_2D_COMPANION_ASSET_PRODUCTION_AND_RUNTIME

Project: COZY_FOCUS
Branch: `recovery/v4.2.1-rebuild`
Date: 2026-10-01

---

## 1. What was actually done

The companion used to be **one approved drawing under increasingly elaborate
transforms**: focus read, write and think differed by a degree of head tilt and a
code-drawn prop, never by a different picture. The brief calls that out and asks
for an asset-driven channel instead.

That channel now exists and is live:

```text
REAL BUSINESS STATE
      -> CompanionBehaviorDirector        (unchanged)
      -> SEMANTIC ACTION
      -> CompanionActionManifest          (new, data)
      -> CompanionSpriteSequence
      -> CompanionSpritePlayer            (new, generic)
      -> Flutter UI
```

Verified on the Android emulator with Mochi selected: during focus the companion
is drawn **reading a book**, and on pause it is drawn **sitting with its eyes
closed and paws together**. Those are different drawings, not a rotated idle.

### New production code

| File | Responsibility |
|---|---|
| `runtime/companion_action_manifest.dart` | One pack per companion: frames, fps, loop mode, interruptibility, Reduced Motion frame, canvas contract, fallback maps |
| `runtime/companion_action_manifest_data.dart` | The synchronous Dart mirror of the shipped JSON (generated; parity-tested) |
| `runtime/companion_sprite_player.dart` | The one generic player: precache active sequence, advance on its own timer, Reduced Motion, visibility, disposal |
| `runtime/companion_sprite_art.dart` | Shared sprite chrome and the data lookup that decides whether a sprite exists for a pose |
| `tools/` | The asset pipeline: master reference, alpha extraction, canvas normalisation, manifest emit |

### Preserved exactly

`CompanionBehaviorDirector`, `CompanionContext`, `CompanionProfile`,
`CompanionPresentationIntent`, `CompanionAssetResolver`,
`RoomInteractionRecipe`, selected-companion persistence. No V2 duplicates. The
director still chooses the semantic action; the player only chooses the frame.

### Macro action vs micro motion

The approved V4.1 rig keeps drawing `idle`, because idle's entire content *is*
micro-motion (breathe, blink, ear twitch, sprout sway) and it carries the real
growth-stage cadence. The sprite channel exists to give the **macro** actions a
distinct silhouette. While a sequence draws, the rig's blink/ear-twitch timers are
stopped, so nothing outlives the widget.

---

## 2. Assets

Produced in Google Flow (`Cozy Focus Companion Production`) from the approved V4.1
Mochi rig as the identity reference — not a crop of a design page, which would
carry scene background and UI text by construction.

| Companion | Actions | Frames |
|---|---|---|
| dog | `focus_read` (3), `focus_write` (4), `focus_think` (3), `pause_rest` (2), `pet_react` (3), `tap_react` (1), `idle` (1) | 17 |
| cat | — | 0 |
| rabbit | — | 0 |

Every frame is a normalised 1024x1024 transparent PNG sharing one ground baseline
(919) and one centre anchor (511), so switching action cannot make the companion
jump.

**Background handling.** Flow exports opaque JPEG at 1K, so transparency was not
assumed: it is produced locally (flood-fill from the border against the sampled
corner colour) and then *verified* — the tests read the PNG colour type and fail on
anything without an alpha channel.

**Room reuse.** A room anchor draws the action it stands for (bookshelf reads, desk
writes, bed sleeps) rather than generating a duplicate. No room-only art was
produced, because no visual evidence showed it was needed.

---

## 3. Honest status

**Not finished: cat and rabbit have no production art, and the dog pack is
partial.** 7 of the 10 requested dog actions exist; `craft_work`,
`celebrate` and `sleep` are still drawn by the rig.

**Why, and why it was not worked around.** Flow's generation path became
unavailable part-way through the session: the agent chat panel failed every request
("Sorry, this image failed to generate", not charged), and after roughly fourteen
successful generations Flow returned "We noticed some unusual activity" — its soft
rate limit. The ingredient picker also stopped rendering reliably once the project
held more than ~20 images, and it is the only way to feed the identity reference.

The brief forbids the ways around this: no crude programmer art presented as
finished, no cropping poses out of design pages, no recolouring the dog into a cat
or rabbit. So the remaining actions are recorded as **blocked**, not faked.

**What that means at runtime.** The fallback is honest and stays inside the
species: a pose with no sequence degrades to a semantic sibling or idle, never to
another companion's frames. `productionPoses` reports the gap **per pose**, so a
partial pack lands as a partial improvement. The resolver still returns
`ASSET_GAP` for every pose without art.

One deliberate refinement: the behaviour chain (`celebrate -> idle`) is *not*
used as a drawing. Substituting the idle sprite for a celebration would replace a
pose carrying a confetti accent with a placid drawing — worse than the rig's own
fallback. Rendering therefore consults a stricter `drawAliases` map.

---

## 4. Gates

```text
FORMAT            PASS   dart format --output=none --set-exit-if-changed lib test
ANALYZE           PASS   flutter analyze --fatal-infos --no-pub
FULL_TESTS        870/870
APK               PASS   flutter build apk --debug
DIFF_CHECK        PASS   git diff --check
RUNTIME           PASS   Android 14 emulator, no crash, ~15 ms frame time
```

New automated coverage (30 tests): manifest/JSON parity, frame existence, canvas
equality across an action, alpha channel, duplicate-frame detection, in-species
fallback, Reduced Motion frame containment, loop/ping-pong/one-shot, visibility
gating, disposal, and a fourth-companion regression.

Subjective beauty is deliberately **not** unit-tested.

---

## 5. Flow prompt archive

`outputs/ai_handoff/flow_asset_prompts/dog/PROMPTS.md` records the project, the
model and settings, the base prompt, the identity reference, every accepted frame
with its attempt count, and every rejection with its reason — so a frame is
reproducible and a rejected attempt is not repeated blindly.

---

## 6. Not done

- **Claude review: NOT_RUN.** The reviewer model was not available in this
  session. The generic runtime integration is the change it would review.
- **GPT-6 Sol: NOT_RUN.** No architecture dispute or hard performance issue arose.
- **Emulator QA for cat/rabbit:** not possible — neither ships production art, so
  they correctly render their procedural placeholders.

---

## 7. Final status block

```text
PROJECT: COZY_FOCUS
TASK: FLOW_DRIVEN_2D_COMPANION_ASSET_PRODUCTION_AND_RUNTIME

LOCAL_HEAD:  9d2421e1263a9e1c0c9297f041591fb48ab6deb5
REMOTE_HEAD: 9d2421e1263a9e1c0c9297f041591fb48ab6deb5

FLOW_BROWSER: AVAILABLE
FLOW_LOGIN:   READY (user's Chrome Google session, PRO tier)

DOG_MASTER:    PASS
CAT_MASTER:    FAIL  (not produced)
RABBIT_MASTER: FAIL  (not produced)

DOG_ACTIONS_READY:    7/10   (focus_read, focus_write, focus_think,
                              pause_rest, pet_react, tap_react, idle)
CAT_ACTIONS_READY:    0/10
RABBIT_ACTIONS_READY: 0/10

DOG_FRAME_COUNT:    17
CAT_FRAME_COUNT:    0
RABBIT_FRAME_COUNT: 0

ALPHA_VALIDATION:  PASS
CANVAS_ALIGNMENT:  PASS
MANIFEST:          PASS
GENERIC_SPRITE_PLAYER: PASS
PAGE_SPECIES_BRANCHES: 0
BEHAVIOR_DIRECTOR_UNCHANGED: YES

FOCUS_READ:  PASS
FOCUS_WRITE: PASS
FOCUS_THINK: PASS
TAP_REACT:   PASS
PET_REACT:   PASS
CRAFT_WORK:  FAIL  (no sequence; rig draws it)
CELEBRATE:   FAIL  (no sequence; rig draws it)
PAUSE:       PASS
SLEEP:       FAIL  (no sequence; rig draws it)
ROOM_REUSE:  PASS  (semantic alias, no duplicate art)
REDUCED_MOTION: PASS
BUSINESS_ISOLATION: PASS
MEMORY_PERFORMANCE: PASS  (active sequence + 1 likely next; no 90-image preload)

FORMAT:   PASS
ANALYZE:  PASS
FULL_TESTS: 870/870
APK:      PASS
RUNTIME:  PASS

CLAUDE_P0:  NOT_RUN
CLAUDE_P1:  NOT_RUN
GPT6_SOL:   NOT_RUN

ASSET_GATE:       PARTIAL
CODE_RUNTIME_GATE: PASS

READY_FOR_OWNER_REVIEW: YES
```

