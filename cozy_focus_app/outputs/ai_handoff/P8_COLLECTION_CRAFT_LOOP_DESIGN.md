# P8 — Collection + Craft + Room Loop: CURRENT_STATE / GAP / DESIGN / TEST_PLAN

Baseline: branch `recovery/v4.2.1-rebuild`, HEAD `6ef0c8b`, worktree clean,
`dart format` clean, `flutter analyze --fatal-infos` clean.

**Status: the truthfulness half of G1 and G3 is CLOSED; the mechanics behind
them are OPEN.** No economy was invented and no balance number was chosen. See
§6 for exactly what changed and §3 for the decisions still owed.

Three candidate scopes are laid out in §3; each one carries a product decision
that belongs to the owner, so none is implemented on a default.

---

## 1. CURRENT_STATE — the loop is already closed

Verified against the code and against the device-verified records in
`outputs/ai_handoff/CURRENT_STAGE.json`.

```text
focus session
  → RewardService.settle          2 coins + 5 XP per whole minute, ledger-keyed
  → CraftEngine.accumulateProgress focus seconds accumulate onto ONE active job
  → job completes                 InventoryItem written / incremented
  → Collection                     reads real inventory quantity > 0
  → Room placement                 placeRoomItemIfAvailable (atomic, P4)
  → Anchor follows placement       FurnitureAnchorRegistry (P7 audit)
  → Companion walks and uses it    LocomotionController + FurnitureActionResolver
  → Presentation changes           growth stage, emotion, ambient modifiers
```

Every arrow above exists. Specifically:

| Piece | Where | Note |
|---|---|---|
| Coin + XP settlement | `lib/domain/services/reward_service.dart` | idempotent, ledger-keyed by session |
| Craft progress | `lib/domain/services/craft_engine.dart:48` | consumes focus seconds only |
| Inventory write | `craft_engine.dart:99` | the **only** writer of inventory |
| Collection ownership | `lib/presentation/pages/pet_collection_page.dart:218` | reads inventory, never invents |
| Unlock reaction | `lib/presentation/companion/collection_unlock.dart` | `0 → positive` only, baseline survives navigation |
| Companion craft activity | `PetCraftActivitySchedule` | wired to a real job, device-verified (C6) |
| Room → Craft / Inventory | `room_page.dart` app bar | two entries |
| 伙伴 / 房间 / 装扮 / 图鉴 | `GrowthSubNav` | four views of one section, mutually reachable |

So the loop is *functionally* closed. What follows is not a missing arrow; it is
three places where the app **declares** something the loop never delivers.

---

## 2. GAP — three declared-but-undelivered claims

### G1 · `ingredientCosts` is a dead field, and the craft page promises otherwise

- `CraftRecipe.ingredientCosts` (`lib/domain/models/craft_models.dart:8`) is a
  real field, with a real Drift column (`craft_tables.dart:8`).
- Every seed writes `'{}'` (`lib/data/local/app_database.dart:145`) and the DAO
  maps `const {}` (`craft_dao.dart:237`). No recipe has ever had a cost.
- Nothing in the app produces a material, and `CraftEngine.startJob` checks
  nothing but an existing active job.
- `craft_detail_page.dart:417` renders, in the empty case:
  **「材料会在专注中慢慢准备好」** — "materials will be prepared during focus".
  That sentence describes a mechanic that does not exist.

Severity: the UI makes a product promise no code keeps.

### G2 · Focus coins are earned and never spent

- `RewardService._coinsPerMinute = 2`; coins are written to `RewardLedger`
  (`reward_service.dart:46,53`) and shown to the player as `+N 专注币`
  (`focus_reward_page.dart:99`).
- There is **no** spend path: `focusCoinsEarned` is only ever written by the
  settlement and read by the reward page. No repository, controller or page
  debits it.

Severity: a reward the player is shown but can never use. Not a lie — the coins
are genuinely recorded — but a dangling economy.

