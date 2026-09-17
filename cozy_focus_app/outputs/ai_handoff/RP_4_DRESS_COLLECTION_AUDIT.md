# RP-4: Dress & Collection Integration Audit

## 1. Executive Summary

- **Program**: Cozy Focus Post-Roadmap Release Polish & Companion Completion
- **Slice**: RP-4 Dress / Collection Binding Audit
- **Mode**: DOCUMENTATION_ONLY (Strict Factual Audit, Zero Production Source Edits)
- **Base Commit**: `f924179b96b7a511fd7dd2485c1081942787f268`
- **Author**: Gemini (Implementation & Audit Writer)
- **Status**: `EQUIPMENT_PERSISTENCE = NOT_IMPLEMENTED`, `COLLECTION_OWNERSHIP = PARTIAL (8/10 SEEDED)`

This audit establishes the factual boundaries of the pet dress and collection systems in the actual Cozy Focus codebase. No outfit domain model, persistence table, repository, or equip mechanics exist. Consequently, introducing an unverified equipment persistence system or overloading the Craft inventory would violate the project guard and invent unapproved domain invariants.

---

## 2. Current Dress Facts & Equipment Invariants

### 2.1 UI Implementation
- **Source File**: `lib/presentation/pages/pet_dress_page.dart`
- **Catalog Model**: `OutfitPreviewItem` (lines 11-25) is purely presentation-local metadata defining `id`, `name`, `category`, `icon`, and `description`.
- **Catalog Constant**: `kPreviewOutfitCatalog` (lines 28-57) contains 4 static preview entries:
  1. `basic_collar` (基础红项圈, 颈饰)
  2. `cozy_scarf` (暖冬姜黄围巾, 颈饰)
  3. `beret_hat` (小画家贝雷帽, 头饰)
  4. `gentleman_bowtie` (绅士小领结, 颈饰)
- **Equip Action**: The equip button in `_buildOutfitCard` (lines 288-301) explicitly sets `onPressed: null` and renders the label `'未连接'`. There is no equip handler, no state mutation, and no fake feedback.

### 2.2 Domain & Data Truth
- **Domain Model**: None. There is no `Outfit`, `Equipment`, or `PetDress` class in `lib/domain/models/`.
- **Database Schema**: None. Drift tables in `lib/data/local/tables/` contain no outfit or equipment tables.
- **DAOs & Repositories**: None. No DAO or repository exists to query or persist equipped accessories.
- **Persistence State**:
  ```text
  EQUIPMENT_PERSISTENCE = NOT_IMPLEMENTED
  ```
- **Equipped Invariant**: None. There is no concept of an "equipped item" across app restarts, route transitions, or focus sessions.

---

## 3. Pet Avatar & Visual Accessory Hook

### 3.1 Unbound Visual Hook
- **Source File**: `lib/presentation/widgets/pet_avatar_widget.dart` (lines 26, 37, 84, 94)
- `PetAvatarWidget` exposes an optional parameter:
  ```dart
  final Widget? accessory;
  ```
  which is forwarded internally to `PetMotionView` (`lib/presentation/animations/pet_motion_view.dart:38`).

### 3.2 Call-site & Test Audit
- **Production Call Sites**: Across all pages using `PetAvatarWidget` (`home_page.dart`, `mochi_growth_page.dart`, `focus_active_page.dart`, `focus_complete_page.dart`, `focus_save_page.dart`, `focus_setup_page.dart`, `pet_dress_page.dart`, `pet_collection_page.dart`, `settings_page.dart`, `notifications_page.dart`, `data_sync_page.dart`, `progress_overview_page.dart`), the `accessory` parameter is **never** passed.
- **Test Suite**: Search across `test/` reveals **0 references** to `accessory:`.
- **Conclusion**: `PetAvatarWidget.accessory` is an unbound visual placeholder hook. It is **not** an equipment contract and cannot be treated as an existing equipped accessory pipeline.

---

## 4. Collection Catalog & Inventory Ownership Facts

### 4.1 Collection Catalog
- **Source File**: `lib/presentation/pages/pet_collection_page.dart`
- **Catalog Model**: `CollectionCatalogItem` (lines 13-25).
- **Hardcoded Catalog**: `kCollectionCatalog` (lines 30-101) contains exactly 10 items:
  1. `sofa` (温馨布艺沙发, 家具)
  2. `table` (原木茶几, 家具)
  3. `bookshelf` (简约书架, 家具)
  4. `bed` (治愈小床, 家具)
  5. `rug` (编织地毯, 生活)
  6. `lamp` (暖光台灯, 生活)
  7. `cabinet` (原木收纳矮柜, 家具)
  8. `desk` (专注写字台, 家具)
  9. `plant_succulent` (多肉盆栽, 植物)
  10. `special_trophy` (专注纪念徽章, 特别)

### 4.2 Ownership Verification
- **Ownership Logic**: Evaluated via a two-pass aggregation mechanism:
  1. First pass in `build()` (`lib/presentation/pages/pet_collection_page.dart:131-135`) aggregates inventory counts into an `inventoryQuantities` map:
     ```dart
     final Map<String, int> inventoryQuantities = {};
     for (final inv in craftState.inventory) {
       inventoryQuantities[inv.itemId] =
           (inventoryQuantities[inv.itemId] ?? 0) + inv.quantity;
     }
     ```
  2. Second pass during grid item rendering in `_buildCollectionGrid` (`lib/presentation/pages/pet_collection_page.dart:416-417`) derives ownership from positive quantity:
     ```dart
     final quantity = inventoryQuantities[item.id] ?? 0;
     final isOwned = quantity > 0;
     ```
