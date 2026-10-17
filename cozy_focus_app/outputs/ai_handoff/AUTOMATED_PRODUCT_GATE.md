# Automated product gate

Generated 2026-10-17 10:47:57 at `a5d8ab4a`. Local equals remote: **NO**.

| Gate | Status | Evidence |
|---|---|---|
| `FORMAT` | **PASS** | 472 files, 0 changed |
| `ANALYZE` | **PASS** | 0 issues |
| `UNIT_TESTS` | **PASS** | 2112/2112 passed |
| `INTEGRATION_TESTS` | **PASS** | 51/51 passed |
| `GOLDEN_FLOW` | **PASS** | 6/6 passed |
| `MIGRATION` | **PASS** | 16/16 passed |
| `LIFECYCLE` | **PASS** | 81/81 passed |
| `ASSET_GATES` | **PASS** | 75/75 passed |
| `DEVICE_MATRIX` | **PASS** | FRAME_TIME 696 frames on emulator-5554, 666 after the 30-frame startup warmup; steady-state UI-thread build p50 787 us / p90 1364 us / p99 2419 us; frames over the 16.67 ms budget after the warmup: 0. Criterion: p90 within one 16.67 ms frame and p50 within half of one. The late-frame count is reported but does not decide: it ranged 0 to 3 across the runs taken while building this harness, tracking host load rather than the app, and it is recorded here rather than hidden. RASTER TIME IS NOT TRANSFERABLE: this AVD has no GPU and Flutter falls back to swiftshader, so the raster numbers describe a software rasteriser, not a phone. The build numbers are Dart CPU work and do transfer. The rest of the device matrix - the golden flows, the size sweep, large text, landscape, the migration walk - is still driven by hand. |
| `APK` | **PASS** | 32.0 MB (budget 34 MB) |
| `AAB` | **PASS** | 50.5 MB (budget 55 MB) |
| `DIFF_CHECK` | **PASS** | no whitespace errors |
| `RELEASE_SIGNING` | **BLOCKED** | RELEASE_SIGNING = NOT_RECOVERED: android/key.properties is absent, and no keystore was invented. The build switches over with no code change the moment it appears. |
| `LAUNCHER_ICON` | **BLOCKED** | still the stock Flutter logo in android/ (dominant colours 0,0,0 / 84,197,248 / 1,87,155). A candidate has been drawn - outputs/launcher_icon_candidate/, six sizes from the app's own palette - but it is NOT approved, so nothing under android/ was touched. Blocked on the owner's approval, not on artwork existing. |
| `OWNER_VISUAL_GATE` | **DEFERRED** | OWNER_VISUAL_GATE is REQUIRED and is never decided by a measurement. P21's technical gates pass; whether the art reads well is human judgement. |
| `PRODUCT_DECISIONS` | **PASS** | P25 reads CLOSED with 0 PRODUCT_DECISION_REQUIRED: every owner decision is made. Four of the six needed no code change - the code already behaved as decided - and two did, D3 (furniture names) and D4 (the long-session memory). Read from the document, not recited. 6 DEFERRED and 4 BLOCKED_EXTERNAL remain in the same file. |
| `BEHAVIOR_AUTHORITY` | **PASS** | BEHAVIOR_AUTHORITY_COUNT=1 (measured): the presented posture is determined by the committed action. |
| `FLOW_GENERATION` | **BLOCKED** | FLOW_GENERATION: no video surface reachable in Flow, and Flow's own banner reports video generation degraded. The video-to-sprite pipeline is built and validated against a local clip; no production video art exists. |

## Counts

- **PASS**: 14
- **BLOCKED**: 3
- **DEFERRED**: 1

---

Gates that can be re-run shell out to the command that already exists; none re-implements a check. The gates that report a standing owner or external state rather than a measurement (RELEASE_SIGNING, LAUNCHER_ICON, OWNER_VISUAL_GATE, PRODUCT_DECISIONS, FLOW_GENERATION) say so in their own evidence instead of pretending to have measured. DEVICE_MATRIX is no longer one of them: its frame-time row is a real measurement now, taken when --with-device is passed and reported as DEFERRED with the reason when it is not. BLOCKED is never reported as PASS.
