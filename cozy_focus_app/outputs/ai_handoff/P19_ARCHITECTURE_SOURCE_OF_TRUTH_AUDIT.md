# P19 — Architecture / Source-of-Truth Audit

Read-only audit of `lib/`. **Nothing was fixed.** The brief is explicit that grep
hits must not be auto-corrected, and several findings below need an owner decision
before any code changes.

The audit was run by the designated `architecture-reviewer` agent (read-only), and
**its load-bearing findings were then verified independently here** before being
reported. Where my severity differs from the agent's, I say so and why.

---

## 1. The phase gate — five authority counts

| Count | Result | Gate |
|---|---|---|
| `BEHAVIOR_AUTHORITY_COUNT` | **2** | ✗ **FAIL** |
| `REWARD_AUTHORITY_COUNT` | 1 | ✓ PASS |
| `ROOM_TRUTH_COUNT` | 1 | ✓ PASS |
| `INVENTORY_TRUTH_COUNT` | 1 | ✓ PASS |
| `GROWTH_TRUTH_COUNT` | 1 | ✓ PASS |

### `BEHAVIOR_AUTHORITY_COUNT = 2` — verified, and it is the reason P19 fails

Two things decide what the companion does, and they can disagree:

- `CompanionBehaviorDirector` decides the macro behaviour and pose.
- `FurnitureActionResolver` decides the room activity — anchor, action and
  `companionAction` — independently.

**Verified myself, not taken on trust.** `room_page.dart:587` passes
`roomAnchor: _anchorRoleFor(anchor.itemId)` to `CompanionAvatar` — the *role*,
derived from the item id — and the simulation's chosen `actionId` never reaches
the renderer. The page's own comment asserts "the two cannot disagree", and that
is the assumption the evidence contradicts.

The concrete consequence, checked against the shipped data:

| Simulation chooses | Label shows | Recipe plays | Sprite resolves to |
|---|---|---|---|
| desk `craft` (`craft_work`) | 正在做点小东西 | `room_work` | **`focus_write`** |
| desk `study` (`focus_think`) | 正在学习 | `room_work` | **`focus_write`** |
| desk `write` (`focus_write`) | 正在写字 | `room_work` | `focus_write` ✓ |

**No pack ships any `room_*` action** — all three companions have the same 13
actions and none is `room_sit`/`room_work`/`room_read`/`room_sleep`/`room_relax`.
They resolve through an explicit `semanticFallback` chain
(`companion_action_manifest_data.dart:214-238`), which is a *designed* mechanism,
not silent breakage: `room_read → focus_read`, `room_sleep → sleep`,
`room_relax → pause_rest`, `room_sit → idle`, `room_work → focus_write`.

So the art is never blank and never obviously wrong — but the label names the
simulation's action while the animation plays the role's fallback. A player asking
the desk to craft sees the companion **writing**.

**Severity: I call this P1, not P0.** The agent classified it P0. The product
works, no data is lost, and the fallbacks produce plausible art; what is wrong is
that the two decisions can name different actions. I would not block a release on
it, but I would not call it clean either.

---

## 2. Findings

| # | Finding | File:line | Classification | Verified |
|---|---|---|---|---|
| 1 | Room activity and played action decouple — two behaviour deciders | `room_page.dart:587`, `room/furniture_action_resolver.dart`, `companion_avatar.dart` | **REAL_DEFECT** (P1) | **yes** |
| 2 | Furniture triggers are declarative only; the use panel offers actions the catalog does not mark as tappable | `room/furniture_catalog.dart:85-93`, `room/furniture_use_panel.dart`, `room/furniture_action_resolver.dart:210-229` | **REAL_DEFECT** (P2) | no — agent's read |
| 3 | Growth page duplicates the level curve instead of calling it | `pages/mochi_growth_page.dart:174-176` | **REAL_DEFECT** (P2) | **yes** |
| 4 | A sprite that fails to load at runtime draws blank, with no gap report | `runtime/companion_sprite_player.dart:183-223` | **REAL_DEFECT** (P2) | no |
| 5 | Reward page can render "+0" while the ledger is still loading | `pages/focus_reward_page.dart:57-109` | **REAL_DEFECT** (P2) | no |
| 6 | Controller caches inventory/room and swallows refresh failures | `controllers/craft_controller.dart:69-84` | **TECH_DEBT** | no |
| 7 | Unreferenced production classes (`RoomInteractionResolver`, `CompanionAssetResolver`, `CompanionPresentationMapper.buildPresentationState`) | three files | **TECH_DEBT** | no |
| 8 | Furniture metadata is spread across four places, not one table | `room_presence.dart:88,123`, `companion_manifest_data.dart:229-235`, `cozy_furniture_artwork.dart:16-102` | **TECH_DEBT** | **yes** |
| 9 | JSON + Dart mirror of the manifests | `companion_manifest_data.dart:8-27` | **INTENTIONAL** | yes |
| 10 | Sequential (non-atomic) reward path | `domain/services/reward_service.dart:12-18,59-73` | **INTENTIONAL** — documented as the test path; production always injects `SettlementDao` | yes |
| 11 | Procedural art for poses a pack lacks; unknown id → safe dog | `pet_avatar_widget.dart:246-255`, `companion_catalog.dart:58-73` | **INTENTIONAL** — documented, and explicitly refuses to draw `celebrate` as idle | yes |
| 12 | `DateTime.now()` in `focus_session.dart:63`; `Timer.periodic` in the room loop and sprite player | — | **INTENTIONAL / FALSE_POSITIVE** — the session getter is commented "kept for existing tests" and production uses the injected clock; the room loop's explicit start/stop is documented for test teardown; the sprite timer only advances frames | yes |
| 13 | `sync_engine.dart` is a no-op stub | `domain/services/sync_engine.dart:6-14` | **INTENTIONAL** — documented as an offline-first skeleton | yes |
| 14 | The level curve, stage boundaries and level cap are a documented temporary default | `growth_level_curve.dart:1-30` | **PRODUCT_DECISION_REQUIRED** | yes |

