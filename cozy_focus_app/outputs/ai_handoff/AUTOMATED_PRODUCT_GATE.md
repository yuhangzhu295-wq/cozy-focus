# Automated product gate

Generated 2026-10-19 16:23:40 at `531fa22c`. Local equals remote: **YES**.

| Gate | Status | Evidence |
|---|---|---|
| `DEVICE_MATRIX` | **BLOCKED** | the frame-time harness cannot be measured: the host has only 1806 MB free after a minute of settling, and the AVD's guest RAM alone is 2048 MB (hw.ramSize=2G), so the emulator is being paged. The measurement would describe the host. Free memory and re-run. The rest of the device matrix - the golden flows, the size sweep, large text, landscape, the migration walk - is still driven by hand. |
| `FORMAT` | **PASS** | 481 files, 0 changed |
| `ANALYZE` | **PASS** | 0 issues |
| `UNIT_TESTS` | **PASS** | 2177/2177 passed |
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
| `OWNER_VISUAL_GATE` | **BLOCKED** | OWNER_VISUAL_GATE is REQUIRED and has not run: no review agent could receive an image on this machine. Four visual-judge agents are bound to an unentitled plan; every gpt-6-sol/gemini/claude subagent returns 'media omitted from provider request because the selected model does not support image input'; image-reader's API key is malformed and no other vision credential is configured. 27 current screenshots and 16 boards are ready to review the moment a channel exists. Evidence: outputs/autonomous_final_delivery/05_VISUAL_COMPARISON.md |
| `PRODUCT_DECISIONS` | **PASS** | P25 reads CLOSED with 0 PRODUCT_DECISION_REQUIRED: every owner decision is made. Four of the six needed no code change - the code already behaved as decided - and two did, D3 (furniture names) and D4 (the long-session memory). Read from the document, not recited. 6 DEFERRED and 4 BLOCKED_EXTERNAL remain in the same file. |
| `BEHAVIOR_AUTHORITY` | **PASS** | BEHAVIOR_AUTHORITY_COUNT=1 (measured): the presented posture is determined by the committed action. |
| `FLOW_GENERATION` | **BLOCKED** | FLOW_GENERATION: no video surface reachable in Flow, and Flow's own banner reports video generation degraded. The video-to-sprite pipeline is built and validated against a local clip; no production video art exists. |

## Counts

- **PASS**: 13
- **BLOCKED**: 5

---

Gates that can be re-run shell out to the command that already exists; none re-implements a check. The gates that report a standing owner or external state rather than a measurement (RELEASE_SIGNING, LAUNCHER_ICON, OWNER_VISUAL_GATE, PRODUCT_DECISIONS, FLOW_GENERATION) say so in their own evidence instead of pretending to have measured. DEVICE_MATRIX is no longer one of them: its frame-time row is a real measurement now, taken when --with-device is passed and reported as DEFERRED with the reason when it is not. BLOCKED is never reported as PASS.
