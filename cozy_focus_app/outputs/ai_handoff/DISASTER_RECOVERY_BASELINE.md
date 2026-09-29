# DISASTER_RECOVERY_BASELINE

Project: COZY_FOCUS
Task: FULL_DISASTER_RECOVERY_AND_V4_2_1_RECONSTRUCTION
Date: 2026-09-29
Status: **BASELINE PASS**

---

## 1. Recovery source identity

| Field | Value |
|---|---|
| REMOTE_BRANCH | `release/android-v1` |
| REMOTE_SHA | `7b3a7f9ec3ffae77b5f835d9a9359a33b9eb4219` |
| LOCAL_SHA (clone HEAD) | `7b3a7f9ec3ffae77b5f835d9a9359a33b9eb4219` |
| EXPECTED_SHA | `7b3a7f9ec3ffae77b5f835d9a9359a33b9eb4219` |
| REMOTE_MOVED | **NO** — remote matches expected exactly |
| RECOVERY_BRANCH | `recovery/v4.2.1-rebuild` |
| ANCESTRY_CHECK | `git merge-base --is-ancestor origin/release/android-v1 recovery/v4.2.1-rebuild` → **YES** |

Recovery branch was created from `origin/release/android-v1` and pushed to the remote
as an empty anchor before any reconstruction work began.

- Anchor push: `origin/recovery/v4.2.1-rebuild` — **PRESENT**
- No commits were made to `main` or `release/android-v1`.

## 2. Path safety

Historical path `C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat` did **not** exist.
Parent directories were created. No holding-rename was required because nothing was
present to preserve. The repository was cloned into the exact historical path.

- GIT_ROOT: `C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat`
- APP_ROOT: `C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app`

## 3. Toolchain

| Component | Actual | Expected | Match |
|---|---|---|---|
| Flutter | 3.32.4 (stable), revision `6fba2447e9` | revision `6fba2447e95c451518584c35e25f5433f14d888c` | YES |
| Dart | 3.8.1 (stable) | 3.8.1 | YES |
| Java | OpenJDK 17.0.10 (Android Studio JBR) | JDK 17 | YES |
| Android SDK | `C:\Users\zyu33\AppData\Local\Android\Sdk` | present | YES |
| build-tools | 34.0.0, 35.0.0, 36.1.0, 37.0.0 | — | — |
| platforms | android-34, android-35, android-36 | android-34 required | YES |
| NDK | `27.0.12077973` (also 25.1.8937393, 26.3.11579264) | `27.0.12077973` | YES |

`cozy_focus_app/.metadata` revision is `6fba2447e95c451518584c35e25f5433f14d888c`,
which matches the installed Flutter SDK. No Flutter upgrade or migration was performed.

## 4. Baseline gates (freshly measured)

| Gate | Result |
|---|---|
| `flutter pub get` | **PASS** — "Got dependencies!" |
| `dart format --output=none --set-exit-if-changed lib test` | **PASS** — 167 files, 0 changed |
| `flutter analyze --fatal-infos --no-pub` | **PASS** — "No issues found!" |
| `flutter test --no-pub` | **PASS** — **684/684** |
| `flutter build apk --debug` | **PASS** |
| `git diff --check` | **PASS** — clean |
| `git status --short` after `pub get` | **clean** — no baseline drift |

TEST_COUNT = **684 / 684** (freshly measured; not a reused historical number).

### APK

| Field | Value |
|---|---|
| Path | `cozy_focus_app/build/app/outputs/flutter-apk/app-debug.apk` |
| Size | 103,959,247 bytes (100 MB) |
| SHA256 | `1257473c2c7ae73dbed6f7d7d9587a5fba60a88e58c5c745bc5b17bd90d80d9d` |

## 5. Android application identity

`android/app/build.gradle.kts`:

- `namespace` = `com.yuhangzhu295.cozyfocus` (unchanged)
- `applicationId` = `com.yuhangzhu295.cozyfocus` (unchanged)
- `ndkVersion` = `27.0.12077973` (unchanged)

No identity change was made during recovery.

## 6. Signing

| Item | Status |
|---|---|
| `android/key.properties` | **ABSENT** |
| keystore (`*.jks` / `*.keystore`) | **ABSENT** |
| RELEASE_SIGNING | **NOT_RECOVERED** |

The Gradle script falls back to debug signing when release signing material is absent.
No passwords, aliases or keystore files were invented. Debug reconstruction is unaffected.

## 7. Emulator

