# Final Gate — Recovery Branch

- Branch: `recovery/v4.2.1-rebuild`
- HEAD: `e956cf1b20928db2e57054241b0f23c0c80aefae`
- Remote: identical (`e956cf1`)
- Worktree: clean
- Commits on this branch: **19**, spanning 160 files, +3985 / −229

**Verdict: PASS as a locally verifiable build. NOT a store-ready release, and
NOT the full roadmap.**

Two things are deliberately not claimed:

1. The roadmap's `Final Release Gate (F1–F13)` checklist is not in my context, so
   this gate reports **measured evidence** rather than asserting a pass against
   criteria I cannot read. Nothing here should be read as "F1–F13 all green".
2. P10 rabbit, P11 Daily Life and P12 AI are **not delivered**. They are roadmap
   scope that remains open, and they are named as such in §6.

---

## 1. Local gates — all measured at this HEAD

| Gate | Result |
|---|---|
| `dart format` | **PASS** — 255 files, 0 changed |
| `flutter analyze --fatal-infos` | **PASS** — 0 issues |
| `flutter test` | **PASS** — 1091 / 1091 |
| Suite stability | **PASS** — two consecutive runs, 1091/1091 each |
| `git diff --check` | **PASS** |
| Worktree | **clean**; local HEAD == remote HEAD |

Test count over the session: **1039 → 1091** (+52).

---

## 2. Release artifacts — measured from the built files

| Artifact | Size |
|---|---|
| `app-release.apk` | 40.4 MB |
| `app-release.aab` | 58.9 MB |

```
aapt2 dump badging app-release.apk
  package: name='com.yuhangzhu295.cozyfocus' versionCode='1' versionName='1.0.0'
  compileSdkVersion='35' targetSdkVersion:'35'
```

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

`emulator-5554` / `GoodnightPixel7Api34`, debug APK built from this HEAD and
installed.

Verified on device across the session, with screenshots retained under
`outputs/ai_handoff/android_v1_runtime/`:

- **Collection** reports `2 / 8` and `已收集 25%`, and the two preview entries read
  `未开放` — the P8 fix, seen on a real screen.
- **Craft detail** carries the honest material copy.
- **P7's placement toolbar** exercised end to end for the first time: two rows
  render, 放大 took a sofa from scale 1.0 to 1.4 with a visibly larger sprite,
  隐藏 left a faint ghost and flipped its icon to 显示 while the other sofa
  stayed opaque.
- **After the canvas change** (`p13_room_512.png`): the companion's feet still sit
  *on* the sofa cushion — no float, no sink. This is the check that matters,
  because a canvas change is exactly the kind that misaligns silently.

---

## 4. What shipped, by phase

| Phase | Delivered | Commits |
|---|---|---|
| **P7** room free placement | capability, toolbar, edit/life separation; **no** `RoomLayoutManager`, no `FurnitureInstance`, no rotation | `3490d6a` `8411598` `f5037c3` `6ef0c8b` |
| **P8** collection + craft loop | audit; the two truthfulness fixes; three scope options recorded, none implemented on a default | `624f2a8` `342a4e7` `0d0a14f` `3b2f75c` |
| **P9** companion memory | audit; producers for `first_focus` and `level_up`, inside the settlement transaction | `303fbe7` `c46eb75` |
| **P10** cat pack | **13 actions / 49 frames**, matching the dog exactly | `aef8df1` `5409c0b` `b7c2827` `e5d86f8` `23a8261` `8017d11` |
| **P13** hardening | global-router leak fixed; release build closed; sprite canvas halved | `83c7044` `e956cf1` |

### The cat went from 1 idle frame to a complete companion

Before this work the cat had one idle frame and no locomotion. It now ships the
dog's exact shape — same 13 actions, same 49 frames, every action meeting its
frame count — so **no pose falls back to a neighbour's art**.

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
   the canvas took the release APK from 75.5 MB to 40.4 MB.

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

---

## 6. Not delivered

| Phase | Status |
|---|---|
| **P10 rabbit** | Not started. The rabbit renders through the layered rig — a real drawing, not a fake animation — so it is degraded rather than broken. The pipeline is ready at the 512 canvas. |
| **P11 Daily Life** | Not started. |
| **P12 AI personality** | Optional by the roadmap; not started. |

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
- **P2: 8** — §5 items 1–6, plus the rabbit and P11 being undelivered.

---

## 9. Verdict

The application is a **verifiable build**: it compiles, its 1091 tests pass twice
in a row, it produces installable release artifacts under the correct
application id, and its behaviour has been checked on a device rather than only
in tests. The two defects that were eroding that confidence — an uncontrolled
clock in the companion and a router leaking state between tests — are fixed and
the fixes were measured.

It is **not** a store-ready release (no signing key, no icon), and it is **not**
the complete roadmap (no rabbit, no daily life, no AI layer). Both of those are
stated here rather than implied by a green suite.
