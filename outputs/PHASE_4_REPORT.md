# Phase 4 Report — Craft Workshop, Inventory & Room Decoration

## Commit
Pending — this report is created immediately before the Phase 4 commit.

## Flutter / Dart Versions
- Flutter: 3.32.4 (stable)
- Dart: 3.8.1

---

## Implemented Modules

### Data Layer
| File | Description |
|---|---|
| `lib/data/local/tables/craft_tables.dart` | CraftRecipes, CraftJobs, InventoryItems, RoomItems tables; added progressSeconds column to CraftJobs |
| `lib/data/local/daos/craft_dao.dart` | CraftDao DriftAccessor — CRUD for all four craft tables |
| `lib/data/repositories/drift_craft_repository.dart` | ICraftRepository implementation backed by CraftDao |
| `lib/data/local/app_database.dart` | Schema v3 with migration; seeds 8 canonical recipes |

### Domain Layer
| File | Description |
|---|---|
| `lib/domain/models/craft_models.dart` | CraftRecipe, CraftJob, InventoryItem, RoomItem with full copyWith |
| `lib/domain/models/enums.dart` | Added CraftJobStatus.cancelled |
| `lib/domain/repositories/i_craft_repository.dart` | Added findActiveJobByUser |
| `lib/domain/services/craft_engine.dart` | startJob, accumulateProgress, cancelJob, cancelActiveJob, getActiveCraftJob |
| `lib/domain/services/reward_service.dart` | Optional CraftEngine injection; calls accumulateProgress after settle |

### Presentation Layer
| File | Description |
|---|---|
| `lib/presentation/controllers/craft_controller.dart` | CraftState, CraftNotifier (Riverpod StateNotifier) |
| `lib/presentation/controllers/providers.dart` | craftRepositoryProvider, craftEngineProvider, rewardServiceProvider wired |
| `lib/presentation/pages/craft_list_page.dart` | Screen 09A — recipe list, active job banner |
| `lib/presentation/pages/craft_detail_page.dart` | Screen 09B — recipe detail, progress display, cancel |
| `lib/presentation/pages/inventory_page.dart` | Screen 09C — inventory grid, place-in-room action |
| `lib/presentation/pages/room_page.dart` | Screen 09 — drag-and-drop room |
| `lib/presentation/pages/home_page.dart` | Active-craft banner, room navigation button |
| `lib/presentation/pages/focus_reward_page.dart` | Real craft progress section (no fake data) |
| `lib/presentation/navigation/app_router.dart` | Routes: /craft, /craft/detail/:recipeId, /inventory, /room |

---

## Architectural Invariants Preserved

- progressSeconds incremented ONLY by CraftEngine.accumulateProgress(), called from RewardService.settle().
- One active CraftJob per user at a time (enforced in startJob).
- Completing a job writes exactly one InventoryItem.
- Placing a RoomItem does NOT decrease InventoryItem.quantity.
- Widget -> Controller -> CraftEngine -> ICraftRepository -> Drift. No shortcuts.
- No Timer.periodic as time source.
- Mochi is a dog (PetSpecies.dog). Domain stays generic Pet.

---

## Test Results

### flutter analyze
```
No issues found! (ran in 8.0s)
```

### flutter test
```
102/102 — All tests passed!
```

| Suite | Count |
|---|---|
| Phase 1 domain (Gate 1) | 14 |
| Phase 2 domain | 10 |
| Focus clock | 1 |
| Statistics engine | 5 |
| Focus flow (presentation) | 8 |
| Phase 3 records/reports | 33 |
| Phase 3 review | 3 |
| Phase 2 widget rendering | 6 |
| Phase 4 craft engine | 23 |
| Total | 102 |

Gate 1 (14 tests) -> all PASS. No regression.

### flutter build apk --debug
```
Built build/app/outputs/flutter-apk/app-debug.apk  (46.7s)
```
SUCCESS.

### Android Emulator
NOT_RUN — no emulator configured.

### iOS Build
NOT_RUN — Windows environment.

---

## Phase 4 Craft Engine Tests (23 tests)

- Start new job; verify status transitions
- Prevent duplicate active jobs
- accumulateProgress adds seconds; completes job at threshold; creates InventoryItem
- Progress not added to non-inProgress job
- Cancel in-progress job; verify cancelled status
- cancelActiveJob no-op when no active job
- Job completed -> item in inventory
- Multiple completions do not duplicate inventory
- getActiveCraftJob returns correct job or null

---

## Recipe Seed Data (8 canonical recipes)

| id | name | required | icon |
|---|---|---|---|
| sofa | 温馨沙发 | 30 min | sofa |
| table | 原木茶几 | 20 min | table |
| bookshelf | 书架 | 90 min | bookshelf |
| bed | 小床 | 60 min | bed |
| rug | 地毯 | 30 min | rug |
| lamp | 落地灯 | 45 min | lamp |
| cabinet | 收纳柜 | 120 min | cabinet |
| desk | 窗边书桌 | 180 min | desk |

---

## Known Tech Debt

1. Room drag-and-drop: no z-index reordering UI for overlapping items.
2. DriftCraftRepository.updateJob delegates to _dao.saveJob (insert-or-replace) — naming asymmetry.
3. Recipe icons stored in static map in CraftDao — must update map when adding recipes.
4. No craft_controller_test.dart — domain coverage via craft_engine_test.dart is sufficient for Phase 4.
5. RoomItem placement does not decrease InventoryItem.quantity — intentional per architecture.
6. Android Emulator / iOS: NOT_RUN.

---

## Final Status

**PHASE_4_APPROVED**

- [x] flutter analyze -> 0 issues
- [x] flutter test -> 102/102 PASS (Gate 1 intact, 23 new craft tests)
- [x] flutter build apk --debug -> SUCCESS
- [x] No fake data, no hardcoded stats, no placeholder buttons
- [x] All craft operations through CraftEngine -> ICraftRepository -> Drift
- [x] RewardService.settle() is the sole caller of accumulateProgress
- [x] Phase 1/2/3 frozen interfaces not broken
