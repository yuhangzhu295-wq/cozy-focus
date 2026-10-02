# Flaky Test Classification

Baseline: HEAD `0d0a14f`, before the fix below. Host clock at the time of
diagnosis was ~03:2x local.

Method: reproduce under load, capture the real assertion, then bisect the
input. Running the two suspect files together reproduced the failure 5 times in
6 runs; running them alone reproduced it 1 time in 6. The difference is load,
not code — which is what pointed at an *input* the test does not control rather
than at a race in the code under test.

---

## Class 1 — FIXED: the avatar did not control its own inputs

Both failures were the same defect wearing two symptoms.

| Test | Symptom | Failure rate before |
|---|---|---|
| `phase6d_interact_reachability_test.dart` — "Home idle Mochi exposes the fallback interaction…" | `Bad state: No element` — `find.byType(PetIdleFallbackView)` matched nothing | 4 of 6 runs |
| `mochi_live_gate_test.dart` — "with nothing running the pet is truthfully idle" | `Expected: idle or sleep, Actual: pause` | 1 of 6 runs |

### Root cause A — the companion read the wall clock, not the app's clock

`CompanionAvatar._readContext()` built its time-of-day band from
`DateTime.now()`:

```dart
timeOfDay: TimeOfDayResolver.resolve(DateTime.now()),   // before
```

The band selects the ambient behaviour pool — a late-night companion is offered
a resting beat a daytime one is not. So the companion's presentation depended on
*when the suite happened to run*. Diagnosed at ~03:2x, which is why it failed
consistently during this session and passed earlier in the day.

This is not only a test problem. It is the same defect the room simulation
already carries a fix and a comment for
(`room_simulation.dart`: "Read through the injected clock rather than
`DateTime.now()`"). The avatar had simply never been given the same treatment,
so the app's own clock abstraction was bypassed for the companion's most
visible output.

**Fix:** read the injected clock.

```dart
timeOfDay: TimeOfDayResolver.resolve(ref.read(focusClockProvider).now()),
```

In production `focusClockProvider` returns `SystemFocusClock`, whose `now()` is
`DateTime.now()`, so production behaviour is byte-identical. In a test it is the
one seam that makes the band controllable.

### Root cause B — no seam for the random source

`CompanionAvatar` constructed its director with the default RNG:

```dart
_director = CompanionBehaviorDirector(catalog: …, context: _readContext());  // before
```

`RandomSource` was already injectable *into the director* — ten test files use
that — but the avatar builds its own director, so a test that renders a real
avatar (home page, room, settings) had no seam and silently got
`SystemRandomSource()`. Which pose Mochi presents was genuinely random, and a
pose with its own sprite drawing routes the avatar through the sprite player
instead of the layered rig `phase6d` reads.

The runtime's own documentation states the rule this restores: *"production uses
natural randomness while tests inject a fixed seed, so a behaviour test can
never be flaky."*

**Fix:** add `companionRandomSourceProvider` (default `SystemRandomSource()`, so
production is unchanged), have the avatar read it, and let the two tests
override it with `FixedRandomSource`.

### Verification

| Check | Before | After |
|---|---|---|
| `phase6d_interact_reachability_test` alone, 6 runs | 4 failures | 6 passes |
| `mochi_live_gate_test` alone, 6 runs | 1 failure | 6 passes |
| Full suite, 3 consecutive runs | 1–2 failures each | **1071 / 1071, three times, zero failures** |

A stale comment in `mochi_live_gate_test` that explained the `sleep` tolerance
by the wall clock was rewritten: the stated reason no longer holds, and a
comment that justifies a tolerance by a cause that has been removed is worse
than no comment.

---

## Class 2 — REAL HAZARD, NOT CURRENTLY FLAKY (deferred)

`appRouter` is a **top-level global `GoRouter`**
(`lib/presentation/navigation/app_router.dart:27`). Nine test files import it
and several call `appRouter.go(…)` on it directly.

Within a file every `testWidgets` shares that one instance, so the current
location leaks from one test into the next: a test that assumes it starts at
`/` actually starts wherever the previous test left off.

It is **deterministic today** because Flutter runs tests within a file in
declaration order. So this is not the cause of anything currently failing. It is
still a hazard, because:

- every test in such a file silently depends on the ones before it;
- any reordering, or a `--test-randomize-ordering-seed` run, would expose it;
- adding a test in the middle of a file can break a later one.

**Not fixed here.** Moving the router behind a provider (or exposing a factory)
touches nine test files plus the app bootstrap — a broad blast radius for
something that is not currently red. It belongs in P13 Hardening with its own
verification, not in a flake fix.

---

## Class 3 — ENVIRONMENT-DEPENDENT BY DESIGN (not a flake)

`room_simulation.dart` uses `DateTime.now()` for its own tick clock. That is
deliberate and documented: the tick measures real elapsed time, and the *night
rule* — the part that changes behaviour — already reads the injected clock. A
test cannot advance that dwell deadline, which is recorded in the P7 design doc
as a known limitation rather than a bug.

---

## Summary

| Class | Count | Status |
|---|---|---|
| Uncontrolled inputs in `CompanionAvatar` (clock + RNG) | 2 tests | **FIXED**, 3× green full suite |
| Global `appRouter` shared across tests in a file | 9 files affected | hazard, deferred to P13 |
| Real-clock tick in the room simulation | 1 | by design, documented |