### G3 · Two collection entries can never be obtained

- `kCollectionCatalog` (`pet_collection_page.dart:39`) has 10 entries.
- 8 have a craft recipe. `plant_succulent` and `special_trophy` have **none**:
  they appear only in the catalog and in `CozyFurnitureArtwork`. No recipe, no
  inventory path, no achievement grant.
- The page renders progress as `ownedCount / kCollectionCatalog.length`, i.e.
  `/ 10`, so the bar is capped at 80% forever.
- The achievement domain (`Achievement`, `IAchievementRepository`, the
  `Achievements` table) exists but has no runtime provider or wiring, so it
  cannot grant them either.

Severity: a completion claim that cannot be satisfied. Note the device-verified
record already accepts this — the celebration was observed at **7 → 8 of 10** —
so this is a *known, accepted* state, not a regression.

### G4 · Craft names and collection names are two hand-kept lists

The same object has two different names depending on which page you are on:

| itemId | recipe (`app_database.dart`) | collection catalog |
|---|---|---|
| sofa | 温馨沙发 | 温馨布艺沙发 |
| bookshelf | 书架 | 简约书架 |
| bed | 小床 | 治愈小床 |
| rug | 地毯 | 编织地毯 |
| lamp | 落地灯 | 暖光台灯 |
| cabinet | 收纳柜 | 原木收纳矮柜 |
| desk | 窗边书桌 | 专注写字台 |
| table | 原木茶几 | 原木茶几 |

Seven of eight disagree. `PHASE_5_COLLECTION_PLAN.md` permits the catalog to
define "item names, categories, and preview icons", so this is *allowed* — but
two hand-kept lists for one object is a drift hazard, and it is user-visible.

---

## 3. DESIGN — three scopes, each an owner decision

I am deliberately **not** choosing between these. Each one either invents a
number (A, B) or changes a behaviour the owner has already verified on device
(C). All three are recorded here with their cost so the choice can be made once.

### Option A — implement materials (G1)

Focus produces materials; recipes consume them; the craft page's sentence
becomes true.

- Touch points: `RewardService` (drop source), `CraftEngine.startJob` (cost
  check), a material catalogue, `craft_detail_page` (already renders costs),
  `inventory_page`.
- Needs owner numbers: which materials, drop rate per focus minute, cost per
  recipe, and what happens to a job already in progress when costs change.
- Risk: this is a second economy next to coins. It must not become a grind
  gate — the standing rule forbids forced chores.
- Test plan: cost is charged exactly once and atomically; a job cannot start
  without materials; a partial job is not silently refunded; materials cannot
  reach XP/coins.

### Option B — give coins a sink (G2)

Spend coins on crafting, or on something else the owner names.

- Touch points: wherever the sink lives, plus a ledger-side debit so the balance
  is derivable and auditable.
- Needs owner numbers: price per recipe, and whether the balance is a stored
  column or always derived from the ledger. Deriving it is strongly preferred —
  it keeps one source of truth.
- Risk: makes crafting strictly harder for an existing user. Needs a decision on
  what happens to a job that is already running.
- Test plan: balance is exactly `sum(earned) - sum(spent)`; a debit cannot go
  negative; settlement stays idempotent.

### Option C — consistency only (G3, G4)

No new economy.

- Make the collection's craft-backed entries read their name/icon from the
  recipe, so one object has one name (G4). This *changes displayed strings* on
  the collection page for seven items.
- Make the denominator honest for G3: either move the two unobtainable entries
  out of the progress total, or label them explicitly as 未开放 so 8/8 reads as
  complete.
- Risk: **both halves change behaviour the owner device-verified.** The 7 → 8 of
  10 celebration and the current collection copy would both need re-verification.
- Test plan: the catalog has no id without either a recipe or an explicit
  preview-only marking; the progress total equals the number of obtainable
  entries; no displayed name disagrees with its recipe.

