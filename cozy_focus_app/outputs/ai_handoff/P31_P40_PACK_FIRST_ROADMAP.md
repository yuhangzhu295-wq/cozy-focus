# CozyFocus — Custom Companion: Pack-First Architecture

Owner roadmap change. Supersedes the AI-first framing of the earlier P31 brief.

## The decision

**Custom companions are pack-first, not AI-first.**

The fundamental product object is a **`CompanionAssetPack`**, not an AI-generated
companion. Cloud generation is an *optional convenience* that produces a pack; it
gets no special runtime privileges.

Users must have a **local** custom-companion path that needs no CozyFocus cloud.

## Pack sources

| Source | Meaning |
|---|---|
| `BUILT_IN` | shipped with the app |
| `LOCAL_IMPORT` | a pack the user picks and installs |
| `LOCAL_COMPILE` | a pack built from the user's own videos/frames on their machine |
| `CLOUD_GENERATED` | a pack produced by AI, delivered through the same path |

**Runtime must not care about the source.** There is one import → validate →
install → register path, and one runtime.

## Revised phases

```
P31  COMPANION PACK STANDARD
P32  LOCAL IMPORT / EXPORT
P33  PARTIAL PACK + CAPABILITY GATING
P34  LOCAL ASSET / VIDEO PACK BUILDER
P35  CUSTOM COMPANION RUNTIME
P36  LOCAL CUSTOM PET GOLDEN FLOW
P37  AI GENERATION SPIKE
P38  OPTIONAL CLOUD GENERATION BACKEND
P39  FULL HARDENING
P40  RELEASE CANDIDATE
```

Note the reordering: **AI moves from P31 to P37.** It is now the last thing built,
not the first, and it is a spike rather than a product commitment.

## P31 — Pack standard

First audit the real, existing:

- `CompanionActionManifest`
- `SpriteAnimationManifest`
- `CompanionProfile`
- `CompanionVisualRegistry`
- `CompanionActionAvailabilityResolver`

**Do not create a parallel manifest format unless required.**

Define one portable **CozyFocus Companion Pack** able to represent:

identity · species · display name · sprite actions · fps · loop semantics ·
anchors · canvas · version · checksums · optional preview.

## P32 — Local import / export

Import: pick local pack → copy to temporary sandbox → safe extract → validate →
preview → install into app-private storage → register → select.
No backend, no login, no AI.

**Security.** Protect against: ZIP traversal, ZIP bomb, invalid PNG, fake
extension, oversized package, oversized extracted content, too many files, invalid
manifest, duplicate IDs, absolute paths, unsafe symlinks. **Never write outside the
sandbox.**

**Export.** An installed user companion may be exported as `*.cozy_pet` for backup,
device transfer and sharing.

## P33 — Partial pack + capability gating

Do **not** require all production actions. Use the existing capability gating:

```
idle       READY
walk       READY
sleep      READY
focus_read MISSING
```

`BehaviorDirector` must never select a missing capability. The UI shows truthful
action completeness. **Do not silently count a fallback as an available action.**

This is the phase that resolves the conflict the previous audit found: built-in
parity demands thirteen actions, a user pack will not have them, and the answer is
gating rather than faking.

## P34 — Local pack builder

Tooling that turns action videos and/or sprite frame directories into a valid pack.
Desktop/CLI first: `tools/cozy_pet_builder/` or equivalent.

Reuse `video_to_sprite.py`, `productionise.py`, `manifest.py` and the PNG probe.
**Do not duplicate asset QA.**

```
input/                cozy_pet_builder
  idle.mp4                    ↓
  walk.mp4              mimi.cozy_pet
  sit_down.mp4
  focus_read.mp4
```

Output QA verifies: video validity, frame extraction, alpha, canvas, anchor,
sharpness, duplicates, loop seam, action completeness, manifest, checksums.

## P35 — Generic runtime

**Do not create one provider class per custom pet.** Use a generic pack-backed
visual provider. A locally imported custom pet uses the same
`BehaviorDirector`, `AnimationController`, `SpritePlayer`, `Locomotion`, `Room`,
`Growth`, `Emotion`, `Memory` and `DailyRoutine` as built-in pets.

## P36 — Local golden flow

Without network: import `.cozy_pet` → preview → install → select → Home → Focus →
Pause → Complete → Room → Walk → Furniture Action → restart → still selected →
airplane/offline → still works → export pack → delete → fallback companion.

Requires `LOCAL_CUSTOM_PET_GOLDEN_FLOW = PASS`.

## P37 / P38 — AI, late and optional

AI's only job is to **produce a valid `CompanionAssetPack`**. It gets no special
runtime privileges. Cloud generation must never become mandatory for custom pets.

## Architecture rule

Local and cloud converge at exactly one place, and there must **not** be separate
`LocalPetRuntime`, `CloudPetRuntime` or `GeneratedPetRuntime` engines:

```
CompanionAssetPack
        ↓
Validation
        ↓
Installation
        ↓
PackBackedCompanionVisualProvider
        ↓
Existing CozyFocus Runtime
```

## Cost principle

Local import: server generation cost **0**.
Local pack building: server generation cost **0**.
Cloud AI: optional, cost-bearing convenience.

Do not make users pay AI generation cost if they already possess compatible assets.

## Final acceptance

The app must support custom companions even when the AI provider is unavailable, the
backend is unavailable, the user is offline, or Google Flow is unavailable.

**If a valid local pack exists, custom companion functionality must work.**