| Field | Value |
|---|---|
| AVD | `GoodnightPixel7Api34` (reused — historical test device, still present) |
| Device id | `emulator-5554` |
| Model | Pixel 7 (`sdk_gphone64_x86_64`) |
| Android version | 14 (API 34) |
| Resolution | 1080 x 2400 |
| Density | 420 dpi |
| Image | `system-images/android-34/google_apis_playstore/x86_64` |

Note: the emulator was initially started with `-gpu swiftshader_indirect` and segfaulted
(exit 139) partway through the run. It was restarted with `-gpu host` and remained stable.
This is an emulator/GPU-renderer issue, not an application defect. No QA database contents
were reproduced; the app built its own fresh local database.

## 8. Baseline runtime smoke (fresh APK)

APK installed with `adb install -r` (Success), launched via `am start`.
The installed artifact is the newly built debug APK (SHA256 above).

Screens exercised, all reached successfully:

| Screen | Result | Evidence |
|---|---|---|
| Home | PASS | Renders title, Mochi idle, duration picker, stats |
| Focus Setup | PASS | Inline on Home — duration presets 5/25/50/90, custom adjust |
| Focus Active | PASS | Timer running, "Mochi 专注中" |
| Tap during Focus (overlay) | PASS | Semantic state stays focus; timer keeps running; returns to focus behavior |
| Pause | PASS | "已暂停", "Mochi 暂停中" — visibly resting |
| Resume | PASS | Returns to "专注中", timer continues |
| End-early confirm dialog | PASS | Confirmation shown with session duration |
| Completion | PASS | "专注完成", duration, rewards, mood input |
| Records | PASS | Session persisted (1 record, 05:04–05:05); Today/History/Calendar/Report tabs |
| Growth | PASS | XP 40/100, Lv.1, stats; sub-nav Mochi/Room/Dress/Collection |
| Room | PASS | Mochi in room, placed furniture rendered, placement actions |
| Craft | PASS | Recipe list with real requirements, "已拥有 x1" truthful state |
| Collection | PASS | 1/10 collected, known-but-unowned items shown truthfully |
| Dress | PASS | Truthful — "装扮系统未连接数据，暂无可用装扮，无法穿戴。" |
| Settings | PASS | Defaults, notifications, sound, appearance, language, data, privacy |

### Logcat

| Metric | Count |
|---|---|
| `FATAL EXCEPTION` (app) | **0** |
| `E/flutter` | **0** |
| `ANR in com.yuhangzhu295.cozyfocus` | **0** |

Log noise observed was entirely from Google Play Services / Play Store
(`com.android.vending`, `Finsky`, `BugleRcs`, GMS) — unrelated to Cozy Focus.

BASELINE_RUNTIME = **PASS** (0 Crash / 0 ANR / 0 P0-P1 app runtime exception).

## 9. Spec packages

| Package | Status | Path |
|---|---|---|
| V4_1_SPEC | **AVAILABLE** | `C:\Users\zyu33\Desktop\番茄种\CozyFocus_V4_1_Visual_Polish_Subagent_Final_FULL_20260910` |
| V4_2_1_SPEC | **AVAILABLE** | `C:\Users\zyu33\Downloads\CozyFocus_V4_2_1_Companion_Runtime_SPEC_FINAL_20260927\CozyFocus_V4_2_1_Companion_Runtime_SPEC_FINAL_20260927` |

### Safe spec backup (copy, originals untouched)

`C:\Users\zyu33\Documents\CozyFocus-Specs\`
- `V4_1\` — 105 MB
- `V4_2_1\` — 35 MB

These external design archives were **not** committed to Git.

## 10. Surviving vs lost truth

- **Surviving source truth**: GitHub `release/android-v1` @ `7b3a7f9e...`
- **Lost local work**: the previously reported V4.2.1 Companion Runtime that had reached
  a larger local test suite and was never committed/pushed. This work is **not** present in
  the surviving GitHub source and is **not** claimed as recovered.
- Historical results (303 / 617 / 680 / 684 / 801) are **not** treated as current truth.
  The only current test number is the freshly measured **684/684** above.
- The lost implementation is a **reference target only**, not source truth.

## 11. Worktree status

```
git status --short   → (clean)
git diff --check     → (clean)
HEAD                 → refs/heads/recovery/v4.2.1-rebuild @ 7b3a7f9e...
```

---

## Baseline hard gate verdict

analyze PASS · test PASS (684/684) · build APK PASS · launch PASS
→ **BASELINE_RECOVERY_BLOCKED = NO**

Reconstruction toward V4.2.1 may proceed.
