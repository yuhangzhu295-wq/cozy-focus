# P7 — Room Free Placement: CURRENT_STATE / GAP / DESIGN / TEST_PLAN

Baseline: branch `recovery/v4.2.1-rebuild`, HEAD `7a78d00`, worktree clean,
`dart format` clean, `flutter analyze --fatal-infos` clean.

Scope guardrails in force:

- **Do not create a second `RoomLayoutManager` or `FurnitureInstance`.**
- **Rotation: DEFER by default.** Not added because a roadmap example mentioned it.
- Presentation may **read** business truth; it may never fabricate or mutate it
  without an explicit Domain UseCase.

---

## 1. CURRENT_STATE — what already exists (verified, not assumed)

### 1.1 The product loop is already closed except for Memory and Daily Routine

| Step | Owner | Status |
|---|---|---|
| Focus | `FocusSessionEngine` | exists |
| Reward | `RewardService` + `RewardLedger` | exists |
| Craft | `CraftEngine` | exists |
| Inventory | `InventoryItem` | exists |
| Room placement | `CraftDao.placeRoomItemIfAvailable` | exists (atomic) |
| Anchor follows placement | `FurnitureAnchorRegistry.build` | exists (pure projection) |
| Companion walks to furniture | `LocomotionController.startTravel` | exists |
| Uses furniture | `FurnitureActionResolver.decide` + `requestAction` | exists |
| Growth/Emotion changes presentation | `CompanionEmotionResolver` + ambient modifiers | exists |
| **Memory** | — | **absent** (P9 scope) |
| **Daily Routine** | — | **absent** (P11 scope) |
| Cat / Rabbit share the architecture | architecture ready, art incomplete | P10 scope |

### 1.2 Placement truth is already modelled

`RoomItem` (`lib/domain/models/craft_models.dart:105`) carries
`id, userId, itemId, positionX, positionY, scale, zIndex, isVisible, placedAt`.
`RoomItems` (`lib/data/local/tables/craft_tables.dart:52`) persists every one of
those columns, with `scale` default 1.0, `zIndex` default 0, `isVisible` default
true. There is **no** parallel layout model anywhere in the tree.

### 1.3 The read/write paths that already work

- `CraftDao.upsertRoomItem` writes **all** fields, including `scale`, `zIndex`,
  `isVisible` — so the persistence layer already supports every placement
  attribute; only the write *triggers* are missing.
- `CraftDao.findRoomItems` returns rows `ORDER BY z_index ASC`, and
  `room_page.dart` draws `Stack(children: [...craft.roomItems.map(...)])`.
  **Draw order is therefore already z-order**, not insertion order.
- `placeRoomItemIfAvailable` is atomic, quantity-aware, and assigns
  `zIndex = MAX(z_index) + 1`.
- `moveRoomItem` persists position only, once, on `onPanEnd` — drag is transient
  in widget state and never writes per frame.
- `clampNormalizedPosition` keeps an item fully inside the canvas.

### 1.4 Anchors and simulation are already correct

- `FurnitureAnchorRegistry.build` derives anchors from **real** placement and
  requires `eligible && visible && owned(quantity>0)`. It caches nothing, so it
  cannot drift from the database. `anchorIdFor(itemId) => '<itemId>_anchor'`.
- `CompanionPlacement.feetYFor` already consumes `anchor.scale` and
  `anchor.surfaceFraction`, so a resized item's surface line moves with it.
- `RoomSimulationController` ticks at 2s, reads `craftControllerProvider` and
  `homeControllerProvider`, and never mutates them. It re-decides on
  `evaluateNow()`, which `room_page.dart` calls after move, place and delete.

---

## 2. GAP — what is genuinely missing

The audit found **no missing architecture**. It found four missing *capabilities*
and one dead field. Each is additive and each lives inside a class that already
owns the job.

| # | Gap | Evidence | Severity |
|---|---|---|---|
| G1 | **`scale` has no writer.** `placeItem` hardcodes `scale: 1.0`; no controller method or UI changes it. The column, the anchor, and the feet math all support scale, but the player can never resize. | `craft_controller.dart:132`; no other `scale:` writer | dead capability |
| G2 | **`zIndex` has no writer after placement.** Auto-assigned `MAX+1` on place; no way to raise/lower an item. | `grep zIndex` shows only DAO assign + DAO read | overlap is insertion-only |
| G3 | **`isVisible` has no writer.** Anchors already respect it, but hiding an item means deleting it. | no `isVisible:` writer outside `placeItem` | no way to stash decor |
| G4 | **No explicit edit/life mode.** The 2s simulation loop runs while the player drags; the companion can begin a decision against a layout that is mid-rearrange. `onMoveEnd → evaluateNow()` recovers it, so this is a *timing window*, not data loss. | `room_page.dart` starts the loop in `initState` and never suspends it | cosmetic/timing |
| G5 | **Placement errors are invisible.** `CraftState.error` is set by `placeItem` (e.g. "All copies of this item are already placed") but `room_page.dart` never renders it. | `room_page.dart` reads `craft.isLoading` only | silent failure |
| — | **Rotation** | deferred by explicit constraint | out of scope |

