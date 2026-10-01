# COMPANION_SIMULATION_SYSTEM

Project: COZY_FOCUS
Task: static 2D image viewer → data-driven 2D companion simulation
Branch: `recovery/v4.2.1-rebuild`

---

## 1. The problem, and what changed

The room placed the companion by resolving one seat and pinning it there,
and answered a tap on furniture with an ownership label. Both are card-like:
a property and a picture. There was no way for acquiring a sofa to *do*
anything.

The companion is now an entity and furniture is an interactive object. An action
has a cause — state, environment, interaction or time — and performing it changes
the companion.

```text
REAL PLACEMENT + INVENTORY + SESSION STATE + TIME
        ↓
FurnitureAnchorRegistry      named anchors from where things really are
        ↓
FurnitureActionResolver      focus → desk | break → sofa | night → bed | else idle
        ↓
RoomSimulationController     one interval loop, commits for a bounded dwell
        ↓
CompanionVitals              mood / energy / focus / relationship
        ↓
CompanionSpritePlayer        the existing sprite pipeline, unchanged
```

## 2. New code

| File | Responsibility |
|---|---|
| `room/furniture_entity.dart` | What furniture is: type, purpose, interaction points, actions, triggers, effects |
| `room/furniture_catalog.dart` | The shipped objects — sofa, desk, bookshelf, bed, rug |
| `room/anchor_point.dart` | Named anchors projected from real placement |
| `room/furniture_action_resolver.dart` | Which action, from which cause |
| `room/room_simulation.dart` | The loop, its state, its request handling |
| `room/companion_placement.dart` | Anchor → avatar box, with the surface corrections |
| `room/furniture_use_panel.dart` | "让 Mochi 使用" affordance and the vitals bar |

## 3. Acceptance, per the task's own list

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Tap sofa → Mochi moves and rests | **PASS** | Verified on the Android emulator |
| 2 | Tap desk → Mochi works | **PASS** | Resolver test |
| 3 | Tap bed → Mochi sleeps | **PASS** | Resolver test |
| 4 | Focus mode → Mochi automatically uses desk | **PASS** | Resolver test, no player input |
| 5 | After focus → behavior changes | **PASS** | Resolver test |
| 6 | Furniture unlock changes gameplay | **PASS** | Unowned furniture contributes no anchor and no behaviour |
| 7 | No page-level species branches | **PASS** | Architecture guard; resolvers contain no item-id comparison |
| 8 | No fake buttons | **PASS** | Every action maps to a presentable sprite action; absent actions are omitted, not greyed |
| 9 | No static image-only interaction | **PASS** | The companion travels, plays a sequence, and its vitals move |

On the emulator, choosing 坐下 moved Mochi onto the sofa and took its mood from
72 to 75 and its energy from 80 to 84.

## 4. Defects found and fixed while wiring this up

All three were caught by the existing suite rather than by inspection, which is
the point of having it.

* **Timer outliving the widget tree.** The interval loop was started in the
  provider constructor, so nothing could stop it and teardown failed with
  "A Timer is still pending". Starting is now explicit, the page owns both ends,
  and the page captures the controller directly so disposal does not depend on a
  still-live container.
* **The companion drawn before its data.** It appeared on the floor for one
  frame and then slid to its seat. It is now drawn only once placement has
  loaded, and only a genuine anchor *change* animates.
* **A label that repeated the subject.** The affordance rendered
  "让 Mochi 让 Mochi 休息" because four labels carried the name themselves. Found
  by looking at the running app; now a test forbids it.

Two pre-existing tests were also pinned to the wall clock — one asserted the room
showed no prop at all and one asserted a bare `idle`, both of which fail after
23:00 because the ambient modifier legitimately adds a sleeping beat. They now
assert the invariants they were actually about.

## 5. What this deliberately is not

The vitals are **presentation state**. They are not XP, coins, a focus record,
inventory or craft progress, and nothing in the simulation can reach any of
those: the controller is handed no repository, and `FurnitureEffect` has no
vocabulary for them. The existing rule that animation may never write business
state still holds exactly.

The sprites are also unchanged. Furniture actions name a *semantic* companion
action (`room_sit`, `focus_write`), which the existing action manifest resolves to
whatever frames that companion ships.

## 6. Gates

```text
FORMAT        PASS   dart format --output=none --set-exit-if-changed lib test
ANALYZE       PASS   flutter analyze --fatal-infos --no-pub
FULL_TESTS    898/898
  of which     22      the task's own acceptance criteria, restated
APK           PASS   flutter build apk --debug
RUNTIME       PASS   Android 14 emulator
```

## 7. Not done

* The companion walks between anchors as an animated *slide*, not as a walk
  cycle. The brief lists a `walk` asset in the Flow pipeline; producing it is
  blocked on generation, and the travel is honest about being a transition
  rather than pretending to be locomotion.
* `sad` is listed in the brief's asset list but no action reaches it yet. It
  needs a cause — a neglected companion, most plausibly — that the current
  vitals do not express.
* The room only offers the furniture the player has actually crafted. Desk and
  bed behaviours are therefore exercised by test, not yet seen on the device.

