# PHASE-6D-INTERACT: Executable Architecture Specification

- SPEC_VERSION: 1.0
- DATE: 2026-09-14
- AUTHOR: claude-sonnet-4-6 (architecture reviewer)
- BASE_STAGE: PHASE-6C (APPROVED)
- BASE_SHA: df1ad82bb406f46fd23c08c86e175e1477d27e29
- REMOTE_HEAD: dbfa4ba9f443c10f9410f267897f07ace665716f
- NEXT_STAGE: PHASE-6D-INTERACT
- SCOPE: PetVisualState.interact + triggerInteract Rive binding

---

## 1. Feature Scope

PHASE-6D adds exactly one new user-visible behavior: a **one-shot tap/click reaction**
("interact") triggered when the user intentionally taps or clicks the Mochi avatar.

Out of scope for this phase:
- No rewards, coins, experience, or persistence side effects.
- No random or automatic triggering; timer-based or background triggering is prohibited.
- No new pages, routes, or services.
- No changes to the domain/data layers.

---

## 2. Trigger Contract

### 2.1 Entry Point

The ONLY permitted trigger path is:

\`\`\`
User tap/click on Mochi avatar
  -> UI gesture handler (GestureDetector.onTap)
  -> PetMotionController.triggerInteract()
  -> PetIdleFallbackView._interactController.forward(from: 0.0)
\`\`\`

No other call site may invoke triggerInteract. Background timers, scheduler
callbacks, state-change hooks, or lifecycle events must NOT trigger interact.

### 2.2 New Public Method on PetMotionController

\`\`\`dart
/// Triggers a one-shot interact animation if state priority allows.
/// Returns true if the animation was fired, false if blocked by priority guard.
bool triggerInteract();
\`\`\`

Internal implementation logic (not exposed as API):

1. Guard: if _isDisposed, return false.
2. Priority guard (see Section 4): if current visualState is focus, pause,
   sleep, craft, celebrate, or greeting, return false.
3. Cooldown guard: if _interactCooldownActive, return false.
4. If all guards pass, notify _onTriggerInteract callback and start cooldown timer.
5. Return true.

### 2.3 New Callback Slot on attach()

The existing attach() signature gains one new optional parameter:

\`\`\`dart
void attach({
  VoidCallback? onTriggerBlink,
  VoidCallback? onTriggerEarTwitch,
  VoidCallback? onStartContinuousLoops,
  VoidCallback? onStopContinuousLoops,
  VoidCallback? onTriggerInteract,   // NEW
});
\`\`\`

Callers that do not supply onTriggerInteract are unaffected (backward compat).

---

## 3. Animation Parameters (Fixed Values)

All values below are normative. Implementor must not deviate without a spec amendment.

### 3.1 Duration

| Parameter        | Value  | Note                    |
|------------------|--------|-------------------------|
| interactDuration | 750 ms | Total one-shot duration |

Rationale: 750 ms sits in the 600-900 ms window, is a round number, and matches
the rhythm already established by greetingCycle (1500 ms / 2).

### 3.2 Motion Geometry (PetMotionSpec additions)

\`\`\`dart
// Phase 6D: Interact
static const Duration interactDuration    = Duration(milliseconds: 750);
static const double interactBounceDyMax   = -8.0;   // px, upward peak
static const double interactScaleMax      = 1.06;   // scale at peak
static const double interactTiltDeg       = 4.0;    // body tilt, degrees
static const double interactEarTiltDeg    = 6.0;    // ear peak tilt, degrees
static const double interactTailTiltDeg   = 5.0;    // tail peak tilt, degrees
static const double interactEyeSquintMin  = 0.55;   // eyeScaleY at squint peak
static const Duration interactCooldown    = Duration(milliseconds: 1500);
\`\`\`

### 3.3 TweenSequence Keyframe Breakdown

All channels use the same 3-segment weight split: **30 / 40 / 30**
(rise / peak-and-hold / settle).

| Channel    | Segment 1 (weight 30)  | Segment 2 (weight 40)    | Segment 3 (weight 30) |
|------------|------------------------|--------------------------|-----------------------|
| dy         | 0.0 -> -8.0 px         | -8.0 -> -8.0 px (hold)  | -8.0 -> 0.0 px        |
| scale      | 1.0 -> 1.06            | 1.06 -> 1.06 (hold)      | 1.06 -> 1.0           |
| body tilt  | 0.0 -> +4.0 deg        | +4.0 -> -4.0 deg (rock)  | -4.0 -> 0.0 deg       |
| ear tilt   | 0.0 -> +6.0 deg        | +6.0 -> -6.0 deg (rock)  | -6.0 -> 0.0 deg       |
| tail tilt  | 0.0 -> +5.0 deg        | +5.0 -> -5.0 deg (wag)   | -5.0 -> 0.0 deg       |
| eyeScaleY  | 1.0 -> 0.55 (squint)   | 0.55 -> 0.55 (hold)      | 0.55 -> 1.0 (open)    |

Curve: Curves.easeInOutSine for dy/scale/eyeScaleY; Curves.easeInOut
for all tilt channels.

### 3.4 Completion and Stable State

On AnimationController.status == AnimationStatus.completed:
- _interactController.reset() is called from a StatusListener.
- All interact channel values return to identity: dy=0, scale=1.0, rotation=0,
  earRotation=0, tailRotation=0, eyeScaleY=1.0.
- PetMotionController._visualState is unchanged after interact fires.
- No setState or rebuild is triggered from the completion callback;
  AnimatedBuilder already handles repaint.

---

## 4. State Priority Guard

### 4.1 States That MUST NOT Be Unconditionally Interrupted

| Blocking State | Rationale                                               |
|----------------|---------------------------------------------------------|
| focus          | User in active focus session; distraction risk          |
| pause          | Session paused; animation context is calm/restful       |
| sleep          | Pet sleeping; sudden jump breaks immersion              |
| craft          | Craft animation loop running; visual conflict           |
| celebrate      | Celebration loop is authoritative; must complete cycle  |
| greeting       | Greeting is already an active motion                    |

### 4.2 Allowed States

| State    | Interact fires? | Behavior                                   |
|----------|-----------------|--------------------------------------------|
| idle     | YES (always)    | Fires immediately if cooldown has elapsed  |
| interact | BLOCKED         | Cannot re-trigger during active animation  |

### 4.3 Priority Logic (precise)

\`\`\`dart
bool triggerInteract() {
  if (_isDisposed) return false;
  if (_interactCooldownActive) return false;
  switch (_visualState) {
    case PetVisualState.focus:
    case PetVisualState.pause:
    case PetVisualState.sleep:
    case PetVisualState.craft:
    case PetVisualState.celebrate:
    case PetVisualState.greeting:
    case PetVisualState.interact:
      return false;
    case PetVisualState.idle:
      _startInteractCooldown();
      _onTriggerInteract?.call();
      return true;
  }
}
\`\`\`

Note: _visualState is NOT changed to PetVisualState.interact at runtime.
The enum value interact exists in enums.dart and is reserved for future Rive
binding. PHASE-6D keeps _visualState = idle throughout the animation.

### 4.4 Cooldown

| Parameter        | Value   | Note                                              |
|------------------|---------|---------------------------------------------------|
| interactCooldown | 1500 ms | Blocks re-trigger for 1.5 s after each fire       |

The cooldown timer is a Timer? field in PetMotionController, cancelled in
both detach() and dispose().

---

## 5. Reduced-Motion Behavior

When MediaQuery.of(context).disableAnimations == true:
- _interactController does NOT start forward().
- PetIdleFallbackView delivers a static, instantaneous visual acknowledgment:
  a bool _interactFlash flag set to true for 80 ms via a single-use Timer,
  then reset to false.
- During _interactFlash, the pet renders at scale=1.02, dy=-1.0 px
  (identity-near, detectable but not distracting).
- No AnimationController is created or started for the reduced-motion path.
- The _interactFlash timer must be cancelled in dispose().

---

## 6. Rive Integration

### 6.1 Current Status

RIVE_ASSET_STATUS: PENDING_AUTHORING (carried from 6A/6B/6C).
No real .riv file exists. RivePetAdapter is decoupled and safe.

### 6.2 triggerInteract Rive Binding (Future)

When the Rive asset is eventually authored, the binding target is:
- Trigger input name: triggerInteract (matches 02_animationarch.md)
- Rive state name: Interact (base motion layer)

The implementor must NOT wire the Rive trigger in PHASE-6D.
The Rive path remains enableRive: false.

### 6.3 Truthful Fallback

RivePetAdapter.buildRiveWidget() already accepts a fallback widget.
PHASE-6D must not modify RivePetAdapter. PetVisualState.interact already
falls through to the idle/greeting/interact shared config in _getConfig.
No change needed.

---

## 7. Lifecycle

### 7.1 New AnimationController in PetIdleFallbackViewState

\`\`\`dart
late AnimationController _interactController;
late Animation<double> _interactDyAnimation;
late Animation<double> _interactScaleAnimation;
late Animation<double> _interactBodyTiltAnimation;
late Animation<double> _interactEarTiltAnimation;
late Animation<double> _interactTailTiltAnimation;
late Animation<double> _interactEyeSquintAnimation;
\`\`\`

Total AnimationController count: 11 (existing in 6C) + 1 = 12.

### 7.2 Initialization in initState

- _interactController created with duration: PetMotionSpec.interactDuration.
- One-shot (no .repeat()).
- _interactController.addStatusListener(_onInteractStatusChanged) registered.

### 7.3 _onInteractStatusChanged

\`\`\`dart
void _onInteractStatusChanged(AnimationStatus status) {
  if (status == AnimationStatus.completed) {
    _interactController.reset();
    // AnimatedBuilder handles repaint; no setState needed.
  }
}
\`\`\`

### 7.4 _stopAllAnimations (updated)

Must add:
\`\`\`dart
if (_interactController.isAnimating) _interactController.stop();
_interactController.reset();
\`\`\`

### 7.5 dispose() (updated)

Must add:
\`\`\`dart
_interactController.removeStatusListener(_onInteractStatusChanged);
_interactController.dispose();
\`\`\`

### 7.6 attach() Registration

\`\`\`dart
_effectiveController.attach(
  onTriggerBlink: _onBlinkTrigger,
  onTriggerEarTwitch: _onEarTwitchTrigger,
  onStartContinuousLoops: _startContinuousLoops,
  onStopContinuousLoops: _stopAllAnimations,
  onTriggerInteract: _onInteractTrigger,   // NEW
);
\`\`\`

\`\`\`dart
void _onInteractTrigger() {
  if (!mounted) return;
  _interactController.forward(from: 0.0);
}
\`\`\`

---

## 8. UI Integration

### 8.1 Widget Wrapping

Wrap the existing PetMotionView call inside PetAvatarWidget.buildAvatar():

\`\`\`dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => controller?.triggerInteract(),
  child: PetMotionView(
    visualState: activeState,
    size: size,
    controller: controller,
    scheduler: scheduler,
    riveRenderer: riveRenderer,
    enableRive: enableRive,
    accessory: accessory,
  ),
)
\`\`\`

The GestureDetector is only added when controller != null.

### 8.2 No New Parameters

PetAvatarWidget and PetMotionView gain no new constructor parameters.
The gesture is implicitly enabled when a PetMotionController is provided.

### 8.3 Call Sites

Only home_page.dart (the main screen where PetAvatarWidget renders Mochi
with a live controller) requires the gesture to be active in PHASE-6D.
Other pages that use PetAvatarWidget without a controller are unaffected.

---

## 9. Business Boundary

The following side effects are explicitly PROHIBITED in PHASE-6D:

- Writing to any Drift DAO or repository.
- Modifying any domain model (FocusSession, Pet, Craft, etc.).
- Emitting to any Stream or ChangeNotifier outside of PetMotionController.
- Awarding coins, experience, or achievements.
- Playing audio.
- Calling FocusSessionEngine, CraftEngine, RewardService, or any other service.

The interact animation is a pure UI affordance with no business consequence.

---

## 10. Acceptance Tests (minimum 12 required)

Tests live in test/presentation/pet_motion_view_test.dart or a new
test/presentation/phase6d_interact_test.dart.

| #  | Test ID    | Description                                                                          | Expected Result                                      |
|----|------------|--------------------------------------------------------------------------------------|------------------------------------------------------|
| 1  | AT-6D-01   | triggerInteract() when visualState=idle and cooldown inactive                        | Returns true; callback invoked                       |
| 2  | AT-6D-02   | triggerInteract() when visualState=focus                                             | Returns false; callback NOT invoked                  |
| 3  | AT-6D-03   | triggerInteract() when visualState=pause                                             | Returns false; callback NOT invoked                  |
| 4  | AT-6D-04   | triggerInteract() when visualState=sleep                                             | Returns false; callback NOT invoked                  |
| 5  | AT-6D-05   | triggerInteract() when visualState=craft                                             | Returns false; callback NOT invoked                  |
| 6  | AT-6D-06   | triggerInteract() when visualState=celebrate                                         | Returns false; callback NOT invoked                  |
| 7  | AT-6D-07   | triggerInteract() when visualState=greeting                                          | Returns false; callback NOT invoked                  |
| 8  | AT-6D-08   | triggerInteract() called twice within 1500 ms (re-tap during cooldown)               | Second call returns false                            |
| 9  | AT-6D-09   | triggerInteract() after full 1500 ms cooldown elapses                                | Returns true; callback invoked again                 |
| 10 | AT-6D-10   | triggerInteract() after dispose()                                                    | Returns false; no exception thrown                   |
| 11 | AT-6D-11   | _interactController reaches completed status and resets after 750 ms                 | interactController.value == 0.0 after completion     |
| 12 | AT-6D-12   | _interactController is disposed in dispose() (no leaked controller)                  | Accessing isAnimating after dispose throws           |
| 13 | AT-6D-13   | All 231 existing tests continue to pass                                              | flutter test exits 0; 231 + N tests passing          |
| 14 | AT-6D-14   | Reduced-motion path: disableAnimations=true, triggerInteract() fires                 | interactController.isAnimating=false; flash applied  |
| 15 | AT-6D-15   | attach() backward compat: omitting onTriggerInteract does not affect other slots     | Existing callbacks fire normally; no assertion error |

---

## 11. PetMotionSpec Additions (normative)

Add to lib/presentation/animations/pet_motion_spec.dart at the end of the class:

\`\`\`dart
// --- Phase 6D: Interact ---
static const Duration interactDuration      = Duration(milliseconds: 750);
static const double   interactBounceDyMax   = -8.0;
static const double   interactScaleMax      =  1.06;
static const double   interactTiltDeg       =  4.0;
static const double   interactEarTiltDeg    =  6.0;
static const double   interactTailTiltDeg   =  5.0;
static const double   interactEyeSquintMin  =  0.55;
static const Duration interactCooldown      = Duration(milliseconds: 1500);
\`\`\`

No existing constants are modified.

---

## 12. Files to Modify

| File                                                       | Change                                                                  |
|------------------------------------------------------------|-------------------------------------------------------------------------|
| lib/presentation/animations/pet_motion_spec.dart           | Add Phase 6D constants (Section 11)                                     |
| lib/presentation/controllers/pet_motion_controller.dart    | Add triggerInteract(), cooldown timer, onTriggerInteract callback slot  |
| lib/presentation/animations/pet_idle_fallback_view.dart    | Add _interactController + 6 animations, _onInteractTrigger, dispose     |
| lib/presentation/widgets/pet_avatar_widget.dart            | Wrap PetMotionView in GestureDetector when controller != null           |

Files that must NOT be modified:
- lib/domain/models/enums.dart (PetVisualState.interact already exists).
- lib/presentation/animations/rive_pet_adapter.dart.
- Any domain model, repository, DAO, or service file.

---

## 13. Risk Register

| Risk ID | Description                                                              | Severity | Mitigation                                                              |
|---------|--------------------------------------------------------------------------|----------|-------------------------------------------------------------------------|
| R-01    | GestureDetector absorbs taps intended for controls near the avatar       | HIGH     | Set HitTestBehavior.opaque only on avatar bounds; test surrounding UI   |
| R-02    | Cooldown timer leaks if detach() is called before it fires              | MEDIUM   | Cancel _interactCooldownTimer in both detach() and dispose()            |
| R-03    | interact animation interrupted mid-flight by updateState()              | MEDIUM   | _stopAllAnimations resets _interactController; verify in syncState      |
| R-04    | 12th AnimationController increases vsync load on low-end devices        | LOW      | Interact controller is idle 99% of time (not looping); negligible cost |
| R-05    | Rive triggerInteract input name mismatch with future .riv asset         | LOW      | Name locked to triggerInteract per 02_animationarch.md; no change needed |
| R-06    | Reduced-motion flash timer (80 ms) leaks on widget unmount              | LOW      | Cancel flash timer in dispose()                                         |

---

## 14. Implementor Checklist (for GEMINI PHASE-6D)

- [ ] Add PetMotionSpec constants (Section 11).
- [ ] Add triggerInteract() + cooldown timer to PetMotionController.
- [ ] Add onTriggerInteract to attach() signature (optional, backward compat).
- [ ] Add _interactController + 6 animations to PetIdleFallbackViewState.initState.
- [ ] Wire _onInteractTrigger in attach() call inside initState.
- [ ] Add _interactController to _stopAllAnimations reset block.
- [ ] Add _interactController.removeStatusListener + dispose() in dispose().
- [ ] Wrap PetMotionView in GestureDetector in PetAvatarWidget.buildAvatar.
- [ ] Implement reduced-motion static flash path.
- [ ] Write >= 15 acceptance tests (Section 10).
- [ ] flutter analyze --fatal-infos --no-pub -> 0 issues.
- [ ] flutter test -> 231 + N tests, all passing.
- [ ] flutter build apk --debug -> success.
- [ ] git diff --check -> 0 issues.
- [ ] Update outputs/ai_handoff/CURRENT_STAGE.json for PHASE-6D.
