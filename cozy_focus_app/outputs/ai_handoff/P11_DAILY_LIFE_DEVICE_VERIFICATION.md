# P11 — Daily Life: device verification

Verified on the emulator (`emulator-5554`, `sdk_gphone64_x86_64`), debug APK
built from `a6070b2`, application id `com.yuhangzhu295.cozyfocus`.

The point of this document is that the routine was checked **on a device**, not
only in tests — the standing requirement that a feature is not finished until it
is reachable at runtime.

---

## 1. The device state

| Fact | Value | Why it matters |
|---|---|---|
| Device clock | `Sat Oct 3 09:58 GMT 2026` | Hour 9 → `TimeOfDayBand.morning` |
| Selected companion | 小兔 (rabbit) | The routine is not dog-specific |
| Furniture placed | sofa only | Morning step 1 (`front` → `read`) has no anchor, so step 2 (`seat` → `sit`) is the reachable one |
| Furniture owned | sofa, 原木茶几 | The tea table is not in the furniture catalog, so it contributes no anchor and no behaviour |
| Focus session | none | The home page read 恢复专注, so no session is running |

---

## 2. What the room did

Captured immediately after opening the room (`p11_02_room.png`):

```text
小兔 正在坐下
心情 75   精力 84   专注 60
```

The companion is drawn **seated on the sofa**.

### The vitals are the proof, not the picture

`CompanionVitals` defaults are `mood 72`, `energy 80`, `focusLevel 60`. The
observed `75 / 84 / 60` is exactly `72+3` and `80+4` — and `energy +4, mood +3`
is precisely the declared effect of **`sofa/sit`** in `furniture_catalog.dart`.

The label is `'$companionName 正在${action.label}'` where the sofa's `sit` action
is labelled `坐下`. So both the label and the applied effect identify the chosen
action as `sofa/sit`.

### No other cause can explain it

At 09:58 with `energy 84` and no tap, every other branch is excluded:

| Cause | Why it did not fire |
|---|---|
| `playerRequest` | No furniture was tapped |
| `focus` | No session is running — the home page offered 恢复专注 |
| `tired` (break) | No session is paused |
| `night` / `tired` | Hour 9 is `morning`, and `energy 84` is far above the tired threshold of 40 |
| `idle` | `sofa/sit` is triggered by `playerTap`, `energyLow` and `routine` — **not** `idle`. The idle walk cannot select it |

The only remaining trigger on `sofa/sit` is the new `FurnitureTrigger.routine`.
The routine branch is therefore the only path that can have produced this, which
is what makes the observation conclusive rather than merely consistent.

### Before this change the same state produced a different room

At 09:58 with only a sofa, the old resolver reached `_idleDecision`, found no
`idle`-triggered action on the sofa, and returned `floorAnchor` with
`isBusy: false` — the companion stood on the floor. The room now shows it seated,
which is the behavioural difference P11 exists to make.

---

## 3. A second observation, 35 seconds later

`p11_05_room_later.png`, at 10:00:

```text
小兔 正在坐下
心情 99   精力 100   专注 60
```

Still seated, still `sofa/sit`, and the vitals have climbed to the ceiling.

### What this reveals

The routine is a **preference list, not a scheduler**: for as long as the band
and the furniture are unchanged, re-making the decision deterministically returns
the same step. So the companion commits to `sofa/sit` for the whole morning band,
and because that action has a *positive* energy effect, the vitals saturate —
energy pins at 100 and mood at 99.

Two consequences follow, and both are accepted rather than overlooked:

1. **The companion does not move during a band.** It sits from 05:00 to 11:00.
   This is consistent with the brief's actual complaint — that the companion
   "behaves like image switching" — because *commitment* is the property being
   asked for, not constant motion. It is also not a regression: the old idle
   walk was equally static, it simply stood on the floor instead of sitting.

2. **Energy saturates, so the `tired` branch is unreachable while seated.** The
   tired branch still fires in the cases it exists for — desk work drains energy
   (`focus_write` is `energy −6`), and a long session genuinely tires the
   companion. Sitting restoring energy is the catalog's own declared effect, and
   the same saturation is reachable today by tapping the sofa repeatedly.

Changing either would mean editing the furniture effects, which is a product
decision outside P11's scope and would move the furniture acceptance tests.

### The correction this forces

`_idleDecision`'s comment claims *"the variety the brief wants comes from the
dwell expiring and the decision being re-made"*. The device shows that is not
true when the decision is deterministic: re-making it returns the same answer.
The variety in the day comes from the **band changing**, four times between 05:00
and 23:00 — not from the dwell. The day has five distinct states instead of two,
which is the improvement, and it should not be described as more than that.

---

## 4. What the device did not show

- **A band change.** The emulator image refuses `adb root`
  (`adbd cannot run as root in production builds`), so `date` cannot be set and
  the clock could not be moved to another band. Band-dependence is covered by
  tests instead: all five bands are asserted in `daily_routine_test.dart`,
  including that the same room behaves differently in the morning and the
  evening.
- **The step-1 preference.** The player owns no bookshelf, so morning's first
  step could not be staged on the device. It is covered by the test that asserts
  the morning routine reads at the bookshelf.

Both gaps are named rather than papered over.

---

## 5. Errors

`adb logcat` filtered for `exception|error|assert|failed` across the app's
process returned **nothing** during the whole session.

---

## 6. Evidence

| File | Content |
|---|---|
| `p11_00_home.png` | Home, 09:57 — rabbit selected, no session running |
| `p11_01_growth.png` | Growth page, 09:58 |
| `p11_02_room.png` | The room, seated on the sofa, `75 / 84 / 60` |
| `p11_03_picker.png` | The furniture picker — sofa and 原木茶几 owned |
| `p11_04_room_routine.png` | The room settled |
| `p11_05_room_later.png` | 35 s later — still seated, `99 / 100 / 60` |
