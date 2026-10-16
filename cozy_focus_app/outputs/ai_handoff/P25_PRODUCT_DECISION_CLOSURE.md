# P25 — Product Decision Closure

**This phase implements nothing.** Every item below is classified, and the ones
that need a decision say exactly what the decision is. Nothing was resolved by
default, and nothing was built to make an open question go away.

Every status was **re-verified against the code today**, not copied from an older
document. Where a number in an earlier document disagrees with what the code
measures, the measurement is used and the difference is noted.

> **Update — the six decisions are closed.** The owner approved D1–D4, D6 and D7
> as V1 rules. Each section below now carries a **Decision** and an
> **Implementation** line saying what actually changed in the code, and §6 records
> the new status. Four of the six needed **no code change at all** — the code
> already behaved that way, and the decision converted "unfinished" into
> "intended". Two needed real changes: D3 (furniture names) and D4 (the
> long-session memory, which needed the one number nobody could derive).

```
P25_PRODUCT_DECISIONS: CLOSED
```

---

## 1. Decided by the owner — the V1 rules

Each of these was a product choice, not a defect. They were open because the
correct answer is not derivable from the code, and inventing one would have been
an agent deciding on the owner's behalf. The owner has now decided.

### D1 — Material economy · **DECIDED — no materials, time only**

**Verified today:** `ingredientCosts` is still a dead field. Every recipe is
seeded with `'{}'`, the DAO parses it to `const {}`, and `craft_detail_page.dart`
loops over `recipe.ingredientCosts.entries` — an always-empty list. So crafting
costs **time only**.

**The decision (owner):** no material economy. Furniture keeps being made from
focus time.

**Implementation: no code change needed.** The code already did this. What
changed is that it is no longer an unfinished feature — it is the rule.

**Guard:** `test/domain/v1_decisions_guard_test.dart` reads the seeded recipes and
fails if any recipe ever gains a non-empty material cost, which is the shape a
material economy would arrive in.

**Why the default was not taken earlier:** a material economy would create a
second currency alongside coins, and a second currency is a grind gate. The
honest intermediate was already taken — the *false claim* was removed rather than
a rate invented.

### D2 — Coin sink · **DECIDED — keep the ledger, no sink in V1**

**Verified today:** nothing in `lib/` spends coins. They accumulate from focus
sessions with no outlet.

**The decision (owner):** keep the real coin ledger; V1 has no coin consumption.
No shop, no redemption button, no fake goods.

**Implementation: no code change needed.** `reward_service.dart` remains the only
writer (`2 coins per whole minute`), and the ledger is real: `reward_ledger`
stores `focus_coins_earned` per settled session.

**Guard:** the same test file asserts the router has no `shop`/`store`/`mall`/
`exchange`/`redeem`/`buy` path, which is the route a sink would need. It cannot
prove no in-page redemption is ever added without a route, so the rule is also
stated here.

### D3 — Collection naming · **DECIDED — the recipe wins**

**Verified today:** of the **5** furniture items the companion can use, **2 had
two names** — `sofa` was 温馨沙发 as a recipe and 沙发 as furniture; `desk` was
窗边书桌 and 书桌. The other three already agreed.

> An earlier document recorded "7 of 8". That counted all eight recipes, three of
> which (`table`, `lamp`, `cabinet`) have no catalog entry to compare against.
> Measured against the furniture the companion actually uses, it is 2 of 5.

**The decision (owner):** the crafting recipe is the user-facing name. Keep
internal ids, historical data and database compatibility.

**Implementation — two surfaces changed, no database change:**

- `furniture_catalog.dart`: `sofa` 沙发 → **温馨沙发**, `desk` 书桌 → **窗边书桌**.
- `pet_collection_page.dart`: the collection is a third naming surface and
  **seven of its eight** recipe-backed items disagreed too (温馨布艺沙发 vs
  温馨沙发, 专注写字台 vs 窗边书桌, …). All eight now read the recipe name.
  Descriptions keep their own voice; only the name had to become single.
- **The database is untouched.** The recipe names were already the canonical ones
  (`app_database.dart` seeds 温馨沙发 / 窗边书桌), so nothing is migrated and
  existing installs keep their ids, their rows and their progress.

**Guard:** `test/presentation/furniture_name_agreement_test.dart` reads the
**seeded database** — the recipe truth — and asks both display surfaces to agree
with it, then asserts no id has two names anywhere. Reverse-proved: restoring
沙发 / 温馨布艺沙发 fails three of its four tests, naming the id and both names.

**Note:** the two `const` catalogs cannot *derive* the name at compile time, so
agreement is enforced by test rather than by construction. That is the weaker of
the two options and is why the test reads the seed rather than the other list —
comparing two hard-coded lists would pass while both drifted from the recipe.

### D4 — `long_session` memory threshold · **DECIDED — 50 minutes**

**Verified today:** `long_session` appears nowhere in `lib/`. `first_focus` and
`level_up` shipped because neither needed a number — "the first" is not a
threshold, and the level rule is the existing curve. A long session does need
one.

**The decision (owner):** a single valid focus session reaching **50 minutes** may
produce a `long_session` memory, respecting the existing memory privacy, consent
and dedup rules.

**Implementation — the one decision that needed real code:**

- `PetMemoryType.longSession = 'long_session'`, added to the closed `all` set
  (which a test already asserts every written type belongs to, so nothing can
  invent a type).
