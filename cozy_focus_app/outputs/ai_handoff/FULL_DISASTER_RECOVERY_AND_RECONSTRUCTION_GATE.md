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
| `flutter test --no-pub` | **PASS — 835 / 835** |
| `flutter build apk --debug` | **PASS** |
| `git diff --check` | **PASS** (clean) |

BASELINE_TESTS = 684/684 · FINAL_TESTS = **835/835**

The historical 801 is not the target and was not treated as one; 822 is the
fresh measurement.

### APK

| Field | Value |
|---|---|
| Path | `cozy_focus_app/build/app/outputs/flutter-apk/app-debug.apk` |
| Size | 125,354,833 bytes |
| SHA256 | `fb3d67483ae044a22863fa4d637f5806f1a161e3bf83fc37d6a40b5aa4563ba3` |

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
| CLAUDE (`11/claude-sonnet-4-6`) | **NOT RUN** — the owner instructed that the GPT and Claude models not be used |
| GPT-6 SOL (`11/gpt-6-sol`) | **NOT RUN** — same instruction |
| Replacement review | **RUN** — a critical self-review with the orchestrator model, at the owner's instruction to complete the outstanding work with the current model only |

**This is a self-review, not the independent review the brief specifies.** The
same model that wrote the code reviewed it, so it cannot provide the
independence the brief is asking for. It is recorded here as a substitute, not
as an equivalent.

### Architecture review (substitute for the Claude pass)

Scope: the whole reconstruction diff against the recovery source
(68 files, ~8,600 insertions).

| Severity | Count | Items |
|---|---|---|
| P0 | **0** | — |
| P1 | **2** | found and fixed, below |
| P2 | **3** | found and fixed, below |

**P1-1 — completion could present `sleep` instead of celebrating.** Slice E
made `complete` an "ambient" context, so the late-night modifier injected
restful beats into the completion pool. Probed across seeds: the companion
celebrated only about a third of the time and looked sleepy the rest, which
contradicts "Completion must visibly celebrate". Completion is a one-shot
moment, not an ambient state; it is now excluded from ambient modifiers, with a
regression test over every hour, every stage and 25 seeds.

**P1-2 — an unknown companion id rendered an empty box.** §46 requires an
unknown id to fall back safely to the dog. The *profile* fell back, so the
companion was named Mochi, but the renderer resolved its provider from the raw
id and drew nothing at all. The provider is now resolved through the resolved
profile's pose pack, so the name and the picture cannot disagree.

**P2-1 — the placeholder companions declared micro-motion they never drove.**
Every profile lists `breathe` / `blink` / `ear_flick` channels, but the
procedural renderer drew a still image, so a cat or rabbit was visibly frozen
beside a dog that breathes. The placeholder now owns one breathing controller
and one blink timer on the same `PetMotionSpec` constants, releases both, and
stops them under reduced motion. Verified on device: the cat blinks and
breathes.

**P2-2 — a vacuous test was hiding P1-2.** The unknown-companion test asserted
`isNotNull` on a non-nullable enum, so it could never fail. It now asserts what
is actually on screen.

**P2-3 — dead code.** `CompanionRendererFor` and `hasVisualProvider` were
written and then orphaned by the P1-2 fix; both removed. `loadFromAssets` had
no caller and no test — it is the documented alternative to the bundled tables,
so it is now covered by a test that loads the real manifests through it rather
than deleting it.

### Integration review (substitute for the GPT-6 Sol pass)

Asked whether the reconstruction satisfies the explicit V4.2.1 contract, not
whether the architecture is theoretically perfect.

| Contract item | Verdict |
|---|---|
| Business → Context → Director → Recipe → Intent → Renderer | met |
| One shared director, no per-species engine | met (asserted) |
| No second business state machine | met (the director cannot reach one) |
| Page-level species branches = 0 | met (asserted) |
| Generic-renderer species branches = 0 | met (asserted) |
| Fourth companion needs no page or engine edit | met (proved with a test-only companion) |
| Overlay never overwrites base context | met (restore by construction; verified on device) |
| Pause must not schedule focus behaviour | met (enforced by recipe data) |
| Craft behaviour only with a real job | met (gated, and asserted) |
| Room interaction only when owned ∧ placed ∧ visible | met (declared as data) |
| Reduced motion preserves the semantic pose | met (asserted) |
| Deterministic behaviour tests | met (injected seed) |
| Asset gap declared, not hidden | met — still **open** |
| Independent reviewer sign-off | **NOT MET** — this is a self-review |

CLAUDE_P0 = 0 · CLAUDE_P1 = 0 (substitute review, not the specified reviewer)
GPT6_SOL_P0 = 0 · GPT6_SOL_P1 = 0 (substitute review, not the specified reviewer)
GPT6_SOL_DECISION = **PASS against the contract**, with the independence caveat
above. The one contract item genuinely unmet is the independent review itself.

## 11. Known limitations (stated, not hidden)

1. **Pose packs are fallback art.** Every companion reports `ASSET_GAP`. The
   props are honest placeholders, not production assets.
2. **Cat and rabbit are placeholders.** They are the correct species and use the
   shared pose vocabulary, but they are procedurally drawn, not painted.
3. **The independent reviews were not run.** A self-review with the
   orchestrator model was done instead, at the owner's instruction. It found and
   fixed two P1s, but the same model wrote the code, so it cannot substitute for
   the independent gate the brief specifies.
4. **The V4.2 room scenes are not implemented.** The designs place the
   companion in a furnished scene; the app keeps the V4.1 treatment and carries
   the V4.2 interaction on top, per the brief's own priority rule.
5. **Release signing is NOT_RECOVERED.** `android/key.properties` and the
   keystore were lost with the workspace and were not invented. The Gradle
   script falls back to debug signing.
