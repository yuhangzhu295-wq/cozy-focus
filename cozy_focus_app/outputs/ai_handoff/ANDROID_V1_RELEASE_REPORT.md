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

- APPLICATION_ID: com.example.cozy_focus_app
- NAMESPACE: com.example.cozy_focus_app
- APPLICATION_ID_STATUS: USER_INPUT_REQUIRED
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

- FORMAT: PASS (dart format --output=none --set-exit-if-changed ., 124 files, 0 changed)
- ANALYZE: PASS (flutter analyze --fatal-infos --no-pub, no issues)
- FULL_TEST_COUNT: 297/297 PASS
- DEBUG_APK: PASS (flutter build apk --debug, exit code 0)
- RELEASE_APK: PASS (flutter build apk --release, exit code 0)
- RELEASE_AAB: PASS (flutter build appbundle --release, exit code 0)
- DIFF_CHECK: PASS (git diff --check)

The final artifact hashes are recorded after the final non-runtime release
build immediately before commit. The runtime smoke install may overwrite its
temporary APK output and is not used as artifact-hash evidence.

- APK_PATH: C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app\build\app\outputs\flutter-apk\app-release.apk
- APK_SIZE: 27004460 bytes
- APK_SHA256: D3031A7FE86732B4D6F5306AEE4A4E2E58B3FD9A27379767551B8593481792D1
- AAB_PATH: C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app\build\app\outputs\bundle\release\app-release.aab
- AAB_SIZE: 46524659 bytes
- AAB_SHA256: 3C9431CAB5152EC228F86B16CD6CE8042A92B1DCE3761FCFC29B4EE6B8BFD757

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

- RUNTIME_DEVICE_QA: PASS (Android 14 emulator release Home launch only)
- RUNTIME_VISUAL_QA: PARTIAL
- PERFORMANCE_QA: NOT_MEASURED

flutter run --release -d emulator-5554 --no-resident exited 0. A separate Home
screenshot was captured at outputs/ai_handoff/android_v1_runtime/home-release-final.png.
It verifies that the release application launches and presents Home with the
Flutter Mochi fallback. It does not certify the complete primary flow, every
page/state, physical-device behavior, or performance metrics.

## Review And Known Issues

- P0: 0
- P1: 0
- P2: 2

P2 items: an approved non-default launcher icon/adaptive icon has not been
provided, and runtime visual coverage is limited to one emulator Home state.

## Store Boundary

Android RC can be evaluated independently from Play publication. Google Play
submission remains NO-GO until the user supplies a final non-placeholder
application identifier, production signing material, and the required store
and device-release evidence. This work does not publish, sign a production
release, upload to Google Play, merge a pull request, or push main.
