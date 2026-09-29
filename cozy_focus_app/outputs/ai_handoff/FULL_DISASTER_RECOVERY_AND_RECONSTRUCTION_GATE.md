# FULL_DISASTER_RECOVERY_AND_RECONSTRUCTION_GATE

Project: COZY_FOCUS
Task: FULL_DISASTER_RECOVERY_AND_V4_2_1_RECONSTRUCTION
Date: 2026-09-29
Recovery branch: `recovery/v4.2.1-rebuild`

---

## 1. Recovery identity

| Field | Value |
|---|---|
| RECOVERY_SOURCE_BRANCH | `release/android-v1` |
| RECOVERY_SOURCE_SHA | `7b3a7f9ec3ffae77b5f835d9a9359a33b9eb4219` |
| EXPECTED_SHA | `7b3a7f9ec3ffae77b5f835d9a9359a33b9eb4219` |
| REMOTE_MOVED | **NO** — remote matched the expected SHA exactly |
| RECOVERY_BRANCH | `recovery/v4.2.1-rebuild` |
| REMOTE_BACKUP_SHA (empty anchor) | `7717a5fe02a40a54dd0db655cf31d82bcca68dc9` |
| REMOTE_RECOVERY_HEAD | `86bdfc680ea9e07afee5e22fb4ad39e3619093a2` |
| LOCAL_HEAD | `86bdfc680ea9e07afee5e22fb4ad39e3619093a2` |
| LOCAL_EQUALS_REMOTE | **YES** |

Git root: `C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat`
App root: `C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app`

The historical path did not exist, so parent directories were created and the
repository was cloned into the exact historical layout. No holding-rename was
needed. Nothing was deleted.

## 2. Toolchain

| Component | Actual |
|---|---|
| Flutter | 3.32.4 stable, revision `6fba2447e9` (matches `.metadata`) |
| Dart | 3.8.1 |
| Java | OpenJDK 17.0.10 (Android Studio JBR) |
| Android SDK | `C:\Users\zyu33\AppData\Local\Android\Sdk` (platforms 34/35/36) |
| NDK | `27.0.12077973` (matches the pinned `ndkVersion`) |
| Emulator | `GoodnightPixel7Api34` — Pixel 7, Android 14 (API 34), 1080x2400, 420dpi |

No Flutter upgrade and no dependency modernisation was performed.
`namespace` and `applicationId` remain `com.yuhangzhu295.cozyfocus`.

## 3. Baseline (freshly measured before any reconstruction)

| Gate | Result |
|---|---|
| pub get | PASS |
| format | PASS (0 changed) |
| analyze | PASS (no issues) |
| tests | **684 / 684** |
| debug APK | PASS |
| runtime smoke | PASS — Home, Focus, tap overlay, Pause, Resume, Complete, Records, Growth, Room, Craft, Collection, Dress, Settings |
| logcat | 0 crash / 0 ANR / 0 app exception |

Baseline report: `cozy_focus_app/outputs/ai_handoff/DISASTER_RECOVERY_BASELINE.md`.

## 4. Spec packages

| Package | Status |
|---|---|
| V4_1_SPEC | **AVAILABLE** |
| V4_2_1_SPEC | **AVAILABLE** |

