# Cozy Focus - PET_ANIMATION_ARCHITECTURE.md

> Phase 0 Pet Animation Architecture Freeze | Generated 2026-09-07

---

## 1. Architecture Overview

```
Business Layer (FocusSessionEngine, CraftEngine, etc.)
       |
       | emits business state changes
       v
PetStateController
       |
       | translates to PetVisualState
       v
PetAnimationEngine (abstract interface)
       |
       +---> RivePetAdapter (when .riv available)
       |
       +---> FallbackPetAdapter (when .riv NOT available)
```

**Rule**: Business pages NEVER directly control animation details (blink, tail, ears, breathing). They only inform PetStateController of business events.

---

## 2. PetStateController

Translates business state into animation-layer vocabulary.

```dart
class PetStateController extends ChangeNotifier {
  PetVisualState _state = PetVisualState.idle;
  double _mood = 0.5;           // 0.0 - 1.0
  double _focusProgress = 0.0;  // 0.0 - 1.0
  double _craftProgress = 0.0;  // 0.0 - 1.0
  bool _reducedMotion = false;

  // Business layer calls these:
  void onSessionStarted()    => _updateState(PetVisualState.focus);
  void onSessionPaused()     => _updateState(PetVisualState.pause);
  void onSessionCompleted()  => _updateState(PetVisualState.celebrate);
  void onSessionIdle()       => _updateState(PetVisualState.idle);
  void onCraftStarted()      => _updateState(PetVisualState.craft);
  void onSleepTime()         => _updateState(PetVisualState.sleep);
  void onUserReturns()       => _updateState(PetVisualState.greeting);
  void onUserInteracts()     => _engine?.triggerInteract();

  void setMood(double value);
  void setFocusProgress(double value);
  void setCraftProgress(double value);
  void setReducedMotion(bool enabled);
}
```

**Prohibited**: Pages calling `_engine.setState()` directly.
**Prohibited**: Pages setting Rive inputs, triggers, or state machine names.

---

## 3. PetVisualState (Base States)

| State | Trigger | Pet Behavior | Rive State Machine |
|-------|---------|-------------|-------------------|
| `idle` | No active session, daytime | Relaxed, occasional fidgets | "idle" state |
| `focus` | Session running | Concentrated work pose, subtle motion | "focus" state |
| `craft` | CraftJob active (during focus) | Building/crafting animation | "craft" state |
| `pause` | Session paused | Waiting, looking around | "pause" state |
| `celebrate` | Session completed + reward | Happy, bouncing, sparkles | "celebrate" state |
| `sleep` | Night time / long idle | Sleeping, slow breathing | "sleep" state |
| `greeting` | User returns after absence | Wave, perk up | "greeting" state |
| `interact` | User taps pet | React to touch | "interact" trigger |

---

## 4. Overlay Animations (Animation Layer Internal)

These are NOT controlled by business logic. They run as concurrent overlays managed entirely within PetAnimationEngine.

| Overlay | Behavior | Frequency | Reduced Motion |
|---------|----------|-----------|----------------|
| `breath` (11A) | Subtle scale oscillation (1.0 - 1.02) | Continuous, 3-4s cycle | Disabled |
| `sway` (11B) | Gentle left-right body sway | Continuous, 4-5s cycle | Disabled |
| `blink` (11C) | Eyelid close/open | Random 2-6s interval | Keep (accessibility: shows "alive") |
| `earTwitch` (11D) | Quick ear rotation | Random 8-15s interval | Disabled |
| `tailWag` (11E) | Tail oscillation, amplitude varies with mood | Continuous during idle/happy, stopped during sleep | Disabled |

**Rule**: Overlays are animation-layer concern. Business layer never says "blink now" or "wag tail."

---

## 5. PetAnimationEngine Interface

```dart
abstract interface class PetAnimationEngine {
  /// Initialize with the artboard/asset.
  Future<void> initialize();

  /// Set the current base visual state.
  void setState(PetVisualState state);

  /// Mood affects overlay intensity (tail wag amplitude, idle fidget frequency).
  void setMood(double value);

  /// Focus progress (0.0-1.0) for progress-dependent visual effects.
  void setFocusProgress(double value);

  /// Craft progress (0.0-1.0) for craft animation intensity.
  void setCraftProgress(double value);

  /// Enable/disable non-essential motion for Reduced Motion accessibility.
  void setReducedMotion(bool enabled);

  /// One-shot interaction trigger (user tapped pet).
  void triggerInteract();

  /// One-shot celebration trigger.
  void triggerCelebrate();

  /// Clean up resources.
  void dispose();
}
```

