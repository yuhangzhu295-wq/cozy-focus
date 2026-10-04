# P25 — Product Decision Closure

**This phase implements nothing.** Every item below is classified, and the ones
that need a decision say exactly what the decision is. Nothing was resolved by
default, and nothing was built to make an open question go away.

Every status was **re-verified against the code today**, not copied from an older
document. Where a number in an earlier document disagrees with what the code
measures, the measurement is used and the difference is noted.

```
P25_PRODUCT_DECISIONS: OPEN
```

---

## 1. Needs a decision from the owner

Each of these is a product choice, not a defect. They are open because the
correct answer is not derivable from the code — inventing one would be a decision
made by an agent on the owner's behalf.

### D1 — Material economy · `PRODUCT_DECISION_REQUIRED`

**Verified today:** `ingredientCosts` is still a dead field. Every recipe is
seeded with `'{}'`, the DAO parses it to `const {}`, and `craft_detail_page.dart`
loops over `recipe.ingredientCosts.entries` — an always-empty list. So crafting
costs **time only**.

**The decision:** whether materials exist at all. If they do: where they come
from, at what rate, and what each recipe costs.

**Why not defaulted:** it would create a second economy alongside coins, and a
second currency is a grind gate. The honest intermediate was already taken — the
*false claim* was removed rather than a rate invented.

### D2 — Coin sink · `PRODUCT_DECISION_REQUIRED`

**Verified today:** nothing in `lib/` spends coins. They accumulate from focus
sessions with no outlet.

**The decision:** whether coins buy anything, and if so what and at what price.

### D3 — Collection naming · `PRODUCT_DECISION_REQUIRED`

**Verified today:** of the **5** furniture items the companion can use, **2 have
two names** — `sofa` is 温馨沙发 as a recipe and 沙发 as furniture; `desk` is
窗边书桌 and 书桌. The other three already agree.

> An earlier document recorded "7 of 8". That counted all eight recipes, three of
> which (`table`, `lamp`, `cabinet`) have no catalog entry to compare against.
> Measured against the furniture the companion actually uses, it is 2 of 5.

**The decision:** which list wins. **My recommendation:** derive the collection's
name from the recipe, so one object has one name and the shorter catalog label
stays as the furniture's own name. Not done, because it changes copy the owner
has already device-verified.

### D4 — `long_session` memory threshold · `PRODUCT_DECISION_REQUIRED`

**Verified today:** `long_session` appears nowhere in `lib/`. `first_focus` and
`level_up` shipped because neither needed a number — "the first" is not a
threshold, and the level rule is the existing curve. A long session does need
one.

**The decision:** how long a session has to be to be memorable. One number.

### D5 — What "use furniture" decides · **DECIDED — the action**

**Was:** the room ran **two behaviour decisions that could disagree**.
`FurnitureActionResolver` picked the activity — anchor, action and
`companionAction` — and `room_page.dart` passed only the anchor's **role** to
`CompanionAvatar`, so the chosen action never reached the renderer while the
label named it. The sofa's 坐下 (+4 精神) and 休息 (+10 精神) were two buttons
with different effects and identical on-screen behaviour.

**The decision:** *does tapping furniture choose the action, or only where the
companion goes?* **The owner chose the action.** Tapping furniture chooses what
the companion does; the panel's label is a promise the avatar must keep.

**Implemented.** The room is now **action-authoritative**:

- `CompanionAvatar` takes a `companionAction` and puts it on
  `CompanionContext.macroBehavior` — a field that already existed and that
  **nothing had ever read**, which is the clearest sign the wiring was the
  intended design all along.
- `CompanionBehaviorDirector._pickMacro` presents a committed behaviour instead
  of picking a second one from the anchor's ambient recipe, and the ambient
  recipe no longer gets a veto over it. `updateContext` also re-picks when the
  action changes at the *same* anchor, because 坐下 and 休息 share the `seat`
  anchor and the slot alone cannot see the change.
- `room_page` passes `simulation.companionAction`.

**Measured, not asserted.** `test/architecture/behavior_authority_test.dart`
drives the real director with the real catalog for every action the furniture
can commit. `BEHAVIOR_AUTHORITY_COUNT` fell from **2 to 1**, and the gate now
reads that number instead of reciting it. Two negative verifications hold the
measurement up: removing the committed action restores 2 and names the eight
overridden actions; the page-level test fails if `room_page` stops forwarding.

**One honest gap.** `room_sit` — the sofa and the rug — has no sprite sequence
in any pack; it renders through the Mochi rig (`mochi_pose_spec.dart`), which is
what it already did before this change, so nothing regressed. A dedicated
sustained-sit sprite remains an art task, and it is the one place where "the
panel names it" is carried by the rig rather than by a production sequence.


### D6 — Growth economy · `PRODUCT_DECISION_REQUIRED`

**Verified today:** `GrowthLevelCurve` documents itself as a **temporary default** —
100 XP per level, cap 30 — chosen because two pages already assumed it, not
because any product contract specifies it.

**The decision:** whether that curve, cap and the stage boundaries are the
intended economy.

