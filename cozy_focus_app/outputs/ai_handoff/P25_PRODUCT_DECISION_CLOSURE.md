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

### D5 — What "use furniture" decides · `PRODUCT_DECISION_REQUIRED` · **the highest-value item**

**Verified today:** the room runs **two behaviour decisions that can disagree**.
`FurnitureActionResolver` picks the activity — anchor, action and
`companionAction` — and `room_page.dart:587` passes only the anchor's **role** to
`CompanionAvatar`, so the chosen action never reaches the renderer while the label
names it. No pack ships any `room_*` action, so those resolve through a documented
`semanticFallback` chain: a desk `craft` presents `focus_write` art under a label
reading 正在做点小东西.

**The decision:** does tapping furniture choose **the action**, or only **where
the companion goes**? The UI and catalog describe the first; the avatar path
effectively does the second.

**Why this gates other work:** the answer determines the direction of any merge
between the two deciders. Fixing it the wrong way would be worse than leaving it —
which is why P19 reported it as `FAIL` rather than repairing it.

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

---

## 5. What this phase did not do

- **It implemented nothing.** No default was chosen to close a question.
- **It did not re-open settled questions.** The three defects fixed in this
  program — the uncontrolled companion clock, the leaking router, the sprite
  weight — are not listed as open.
- **It did not treat `FAIL` as resolved.** P19's gate still fails, and D5 is the
  reason why.

---

## 6. Status

```
P25_PRODUCT_DECISIONS: OPEN

PRODUCT_DECISION_REQUIRED:  7   (D1-D7)
DEFERRED:                   6   (F1-F6)
BLOCKED_EXTERNAL:           4   (B1-B4)
APPROVED / SHIPPED:         7   (section 4)
```

**OPEN is the honest answer.** Six of the seven decisions are product choices that
would be a guess if made here. The seventh — D5 — is a genuine architectural
question whose answer changes what a correct fix even is, which is why P19 left
it failing rather than repairing it.

The four blocked items need the owner or an artist, not an agent. Nothing in this
list is blocked on engineering.