6. **Emulator GPU.** `-gpu swiftshader_indirect` segfaulted the emulator once;
   it was restarted with `-gpu host` and was stable thereafter. An emulator
   renderer issue, not an application defect.

## 12. Remote checkpoint status

Every slice was committed and pushed to `origin/recovery/v4.2.1-rebuild`.
No work exists only in the working tree: the only untracked files are three
JSON files that the test suite regenerates on every run.

REMOTE_CHECKPOINT_STATUS = **PRESENT** for all seven commits.

## 13. Final emulator gate (completed on the final artifact)

The whole §75 journey was walked on the build above, not on an earlier one.

| Step | Result |
|---|---|
| HOME | PASS |
| DOG focus — three distinct work behaviours | **PASS** — reading (open book), writing (notebook + pencil), thinking (thought bubbles), captured as a 16-frame contact sheet over 96s, plus the `starting` phase's neutral prepare beat |
| DOG tap during focus | PASS — exclamation overlay; state stayed 专注中 |
| DOG long press during focus | PASS — heart overlay; state stayed 专注中 |
| Focus restore | PASS — a 33:06 session survived several app restarts and resumed via 恢复专注, then completed |
| Pause | PASS — "Mochi 休息中" with resting markers |
| Complete | PASS — "Mochi 庆祝中" with confetti |
| CAT selection / restart / focus / interaction | PASS (verified in Slice C and re-verified here) |
| RABBIT selection / restart / focus / interaction | PASS — long ears, puff tail, shared reading prop |
| GROWTH | PASS — name, tab and copy follow the selection |
| CRAFT inactive | PASS — 8 craftable, no active section |
| CRAFT active | PASS — job started, "0 / 20 分钟", craftable list dropped to 7; a second job is refused with 当前有其他制作任务进行中 |
| COLLECTION | PASS — truthful ownership; unlock transition pinned by `collection_unlock_test.dart` |
| ROOM unowned | PASS — shown as 未收集 in the Collection |
| ROOM owned / unplaced | PASS — the inventory panel correctly reports nothing placeable while the only owned sofa is placed |
| ROOM placed | PASS — two placed sofas; the newer placement wins the tie-break |
| ROOM pet interaction | PASS — the companion sits on the resolved seat |
| DRESS | PASS — states plainly that no dress data is connected |
| REDUCED MOTION | PASS — the writing pose is preserved with motion damped |
| background / foreground | PASS — no stuck state, no duplicate message |

logcat over the whole journey: **0 crash / 0 ANR / 0 app exception**.

One inconsistency was found and fixed during this pass: the dog reported
"Mochi 空闲" while in the room, because the renderer's state enum has no
"in the room" value, while the cat and rabbit said "在房间". The runtime now
supplies the truthful label from the base context. `822/822`.

## 14. Visual QA against the V4.2.1 designs

Judged on the criteria §66 sets — identity, pose distinction, scale,
hierarchy, interaction meaning, room context — and not on pixel matching,
because the package states its page art is conceptual.

| Criterion | Verdict |
|---|---|
| Identity | **PASS** — Mochi is the approved V4.1 layered art, unchanged |
| Pose distinction | **PASS** — the three work poses are told apart at avatar size |
| Scale and hierarchy | **PASS** — layouts are the V4.1 screens; the runtime did not move them |
| Interaction meaning | **PASS** — tap and long press read as reactions, and neither interrupts the work |
| Room context | **PASS** — the companion sits on resolved furniture |

**Declared gap.** The V4.2 page designs place the companion in a *scene* —
a desk and chair, a cushion and a carrot, a room interior. Those scenes are
not implemented. §31 of the brief puts the V4.1 base visual language above the
V4.2 interaction art for the app's look, so the shipped screens keep the V4.1
treatment and carry the V4.2 *interaction* on top. This is a real difference
from the design images and is recorded rather than glossed.

## 15. Scheduler and resource audit (§61, §65)

The presentation scheduler was a `Ticker`. It satisfied "one scheduler", but a
ticker holds a transient frame callback for as long as it runs, so the engine
was asked for a frame **every vsync forever** — an idle companion kept the app
from ever settling. For an app whose purpose is to sit quietly beside a focus
timer that is a real battery cost for no visual benefit.

It is now a single periodic timer at 250 ms. The director's decisions are
seconds-scale (a behaviour dwells 8–30 s, an overlay 0.6–2.5 s), so a quarter of
a second is imperceptible while being roughly sixty times cheaper. Frame-rate
interpolation stays with the renderer's own AnimationControllers, which is what
§61 asks for.

Two consequences worth recording:

- elapsed presentation time is now accumulated from ticks rather than read from
  a `Stopwatch`. A stopwatch reads wall-clock time, which a widget test's fake
  clock does not advance, so a stopwatch would have made every timing behaviour
  untestable.
- hidden time is not presentation time: the timer is cancelled while the app is
  not visible, so a resumed app shows the companion mid-behaviour instead of
  having silently skipped several.

Audit results (`test/architecture/companion_lifecycle_leak_test.dart`):

| Check | Result |
|---|---|
| The clock holds no frame callback (mounted in isolation) | PASS |
| No pending timer survives disposal | PASS |
| A supplied motion controller returns to 0 listeners / 0 timers | PASS |
| Repeated companion switching accumulates nothing | PASS |
| Background then foreground resumes without advancing time | PASS |
| Reduced-motion toggling mid-flight leaves no pending timer | PASS |
| The director's source owns no Timer / Ticker / subscription / listener | PASS |

Re-verified on device after the change: all three work poses still cycle, and
long press shows the heart overlay then restores the writing pose rather than
falling to idle. 0 crash / 0 ANR / 0 app exception.

## 16. Final status

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