### D7 — Is cloud sync a shipping promise? · `PRODUCT_DECISION_REQUIRED`

**Verified today:** `SyncEngine` documents itself as an offline-first skeleton and
`flush()` is a no-op.

**The decision:** if sync is promised, the stub cannot be presented as complete.
If it is not, the code should say so to the user rather than the reverse.

---

## 2. Deliberately deferred

Real, understood, and not worth doing before a release. Each has a reason it is
safe to defer.

| # | Item | Why deferring is safe |
|---|---|---|
| F1 | Furniture triggers are declarative only — the use panel offers actions the catalog does not mark tappable | The panel **is** the `playerTap` path, so the outcome is what the player asked for. A catalog/UI inconsistency, no functional harm |
| F2 | A sprite that fails to load at runtime draws blank with no gap report | The asset gates catch every frame that is missing or malformed today; this is the *runtime* failure path, which needs a device fault to trigger |
| F3 | The reward page can render "+0" while the ledger is still loading | A flash on a slow read, not a wrong final number. P14 already removed the case where it persisted |
| F4 | `CraftController` caches inventory/room and swallows refresh failures | Not a second source of truth — the DAO is authoritative and re-verifies placement. Visibility of failure, not correctness |
| F5 | Three production classes are unreferenced (`RoomInteractionResolver`, `CompanionAssetResolver`, `CompanionPresentationMapper.buildPresentationState`) | Deleting on a static-read basis risks removing something a future path wants. **Not recommended for deletion on this evidence** |
| F6 | The room simulation's tick reads `DateTime.now()` | By design and documented: the night rule it feeds uses the injected clock. Timing the loop off a monotonic source is correct |

---

## 3. Blocked externally — cannot be resolved by any agent

| # | Item | Status |
|---|---|---|
| B1 | **Release signing** | `BLOCKED_EXTERNAL`. **Verified today:** `android/key.properties` is absent. The build config already reads it and switches over with no code change. A fabricated keystore was explicitly ruled out and remains ruled out |
| B2 | **Launcher icon** | `BLOCKED_EXTERNAL`. **Verified today:** still the stock Flutter logo — dominant colours `(0,0,0)`, **(84,197,248)**, **(1,87,155)**, the Flutter blue pair. Needs approved artwork, which does not exist |
| B3 | **`OWNER_VISUAL_GATE`** | `BLOCKED_EXTERNAL`. Whether the sprite art reads well is human judgement. P21's technical gates pass and every report carries `owner_visual_gate: REQUIRED`; no measurement decides it |
| B4 | **Store submission** | `BLOCKED_EXTERNAL`. Depends on B1 and B2 |

---

## 4. Already decided and shipped

Recorded so the register is complete rather than a list of complaints.

| Decision | Where it lives |
|---|---|
| No neglect, death, hunger or punishment mechanics | A standing constraint, honoured throughout — no such mechanic exists |
| Canvas contract: 512×512, baseline 458, anchor 255, tolerance 2 px | `animation_manifest.json`, asserted per frame |
| Reward rate: 2 coins + 5 XP per whole minute | `RewardService`, stated once and nowhere else |
| Sprites ship as indexed PNG | Measured: 19.2 MB → 3.1 MB, APK 42.3 → 29.5 MB |
| The QA fixture harness is debug-only | Separate entry point, import-scanning guard, `kDebugMode` throw |
| One record per session is enforced by the database | `uniqueKeys => [{sessionId}]`, proven load-bearing in P20 |
| `sit_down` is `reverse(stand_up)` for the dog and rabbit | Measured and visually reviewed; acceptable, not proven better (P16) |
| **D5 — tapping furniture chooses the action** | `room_page` → `CompanionAvatar.companionAction` → `CompanionContext.macroBehavior` → `CompanionBehaviorDirector`; measured `BEHAVIOR_AUTHORITY_COUNT = 1` |

---

## 5. What this phase did not do

- **It implemented nothing.** No default was chosen to close a question. *(D5 was
  decided later, by the owner, and implemented as its own change — see below.)*
- **It did not re-open settled questions.** The three defects fixed in this
  program — the uncontrolled companion clock, the leaking router, the sprite
  weight — are not listed as open.
- **It did not treat `FAIL` as resolved.** P19's gate failed at the time of this
  phase, and D5 was the reason why.

---

## 6. Status

```
P25_PRODUCT_DECISIONS: PARTIALLY_CLOSED

DECIDED AND IMPLEMENTED:    1   (D5 — the owner chose the action)
PRODUCT_DECISION_REQUIRED:  6   (D1-D4, D6, D7)
DEFERRED:                   6   (F1-F6)
BLOCKED_EXTERNAL:           4   (B1-B4)
APPROVED / SHIPPED:         8   (section 4)
```

**Six decisions remain open, and they are product choices** that would be a guess
if made here. **D5 was the seventh and is now closed:** the owner decided that
tapping furniture chooses the action, so the room is action-authoritative and
P19's gate passes on a measured count of 1 rather than a remembered 2.

The four blocked items need the owner or an artist, not an agent. Nothing in this
list is blocked on engineering.
