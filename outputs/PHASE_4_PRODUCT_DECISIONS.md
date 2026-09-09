# Phase 4 Product Decisions & Technical Debt Register

**Review Date**: 2026-09-09  
**Review Base**: `e3409b55a89aaa8c9f89d6f0afc2e95c6306e52a`  
**Status**: REVIEWED & DOCUMENTED  

---

## 1. Time Overflow Rule (Surplus Focus Seconds)

- **Issue**: When a user completes a focus session of 60 minutes (3,600s) on a recipe requiring 20 minutes (1,200s), the job completes. The surplus 40 minutes (2,400s) are currently absorbed into the completed job's `progressSeconds = 3600` and not credited toward the next craft.
- **Spec Analysis**: Primary Spec V2 (`designs/09A`, `designs/09B`, `prompts/09*`) does not define a time-banking or automatic carry-over mechanism for surplus craft focus seconds.
- **Current Behavior**: The completed job records `progressSeconds = min(newProgress, requiredSeconds)` in display clamps, but the database holds the full value. Surplus does not automatically start or fund a new job.
- **Decision Status**: `PRODUCT_DECISION_REQUIRED`
- **Options for Future Phase**:
  1. *Discard surplus* (current MVP behavior): simple, predictable, rewards right-sizing focus to recipes.
  2. *Time Bank*: deposit unused craft seconds into a "Craft Energy" pool.
  3. *Auto-carry*: automatically apply remainder to next selected craft job.

---

## 2. Craft Cancellation Rule (Invested Focus Seconds)

- **Issue**: When a user cancels an active craft job with partial progress (e.g., 15/30 minutes complete), what happens to the 15 minutes of invested focus time?
- **Spec Analysis**: V2 spec does not define a penalty or refund model for cancelled craft jobs.
- **Current Behavior**: The job transitions to `CraftJobStatus.cancelled`. The accumulated `progressSeconds` remain frozen on that job row for audit, but are not refunded as coins, XP, or time.
- **Decision Status**: `PRODUCT_DECISION_REQUIRED`
- **Recommendation**: Retain current conservative behavior (frozen on record, no refund) until product clarifies whether partial craft salvage/scrap materials should exist.

---

## 3. Technical Debt: `CraftJob.rewardClaimed` Field

- **Location**: `lib/domain/models/craft_models.dart`, `lib/data/local/tables/craft_tables.dart`
- **Issue**: `rewardClaimed` defaults to `false` and is never read or set to `true` by any active business logic.
- **Root Cause**: Furniture items are delivered automatically to `InventoryItem` upon craft job completion (atomic transaction in `SettlementDao`). There is no separate manual "claim reward" step in V2 UI.
- **Classification**: Dead field / architectural residue.
- **Action**: Retained for schema backwards-compatibility (no destructive migration); documented as deprecated for Phase 7 cleanup.

---

## 4. Technical Debt: `CraftJob.sessionId` Field

- **Location**: `lib/domain/models/craft_models.dart`, `lib/data/local/tables/craft_tables.dart`
- **Issue**: A craft job can span multiple focus sessions (e.g. three 30-minute sessions to complete a 90-minute bookshelf). Storing a single nullable `sessionId` on the job is semantically misleading.
- **Current State**: Always set to `null` in `startJob()`.
- **Classification**: Semantic mismatch / dead column.
- **Action**: Kept nullable in Drift table for schema safety; relations between sessions and craft progress are traceable via `RewardLedger` session timestamps rather than a single 1:1 foreign key.

---

## 5. `CraftJobStatus.pending` Lifecycle State

- **Location**: `lib/domain/models/enums.dart`
- **Issue**: `CraftJobStatus.pending` is defined in the enum but jobs currently transition directly from non-existent to `inProgress` via `startJob()`.
- **Intended Purpose**: Reserved for a future craft queueing feature (e.g., "queue next recipe after current completes").
- **Current State**: Valid enum member, zero database rows in `pending` state. Documented as reserved.

---

## 6. Architecture Smell: Recipe Emoji Fallbacks in DAO Layer

- **Location**: `lib/data/local/daos/craft_dao.dart` (`_recipeIcons` static map)
- **Issue**: The data access object contains UI presentation metadata (emoji characters like 🛋️, 🪵, 📚) as temporary fallback artwork.
- **Mitigation / Architecture Boundary**:
  - `CraftDao` populates `CraftRecipe.iconKey` and `artworkPath`.
  - In a future Phase with formal 2D illustration assets, an `AssetResolver` in the presentation layer will map `iconKey` to asset paths.
  - For Phase 4, the mapping remains harmless and self-contained; marked as `VISUAL_ASSET_GAP`.
