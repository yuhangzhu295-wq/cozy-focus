# RP-0 COMPANION COMPLETION AUDIT (COZY FOCUS)

Date: 2026-09-17
Auditor: DeepSeek Flash (Analysis-Only Agent) & Gemini 3.8 Flash High (Code Writer)
Repository: yuhangzhu295-wq/cozy-focus
App Root: C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app
Status: FACTUAL AUDIT COMPLETE - NO CODE MODIFIED

---

## 1. CURRENT_DOMAIN_TRUTH

The domain layer establishes the authoritative models and rules for Cozy Focus.
- Pet representation: Character ID 'mochi', species Dog, name 'Mochi'.
- Focus sessions: `FocusSessionEngine` manages `running`, `paused`, `completed`, `finishing`, and `idle` states with strict timestamp auditing.
- Reward calculations: Driven strictly by `RewardService` and `SettlementDao` (2 coins/min, 5 XP/min, +5 happiness clamped 0..100).
- Craft engine: `CraftEngine` and `CraftDao` govern recipe progress increments and inventory deposits atomically.
- Room placement: Governed by `RoomGeometry` and `CraftDao`.

---

## 2. CURRENT_PET_MODEL

Defined in `lib/domain/models/pet.dart` and Drift tables in `lib/data/local/tables/pet_tables.dart`:
- `Pet` table fields:
  - `id`: text (e.g., 'mochi_pet_id')
  - `userId`: text (unique)
  - `characterId`: text ('mochi')
  - `species`: text ('dog')
  - `name`: text ('Mochi')
  - `adoptedAt`: dateTime
- `PetProgress` table fields:
  - `id`: text
  - `petId`: text (unique)
  - `level`: int (default 1)
  - `experiencePoints`: int (default 0)
  - `totalFocusMinutes`: int (default 0)
  - `happinessScore`: int (table/DAO default 50; bootstrap initial value 100)
  - `updatedAt`: dateTime
- Note: `level` is initialized at bootstrap and has NO increment logic anywhere in `lib/`. XP, total focus minutes, and happiness are updated upon session settlement via `SettlementDao`.

---

## 3. CURRENT_GROWTH_SYSTEM

- Persistence: `pet_progress` Drift table.
- Leveling: Currently fixed at level 1; no XP thresholds or level-up logic are implemented in `lib/`.
- UI: `MochiGrowthPage` displays level, XP progress bar, total focus time, and happiness.
- Visual reflection: The pet visual display is NOT scaled or modified based on growth or level.

---

## 4. CURRENT_MOOD_SYSTEM

- Representation: Emoji strings stored on `focus_records.mood`.
- Discrepancy noted:
  - `focus_save_page.dart`: `['😆', '🙂', '😊', '😐', '🥺', '🥰']`
  - `record_detail_page.dart`: `['😊', '😄', '🌿', '😌', '💪', '😴']`
- Happiness: Numeric score (0..100) in `pet_progress`.
- Visual reflection: Pet motion and fallback rendering do not currently map or alter visual expressions based on mood.

---

## 5. CURRENT_DRESS_SYSTEM

- Status: UNCONNECTED / PLACEHOLDER.
- Schema/Data: No Drift tables, domain models, or repositories exist for equipment, outfits, or clothing slots.
- UI: `PetDressPage` explicitly renders an unlinked state ("装扮系统未连接数据") with disabled actions (`onPressed: null`).
- Visual reflection: None.

---

## 6. CURRENT_COLLECTION_SYSTEM

- Catalog: Hardcoded `kCollectionCatalog` (10 items) in `lib/presentation/pages/pet_collection_page.dart`.
- Persistence: Ownership is derived by checking `inventory_items` for matching item IDs.
- Unlinked entries: Non-recipe items (e.g., plant, trophy) have no writers or unlock triggers in production.
- Visual reflection: None directly attached to the pet avatar.

---

## 7. CURRENT_ROOM_LINKS

- Persistence: `room_items` table managed by `CraftDao` and `RoomGeometry`.
- UI: `RoomPage` renders furniture items placed in coordinates.
- Companion link: Mochi does not have reactive placement or interactive triggers inside the room scene.

---

## 8. CURRENT_CRAFT_LINKS

- State: `craft_jobs` with `progressSeconds` accumulating toward `requiredMinutes * 60`.
- Visual state: `PetVisualState.craft` exists in the enum, but no UI flow currently transitions `PetMotionController` into `PetVisualState.craft` during crafting.

---

## 9. CURRENT_MOTION_SYSTEM

- Enum: `PetVisualState` in `lib/domain/models/enums.dart`:
  - Exactly 8 values: `idle`, `focus`, `craft`, `pause`, `celebrate`, `sleep`, `greeting`, `interact`.
- Controller: `PetMotionController` in `lib/presentation/controllers/pet_motion_controller.dart`:
  - Extends `ChangeNotifier`.
  - Getters: `isIdle`, `isFocus`, `isPause`, `isSleep`, `isCelebrate`, `isCraft`, `isGreeting`.
  - Notice: `hasActiveMotion` evaluates the above 7 states and explicitly excludes `interact`.
  - Methods: `triggerInteract()` (cooldown-gated, idle-only, does not mutate base state), `updateState()`, `startMotion()`, `stopMotion()`, `dispose()`.
- Scope: Currently instantiated locally in `HomePage`. Not registered in global Riverpod providers.
- Micro-motions in fallback:
  - Breathe, Sway, Blink, Ear Twitch, Tail Wag implemented via Flutter transforms and tickers in `PetIdleFallbackView`.

---

## 10. CURRENT_RIVE_STATUS

