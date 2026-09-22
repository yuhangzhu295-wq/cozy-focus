# Cozy Focus Android V1 Release Report

## Identity And Scope

- PROJECT: COZY_FOCUS
- BRANCH: release/android-v1
- BASE_SHA: 41e26a138e9230889c540e4a3c74119d9751cd07
- FINAL_PRECOMMIT_SHA: 41e26a138e9230889c540e4a3c74119d9751cd07
- AGENTS_MD: FOUND
- REVIEW_MODE: SINGLE_AGENT
- PRODUCTION_PET_RENDERER: FLUTTER_FALLBACK
- RIVE_RELEASE_DEPENDENCY: REMOVED
- RIVE_ASSET_STATUS: DEFERRED_OPTIONAL
- FOCUS_PROGRESS_CHANNEL: PASS
- CRAFT_PROGRESS_CHANNEL: PASS

## Toolchain

- FLUTTER_VERSION: 3.32.4 stable, framework 6fba2447e9
- DART_VERSION: 3.8.1
- JAVA_VERSION: OpenJDK 17.0.10, Android Studio bundled JBR
- GRADLE_VERSION: 8.12
- AGP_VERSION: 8.7.3
- ANDROID_SDK: platform android-36, build-tools 36.1.0
- MIN_SDK: 21
- TARGET_SDK: 35
- COMPILE_SDK: 35 in the generated release APK

flutter doctor -v reports unaccepted Android licenses and a PATH warning for
the Flutter wrapper, but all recorded Flutter analysis, test, APK, and AAB
commands completed successfully with the configured local toolchain. No global
toolchain changes were made.

## Android Identity

- APPLICATION_ID: com.yuhangzhu295.cozyfocus
- NAMESPACE: com.yuhangzhu295.cozyfocus
- APPLICATION_ID_STATUS: RESOLVED (owner supplied 2026-09-21; see the amendment at the foot of this file)
- APP_NAME: Cozy Focus
- VERSION_NAME: 1.0.0
- VERSION_CODE: 1
- LAUNCHER_ICON: BLOCKED
- SPLASH: PASS

The manifest label resolves to Cozy Focus in both debug and release APKs. The
launch path uses the approved warm #FBF8F2 background for legacy Android and
Android 12+ splash resources. The checked-in launcher resource remains the
default Flutter icon and no approved Cozy Focus launcher artwork or adaptive
icon source was found, so no invented replacement was made.

## Verification

- FORMAT: PASS (dart format --output=none --set-exit-if-changed ., 124 files, 0 changed at the release build; 133 files, 0 changed at the 2026-09-21 re-run)
- ANALYZE: PASS (flutter analyze --fatal-infos --no-pub, no issues)
- FULL_TEST_COUNT: 303/303 PASS at the release build; 339/339 PASS at the 2026-09-21 re-run
- DEBUG_APK: PASS (flutter build apk --debug, exit code 0)
- RELEASE_APK: PASS (flutter build apk --release, exit code 0)
- RELEASE_AAB: PASS (flutter build appbundle --release, exit code 0)
- DIFF_CHECK: PASS (git diff --check)

The hashes below are from the post-fix release build, and were re-computed after
the runtime QA install to confirm the on-disk artifact is byte-identical
(`adb install` reads the local APK but does not modify it).

- APK_PATH: C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app\build\app\outputs\flutter-apk\app-release.apk
- APK_SIZE: 27037953 bytes
- APK_SHA256: 42325232BF86A9BE67D268650F7BF1AA3E0F391AE0577C39D61D9DEB3E443CD5
- AAB_PATH: C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app\build\app\outputs\bundle\release\app-release.aab
- AAB_SIZE: 46558157 bytes
- AAB_SHA256: A3E75411BEA422C8741E9624B6091E57E856FF004BE594C8C61DD46E6BF35020

Both artifacts were rebuilt after the runtime repair recorded in
ANDROID_V1_RELEASE_CANDIDATE_VERIFICATION.md (§4), so they embed that fix.

## Signing

- SIGNING_FRAMEWORK: PASS
- REAL_RELEASE_SIGNING: BLOCKED_NO_RELEASE_KEY
- TECHNICAL_APK_SIGNATURE: PASS (v1 and v2 verification)

The final APK has one technical signer; its certificate SHA-256 digest is
4d9c3c3df843d21876aa23a8078a7a449eac7edf0a018618bf200de8fc0321d4.

android/key.properties.example contains placeholders only. android/key.properties,
keystores, passwords, private keys, and API secrets were not found in the
pending release diff. In the absence of a local production key, Gradle uses its
debug signing configuration solely to permit local release-build verification;
this is not production or store signing.

## Runtime And Visual Evidence

- RUNTIME_DEVICE_QA: PASS (Android 14 emulator, real release APK installed via adb)
- RUNTIME_VISUAL_QA: PASS (complete primary flow + all 22 routed pages)
- RELEASE_INSTALL_SMOKE: PASS
- RUNTIME_EXCEPTION_SCAN: CLEAN (0 E/flutter, 0 exception signatures, 0 ANR/crash)
- PERFORMANCE_QA: NOT_MEASURED
- PHYSICAL_DEVICE_QA: NOT_ASSESSED

