# 01 — Execution summary

**Branch:** `recovery/v4.2.1-rebuild`
**Starting HEAD:** `a8d679c` (local == remote)
**This round's commits:** `b9e19ee`, `599099a`, `df811ca`, `b068495`, `6f03180`,
`b314c28`
**Gate commit:** `b314c28` (14 PASS / 3 BLOCKED / 1 DEFERRED / 0 FAIL). These
delivery documents are committed immediately after it, and both are pushed to
`origin/recovery/v4.2.1-rebuild`.

## What was actually built

### 1. Room: both renderers now share one ground line (`b9e19ee`)

The room draws `idle` from the layered rig and every action from a sprite, and
the two put their paws at different fractions of the box (`83/482` vs
`(512-458)/512`). A sprite drawn into a rig-anchored box sat **6.14 pt** low on
the 92 pt avatar. The correction is applied **inside** the sprite's box, not by
moving the box, so a renderer switch cannot jump the character. It is zero
everywhere except the room.

Guarded by `test/presentation/companion/room_sprite_grounding_test.dart` (8
tests), which reads the three packs' own manifests rather than a second
hard-coded number.

### 2. Hand-drawn room candidate, V1–V3 fixed, default-off (`599099a`)

The candidate painter was brought onto the current HEAD. The three defects the
first candidate shipped with were fixed and measured:

- **V1** shelf in the far plane's 3.1σ blur → own 0.9σ layer, backing panel,
  larger spines.
- **V2** side wall's near edge started at `deskY*0.30`, drawing a dark diagonal
  band → the near edge now starts above the frame.
- **V3** window smaller/dimmer → 0.40×0.56 of the wall, brighter glow, light
  core.

Pixel guards in `test/presentation/room_candidate_visual_test.dart` are
calibrated **between** the two versions (135.9 vs 150.7; 0.563 vs 0.427; 127 vs
92) and were reverse-proved by restoring the original file: all three fail.

The candidate is reachable only with `--dart-define=ROOM_CANDIDATE=true`.

### 3. Local backup and restore (`df811ca`)

New: a versioned JSON envelope, canonical SHA-256, preview, explicit
confirmation, live-session refusal, column validation, a single transaction with
a row-count check, pack staging and a snapshot rollback. Android uses the
Storage Access Framework in `MainActivity` (no storage permission). Settings →
数据与同步 now has two real actions.

11 isolated tests cover the failure modes. Walked end to end on the emulator:
export → create a task → restore → the task is gone.

### 4. Flow gaps and one more candidate defect (`b068495`)

- FLOW-01: editing a task keeps its recorded time and its history.
- FLOW-02: an early finish records the time actually focused, and the ledger
  agrees (10:30 → 20 coins).
- FLOW-04: a rest records its length and earns no focus reward.
- The device walk found the candidate's rug plane 200px below the paws; the rug
  now centres on the same expression as `kCozyRoomMatCentre`, exposed as a
  static so the contract is testable without pixels.
- Removed a duplicate accessibility label on the backup cards (the device read
  "导出备份 导出备份").

## What was verified, and how

- `flutter test`: full suite, no skips added.
- `flutter analyze --fatal-infos`: 0 issues.
- `dart format --set-exit-if-changed`: 0 changed.
- `flutter build apk --debug`: succeeded; the APK is in `build/`.
- Device: `emulator-5554`, package `com.yuhangzhu295.cozyfocus`; screenshots in
  `device/`.
- The full gate's own output is in `07_BUILD_AND_PERFORMANCE.md`.

## What this round did not do

- No release keystore, no private key, no store submission.
- The launcher icon candidate was not installed into `android/`; the owner has
  not approved it.
- No candidate room was promoted to production; the owner's visual gate is
  untouched.
- No cloud sync, white noise, notifications or dress feature was implemented.
- No scheduled task or recurring automation was created.
- No claim of `OWNER_VISUAL_APPROVED` or `STORE_RELEASE_READY`.

## Files added this round

```
lib/data/backup/backup_format.dart
lib/data/backup/backup_service.dart
lib/data/backup/backup_file_service.dart
lib/presentation/widgets/cozy_room_handdrawn_candidate.dart
test/data/backup/backup_round_trip_test.dart
test/integration/v1_flow_gaps_test.dart
test/presentation/companion/room_sprite_grounding_test.dart
test/presentation/room_candidate_visual_test.dart
outputs/autonomous_final_delivery/*
```

## Files modified this round

```
lib/presentation/pages/data_sync_page.dart
lib/presentation/widgets/cozy_room_backdrop.dart
lib/presentation/companion/room/companion_placement.dart
lib/presentation/companion/runtime/companion_sprite_player.dart
lib/presentation/companion/runtime/companion_visual_provider.dart
lib/presentation/companion/runtime/companion_renderer.dart
lib/presentation/companion/mochi_visual_provider.dart
lib/presentation/companion/companion_avatar.dart
lib/presentation/widgets/pet_avatar_widget.dart
android/app/src/main/kotlin/com/yuhangzhu295/cozyfocus/MainActivity.kt
pubspec.yaml / pubspec.lock (crypto)
test/presentation/phase7c_data_sync_test.dart
```