- **Underlying Persistence**: Drift table `InventoryItems` (`lib/data/local/tables/craft_tables.dart:36-50`) with schema:
  - `id` (Text, Primary Key)
  - `userId` (Text)
  - `itemId` (Text)
  - `quantity` (Int, default 0)
  - `updatedAt` (DateTime)
  - Unique constraint: `{userId, itemId}`

### 4.3 Catalog Reachability & Seed Recipes
- Canonical craft seed recipes are defined in `_seedRecipes` starting around `lib/data/local/app_database.dart:88`.
- Each seed record defines a tuple containing `outputId`, which is mapped to the Drift companion column `outputItemId: Value(s.outputId)` around line 106:
  1. `sofa` (requiredMinutes: 30, seed record `outputId: 'sofa'` -> companion `outputItemId: 'sofa'`)
  2. `table` (requiredMinutes: 20, seed record `outputId: 'table'` -> companion `outputItemId: 'table'`)
  3. `bookshelf` (requiredMinutes: 90, seed record `outputId: 'bookshelf'` -> companion `outputItemId: 'bookshelf'`)
  4. `bed` (requiredMinutes: 60, seed record `outputId: 'bed'` -> companion `outputItemId: 'bed'`)
  5. `rug` (requiredMinutes: 30, seed record `outputId: 'rug'` -> companion `outputItemId: 'rug'`)
  6. `lamp` (requiredMinutes: 45, seed record `outputId: 'lamp'` -> companion `outputItemId: 'lamp'`)
  7. `cabinet` (requiredMinutes: 120, seed record `outputId: 'cabinet'` -> companion `outputItemId: 'cabinet'`)
  8. `desk` (requiredMinutes: 180, seed record `outputId: 'desk'` -> companion `outputItemId: 'desk'`)
- **Seeded & Obtainable (8/10)**: The first 8 catalog items map 1:1 with real craft recipes and can be crafted, deposited into `InventoryItems`, and marked owned in the Collection.
- **Unobtainable / No Writer (2/10)**:
  - `plant_succulent` has no recipe, seed, or drop logic in any domain service.
  - `special_trophy` has no achievement engine, recipe, or writer in the database.
  - These 2 items **cannot truthfully become owned** under current business truth.

---

## 5. Inventory Data Model & Raw ID Namespace Risk

- **Single Key Structure**: `InventoryItems` stores an unformatted `itemId` string without any `itemType` or `category` discriminator.
- **Namespace Collision Hazard**:
  - Because `PetCollectionPage` evaluates ownership solely on raw string match (`inv.itemId == item.id`), inserting arbitrary outfit IDs into `InventoryItems` would pollute the collection namespace if IDs ever overlap.
  - Reusing `InventoryItems` to simulate an outfit equipment inventory would corrupt domain boundaries between Room/Craft items and Pet Wearables.
- **Policy Invariant**: **Never repurpose the Craft Inventory table as a fake outfit system.**

---

## 6. Navigation Routes & Reachability

### 6.1 Router Declarations
- Defined in `lib/presentation/navigation/app_router.dart`:
  - `/growth/dress` (line 67) & `/dress` (line 71) -> `PetDressPage`
  - `/growth/collection` (line 75) & `/collection` (line 79) -> `PetCollectionPage`

### 6.2 UI Flow
- `MochiGrowthPage` (`lib/presentation/pages/mochi_growth_page.dart:104`) has a direct action button navigating to `/growth/collection`.
- `MochiGrowthPage` does **not** link directly to `/growth/dress`.
- `PetCollectionPage` provides sub-navigation tabs (`pet_collection_page.dart:225-226`):
  - Tab `'装扮'` -> navigates to `/growth/dress`
  - Tab `'图鉴'` -> active on `/growth/collection`
- Both pages are fully reachable via standard GoRouter routing.

---

## 7. Real Rive Companion Asset Status

- **Asset Directory**: `cozy_focus_app/assets/animations/`
- **Contents**: `.gitkeep` only.
- **Status**:
  ```text
  REAL_RIVE_ASSET_STATUS = BLOCKED_PENDING_AUTHORING
  ```
- No Rive companion binary (`.riv`) exists in the repository. Flutter custom painter fallback remains the authoritative and active visual presentation layer.

---

## 8. Integration Boundaries & Recommendations

1. **Strict No-Op on Source Code for RP-4**:
   - Do not invent an `outfit_tables.dart` or Drift migration.
   - Do not create fake equipment controllers or mock equip states.
   - Do not modify `PetAvatarWidget` or `PetMotionView`.
2. **Prerequisites for Future Equipment Work**:
   - Requires a dedicated product-approved domain contract (slots, unlock conditions, attachment anchor specifications).
   - Requires a formal Drift schema migration (e.g. `PetEquipments` or `PetOutfits` table).
   - Requires actual art assets (Rive state machine inputs or vector layers for accessories).
3. **Current Integrity**:
   - Current UI honestly communicates system capability: `PetDressPage` displays `'未连接'` without deceiving the user.
   - `PetCollectionPage` truthfully checks real `InventoryItems` for the 8 craftable items and leaves the remaining 2 locked.

---

## 9. Verification & Gate Outcomes

### 9.1 Local Test Suite
Executed the 6 required test suites covering dress, collection, growth, craft, and atomic placement:
```powershell
flutter test --no-pub test/presentation/pet_dress_page_test.dart test/presentation/pet_collection_page_test.dart test/presentation/mochi_growth_page_test.dart test/presentation/craft_controller_test.dart test/domain/craft_engine_test.dart test/domain/phase4_atomic_placement_test.dart
```
- **Result**: **59/59 Tests Passed** (0 failures).

### 9.2 Static Analysis
```powershell
flutter analyze --fatal-infos --no-pub
```
- **Result**: **No issues found!** (Clean pass).

### 9.3 Repository Checks
- `git diff --check`: Clean (0 whitespace/formatting errors).