- `CompanionMemory.longSessionThreshold = 50 * 60`, declared beside the only rule
  that reads it. The rule measures **sustained focus** — the same
  `sessionSeconds` settlement uses for coins and XP — so a memory cannot describe
  a session the ledger disagrees with.
- Both settlement paths now pass the duration: the atomic
  `SettlementDao.settleAtomically` (which already had `addedFocusSeconds`) and the
  sequential `RewardService` fallback (`session.elapsedSeconds`). The decision
  stays in the one pure function so the two paths cannot disagree.
- The memory's content names the session's own length (`陪你专注了 90 分钟`), not
  the threshold, so a 90-minute session does not read as "50 minutes".

**Existing rules honoured, not re-invented:** dedup is the existing derived id
(`mem_<pet>_<type>_<ts>`) plus `InsertMode.insertOrIgnore`; the write stays inside
the settlement transaction that owns the exactly-once gate, so a memory can never
describe a rolled-back session; privacy is unchanged (memories are local-only and
never synced — see D7).

**Tests:** 6 new cases in `companion_memory_test.dart` pin the boundary
(49:59 no, 50:00 yes), the content, the closed set, and — the one that matters —
that a 50-minute session reaches the database through **both** real settlement
paths. Reverse-proved: disabling the rule fails 4 tests including that one.

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


### D6 — Growth economy · **DECIDED — 100 XP per level, cap 30, no reset**

**Verified today:** `GrowthLevelCurve` documented itself as a **temporary
default** — 100 XP per level, cap 30 — chosen because two pages already assumed
it, not because any product contract specifies it.

**The decision (owner):** keep 100 XP per level and the 30-level cap for V1, and
**do not reset existing levels or cumulative XP**.

**Implementation: no behavioural change; the doc comment changed.** The curve was
already the approved shape and was already applied to stored XP rather than
replacing it, so no install loses progress. What changed is the class's own
status line, from `TEMPORARY DEFAULT MAPPING` to `APPROVED FOR V1 (D6)` — a claim
a future reader would otherwise act on.

**Guard:** `test/domain/growth_curve_v1_test.dart` pins the numbers **as
literals**. The pre-existing curve tests assert relationships *through* the
constants ("the level at the cap is `maxLevel`"), so they stay green if
`xpPerLevel` becomes 250 — they check internal consistency, not the approved
economy. This one names 100 and 30, and also pins the no-reset half: an XP total
already stored still maps to its own level, and XP beyond the cap is kept rather
than clamped away (so raising the cap later needs no data recovery).

### D7 — Is cloud sync a shipping promise? · **DECIDED — local-first, no sync promised**

**Verified today:** `SyncEngine` documents itself as an offline-first skeleton and
`flush()` is a no-op.

**The decision (owner):** V1 is local-first and does not promise cloud sync. Any
unimplemented sync capability must be plainly unavailable, and **no screen may
show a fake "synced" state**.

**Implementation: no code change needed — the UI was already honest.** The
data-and-sync page reads `本地数据已保存` / `当前处于离线状态` / `当前版本暂不支持云端同步`
/ `当前版本以本地存储方式运行，不会执行云端同步`, and device-walked this window
(`54_data_sync.png`). `LocalOnlySyncEngine.isOnline` returns `false`.

**Guard:** the same test file asserts the engine reports itself offline, and — the
part that matters — that a real `enqueue()` followed by a real `flush()` leaves
the outbox entry **pending**. The machinery to claim success exists
(`SyncStatus.synced` and `markSynced()`), so this pins that no code path reaches
it. Reverse-proved: making `flush()` mark entries synced fails the test with
"would let the UI show a synced state for a sync that never happened".

**Also verified:** `markSynced` has no caller anywhere in `lib/`.

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
P25_PRODUCT_DECISIONS: CLOSED

DECIDED AND IMPLEMENTED:    7   (D1, D2, D3, D4, D5, D6, D7)
PRODUCT_DECISION_REQUIRED:  0
DEFERRED:                   6   (F1-F6)
BLOCKED_EXTERNAL:           4   (B1-B4)
APPROVED / SHIPPED:         8   (section 4)
```

**All seven decisions are closed.** D5 was closed earlier (the room is
action-authoritative; P19's gate measures 1 rather than a remembered 2). The owner
approved the remaining six as V1 rules:

| | decision | code change |
|---|---|---|
| D1 | no material economy, crafting costs time | **none** — already true |
| D2 | keep the coin ledger, no sink in V1 | **none** — already true |
| D3 | the recipe is the furniture's user-facing name | 2 furniture labels + 8 collection names |
| D4 | `long_session` at 50 minutes | type, threshold, rule, both call sites |
| D6 | 100 XP/level, cap 30, no reset | **none** — doc status only |
| D7 | local-first, nothing claims to sync | **none** — already honest |

**Four of the six needed no code at all**, which is the honest headline: the
product already behaved as decided, and what the decision changed was the
*meaning* — an unfinished feature became an intended rule. The two that did need
work are the two where the code genuinely disagreed with the intent: a name shown
two ways, and a memory type that needed a number.

Each decision carries a guard that fails if it is silently reversed:
`furniture_name_agreement_test.dart`, `growth_curve_v1_test.dart`,
`v1_decisions_guard_test.dart`, and the D4 cases in `companion_memory_test.dart`.
Each guard was reverse-proved by restoring the pre-decision behaviour.

The four blocked items need the owner or an artist, not an agent. Nothing in this
list is blocked on engineering.
