# P11 — Daily Life: design

## 0. Scope and its source

The roadmap lists P11 as **Daily Life**. It is not specified anywhere in the
repository: a full-tree search for `P11`, `Daily Life`, `daily_life` and
`dailyLife` returns exactly four hits, and none of them defines the feature —
`CURRENT_STAGE.json` records `"P11_daily_life": "NOT STARTED"`,
`P7_ROOM_PLACEMENT_DESIGN.md` records the capability as *"Daily Routine —
absent (P11 scope)"*, and `FINAL_GATE.md` records it as *"Not started."*

So the shape below is a **chosen design**, not a transcription, and it is
written to be argued with. What is *not* invented is the surrounding
architecture: the companion runtime, the room simulation, the furniture catalog
and the time-of-day bands all already exist, and this design is constrained to
fit them.

---

## 1. The audit: what "daily life" is today

### 1.1 The day has five bands and one rule

`lib/presentation/companion/time_of_day.dart` already tiles the 24-hour clock
into five bands — `morning`, `midday`, `afternoon`, `evening`, `lateNight` — and
`time_of_day_test.dart` sweeps all 24 hours to prove the bands neither overlap
nor leave a gap.

`FurnitureActionResolver.decide` then reads that band in exactly **one** place:

```dart
if (input.timeOfDay == TimeOfDayBand.lateNight || input.vitals.isTired) {
  final decision = _restDecision(input);
  if (decision != null) return decision;
}
return _idleDecision(input);
```

### 1.2 Therefore the companion has no day

`_idleDecision` walks the anchors in `roomItemId` order and returns the first
unlocked action carrying the `idle` trigger. It does not read the band, the
clock or anything else that changes across a day.

The consequence is precise and worth stating plainly:

> Between **05:00 and 22:59** — eighteen hours, four of the five bands — the
> companion's behaviour is **identical**. It has a bedtime and nothing else.

That is the gap P11 exists to close. A companion that behaves the same at 07:00
and 21:00 has a night mode, not a daily life.

### 1.3 What is already true and must stay true

| Property | Where it is enforced |
|---|---|
| Time-of-day is presentation-only; it cannot reach XP, coins or a settlement | `time_of_day_test.dart` scans `lib/domain/` and `lib/data/` and fails if either references the types |
| The simulation cannot write business state | `RoomSimulationController` holds no repository; it only reads providers |
| Furniture behaviour is data, not branching | `furniture_catalog.dart` is a table; a test asserts the resolvers contain no `== 'sofa'`-style id tests |
| Every action has a cause | `RoomDecisionCause`; a test asserts each catalog action declares at least one trigger |
| An unlock *adds* behaviour | `FurnitureAction.requiresUnlock`, asserted for every catalog action |

Any P11 design must add a daily rhythm **without** weakening any of these. In
particular it must not become a second source of business truth, and it must not
become a second source of bedtime.

---

## 2. The design

### 2.1 The idea in one line

**A routine is a per-band, ordered preference list over behaviours the catalog
already declares.**

It does not invent behaviour. It *selects* among behaviours that exist, and it
says why. `lateNight` is deliberately left out, because the existing night rule
already owns bedtime and two answers to "when does it sleep" is one too many.

### 2.2 Priority: where the routine sits

The existing branch order *is* the policy, and the routine is inserted so that
it never overrides a stronger cause:

| Order | Cause | Why it outranks the routine |
|---|---|---|
| 1 | `playerRequest` | The player asked. Nothing outranks an explicit request. |
| 2 | `focus` | The player asked for a focus session; the companion is supposed to be working *with* them. |
| 3 | `tired` (break) | A paused session is the brief's break — the companion should head for the sofa. |
| 4 | `night` / `tired` | Being genuinely tired, or it being late, outranks a preference. |
| **5** | **`routine`** | **The daily rhythm. Fills the eighteen hours that were previously shapeless.** |
| 6 | `idle` | The fallback, unchanged. |

The routine therefore only ever changes what the companion does **when nothing
more important is happening** — which is exactly the window that was previously
undifferentiated.

### 2.3 The routine table

Grounded in the actions the catalog actually declares. A step names a role and a
specific action id; the action must also carry the `routine` trigger, so the
table and the catalog have to agree.

| Band | Hours | Step 1 | Step 2 | Reading |
|---|---|---|---|---|
| `morning` | 05–10 | `front` → `read` | `seat` → `sit` | A gentle start: read, or sit in the light |
| `midday` | 11–13 | `work` → `craft` | `front` → `search` | The active middle of the day |
| `afternoon` | 14–17 | `front` → `search` | `work` → `craft` | Exploring, then making |
| `evening` | 18–22 | `seat` → `sit` | `seat` → `rest` | Winding down |
| `lateNight` | 23–04 | *(none)* | *(none)* | Owned by the night rule — see §2.1 |

Two properties fall out of this table, and both are asserted:

- **Every step is reachable.** Each names an action that exists in the catalog
  and carries the `routine` trigger.
- **Every band except `lateNight` has at least one step**, and `lateNight` has
  none *on purpose*. The absence is pinned by a test so it reads as a decision
  rather than an omission.

### 2.4 Why the routine cannot be a second source of truth

- It is a `const` table plus a pure resolver. No I/O, no `DateTime.now()`, no
  state.
- It is **presentation-only**, and this is enforced the same way the time-of-day
  bands are: a test scans `lib/domain/` and `lib/data/` and fails if either
  references the routine types. The routine therefore *cannot* express an XP
  change, a coin change or a settlement, because it has no vocabulary for them.
- It returns a `RoomDecision` and nothing else. Applying the decision — moving
  the companion, adjusting vitals — stays in the simulation, exactly as before.

### 2.5 Why author it as JSON *and* Dart

This is the codebase's established pattern for authored behaviour
(`assets/companion/*.json` is the authoring source; Dart tables are the runtime
mirror; a parity test pins them). The routine follows it:

- `assets/companion/daily_routine.json` — the authoring source, with the
  rationale for each band written next to it.
- `lib/presentation/companion/runtime/daily_routine.dart` — the synchronous
  runtime mirror. Synchronous because the room must know what the companion is
  doing on the first frame, without an `await` between app start and first paint.
- `daily_routine_parity_test.dart` — asserts the two agree field for field, so
  editing one without the other is a red gate rather than a silent divergence.

---

## 3. Slices

| Slice | Content | Gate |
|---|---|---|
| **1** | `daily_routine.json`, the Dart mirror, and the parity test | Parity test green; no behaviour change |
| **2** | `FurnitureTrigger.routine`, the catalog additions, `RoomDecisionCause.routine`, the resolver branch | Resolver and priority tests green |
| **3** | Room copy for the new cause; the presentation-only guard; full gates | `format` / `analyze` / full suite |

Slice 1 deliberately ships a table nothing reads. That is intentional: it makes
the data reviewable on its own, and it means the behaviour change in slice 2 is
a branch insertion rather than a table edit and a branch insertion at once.

---

## 4. What P11 is not

- **Not a scheduler with wall-clock state.** The routine reads the *band*, which
  the existing resolver already receives. No new timer, no new stored state.
- **Not a punishment system.** No neglect, no decay, no "you did not visit me".
  The routine changes what the companion does, never how it feels about the
  player.
- **Not a second bedtime.** `lateNight` is left to the rule that already owns it.
- **Not a business change.** It cannot reach the reward economy, and a test
  proves it rather than a comment claiming it.