Not gaps: draw order (already z-ordered), anchor freshness (already rebuilt),
drag persistence (already single-write), coordinate clamping (already present).

---

## 3. DESIGN

### 3.1 Architecture-reviewer contract (answered for every proposed change)

1. **What existing class already owns this job?** `CraftController` (placement
   mutations) and `CraftDao.upsertRoomItem` (persistence). No new class is
   introduced for G1–G3.
2. **Why can't it be safely extended?** It can. The DAO already writes all three
   fields; the controller already has a single-item update pattern
   (`moveRoomItem`). Extension is a method, not a refactor.
3. **Would new state duplicate business truth?** No. The only new state is the
   clamped scale value, and it is written into the existing `RoomItem` row — the
   single source of truth — then re-read, exactly as `placeItem` does.
4. **Where is the single source of truth?** The `RoomItems` table. `RoomItem` in
   `CraftState` is a mirror refreshed from it. No cache, no shadow list.
5. **How will it be tested?** In-memory Drift (`AppDatabase.forTesting`), through
   the controller, asserting both the persisted row and the derived anchor / feet
   position — see §4.
6. **What files must remain untouched?** `anchor_point.dart`,
   `companion_placement.dart`, `room_simulation.dart`,
   `furniture_action_resolver.dart`, `room_geometry.dart`, and every Drift table
   and generated file. Slice 1 touches exactly three files: the controller and two
   test files. No new model, no new table, no second layout manager.

### 3.2 Slice 1 — placement-control capability (domain + controller, no UI)

Add four methods to `CraftController`, each persisting through the existing
`ICraftRepository.updateRoomItem` and then reconciling `CraftState`:

```dart
static const double minRoomItemScale = 0.6;
static const double maxRoomItemScale = 1.8;

Future<void> setRoomItemScale(String id, double scale);   // clamped, in place
Future<void> setRoomItemVisible(String id, bool visible); // in place
Future<void> bringRoomItemToFront(String id);             // re-densify z
Future<void> sendRoomItemToBack(String id);               // re-densify z
```

Rules:

- **Clamp, never reject.** A malformed scale is clamped to `[0.6, 1.8]`; the
  bound is a constant so a test and the future UI share one number.
- **z-order stays dense.** Front/back re-sorts the list by current `zIndex`
  (stable), moves the target to the end/front, then reassigns `0..n-1` and
  persists only the rows whose value changed. No gaps, no duplicate z values.
- **Re-read after a z change.** Front/back re-read `findRoomItems` afterwards so
  `CraftState.roomItems` order — which *is* draw order — comes from the database,
  matching `placeItem`'s existing pattern.
- **Unknown id is a silent no-op.** Matches `moveRoomItem`'s current behaviour;
  no error is raised for a row that is already gone.
- **Business isolation is structural.** These methods write placement rows only.
  They import no session, reward, or economy type, and cannot change XP, coins,
  records, inventory quantities, or craft progress.

### 3.3 Slice 2 — the placement UI (deferred to the next slice)

Extend `_SelectionToolbar` in `room_page.dart` with 放大 / 缩小 (calls
`setRoomItemScale`), 置顶 / 置底 (`bringRoomItemToFront` / `sendRoomItemToBack`)
and 显示 / 隐藏 (`setRoomItemVisible`). Surface `craft.error` as a `SnackBar` so
G5 stops being silent. The toolbar already exists and already holds the selected
`RoomItem`; this is additions, not a new panel.

### 3.4 Slice 3 — edit/life mode separation (deferred to the next slice)

Introduce an explicit *arranging* flag on the page. While arranging, the
simulation is not asked to re-decide; on exit it calls `evaluateNow()` once. This
removes the G4 timing window without adding a scheduler — `RoomSimulationController`
keeps its single timer and gains at most a "do not start a new decision" guard.

### 3.5 Explicitly not doing

