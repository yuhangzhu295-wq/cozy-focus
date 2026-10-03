# Final Gate — Recovery Branch

**Re-measured at `47af403`.** An earlier version of this document was written when
the rabbit had no pack and P11 did not exist; its §1, §2, §4, §6 and §9 were all
out of date, so the whole document was re-measured rather than patched. Where a
number changed, the previous value is shown beside it.

---

## 1. Local gates — all measured at this HEAD

| Gate | Result | Was |
|---|---|---|
| `dart format` | **PASS** — 258 files, 0 changed | 255 |
| `flutter analyze --fatal-infos` | **PASS** — 0 issues | same |
| `flutter test` | **PASS** — 1117 / 1117 | 1091 |
| `git diff --check` | **PASS** | same |
| Worktree | **clean**; local HEAD == remote HEAD | same |

Test count over the whole recovery track: **1039 → 1117** (+78).

---

## 2. Release artifacts — measured from the built files

| Artifact | Size | Was |
|---|---|---|
| `app-release.apk` | **29.5 MB** | 40.4 MB |
| `app-release.aab` | **48.1 MB** | 58.9 MB |

```
aapt2 dump badging app-release.apk
  package: name='com.yuhangzhu295.cozyfocus' versionCode='1' versionName='1.0.0'
  compileSdkVersion='35' targetSdkVersion:'35'
```

### The drop is larger than it looks

Between the two measurements the rabbit pack grew from **30 to 49 frames**, so
the artifacts got heavier and lighter at the same time. The saving is not a
side-effect of removing content.

It comes from shipping the sprites as **255-colour indexed PNGs**. The frames are
flat-shaded cartoon art; their raw colour counts (9.5k on a simple frame, 30k on
the busiest) are almost entirely anti-aliasing and soft shading spread across a
large smooth area, not colours anyone can distinguish. Indexing cut the sprite
directory from **19.2 MB to 3.1 MB** with no visible change — verified per-pixel
across all 147 frames (mean error 0.58/255; two pixels in the worst frame exceed
40/255, both on an anti-aliased edge) and by eye at 4× zoom on the busiest frame,
including a 5×-amplified difference map.

This is the second weight pass on the same problem: P13 halved the sprite canvas
(75.5 MB → 40.4 MB), and this re-encoded what remained.

**Signing: `RELEASE_SIGNING = NOT_RECOVERED`.**

```
apksigner verify --print-certs app-release.apk
  V2 Signer: certificate DN: C=US, O=Android, CN=Android Debug
```

The artifact is debug-signed. No keystore exists in the tree, and none was
generated — that would have been a fake. The build config already switches to
real signing the moment `android/key.properties` appears, with no code change.

---

## 3. Device verification

`emulator-5554` / `sdk_gphone64_x86_64`, release APK built from this HEAD,
installed and launched.

Verified on device, with screenshots retained under
`outputs/ai_handoff/android_v1_runtime/`:

- **Collection** reports `2 / 8` and `已收集 25%`, and the two preview entries read
  `未开放` — the P8 fix, seen on a real screen.
- **Craft detail** carries the honest material copy.
- **P7's placement toolbar** exercised end to end: two rows render, 放大 took a
  sofa from scale 1.0 to 1.4 with a visibly larger sprite, 隐藏 left a faint ghost
  and flipped its icon to 显示 while the other sofa stayed opaque.
- **After the canvas change** (`p13_room_512.png`): the companion's feet still sit
  *on* the sofa cushion — no float, no sink. A canvas change is exactly the kind
  that misaligns silently.
- **The rabbit pack is wired in** (`rabbit_wiring_*.png`): selecting the rabbit
  changes the art, and the room names the selected companion rather than always
  saying Mochi — which was a real hardcoded-name defect found by looking.
- **P11's daily routine fires** (`p11_02_room.png`): at 09:58 with only a sofa the
  room seated the companion, and the vitals read `75 / 84 / 60` — exactly the
  `sofa/sit` effect on the `72/80/60` defaults. `sofa/sit` is not `idle`-triggered,
  so no other branch could have chosen it. The vitals are what identify the action;
  the picture alone would not.
- **Indexed sprites render** (`p10_indexed_sprites_home.png`): the release APK
  draws them with correct transparency and no decode errors in the app process log.
  This is the check that the re-encoding did not break rendering.

### What the device did *not* show

- **P11 band changes.** The emulator refuses `adb root`, so the clock could not be
  moved to another band. Band-dependence is covered by tests across all five bands.
- **Per-action playback of the rabbit pack.** Tapping the rabbit in the room does
  not fire `tap_react`, so that action is unverified on device — the room page
  appears not to wire companion taps to the overlay. Per-action wiring is covered
  by `companion_pack_completeness_test.dart` instead.
- **The P4B visual gate.** Needs human judgement of whether the sprite art reads
  well. It cannot be automated.

---

## 4. What shipped, by phase