### Finding 3 — verified in detail

`mochi_growth_page.dart:174-176`:

```dart
const xpPerLevel = 100;
final currentLevelXp = xp % xpPerLevel;
```

and the page **does not import `GrowthLevelCurve` at all** (grep returns
nothing). The curve already offers `xpWithinLevel()`, whose doc says it reports a
*full* bar at max level precisely so the UI does not imply another level exists.
The page's `% 100` can show **zero** at max level.

Today `xpPerLevel` is 100 so the page agrees by coincidence; it breaks at max
level and would silently diverge if the curve changed. `monthly_report_page.dart`
carries the same duplication.

### What is clean

- **No `TODO` / `FIXME` / `HACK` / `XXX` anywhere in `lib/`.**
- **No widget writes to a DAO or repository.** Grepping `Dao|Repository` under
  `lib/presentation/` returns nothing; pages go through controllers.
- The reward rate lives in exactly one place (`RewardService._coinsPerMinute`,
  `_xpPerMinute`) and is not restated anywhere else.
- The furniture catalog's claim that "nothing branches on `'sofa'`" is **true of
  the resolvers** — the ids that do appear elsewhere are presentation metadata
  (artwork, seat surface fractions), which finding 8 covers.

---

## 3. Needs an owner decision

1. **Does "use furniture" decide the action, or only the destination?** The UI and
   catalog describe the former; the avatar path effectively does the latter.
   Answering this comes *before* merging the two behaviour deciders, because the
   merge direction depends on it. This is finding 1's real blocker.
2. **The growth economy** — curve shape, level cap and stage boundaries are a
   documented temporary default. Fixing finding 3 must not silently change them.
3. **Is cloud sync a shipping promise?** If so, the no-op stub cannot be
   presented as complete.

---

## 4. Not determined

- This was a static audit. **No Flutter test, device frame or asset decode was
  run**, so I cannot say how often finding 1 is visible in practice, nor whether
  every frame loads on a real device (finding 4 is a code-path observation, not a
  reproduced failure).
- "Unreferenced" means no production reference in `lib/`; tests, future plans and
  reflection are out of scope. **No class is recommended for deletion on this
  evidence.**
- Findings 2, 4, 5, 6 and 7 are the agent's read and were **not** independently
  reproduced. They are reported as such rather than as verified facts.

---

## 5. Gate

```
P19_ARCHITECTURE: FAIL

BEHAVIOR_AUTHORITY_COUNT:  2   (gate 1)
REWARD_AUTHORITY_COUNT:    1
ROOM_TRUTH_COUNT:          1
INVENTORY_TRUTH_COUNT:     1
GROWTH_TRUTH_COUNT:        1
```

**FAIL is the honest result.** Four of the five counts are 1 and the codebase is
unusually disciplined — one reward rate, no TODOs, no widget-to-database writes,
and every deliberate degradation documented at the point of degradation. The one
that fails is real: the room runs two behaviour decisions and they can name
different actions.

Nothing was fixed. Finding 1 needs the owner's answer to question 1 before a fix
can be the right one, and the rest are either intentional, technical debt, or
gated on the same decision.