---

## 6. RivePetAdapter

Concrete implementation using Rive State Machine.

```dart
class RivePetAdapter implements PetAnimationEngine {
  late RiveFile _riveFile;
  late Artboard _artboard;
  late StateMachineController _stateMachine;

  // Rive State Machine Inputs (names match .riv asset contract)
  late SMINumber _stateInput;       // maps PetVisualState -> number
  late SMINumber _moodInput;        // 0.0-1.0
  late SMINumber _focusProgressInput;
  late SMINumber _craftProgressInput;
  late SMIBool _reducedMotionInput;
  late SMITrigger _interactTrigger;
  late SMITrigger _celebrateTrigger;

  @override
  void setState(PetVisualState state) {
    _stateInput.value = state.riveValue;
  }
  // ... other implementations
}
```

---

## 7. FallbackPetAdapter

Used when no legitimate .riv file exists.

```dart
class FallbackPetAdapter implements PetAnimationEngine {
  // Uses static PNG/SVG of Mochi + simple Flutter animations
  // (AnimationController for breathing scale, opacity for blink)

  // Provides minimal visual feedback without Rive:
  // - Static pet image
  // - Simple scale animation for breathing
  // - Opacity animation for blink
  // - Color tint changes for mood
  // - Text label showing current state (debug mode)

  // TODO markers for each missing .riv capability
}
```

**Rule**: FallbackPetAdapter is a REAL adapter, not a placeholder. It must respond correctly to all PetAnimationEngine methods. It just uses simpler visuals.

---

## 8. Mochi .riv Asset Requirements

Since the design pack does NOT include a .riv file, the following is the contract for the Rive artist:

### Artboard
- Name: `mochi_main`
- Size: 400x400 logical pixels (scalable)
- Background: transparent

### Required Bones/Groups
- `body` - main body group
- `head` - head group (for sway, tilt)
- `eyes` - eye group
  - `eye_left`, `eye_right` - individual eyes
  - `eyelid_left`, `eyelid_right` - for blink
- `ears` - ear group
  - `ear_left`, `ear_right` - for twitch
- `tail` - tail chain (3+ bones for smooth wag)
- `paws` - paw group (for work/craft animation)
- `accessories_mount` - attachment point for outfit items

### State Machine: `mochi_state_machine`

**Inputs:**
| Input Name | Type | Values |
|-----------|------|--------|
| `state` | Number | 0=idle, 1=focus, 2=craft, 3=pause, 4=celebrate, 5=sleep, 6=greeting, 7=interact |
| `mood` | Number | 0.0 - 1.0 |
| `focusProgress` | Number | 0.0 - 1.0 |
| `craftProgress` | Number | 0.0 - 1.0 |
| `reducedMotion` | Boolean | true/false |
| `interact` | Trigger | one-shot |
| `celebrate` | Trigger | one-shot |

### ViewModel / Data Binding
- `petName` (Text) - display pet name
- `levelBadge` (Text) - display current level
- `moodIndicator` (Color) - tint based on mood value

### Animations Per State
| State | Base Animation | Overlays Active |
|-------|---------------|----------------|
| idle | gentle bounce, occasional look around | breath, sway, blink, earTwitch, tailWag |
| focus | hunched over, writing/reading pose | breath, blink (slower) |
| craft | hammering/building motion | breath, blink |
| pause | sitting up, looking around | breath, sway, blink, earTwitch |
| celebrate | jumping, sparkle effects | blink, tailWag (fast) |
| sleep | lying down, slow breathing | breath (slower, deeper) |
| greeting | standing up, waving | blink, tailWag, earTwitch |

### State Transition Conditions
- All transitions driven by `state` input number change
- Blend time between states: 300ms (smooth crossfade)
- Reduced Motion: disable overlays except blink; minimize base animation amplitude

---

## 9. Background/Resume Behavior

- On background: stop Rive rendering (pause artboard tick).
- On foreground resume: read current PetVisualState from PetStateController, set state, resume rendering.
- Do NOT cache animation frame. Always re-derive from business state.
- If session was running during background: pet resumes "focus" state on return.

---

## 10. Reduced Motion / Accessibility

When `reducedMotion = true`:
- Disable: breath, sway, earTwitch, tailWag overlays
- Keep: blink (essential liveliness signal)
- Base state animations: use simplified versions (position change without easing flourishes)
- Celebrate: show static sparkle + text instead of bouncing animation
- All state transitions: instant cut instead of blend