| Phase | Delivered | Commits |
|---|---|---|
| **P7** room free placement | capability, toolbar, edit/life separation; **no** `RoomLayoutManager`, no `FurnitureInstance`, no rotation | `3490d6a` `8411598` `f5037c3` `6ef0c8b` |
| **P8** collection + craft loop | audit; the two truthfulness fixes; three scope options recorded, none implemented on a default | `624f2a8` `342a4e7` `0d0a14f` `3b2f75c` |
| **P9** companion memory | audit; producers for `first_focus` and `level_up`, inside the settlement transaction | `303fbe7` `c46eb75` |
| **P10** cat pack | **13 actions / 49 frames**, matching the dog exactly | `aef8df1` `5409c0b` `b7c2827` `e5d86f8` `23a8261` `8017d11` |
| **P10** rabbit pack | **13 actions / 49 frames**, matching the dog and cat exactly | `5964f9d` `3ffc40d` `dbc0d95` `701afd2` `88829cc` `e4a9063` `8993c49` `e95ef78` `b664fe5` |
| **P11** daily life | authored routine + parity test; `FurnitureTrigger.routine` opt-in; `RoomDecisionCause.routine` second-to-last; 23 new tests | `c936397` `a6070b2` `a3b91ca` |
| **P13** hardening | global-router leak fixed; release build closed; sprite canvas halved; **sprites re-encoded as indexed PNG** | `83c7044` `e956cf1` `47af403` |

### All three companions now ship the same shape

The dog was the reference; the cat and then the rabbit were built to match it.
A test now asserts all three ship **the same action set and the same frame
count** and that none declares anything incomplete — deliberately stronger than
"the rabbit made progress", because it means a companion cannot quietly fall
behind and still look finished. **No pose falls back to a neighbour's art.**

### P11 gave the companion a day

Before P11 the companion had five time-of-day bands and exactly one rule that
read them: bedtime. Between 05:00 and 22:59 — four of the five bands — its
behaviour was identical. It had a night mode, not a daily life. The routine is a
per-band preference list over behaviours the furniture catalog already declares,
so it selects rather than invents, and it sits second-to-last in the priority
order so it only changes what happens when nothing more important is going on.

### Three defects found by measuring rather than assuming

1. **The companion did not control its own clock or randomness.** `CompanionAvatar`
   read `DateTime.now()` instead of the injected `FocusClock`, and built its
   director with the system RNG. The first is a *product* bug — the app's own
   clock abstraction was bypassed for its most visible output — and it made two
   widget tests depend on what time the suite ran. Fixed; three consecutive green
   full runs followed.
2. **The shared global router leaked navigation location between tests.** Measured
   with a two-test probe: a test that never navigated began at `/growth` because
   the test before it had gone there. Fixing it immediately exposed an assertion
   that had never been a true invariant and was only green because of the leak.
3. **The sprite packs were 45.6 MB for a character drawn at 92–150 px.** Halving
   the canvas took the release APK from 75.5 MB to 40.4 MB; re-encoding the
   remaining frames as indexed PNG took it to 29.5 MB.

A fourth, smaller one is recorded in §5 item 7.

---

## 5. Findings left open by decision, not by omission

| # | Item | Why it is open |
|---|---|---|
| 1 | P8 **materials** (`ingredientCosts` is a dead field) | Needs an owner-chosen source, drop rate and cost per recipe. Inventing them would add a second economy next to coins and risk a grind gate. The *false claim* was removed instead. |
| 2 | P8 **coin sink** (coins are earned and never spendable) | Needs an owner-chosen sink and price. |
| 3 | P8 **name drift** (7 of 8 items have two names) | Needs a choice of which list wins. My recommendation: derive the collection's name from the recipe, so one object has one name. Not done, because it changes copy the owner device-verified. |
| 4 | P9 `long_session` memory | Needs a threshold. `first_focus` and `level_up` needed none, so they shipped. |
| 5 | P4B visual gate | Needs human judgement of whether the sprite art reads well. Cannot be automated. |
| 6 | Room simulation tick reads `DateTime.now()` | By design; the night rule it feeds already uses the injected clock. Documented in the P7 design. |
| 7 | The room's label can disagree with the sprite it is drawing | The label resolves the furniture from the anchor id to name the action, and a companion on the **floor anchor** has none to look up, so it falls through to the cause-based sentence while a `companionAction` is still playing. Cosmetic and pre-existing; found while device-verifying P11 and recorded rather than fixed, because fixing it changes copy the owner device-verified. |

---

## 6. Not delivered

| Phase | Status |
|---|---|
| **P12 AI personality** | Optional by the roadmap; not started. |

That is the whole list. The rabbit pack and P11 are both delivered — see §4.

---

## 7. Blocked on the owner

| # | Item | Detail |
|---|---|---|
| 1 | **Release keystore** | `RELEASE_SIGNING = NOT_RECOVERED`. A fabricated keystore was explicitly ruled out. Supply one and the build switches over with no code change. |
| 2 | **Launcher icon (P1)** | Still the stock Flutter logo — dominant colours `(84,197,248)` / `(1,87,155)`. No approved artwork exists, so none was invented. |
| 3 | Store submission | Blocked on 1 and 2. |

---

## 8. Review findings

- **P0: 0**
- **P1: 1** — the launcher icon. It cannot be fixed by an agent, only by artwork.
- **P2: 8** — §5 items 1–7, plus P12 being undelivered. Down from 8 on the same
  scale only because two items left it: the rabbit pack and P11 are now
  delivered, and one item (the room label) was added.

---

## 9. Verdict

The application is a **verifiable build**: it compiles, its 1117 tests pass, it
produces installable release artifacts under the correct application id at
**29.5 MB**, and its behaviour has been checked on a device rather than only in
tests. The three defects that were eroding that confidence — an uncontrolled
clock in the companion, a router leaking state between tests, and 45.6 MB of
sprites for a character drawn at 92–150 px — are fixed and the fixes were
measured.

The roadmap content is now complete apart from one optional item: **all three
companions ship the same 13 actions / 49 frames**, and the companion has a daily
life rather than a bedtime.

It is **not** a store-ready release: there is still no signing key and no icon,
and both are stated here rather than implied by a green suite.