- No `RoomLayoutManager`, no `FurnitureInstance`, no second table or column.
- No rotation.
- No change to `RoomSimulationController`'s decision policy in Slice 1.
- No economy, XP, or reward surface anywhere in this phase.

---

## 4. TEST_PLAN

### Slice 1 — `test/presentation/room_placement_control_test.dart`

| # | Assertion | Guards |
|---|---|---|
| 1 | `setRoomItemScale` persists the value on the row | G1 |
| 2 | scale above `max` clamps to `max`; below `min` clamps to `min` | malformed input |
| 3 | a scale change leaves every other row byte-identical | business isolation |
| 4 | `CompanionPlacement.feetYFor` returns a **different** y after a scale change | scale is wired, not dead data |
| 5 | `bringRoomItemToFront` moves the item to the end of `roomItems` | G2 |
| 6 | `sendRoomItemToBack` moves it to the front | G2 |
| 7 | after either, z values are exactly `0..n-1` with no duplicate | dense ordering |
| 8 | `setRoomItemVisible(false)` persists, and `FurnitureAnchorRegistry.build` drops that item's anchor | G3 + anchor coupling |
| 9 | an unknown id is a no-op and sets no error | matches `moveRoomItem` |
| 10 | after all four methods, inventory quantities, craft jobs and recipes are unchanged | business isolation |

### Regression — the existing suite must stay green

- `craft_controller_test.dart` (place / move / remove paths unchanged)
- `room_simulation_acceptance_test.dart` (resolver policy unchanged)
- `phase4_atomic_placement_test.dart` (atomicity unchanged)
- `companion_business_isolation_test.dart` (no business write introduced)
- full suite, `dart format`, `flutter analyze --fatal-infos`

### Gate

- New tests green; full suite green; format clean; analyze clean.
- One commit for Slice 1, message `feat(room): add placement-control capability
  for scale, z-order and visibility`.

---

## 5. Risk

| Risk | Mitigation |
|---|---|
| Scale changes the companion's feet unexpectedly | Test #4 pins the feet line to the scale, and `feetYFor` is unchanged — only its input moves |
| z re-densification rewrites many rows | Only rows whose `zIndex` actually changed are persisted |
| A future direct-write path fakes an anchor | Unchanged: `FurnitureAnchorRegistry` still requires `owned(quantity>0)` |
| Scope creep into rotation / a layout manager | §3.5 forbids it; the contract in §3.1 names the untouched files |

---

## 6. DELIVERY RECORD

All three slices are implemented. No `RoomLayoutManager`, no `FurnitureInstance`,
no second table or column, no rotation.

| Slice | Commit | Files | Tests |
|---|---|---|---|
| Design | `3490d6a` | `outputs/ai_handoff/P7_ROOM_PLACEMENT_DESIGN.md` | — |
| 1 — capability | `8411598` | `lib/presentation/controllers/craft_controller.dart`, `test/presentation/room_placement_control_test.dart` | 12 new |
| 2 — toolbar | `f5037c3` | `lib/presentation/pages/room_page.dart`, `test/presentation/room_placement_toolbar_test.dart` | 7 new |
| 3 — edit/life mode | *(this commit)* | `lib/presentation/companion/room/room_simulation.dart`, `lib/presentation/pages/room_page.dart`, `test/presentation/room_edit_mode_test.dart` | 6 new |

Suite: **1064 passing** (baseline 1039 + 25 new). `dart format` clean,
`flutter analyze --fatal-infos` clean.

### Two findings worth recording

1. **`phase6d_interact_reachability_test.dart` is flaky, independent of P7.**
   It failed intermittently during this work. Verified by running it six times
   on a stashed (clean) tree: five passes, one failure. It is a pre-existing
   timing flake in the same family as `mochi_live_gate_test`, not a regression.

2. **The pause had to be kept out of `RoomSimulationState`.** The first attempt
   stored `arranging` in the state and cleared it from `RoomPage.dispose`. That
   writes provider state during teardown, which Riverpod rejects with
   `'_lifecycleState != _ElementLifecycle.defunct'`. The flag now lives on the
   controller, so clearing it notifies nobody.

### Not covered by a test, deliberately

`mayChoose` is asserted directly, and the page's raising/clearing of the pause
is asserted through a real gesture. The *suppression* is not covered by a
timing test, because `RoomSimulationController._tick` reads `DateTime.now()`
rather than the injected `FocusClock`, so a test cannot advance the dwell
deadline. Making the tick clock-injectable is a separate change with its own
risk to the existing room tests, and was not folded into P7.