### What is NOT in scope under any option

- No new collection schema, no achievement runtime, no unlock engine.
- No change to `CraftEngine`'s inventory invariant, the settlement transaction,
  the Drift schema, or the room placement path.
- No rotation, no second layout model (P7 constraints still hold).

---

## 4. TEST_PLAN (once a scope is chosen)

- The chosen option's own tests, per §3.
- Regression: `craft_controller_test`, `craft_engine_test`,
  `phase4_atomic_placement_test`, `collection_unlock_test`,
  `pet_collection_page_test`, `companion_business_isolation_test`.
- Full suite, `dart format`, `flutter analyze --fatal-infos`.
- Device re-verification for Option C, because it changes visible copy and the
  collection total.

---

## 5. WHAT THIS PHASE SHIPPED

`test/presentation/collection_craft_loop_gap_test.dart` — 7 characterisation
tests that make the gaps *enumerable and drift-proof*:

- G3: the set of catalog ids with no recipe is asserted to be exactly
  `{plant_succulent, special_trophy}`, and the catalog's `obtainable` flag is
  cross-checked against that truth **in both directions**.
- G1: every seeded recipe's `ingredientCosts` is asserted empty, and the craft
  page is asserted not to contain the old promise.
- G4: every catalog id is either craftable or explicitly declared preview-only,
  so a typo or a new pathless entry fails.

This follows the project's own precedent for an open owner decision —
`mochi_copy_coverage_test.dart` "locks the current coverage so a cadence edit
fails loudly and forces the review doc to be re-issued".

The tests pin *current truth*. They do not assert the gaps are desirable, and
they are expected to be rewritten by whichever option is chosen.

---

## 6. DELIVERY RECORD

Guided by the standing project value that a thing which does not exist must not
be claimed — the same reasoning that makes `RELEASE_SIGNING = NOT_RECOVERED` a
valid answer instead of a fake keystore — this phase fixed the two places where
the app **claimed** something false, and left the two places that would require
**inventing** something for the owner.

| Gap | Claim half | Mechanic half |
|---|---|---|
| G1 materials | **FIXED** — the craft page no longer says materials will be prepared during focus; it now says the recipe needs none, which is true | **OPEN** — materials are still not produced or charged (Option A) |
| G2 coins | not touched | **OPEN** — still no spend path (Option B) |
| G3 collection | **FIXED** — `obtainable` marks the two preview entries; the progress total counts only obtainable entries, so 8/8 is reachable instead of a permanent 8/10 | **OPEN** — the two entries still have no acquisition path |
| G4 names | not touched | **OPEN** — two hand-kept name lists (Option C) |

Files changed:

- `lib/presentation/pages/craft_detail_page.dart` — the materials empty state.
- `lib/presentation/pages/pet_collection_page.dart` — `CollectionCatalogItem.obtainable`,
  the two preview entries flagged, the summary denominator, and the card label
  (未开放 rather than 未收集).
- `test/presentation/pet_collection_page_test.dart` — the three assertions that
  pinned `0 / 10` and `1 / 10` updated to `0 / 8` and `1 / 8`, plus a
  `未开放` assertion. **These are the tests that caught the change**, which is
  why they existed.

### Re-verification needed

The collection total is user-visible and was previously recorded as `/ 10`. The
device-verified record (`CURRENT_STAGE.json`, the 7 → 8 of 10 celebration) is
about the *owned count*, not the denominator, so it is probably unaffected — but
the collection page has not been re-checked on a device since this change, and
should be before it is treated as verified.

### Deliberately not done

- No material source, no material cost, no coin sink, no balance number.
- No change to `CraftEngine`, the settlement transaction, the Drift schema, or
  any recipe seed.
- G4's name drift is left alone: choosing which of the two names wins is a copy
  decision, and `PHASE_5_COLLECTION_PLAN.md` explicitly permits the catalog to
  own names.

