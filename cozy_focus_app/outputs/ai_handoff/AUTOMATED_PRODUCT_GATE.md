# Automated product gate

Generated 2026-10-10 06:37:34 at `3b67881b`. Local equals remote: **YES**.

| Gate | Status | Evidence |
|---|---|---|
| `FORMAT` | **PASS** | 458 files, 0 changed |
| `ANALYZE` | **PASS** | 0 issues |
| `UNIT_TESTS` | **PASS** | 2029/2029 passed |
| `INTEGRATION_TESTS` | **PASS** | 51/51 passed |
| `GOLDEN_FLOW` | **PASS** | 6/6 passed |
| `MIGRATION` | **PASS** | 16/16 passed |
| `LIFECYCLE` | **PASS** | 80/80 passed |
| `ASSET_GATES` | **PASS** | 75/75 passed |
| `APK` | **PASS** | 32.0 MB (budget 34 MB) |
| `AAB` | **PASS** | 50.5 MB (budget 55 MB) |
| `DIFF_CHECK` | **PASS** | no whitespace errors |
| `RELEASE_SIGNING` | **BLOCKED** | RELEASE_SIGNING = NOT_RECOVERED: android/key.properties is absent, and no keystore was invented. The build switches over with no code change the moment it appears. |
| `LAUNCHER_ICON` | **BLOCKED** | still the stock Flutter logo (dominant colours 0,0,0 / 84,197,248 / 1,87,155); no approved artwork exists, so none was invented |
| `OWNER_VISUAL_GATE` | **DEFERRED** | OWNER_VISUAL_GATE is REQUIRED and is never decided by a measurement. P21's technical gates pass; whether the art reads well is human judgement. |
| `DEVICE_MATRIX` | **DEFERRED** | device verification exists and is recorded (collection, craft, P7 toolbar, room alignment, the rabbit pack, the P11 routine, indexed sprites, the P14 fix, and the P21 idle and travel motion gates) - but it was driven by hand each time, not by this script. A re-runnable device matrix would need an unattended driver. |
| `PRODUCT_DECISIONS` | **DEFERRED** | P25 records 6 PRODUCT_DECISION_REQUIRED (D1-D4, D6, D7), 6 DEFERRED and 4 BLOCKED_EXTERNAL. D5 was decided by the owner - tapping furniture chooses the action - and is implemented; see BEHAVIOR_AUTHORITY, which now measures 1. The remaining six are product choices, and none was defaulted on the owner's behalf. |
| `BEHAVIOR_AUTHORITY` | **PASS** | BEHAVIOR_AUTHORITY_COUNT=1 (measured): the presented posture is determined by the committed action. |
| `FLOW_GENERATION` | **BLOCKED** | FLOW_GENERATION: no video surface reachable in Flow, and Flow's own banner reports video generation degraded. The video-to-sprite pipeline is built and validated against a local clip; no production video art exists. |

## Counts

- **PASS**: 12
- **BLOCKED**: 3
- **DEFERRED**: 3

---

Gates that can be re-run shell out to the command that already exists; none re-implements a check. The gates that report a standing owner or external state rather than a measurement (RELEASE_SIGNING, LAUNCHER_ICON, OWNER_VISUAL_GATE, DEVICE_MATRIX, PRODUCT_DECISIONS, FLOW_GENERATION) say so in their own evidence instead of pretending to have measured. BLOCKED is never reported as PASS.
