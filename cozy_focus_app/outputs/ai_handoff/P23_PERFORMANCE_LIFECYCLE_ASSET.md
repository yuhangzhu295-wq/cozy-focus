# P23 — Performance / Lifecycle / Asset Regression

```
P23_LIFECYCLE:   PASS
P23_PERFORMANCE: PASS
```

`test/architecture/performance_lifecycle_budget_test.dart` — 6 tests, plus the
existing `companion_lifecycle_leak_test.dart` (10 tests) which this phase did not
duplicate.

---

## 1. Every budget came from a measurement

The brief is explicit: **do not invent arbitrary performance promises**. So each
budget below was measured first, and the gate that uses it prints the measurement
it is derived from. A budget with no measurement behind it is a wish, and a wish
that fails is worse than no gate.

| What | Measured | Budget | Headroom |
|---|---|---|---|
| sprite packs | **3.11 MB**, 147 frames | 6 MB | ~2× |
| bytes per frame | **21.6 KB** | 40 KB | ~1.9× |
| release APK | **29.5 MB** | 34 MB | ~15% |
| release AAB | **48.1 MB** | 55 MB | ~14% |
| `assets/` total | **3.7 MB** | 7 MB | ~1.9× |
| peak frame callbacks, one companion | **5** | 20 | 4× |
| fastest periodic interval | **250 ms** | ≥ 100 ms | 2.5× |

Bytes-per-frame is deliberately a separate budget from the total. The total moves
whenever an action is added — which is normal and should not trip a gate — while
the average frame size does not, so it is the better regression signal for the
encoding itself.

---

## 2. Lifecycle

### What was already covered, and not repeated

`companion_lifecycle_leak_test.dart` already asserts: no frame callback and no
pending timer after disposal; the clock requests no frame callback; the motion
controller returns to zero listeners and timers; switching companion repeatedly
leaks nothing; **background then foreground resumes the same behaviour**; reduced
motion toggling leaves no pending timer; the cat animates and releases
everything. That is the background/foreground requirement the brief names, and it
was already met.

### What this phase added

**No permanent busy loop.** The presentation scheduler's interval is asserted to
be ≥ 100 ms. Measured at 250 ms (4 Hz) — a scheduler picking behaviours, not a
frame loop.

**Frame callbacks stay bounded.** Sampled across ten simulated seconds and the
peak bounded.

> The first version of this test asserted the count was **constant**, and it
> failed: 4, then 6. That was not a leak. The companion changes behaviour, so a
> different number of `AnimationController`s is legitimately running at different
> moments. **A snapshot of a varying quantity is the wrong assertion** — what an
> unsettled loop looks like is the count growing *without bound*, so the gate now
> samples and bounds the peak.

**No per-companion timer proliferation.** Each avatar has exactly one
`CompanionPresentationClock` — asserted as `==`, not `<= 1`, and the reason is
worth recording because my first attempt got it backwards.

The companion picker renders one `CompanionAvatar` per companion, so three
companions means three clocks. My first assertion was that three should be one,
and it failed. That premise was wrong: **each avatar owns its own
`CompanionBehaviorDirector`, and the clock is what advances it**, so one clock per
companion is the design, not duplication. What *would* be proliferation is a
**second** repeating timer per avatar — someone adding another `Timer.periodic`
inside the avatar, so a page with three companions runs six schedulers for three
behaviours. That is what the exact `==` catches, and a `<= 1` would not.

### The timer inventory, for the record

| Site | Interval | Kind |
|---|---|---|
| `companion_presentation_clock.dart` | **250 ms** | periodic, app-scoped per director |
| `room_simulation.dart` | 2 s | periodic, explicit start/stop |
| `focus_session_controller.dart` | 1 s | periodic, while a session runs |
| `companion_sprite_player.dart` | frame duration (3–8 fps) | periodic, only while visible |
| `focus_active_page.dart` | encouragement | periodic, while the page is up |
| `room_page.dart` | — | `Ticker` for travel, disposed |
| motion / blink / cooldown timers | 80 ms – seconds | **one-shot**, self-releasing |

The fastest repeating interval in the app is 250 ms. Nothing polls at frame rate.

---

## 3. The negative proof

A gate that cannot fire is indistinguishable from one that is not there. The
proof mounts a widget that schedules another repeating `AnimationController` on
every frame — the shape of a loop that never settles — and runs the same
measurement:

| | peak frame callbacks |
|---|---|
| a settled companion | **5** |
| an unbounded spinner | **62** |
| budget | **20** |

The separation is wide and the loop climbs monotonically, so the gate is not
sitting on the line. The proof also releases its controllers, so it does not leak
into teardown itself.

---

## 4. What this does not claim

- **No frame-rate claim.** Widget-test frame timing is synthetic — the binding
  does not rasterise — so nothing here asserts frames per second. What is
  measured is the rate at which the app *asks to do work*.
- **No memory measurement.** The brief lists memory; Dart's widget tests do not
  give a meaningful heap figure, and an invented one would be worse than none.
  The leak tests are structural (listeners, timers, callbacks) rather than
  byte-counting.
- **No decode benchmark.** `decodePngFile` is the test-only pure-Dart decoder,
  which is far slower than the engine's and would produce a misleading number.
  Asset size is budgeted instead, and P15 measured the decode-relevant property
  that matters: the frames are indexed PNGs, which is what the 3.11 MB is.
- **The APK/AAB budgets are recorded, not yet enforced by a test.** They need a
  build, so they belong to the orchestrator gate (P26/master automation) rather
  than to a Dart test. They are written down here so that gate has a baseline.

---

## 5. Gates

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | **PASS** — 266 files, 0 changed |
| `flutter analyze --fatal-infos --no-pub` | **PASS** — 0 issues |
| `flutter test --no-pub` | **PASS** — **1175 / 1175** (was 1169; +6) |
| `flutter build apk --release` | **PASS** — 29.5 MB |
| `flutter build appbundle --release` | **PASS** — 48.1 MB |
| `git diff --check` | **PASS** |
