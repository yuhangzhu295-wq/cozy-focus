# Phase 5 Collection Plan

- BASE_SHA: d5b1026f0fe20ff4f5c9fd853442c6dd5294668c
- GOAL: Implement only the truthful Growth > Collection presentation slice.
- DESIGN_REFERENCE: docs/cozy_focus_v4_1/designs/pages_ascii/10B_collection.png

## REAL_DATA_SOURCES

- Existing repository-backed Craft/Inventory data and its presentation provider/controller, when available to the page.
- Existing repository-backed Pet and PetProgress state only for the Growth context and identity.
- Static catalog metadata may define item names, categories, and preview icons, but never ownership.

## UNAVAILABLE_DATA

- Achievement runtime state is not proven to have a complete provider/repository/data path in the bounded review. Do not show unlocked achievements, progress, dates, rewards, or completion percentages from the Achievement interface alone.
- No new Collection schema, Achievement migration, unlock engine, outfit persistence, or Pet domain is in scope.
- If an item has no real Inventory record, render it as unavailable/未收集 rather than inventing ownership.

## FILES_ALLOWED_TO_MODIFY

- lib/presentation/pages/pet_collection_page.dart
- lib/presentation/navigation/app_router.dart
- lib/presentation/controllers/ only for a narrow read-only presentation adapter if existing Inventory access cannot be consumed directly
- lib/presentation/pages/mochi_growth_page.dart only for a minimal real Collection navigation entry
- lib/presentation/pages/pet_dress_page.dart only for minimal Growth navigation consistency
- test/presentation/
- outputs/ai_handoff/

## FILES_PROTECTED

- FocusClock, FocusSessionEngine, RewardLedger, SettlementDao, StatisticsEngine
- Drift schema and database migrations
- CraftEngine, craft transactions, inventory ownership invariant
- Room placement and RoomGeometry
- Pet persistence and Pet growth calculation semantics
- Achievement domain/data contracts unless a compile-only read is unavoidable; do not add a new runtime contract

## ROUTES_REQUIRED

- Add /growth/collection and keep any existing compatible alias behavior consistent if required by the router.
- Preserve exactly three primary bottom-navigation items: Home, Records, Growth.
- Collection should return to /growth and be reachable from Growth internal navigation.

## IMPLEMENTATION_STEPS

1. Confirm the existing Craft/Inventory read provider and map only persisted InventoryItem quantities into a presentation model.
2. Add a Collection page aligned to the 10B visual language: header, Growth context, truthful collection summary, category tabs/filter state, catalog cards, and empty/unavailable states.
3. Mark an item owned only when the real Inventory quantity is greater than zero; display quantity from the persisted record when shown.
4. Keep unsupported Achievement states explicitly unavailable and avoid empty callbacks, claim actions, unlock actions, sample counts, sample dates, or fake percentages.
5. Add the Growth internal route and navigation entry without changing the bottom navigation contract.
6. Provide direct navigation entry from MochiGrowthPage header to /growth/collection.
7. Add focused presentation and routing regression tests.

## TESTS_REQUIRED

- /growth/collection resolves to PetCollectionPage.
- Collection is reachable from Growth and returns to /growth.
- BottomNavigationBar remains exactly three items and Growth/Dress/Collection are not promoted to primary navigation.
- Real Inventory quantity is rendered as ownership; absent or zero quantity is not rendered as owned.
- Empty/unavailable data state is truthful and contains no fake unlocked/owned state.
- No empty onPressed callback or fake claim/equip/unlock CTA is introduced.
- Existing Mochi Growth, Pet Dress, Craft, and Inventory regression tests remain green.

## ACCEPTANCE_CRITERIA

- Collection is reachable and visually aligned to the reference without using the PNG as a background.
- Every ownership/count/progress claim is backed by existing data or is explicitly unavailable.
- No Achievement, Collection, outfit, or Pet domain is expanded.
- Growth and Dress behavior does not regress.
- Local format, analyze, tests, APK, and diff checks pass.
- GitHub Actions for the exact pushed HEAD is green before approval.

## REMOTE_CI_REQUIRED

- Yes. Verify Check formatting, Analyze, Run tests, Build APK (debug), and workflow conclusion for the exact pushed HEAD.
