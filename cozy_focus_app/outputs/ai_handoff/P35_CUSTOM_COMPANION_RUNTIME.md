# P35 — Custom Companion Runtime Productionization

Pack-first roadmap (`P31_P40_PACK_FIRST_ROADMAP.md`). Branch
`recovery/v4.2.1-rebuild`.

**Status: COMPLETE.** 1473/1473 tests, format clean, analyze clean.
Latest slice `4c3bc4d`.

## The defect, and why it was the same one as P33

The furniture panel was already capability-gated, so an action the companion has
no art for was never *offered*. The decision loop was not. It resolved a cause to
furniture and an action, and **the effect was applied to the companion's vitals**
— energy restored, mood lifted — before the director ever saw the committed
action and quietly declined to draw it.

So the companion rested without appearing to, and recovered from something that
never happened. That is the P33 defect one layer down: a decision about behaviour
made by something that does not know what the companion can do. P33 fixed the
*answer*; P35 fixes who is allowed to *ask*.

## The fix

`RoomDecisionInput` now carries the companion's capabilities, and it is a
**required** parameter. A default would be the same trap P33 removed — a gate
handed a permissive answer refuses nothing — and there is exactly one production
caller, so making it required means production cannot forget.

`_decisionFor` returns null when the action cannot be performed, so each branch
tries the next anchor (a pack that cannot sit may still rest on a rug) and then
falls through to the next cause, ending at the floor. **No commitment, no
effect.** The routine and idle decisions go through the same gate as a player
request, which is what "capability truth applies to autonomous decisions too"
means in practice.

`canPerform(actionId)` answers in the vocabulary the furniture recipes already
speak — `room_sit`, `focus_read`, `pause_rest` — so the question is a membership
test rather than a translation, and it lives in one place.

## Two things this deliberately did not do

Both of which I tried first, which is how I know.

### It did not use the stricter `canShow`

`canShow` is "can the companion be seen doing it", which is the *panel's*
question, because a chip promises a specific visible action. Using it in the
decision refused the dog its own sofa: `room_sit` is declared as a fallback rather
than shipped as frames, so the dog can be asked for it and draws idle. That is a
decided behaviour with its own P28 tests — the commitment-dwell work — and
**fifteen of them failed**, which is how I found out.

So the panel keeps the strict rule and the decision takes the permissive one, and
both now read from one place (`canShow` / `canPerform`), so the offer and the
decision cannot drift apart while still asking different questions. The panel's
`isOfferable` was rewritten to call `canShow` and is behaviour-identical — its old
`canSchedule && hasOwnDrawing` is exactly that.

### It did not remove the bookshelf's `search`

P35 asked whether two affordances sharing one animation should be resolved by
removing one. `bookshelf/search` and `desk/study` both produce `focus_think`. The
labels describe what the *player* is asking for — search this shelf, study at that
desk — and both are the companion thinking. There is one `focus_think` and no
second one is going to be invented for the difference, so the honest position is
**two affordances with one visible behaviour**, recorded in the catalog and pinned
by a test.

Writing that test then found two more shared pairs I had not noticed:

| companion action | affordances |
|---|---|
| `room_sit` | sofa/sit, rug/sit |
| `sleep` | sofa/nap, bed/sleep |
| `focus_think` | bookshelf/search, desk/study |

All three are now recorded decisions rather than coincidences, and a *new*
collision fails the test and has to be argued for.

## First-class, and staying that way

The failure mode here is not a crash. It is a custom companion that works while
quietly becoming a second kind of thing — a `CustomCompanionPage`, a
`MimiVisualProvider`, a room that asks where a companion came from before
deciding how it behaves. Each of those passes its own tests and then means every
future feature has to be built twice.

`custom_companion_first_class_test.dart` is a source-level guard, because
behaviour tests cannot see the class that does not exist yet:

- **one generic provider class, not one per pet** — the provider list is asserted
  to be exactly the three shipped companions plus `PackBackedCompanionVisualProvider`;
- **no page or room file reads `CompanionPackSource`** — the P31 rule that origin
  is recorded and consulted by nothing, made executable across the whole of `lib`;
- **no `isCustom` / `customCompanion` / `importedPack` branch anywhere** in `lib`.

## Verification

Capability truth, at both levels:

- `room_capability_test.dart` (9 tests) — the rule: no action, no effect, for the
  sofa, the bed, a player request, and every time-of-day band with the routine
  running; plus the guard against over-gating, that a companion which *can* do it
  still does.
- `room_capability_wiring_test.dart` (3 tests) — that the rule is **fed the
  truth** in production: a real `RoomSimulationController`, a real installed pack,
  a real sofa in the database, and the real availability provider. The dog still
  rests; a pack that ships only `idle` gets no action and no effect; and the same
  pack given the action is sent to the sofa.

The second file exists separately on purpose. The P33 audit found exactly this
class of bug — a gate that agrees with itself and refuses nothing — while every
gate test passed.

Hot install, cold start, selection, delete, fallback, partial and complete
capability are covered by the P32, P33 and P34 suites and were walked on the
device in those phases; P36 walks the whole flow again offline.

## Carried forward

- `room_sit` still has no frames of its own. The panel does not offer it, and a
  companion that does not declare a fallback for it cannot be given it. Give it
  real frames or a `drawAliases` entry and the chip returns with no code change.
- The animation-state path (travel, posture transitions) is still a separate
  selection path from the director, gated in P33 only to the extent that a pack
  cannot be forced into an override it has no art for.
- `docs/companion_assets.md` is still stale (1024×1024 / 919 / 511 claimed;
  512×512 / ~458 / 255 real).
