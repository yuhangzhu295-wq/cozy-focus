# Automated product gate

Generated 2026-10-21 04:15:26 at `653f51f9`. Local equals remote: **NO**.

| Gate | Status | Evidence |
|---|---|---|
| `DEVICE_MATRIX` | **DEFERRED** | the frame-time harness (integration_test/frame_time_test.dart, driver test_driver/perf_driver.dart) is re-runnable but needs an attached device and about three minutes, so it is not run by default. Pass --with-device to run it. The rest of the device matrix - the golden flows, the size sweep, large text, landscape, the migration walk - is still driven by hand. |
| `FORMAT` | **PASS** | 482 files, 0 changed |
| `ANALYZE` | **PASS** | 0 issues |
| `UNIT_TESTS` | **PASS** | 2288/2288 passed |
| `INTEGRATION_TESTS` | **PASS** | 54/54 passed |
| `GOLDEN_FLOW` | **PASS** | 6/6 passed |
| `MIGRATION` | **PASS** | 16/16 passed |
| `LIFECYCLE` | **PASS** | 81/81 passed |
| `ASSET_GATES` | **PASS** | 75/75 passed |
| `APK` | **PASS** | 32.1 MB (budget 34 MB) |
| `AAB` | **PASS** | 50.7 MB (budget 55 MB) |
| `DIFF_CHECK` | **PASS** | no whitespace errors |
| `RELEASE_SIGNING` | **BLOCKED** | RELEASE_SIGNING = NOT_RECOVERED: android/key.properties is absent, and no keystore was invented. The build switches over with no code change the moment it appears. |
| `LAUNCHER_ICON` | **BLOCKED** | still the stock Flutter logo in android/ (dominant colours 0,0,0 / 84,197,248 / 1,87,155). A candidate has been drawn - outputs/launcher_icon_candidate/, six sizes from the app's own palette - but it is NOT approved, so nothing under android/ was touched. Blocked on the owner's approval, not on artwork existing. |
| `OWNER_VISUAL_GATE` | **BLOCKED** | OWNER_VISUAL_GATE: the independent review passed all 16 boards and every supplementary state on 2026-10-20 (final-gate). The owner's final style approval has not been given, and REVIEW_APPROVED is not OWNER_VISUAL_APPROVED. Evidence: outputs/autonomous_final_delivery/05_VISUAL_COMPARISON.md |
| `PRODUCT_DECISIONS` | **PASS** | P25 reads CLOSED with 0 PRODUCT_DECISION_REQUIRED: every owner decision is made. Four of the six needed no code change - the code already behaved as decided - and two did, D3 (furniture names) and D4 (the long-session memory). Read from the document, not recited. 6 DEFERRED and 4 BLOCKED_EXTERNAL remain in the same file. |
| `BEHAVIOR_AUTHORITY` | **PASS** | BEHAVIOR_AUTHORITY_COUNT=1 (measured): the presented posture is determined by the committed action. |
| `FLOW_GENERATION` | **BLOCKED** | FLOW_GENERATION: no video surface reachable in Flow, and Flow's own banner reports video generation degraded. The video-to-sprite pipeline is built and validated against a local clip; no production video art exists. |

## Counts

- **PASS**: 13
- **BLOCKED**: 4
- **DEFERRED**: 1

---

Gates that can be re-run shell out to the command that already exists; none re-implements a check. The gates that report a standing owner or external state rather than a measurement (RELEASE_SIGNING, LAUNCHER_ICON, OWNER_VISUAL_GATE, PRODUCT_DECISIONS, FLOW_GENERATION) say so in their own evidence instead of pretending to have measured. DEVICE_MATRIX is no longer one of them: its frame-time row is a real measurement now, taken when --with-device is passed and reported as DEFERRED with the reason when it is not. BLOCKED is never reported as PASS.
