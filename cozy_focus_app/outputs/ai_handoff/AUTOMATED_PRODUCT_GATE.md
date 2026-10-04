# Automated product gate

Generated 2026-10-04 14:53:15 at `3e6ef82a`. Local equals remote: **YES**.

| Gate | Status | Evidence |
|---|---|---|
| `FORMAT` | **PASS** | 269 files, 0 changed |
| `ANALYZE` | **PASS** | 0 issues |
| `UNIT_TESTS` | **PASS** | 1196/1196 passed |
| `INTEGRATION_TESTS` | **PASS** | 20/20 passed |
| `GOLDEN_FLOW` | **PASS** | 6/6 passed |
| `MIGRATION` | **PASS** | 15/15 passed |
| `LIFECYCLE` | **PASS** | 52/52 passed |
| `ASSET_GATES` | **PASS** | 75/75 passed |
| `APK` | **NOT_TESTED** | --skip-builds was passed |
| `AAB` | **NOT_TESTED** | --skip-builds was passed |
| `DIFF_CHECK` | **PASS** | no whitespace errors |
| `RELEASE_SIGNING` | **BLOCKED** | RELEASE_SIGNING = NOT_RECOVERED: android/key.properties is absent, and no keystore was invented. The build switches over with no code change the moment it appears. |
| `LAUNCHER_ICON` | **BLOCKED** | still the stock Flutter logo (dominant colours 0,0,0 / 84,197,248 / 1,87,155); no approved artwork exists, so none was invented |
| `OWNER_VISUAL_GATE` | **DEFERRED** | OWNER_VISUAL_GATE is REQUIRED and is never decided by a measurement. P21's technical gates pass; whether the art reads well is human judgement. |
| `DEVICE_MATRIX` | **DEFERRED** | device verification exists and is recorded (collection, craft, P7 toolbar, room alignment, the rabbit pack, the P11 routine, indexed sprites, the P14 fix, and the P21 idle and travel motion gates) - but it was driven by hand each time, not by this script. A re-runnable device matrix would need an unattended driver. |
| `PRODUCT_DECISIONS` | **DEFERRED** | P25 records 7 PRODUCT_DECISION_REQUIRED, 6 DEFERRED and 4 BLOCKED_EXTERNAL. Nothing was implemented to close a question. |
| `BEHAVIOR_AUTHORITY` | **FAIL** | BEHAVIOR_AUTHORITY_COUNT=2 (measured): the room can commit an action it cannot show on sofa,desk,bookshelf. The presentation layer has a second, independent say in what the companion does. Open pending the P25 D5 decision - does tapping furniture choose the action or only the destination. Fixing it before that answer would be fixing it the wrong way. |
| `FLOW_GENERATION` | **BLOCKED** | FLOW_GENERATION: no video surface reachable in Flow, and Flow's own banner reports video generation degraded. The video-to-sprite pipeline is built and validated against a local clip; no production video art exists. |

## Counts

- **PASS**: 9
- **FAIL**: 1
- **BLOCKED**: 3
- **DEFERRED**: 3
- **NOT_TESTED**: 2

---

Gates that can be re-run shell out to the command that already exists; none re-implements a check. The gates that report a standing owner or external state rather than a measurement (RELEASE_SIGNING, LAUNCHER_ICON, OWNER_VISUAL_GATE, DEVICE_MATRIX, PRODUCT_DECISIONS, FLOW_GENERATION) say so in their own evidence instead of pretending to have measured. BLOCKED is never reported as PASS.
