# Automated product gate

Generated 2026-10-10 10:08:12 at `f4bc36be`. Local equals remote: **YES**.

| Gate | Status | Evidence |
|---|---|---|
| `FORMAT` | **PASS** | 458 files, 0 changed |
| `ANALYZE` | **PASS** | 0 issues |
| `UNIT_TESTS` | **PASS** | 2034/2034 passed |
| `INTEGRATION_TESTS` | **PASS** | 51/51 passed |
| `GOLDEN_FLOW` | **PASS** | 6/6 passed |
| `MIGRATION` | **PASS** | 16/16 passed |
| `LIFECYCLE` | **PASS** | 81/81 passed |
| `ASSET_GATES` | **PASS** | 75/75 passed |
| `DEVICE_MATRIX` | **PASS** | FRAME_TIME 691 frames on emulator-5554, 661 after the 30-frame startup warmup; steady-state UI-thread build p50 1744 us / p90 3650 us / p99 7160 us; frames over the 16.67 ms budget after the warmup: 0. Criterion: p90 within one 16.67 ms frame and p50 within half of one. The late-frame count is reported but does not decide: it ranged 0 to 3 across the runs taken while building this harness, tracking host load rather than the app, and it is recorded here rather than hidden. RASTER TIME IS NOT TRANSFERABLE: this AVD has no GPU and Flutter falls back to swiftshader, so the raster numbers describe a software rasteriser, not a phone. The build numbers are Dart CPU work and do transfer. The rest of the device matrix - the golden flows, the size sweep, large text, landscape, the migration walk - is still driven by hand. |
| `APK` | **PASS** | 32.0 MB (budget 34 MB) |
| `AAB` | **PASS** | 50.5 MB (budget 55 MB) |
| `DIFF_CHECK` | **PASS** | no whitespace errors |
| `RELEASE_SIGNING` | **BLOCKED** | RELEASE_SIGNING = NOT_RECOVERED: android/key.properties is absent, and no keystore was invented. The build switches over with no code change the moment it appears. |
| `LAUNCHER_ICON` | **BLOCKED** | still the stock Flutter logo (dominant colours 0,0,0 / 84,197,248 / 1,87,155); no approved artwork exists, so none was invented |
| `OWNER_VISUAL_GATE` | **DEFERRED** | OWNER_VISUAL_GATE is REQUIRED and is never decided by a measurement. P21's technical gates pass; whether the art reads well is human judgement. |
| `PRODUCT_DECISIONS` | **DEFERRED** | P25 records 6 PRODUCT_DECISION_REQUIRED (D1-D4, D6, D7), 6 DEFERRED and 4 BLOCKED_EXTERNAL. D5 was decided by the owner - tapping furniture chooses the action - and is implemented; see BEHAVIOR_AUTHORITY, which now measures 1. The remaining six are product choices, and none was defaulted on the owner's behalf. |
| `BEHAVIOR_AUTHORITY` | **PASS** | BEHAVIOR_AUTHORITY_COUNT=1 (measured): the presented posture is determined by the committed action. |
| `FLOW_GENERATION` | **BLOCKED** | FLOW_GENERATION: no video surface reachable in Flow, and Flow's own banner reports video generation degraded. The video-to-sprite pipeline is built and validated against a local clip; no production video art exists. |

## Counts

- **PASS**: 13
- **BLOCKED**: 3
- **DEFERRED**: 2

---

Gates that can be re-run shell out to the command that already exists; none re-implements a check. The gates that report a standing owner or external state rather than a measurement (RELEASE_SIGNING, LAUNCHER_ICON, OWNER_VISUAL_GATE, PRODUCT_DECISIONS, FLOW_GENERATION) say so in their own evidence instead of pretending to have measured. DEVICE_MATRIX is no longer one of them: its frame-time row is a real measurement now, taken when --with-device is passed and reported as DEFERRED with the reason when it is not. BLOCKED is never reported as PASS.