- Package: `rive: ^0.13.17` in `pubspec.yaml`.
- Adapter: `lib/presentation/animations/rive_pet_adapter.dart`.
- Configuration: Default asset path is `assets/animations/mochi.riv`, default state machine is `'State Machine 1'`.
- Runtime flag: `enableRive` defaults to `false` in `PetMotionView` and `PetAvatarWidget`.
- Actual usage: ZERO production screens pass `enableRive: true`. Only test files enable it.
- State machine binding: `_RivePetAssetLoader` receives `visualState` but contains no binding logic to set SMINumber, SMIBool, or SMITrigger on the state machine.

---

## 11. MISSING_CONNECTIONS

1. Rive asset is missing completely; `enableRive` is false across all production call sites.
2. `RivePetAdapter` lacks input mapping logic for Rive state machines.
3. `focus_active_page.dart` passes `PetVisualState.idle` rather than `PetVisualState.focus`.
4. `craft`, `sleep`, and `greeting` have no business-driven triggers wired from application state.
5. `PetMotionController` is page-local to `HomePage` rather than shared via Riverpod.
6. Mood and Growth systems do not connect to companion rendering expressions or scaling.
7. Dress system is completely unbacked by domain/data layers.

---

## 12. REAL_ASSET_STATUS

- App repository `assets/`: No `.riv` files found (`animations/`, `images/`, `sounds/` contain only `.gitkeep`).
- Desktop V4.1 package (`C:\Users\zyu33\Desktop\番茄种\CozyFocus_V4_1_Visual_Polish_Subagent_Final_FULL_20260910`):
  - No `.riv`, `.rpp`, or `.rev` files found.
  - Usable art: Reference PNG concept images and motion specifications (`designs/motion/11_宠物动效总览.png`, `11A_Idle_Breathe.png` through `11K_Greeting.png`).
- Verdict: `REAL_RIVE_ASSET_STATUS = BLOCKED_PENDING_AUTHORING`.

---

## 13. PROTECTED_CORE

The following core modules remain strictly unmodified and protected:
- `FocusClock` & `FocusSessionEngine`
- `RewardLedger` & `SettlementDao`
- `StatisticsEngine`
- Drift schema & migrations
- `CraftEngine` & `CraftDao`
- `RoomGeometry`
- Inventory ownership and settlement invariants

---

## 14. RECOMMENDED_MINIMAL_INTEGRATION

1. Keep Flutter fallback (`PetIdleFallbackView`) as the safe, production-default renderer.
2. Await external authoring of `assets/animations/mochi.riv` matching the official Rive Companion Asset Contract.
3. Never fake binary Rive assets.
4. Prepare `RivePetAdapter` input mapping to bind `PetVisualState` to Rive inputs safely behind the `IPetRiveRenderer` contract.
5. Fix UI call sites like `focus_active_page.dart` to use `PetVisualState.focus` during active sessions.

---

## 15. FACTUAL DOMAIN & PET VISUAL MATRIX

| DOMAIN_FIELD | SOURCE_FILE | CURRENT_VALUES | PERSISTENCE | CURRENT_UI_CONSUMER | PET_VISUAL_CONSUMER | CURRENTLY_CONNECTED |
|---|---|---|---|---|---|---|
| pet.id / characterId | lib/data/local/tables/pet_tables.dart | 'mochi_pet_id' / 'mochi' | SQLite (pets) | HomePage, MochiGrowthPage | PetAvatarWidget (static label/asset) | YES |
| pet_progress.level | lib/data/local/tables/pet_tables.dart | 1 (no increment) | SQLite (pet_progress) | MochiGrowthPage | None | NO |
| pet_progress.experiencePoints | lib/data/local/tables/pet_tables.dart | int >= 0 (5 XP/min) | SQLite (pet_progress) | MochiGrowthPage | None | NO |
| pet_progress.totalFocusMinutes | lib/data/local/tables/pet_tables.dart | int >= 0 | SQLite (pet_progress) | MochiGrowthPage | None | NO |
| pet_progress.happinessScore | lib/data/local/tables/pet_tables.dart | 0..100 (+5/session) | SQLite (pet_progress) | MochiGrowthPage | None | NO |
| focus_records.mood | lib/data/local/tables/focus_tables.dart | Emoji strings | SQLite (focus_records) | ProgressOverviewPage | None | NO |
| focus_session.status | lib/domain/models/enums.dart | running, paused, completed, idle | SQLite (focus_sessions) | FocusActivePage, HomePage | HomePage -> PetMotionController (focus, pause, celebrate, idle) | PARTIAL (Home only; FocusActive uses idle) |
| craft_jobs.status | lib/data/local/tables/craft_tables.dart | crafting, completed, idle | SQLite (craft_jobs) | CraftPage | None (craft visual unused) | NO |
| inventory_items | lib/data/local/tables/craft_tables.dart | itemId, count | SQLite (inventory_items) | RoomPage, PetCollectionPage | None | NO |
| room_items | lib/data/local/tables/room_tables.dart | itemId, posX, posY, zIndex | SQLite (room_items) | RoomPage | None | NO |
| outfit / equipment | None | None | None | PetDressPage ("未连接数据") | None | NO |
| pet_memories | lib/data/local/tables/pet_tables.dart | None (no writer) | SQLite (pet_memories) | None | None | NO |
| PetVisualState | lib/domain/models/enums.dart | 8 states (idle..interact) | In-Memory (Controller) | PetMotionView, PetAvatarWidget | PetIdleFallbackView, RivePetAdapter | PARTIAL (Fallback active; Rive unbacked) |

