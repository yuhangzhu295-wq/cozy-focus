# RIVE COMPANION ASSET CONTRACT (COZY FOCUS)

Date: 2026-09-17
Author: Gemini 3.8 Flash High
Status: REAL_RIVE_ASSET_STATUS = BLOCKED_PENDING_AUTHORING

---

## 1. REAL_RIVE_ASSET_STATUS

```text
REAL_RIVE_ASSET_STATUS = BLOCKED_PENDING_AUTHORING
```

- Current state: No valid `.riv` or Rive source project file exists in the repository or V4.1 desktop package.
- Absolute Rule: Never fabricate binary `.riv` files or insert placeholder dummy bytes.
- Safe Production Path: The Flutter fallback motion (`PetIdleFallbackView`) remains the production-safe default renderer.

---

## 2. ASSET SPECIFICATION & TARGET LOCATION

- Target Path: `assets/animations/mochi.riv` (pre-declared in `pubspec.yaml`).
- Target Artboard: `Mochi` (fallback to default artboard if unspecified).
- Target State Machine: `State Machine 1`.

---

## 3. REQUIRED ART HIERARCHY & ANCHORS

Derived strictly from the V4.1 visual motion specification (`designs/motion/11_宠物动效总览.png` and `11A` through `11K`):
- Root / Body: Base torso and root transform for breathing and position shifts.
- Head: Pivot for sway, nodding, and tilt.
- Eyes: Left and right eye nodes supporting blink, squint, and wide states.
- Eyelids: Upper/lower lid controls for blinking and sleep states.
- Ears: Left and right ear nodes supporting independent twitch and droop/perk.
- Tail: Segmented or skinned tail bone supporting wag, curled sleep, and idle sway.
- Mouth / Expression: Open, smile, neutral, and focused poses.
- Cheeks: Optional blush opacity anchor.
- Accessories Anchors (for future domain support; DO NOT invent extra slots):
  - Head slot (e.g. hat / flower pin).
  - Neck slot (e.g. collar / scarf).

---

## 4. STATE MACHINE INPUT CONTRACT

The state machine `State Machine 1` MUST expose the following inputs:

| INPUT NAME | RIVE TYPE | VALUE RANGE / DESCRIPTION | SOURCE OF TRUTH |
|---|---|---|---|
| `petState` | Number | Integer enum mapping (0..7) | `PetVisualState` in `lib/domain/models/enums.dart` |
| `mood` | Number | Optional input with no defined mapping until the app has one authoritative persisted mood enum; current emoji records must not be coerced | Future authoritative persisted mood enum only |
| `focusProgress` | Number | Float 0.0 .. 1.0 | Authoritative `FocusSessionEngine` elapsed/planned |
| `craftProgress` | Number | Float 0.0 .. 1.0 | Authoritative `CraftJob` elapsed/required |
| `reducedMotion` | Boolean | true / false | System or App Accessibility Settings |
| `triggerInteract` | Trigger | One-shot trigger | User tap on companion (cooldown gated) |
| `triggerCelebrate` | Trigger | One-shot trigger | Verified session completion settlement |

---

## 5. EXACT `petState` ENUM INDEX MAPPING

To prevent any mismatch between Dart domain models and Rive state machine transitions, the `petState` input MUST exactly mirror the declaration order in `lib/domain/models/enums.dart`:

```text
0 = idle
1 = focus
2 = craft
3 = pause
4 = celebrate
5 = sleep
6 = greeting
7 = interact
```

---

## 6. BASE & MICRO-MOTION BEHAVIORS

### Base States
1. `idle` (0): Default calm resting state.
2. `focus` (1): Concentrated posture, subtle breathing, minimal head tilt.
3. `craft` (2): Active tinkering/making motion.
4. `pause` (3): Curious, head tilted, awaiting resumption.
5. `celebrate` (4): Upbeat bounce, joyous tail wag, starry/happy eyes.
6. `sleep` (5): Curled up, eyes closed, slow rhythmic breathing.
7. `greeting` (6): Friendly wave or cheerful nod upon app launch/resume.
8. `interact` (7): Playful reaction to touch/tap.

### Micro-Motions (Organic Blending in Idle)
- `Breathe`: Continuous organic scale/expansion cycle (3.0s - 4.0s).
- `Sway`: Gentle subtle horizontal tilt (4.0s - 6.0s).
- `Blink`: Rapid eye close/open cycle (200ms) with bounded random intervals (3s - 7s).
- `Ear Twitch`: Occasional twitch of left or right ear (300ms).
- `Tail Wag`: Gentle rhythmic wag, accelerating on positive mood or celebrate.

---

## 7. PRIORITY, TRANSITION, AND FALLBACK RULES

1. Authoritative Override:
   Active business states (`focus`, `pause`, `celebrate`, `sleep`, `craft`) override idle micro-motions.
2. One-Shot Safety:
   `interact` and `greeting` are one-shot actions that MUST automatically transition back to `idle` upon completion without getting stuck.
3. Reduced Motion:
   When `reducedMotion == true`, large translations, rapid bounces, and aggressive rotations MUST be muted or dampened, while preserving static posture and state clarity.
4. Asset Failure Safety:
   If the asset is missing, corrupted, lacks the expected artboard, or lacks the expected state machine, `RivePetAdapter` MUST gracefully fall back to `PetIdleFallbackView` with zero user-visible crashes.