Backed up (copied, originals untouched) to `C:\Users\zyu33\Documents\CozyFocus-Specs\`
(`V4_1\` 105 MB, `V4_2_1\` 35 MB). Not committed to Git.

## 5. Slice commits

| Slice | Commit |
|---|---|
| Baseline recovery report | `7717a5f` |
| A — Runtime foundation | `267303c` |
| B — Mochi migration | `9e61739` |
| C — Multi companion | `eb5c86f` |
| D — Room / Craft | `8b2bb13` |
| E — Growth / Time / Collection / Dress | `8dbc706` |
| Extensibility — fourth companion | `86bdfc6` |

## 6. Final gates

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | **PASS** (204 files, 0 changed) |
| `flutter analyze --fatal-infos --no-pub` | **PASS** (No issues found) |
| `flutter test --no-pub` | **PASS — 821 / 821** |
| `flutter build apk --debug` | **PASS** |
| `git diff --check` | **PASS** (clean) |

BASELINE_TESTS = 684/684 · FINAL_TESTS = **821/821**

The historical 801 is not the target and was not treated as one; 821 is the
fresh measurement.

### APK

| Field | Value |
|---|---|
| Path | `cozy_focus_app/build/app/outputs/flutter-apk/app-debug.apk` |
| Size | 125,352,348 bytes |
| SHA256 | `25b3ef025891827c392d1e7f75b766505b92f562f26e05b3d5b6cec4067bd60b` |

## 7. Architecture gates

| Property | Value |
|---|---|
| SHARED_BEHAVIOR_DIRECTOR | **YES** — exactly one `CompanionBehaviorDirector` class (asserted) |
| DATA_DRIVEN | **YES** — behaviour, profiles and room recipes come from manifests |
| SECOND_BUSINESS_STATE_MACHINE | **NO** — the director cannot reach a controller, repository or engine (asserted) |
| PAGE_LEVEL_SPECIES_BRANCHES | **0** (asserted by a static scan of `lib/presentation/pages/`) |
| GENERIC_RENDERER_SPECIES_BRANCHES | **0** (asserted by a static scan of the runtime) |
| FOURTH_COMPANION_PAGE_EDITS_REQUIRED | **NO** (proved with a test-only companion) |
| FOURTH_COMPANION_ENGINE_EDITS_REQUIRED | **NO** (same proof) |

Guards live in `test/architecture/` and read the source tree, because these
properties are about code that must not exist.

## 8. Companion behaviour

| Item | Result |
|---|---|
| DOG distinct focus behaviours | **3** — reading (open book), writing (notebook + pencil), thinking (thought bubbles) |
| CAT distinct focus behaviours | **3** — same vocabulary and props, own species art |
| RABBIT distinct focus behaviours | **3** — same vocabulary and props, own species art |
| TAP | PASS — overlay pose, then restores the previous focus pose (never idle) |
| LONG_PRESS | PASS — petting overlay |
| CONTEXT_RESTORE | PASS |
| PAUSE | PASS — visibly rests |
| CELEBRATE | PASS — confetti on completion |
| TIME_OF_DAY | PASS — late night calms the ambient pool |
| GROWTH | PASS — changes the visible behaviour pool, additively |
| CRAFT | PASS — craft behaviour only with a real `CraftJob`; the animation cannot advance it |
| COLLECTION | PASS — real `0 → positive` only; a cold start stays silent |
| ROOM | PASS — recipe-driven; `owned && placed && visible`; anchor drives sit/sleep/read/work |
| DRESS | **TRUTHFUL_DEFERRED** — states plainly that no dress data is connected |
| REDUCED_MOTION | PASS — semantic pose preserved, movement damped |
| LIFECYCLE | PASS — background/foreground and route changes leave no stuck state |
| BUSINESS_ISOLATION | PASS — no business table changes under pose/tap/press/switch/time/motion |

## 9. Asset gap (declared, not hidden)

The V4.2.1 package states the transparent dog/cat/rabbit pose packs are still a
production task (`docs/08_Runtime_Asset_GAP.md`). Accordingly:

- `productionPoses` is empty for every companion, so every pose resolves to
  `ASSET_GAP` rather than claiming finished art.
- Mochi keeps the approved V4.1 layered art; poses are carried by code-drawn
  fallback props plus posture.
- The cat and rabbit are drawn as **their own species** — triangle ears,
  whiskers and a slender tail; long ears and a puff tail — never as Mochi
  recoloured, which the brief forbids.

ASSET_GAP = **OPEN** for all three companions' runtime pose packs.

## 10. Model reviews

| Review | Status |
|---|---|
| CLAUDE (`11/claude-sonnet-4-6`) | **NOT RUN** — the owner instructed that the GPT and Claude models not be used at this time |
| GPT-6 SOL (`11/gpt-6-sol`) | **NOT RUN** — same instruction |

CLAUDE_P0 / CLAUDE_P1 / GPT6_SOL_P0 / GPT6_SOL_P1 = **NOT_ASSESSED**
GPT6_SOL_DECISION = **NOT_ASSESSED**

Their gates (P0=0, P1=0) therefore remain **unmet**, not satisfied. The
reconstruction's own gates are green, but the independent architecture and
integration reviews the brief requires have not happened.

## 11. Known limitations (stated, not hidden)

1. **Pose packs are fallback art.** Every companion reports `ASSET_GAP`. The
   props are honest placeholders, not production assets.
2. **Cat and rabbit are placeholders.** They are the correct species and use the
   shared pose vocabulary, but they are procedurally drawn, not painted.
3. **Claude and GPT-6 Sol reviews were not run**, per the owner's instruction.
   The final independent review gate is therefore open.
4. **Release signing is NOT_RECOVERED.** `android/key.properties` and the
   keystore were lost with the workspace and were not invented. The Gradle
   script falls back to debug signing.
5. **Emulator GPU.** `-gpu swiftshader_indirect` segfaulted the emulator once;
   it was restarted with `-gpu host` and was stable thereafter. An emulator
   renderer issue, not an application defect.

## 12. Remote checkpoint status

Every slice was committed and pushed to `origin/recovery/v4.2.1-rebuild`.
No work exists only in the working tree: the only untracked files are three
JSON files that the test suite regenerates on every run.

REMOTE_CHECKPOINT_STATUS = **PRESENT** for all seven commits.

## 13. Final status

| Field | Value |
|---|---|
| RECOVERY_GATE | **PASS** |
| READY_FOR_RECOVERY_PR | **YES** |
| RECOMMENDED PR | `recovery/v4.2.1-rebuild` → `release/android-v1` |
| MERGED_TO_RELEASE | **NO** |
| PUSHED_TO_MAIN | **NO** |
| STORE_SUBMITTED | **NO** |

Nothing was merged, and no pull request was opened. The recovery branch stops
here for explicit owner approval.
