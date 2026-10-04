# P29 — Collection Acquisition UX

Implemented in `1d8a488`. Device-verified in `ad09f6e`-era captures
(`p29_collection_locked.png`, `p29_acquisition_detail.png`).

## The gap

The collection listed locked items but never said how to get them, and its cards
did nothing. A player could see eight things they did not have and had no way to
learn that focusing is what produces them.

## What was built

`lib/presentation/companion/collection/collection_acquisition.dart` — a
presentation-only projection, plus a detail sheet and CTA routing in
`lib/presentation/pages/pet_collection_page.dart`.

### P29.1 — no duplicate business truth

`CollectionAcquisitionViewModel.from` reads the live `CraftRecipe`, `CraftJob`,
inventory rows and placed room rows on **every build**. Nothing is copied into
`CollectionCatalog`: no duration, no progress, no ownership, no placement. The
proof is a test that changes a recipe's duration and shows the detail follow it
with no edit to the catalog.

`requiredMinutes` / `requiredSeconds` delegate to the recipe. `requiresMaterials`
reads `ingredientCosts` rather than asserting the constant — every shipped recipe
seeds an empty map, so the sheet says 无需额外材料 instead of showing an empty
list that reads like a missing feature, and a recipe that one day costs something
will show it with no change to the view model.

### P29.2 — derived states, never persisted

`CollectionAcquisitionStatus` is computed each build. There is no column, no
provider, no cache. Precedence, and why:

| Derived | When |
|---|---|
| `unavailable` | no matching recipe, or the catalog marks it unobtainable |
| `crafting` | a real job for *this* item's recipe is running |
| `placed` | owned, and every owned copy is placed |
| `owned` | owned, with at least one copy still to place |
| `craftable` | a real recipe exists and nothing has started |

Two decisions worth stating. A job for a *different* recipe does not claim this
item. And an item owned twice with one copy placed reports 已拥有 x2 rather than
已摆放 — there is still something to put down, and 已摆放 would hide it.

### P29.3–P29.5 — the card, the detail, the CTA

Obtainable cards are tappable and open a sheet showing 获取方式, 制作工坊, the
real required minutes, the material requirement, live progress, ownership and
placement.

| State | Shows | CTA | Route |
|---|---|---|---|
| `unavailable` | 当前版本尚未开放 | **none** | — |
| `craftable` | 需要专注 X 分钟 | 开始制作 | `/craft/detail/:recipeId` |
| `crafting` | current / target | 继续专注 | `/craft/detail/:recipeId` |
| `owned` | 已拥有 xN | 去房间摆放 | `/inventory` |
| `placed` | 已摆放 | 查看房间 | `/room` |

Every route is one the app already has. An unavailable item gets **no button at
all** — a disabled one would imply a path that does not exist. A test asserts that
no status invents a destination.

### P29.6 — the loop, replacing vague copy

The summary card's tagline now reads 选配方 → 专注变制作进度 → 做好入库存 → 摆进房间.
This *replaced* a vague line rather than adding a banner: the copy was the
problem, and a second block saying the same thing pushed the grid below the lazy
build window in the test viewport, which is how the duplication was caught.

### P29.7 — unavailable items

`plant_succulent` and `special_trophy` have no recipe. They stay visible, read
未开放, are excluded from the completion denominator, and offer no CTA. The
`obtainable` flag is checked against recipe truth in both directions by
`test/presentation/collection_craft_loop_gap_test.dart`.

## Tests

`test/presentation/collection_acquisition_test.dart` — 16 tests covering
resolution by `outputItemId`, live duration, materials read not asserted, all five
states, the crafting-outranks-placed rule, the multi-copy rule, and that every
route exists.

Negative proofs, run and restored:
- removing the recipe resolution → **13 failures**
- giving an unavailable item a CTA → **1 failure**

## Found later, in P30, and fixed

The inventory's own placement button read 摆放到房间 while its action was
`context.go('/room')` — it navigated and never placed. A player followed it, the
room stayed empty, and `room_items` was empty. Relabelled 去房间摆放 in
`19847f1` to say where it goes. Placement itself lives in the room's 摆放家具
toolbar and works.

## Open, for the owner

- **The rug's purpose.** `rug/sit` is hidden because `room_sit` has no drawing,
  and `sit` was the rug's only catalog action, so its panel now reports that it
  has nothing to offer. Reopening it needs approved real sit art, or a decision
  about what the rug is honestly for.
- **Whether `bookshelf/search` may share `focus_think` with `desk/study`.** Within
  one object the alternatives are distinguishable, but search has no searching
  motion — it is thinking.