The release APK was installed with `adb install -r` and driven on emulator-5554.
Interaction used uiautomator hierarchy dumps for real on-screen coordinates, which
resolved flows that had previously been unreachable by blind coordinate tapping.

Covered: Home → resume → Focus Active (paused) → continue → background/foreground
restore → end-early confirm → Focus Complete → Save (mood/note) → Reward → Home;
plus every route in app_router.dart (Home, focus setup/active/complete/save/reward,
progress, records 今日/历史/日历/报告, record detail, growth, collection, dress,
weekly/monthly/yearly reports, wrapped, craft, craft detail, inventory, room,
settings, notifications, data sync). 44 screenshots + XML dumps are at
outputs/release_qa/.

One real P1 release defect was found and repaired during this QA (blank Monthly
Report page from a `dynamic` PetProgress access); see
ANDROID_V1_RELEASE_CANDIDATE_VERIFICATION.md §4 for root cause, fix, and on-device
re-verification. Two further anomalies were investigated and correctly ruled out
as non-defects (records attributed to their start date; the documented
DRESS_PRODUCT_DECISION unconnected state).

Physical-device behavior and performance metrics remain uncertified.

## Review And Known Issues

- P0: 0
- P1: 1 (was 2; the application-identity item was resolved on 2026-09-21)
- P2: 1

P1 item (a non-code owner decision, not repairable by the agent):
1. The launcher icon is still the stock Flutter logo with no adaptive icon; the V4.1
   package and the repository contain no approved brand/icon asset, so no replacement
   was invented.

Resolved 2026-09-21: `applicationId` and `namespace` are no longer the placeholder.
The owner supplied `com.yuhangzhu295.cozyfocus`; `android/app/build.gradle.kts` and
`MainActivity.kt` (moved to `.../kotlin/com/yuhangzhu295/cozyfocus/`) both carry it,
and `tools/visual_qa/drive.py` was updated to the new package. The previously recorded
`com.example.cozy_focus_app` was an explicit invalid-release-identity pattern, so this
closes that finding — but see the amendment below for the artifact consequence.

P2 item: `flutter_local_notifications`, `supabase_flutter`, and `connectivity_plus`
are declared but unused in `lib/` (surfaced honestly as "not connected" states).

Resolved this run: the single P1 runtime defect (blank Monthly Report page) was
repaired and re-verified; runtime visual coverage is no longer a gap.

## Store Boundary

Android RC can be evaluated independently from Play publication. Google Play
submission remains NO-GO. The application-identifier blocker is now cleared, so
the remaining blockers are production signing material, an approved launcher
icon, and the required store and device-release evidence. This work does not
publish, sign a production release, upload to Google Play, merge a pull request,
or push main.

The validated runtime repair (§ Runtime And Visual Evidence) and these reports
were committed locally on `release/android-v1`. Nothing was pushed, so `origin`
and PR #1 remain at 75b3e4be565ad1db6d7ce1fe9bf2a08f9f114b59 and no CI re-run is
triggered.

---

## Amendment — 2026-09-21 (identity change, and what it invalidates)

`release/android-v1` moved from `764aaa1` to `6a548b5`
(`feat(v4.1): rebuild screen 04, fix screen 06's donut, land release applicationId`),
5 files changed, +786/−173. Still local only; `origin` is at `764aaa1`.

**The recorded release artifacts are now stale.** The release APK
(`42325232…`, 27037953 bytes) and the AAB (`A3E75411…`, 46558157 bytes) were built
on 2026-09-19 from source that still carried `applicationId =
com.example.cozy_focus_app`. Both hashes above therefore describe an artifact whose
package identity no longer matches the source tree. They are left in place as the
historical record of the 09-19 verification, not as a current candidate. Before any
store submission both must be rebuilt from `6a548b5` and re-hashed, and the runtime
QA below must be repeated against the rebuilt APK.

The debug APK used for visual QA was rebuilt on 2026-09-21 (md5
`5360261b1ea2f0fc65b45051a1f41be3`) and does carry the new identity; `adb install`
confirmed the package as `com.yuhangzhu295.cozyfocus`.

Also changed in the same commit, both landing after the last device capture and
therefore **not yet device-verified**:

- `focus_complete_page.dart`: hero band height `187 → 184`.
- `weekly_report_page.dart`: donut `106 → 128` with stroke `14 → 19`.

These two numbers are the only unverified part of the commit; the rest of the
screen 04 rebuild and the screen 06 donut conversion were measured on-device at
md5 `5360261b`. See `V4_1_RUNTIME_FIDELITY_MATRIX.md` § Screen 04 and § Screen 06.

Unchanged by this amendment: the launcher-icon P1, the unused-dependency P2, and
`PHYSICAL_DEVICE_QA: NOT_ASSESSED` / `PERFORMANCE_QA: NOT_MEASURED`.
