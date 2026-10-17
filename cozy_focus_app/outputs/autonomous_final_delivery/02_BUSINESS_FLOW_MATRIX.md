# 02 — Business flow matrix (FLOW-01 … FLOW-10)

**Measured at HEAD `df811ca` + the uncommitted gap tests; full suite 2134/2134
before them, 3/3 for the new file.** Every row below names the test that proves
it. No row is marked PASS because a screen was seen; each one asserts the rows
the flow leaves in the database.

## How to read this

- **PASS** — the named test ran in this round and asserted the flow's data.
- **PASS (device)** — additionally walked on the emulator in this round.
- **PARTIAL** — part of the scenario is asserted, part is not; the gap is named.
- **NOT COVERED** — no test asserts it. These are listed rather than hidden.

The existing A–F golden flows were not modified, weakened or skipped.

## The matrix

| FLOW | Scenario | Evidence | Status |
|---|---|---|---|
| 01 | 任务完整闭环 | `test/integration/golden_flows_a_to_f_test.dart` → *A: task to plan to focus to review to records to stats to timeline*; `task_flow_test.dart` → *the whole flow leaves the right rows behind*; `v1_flow_gaps_test.dart` → *FLOW-01: editing a task keeps its recorded time and its history*; `golden_flows_a_to_f_test.dart` → *E: a task and its plan survive a restart*; `task_detail_subtask_test.dart` → *adding one writes it…*, *ticking one moves the fraction…*, *a subtask can be removed…* | **PASS** |
| 02 | 计时边界与结算 | `focus_timing_mode_flow_test.dart` (6 tests: 番茄钟, 正计时, 深度专注, mode switch, pause refusal, restored mode); `persistence_recovery_test.dart` → *during an active focus session*, *during a pause*, *while finishing, and recovery settles it exactly once*, *a restart does not settle, duplicate or reset anything*; `golden_flow_test.dart` → *a repeated save is refused, and cannot double the record*, *the database itself refuses a second record for one session*; `v1_flow_gaps_test.dart` → *FLOW-02: finishing a countdown early records the time actually focused* | **PASS** |
| 03 | 分心箱 | `distraction_flow_test.dart` → *the whole flow leaves the right rows behind*, *安排到今天 files it and schedules it*, *several notes from one session all keep its id*, *a note captured without a session is still kept* | **PASS** |
| 04 | 自由时间 | `free_time_flow_test.dart` → *the whole flow leaves a real rest behind*, *ending a rest early is a rest that still happened*, *a running rest is the highlighted row on the timeline*, *the chooser is back after a rest*; `v1_flow_gaps_test.dart` → *FLOW-04: a rest records its length and earns no focus reward* | **PASS** |
| 05 | 成长与制作闭环 | `user_golden_flow_test.dart` → *a new player can discover and complete the whole loop* (starts with an empty inventory and crafts the target); `golden_flow_test.dart` → *fresh user through focus, craft, room, memory and restart*; `room_simulation_acceptance_test.dart` → *an unowned item contributes no anchor and no behaviour*; `five_sources_agree_test.dart` → *one session settles once, across all five* | **PASS** |
| 06 | 伙伴及动画 | `multi_companion_test.dart` → *every shipped companion has a visual provider*, *the asset gap is reported per pose, and never overstated*, *the cat and rabbit are drawn as their own species, not as Mochi*, *the same director drives any companion id*, *all three share the same pose vocabulary*; `room_simulation_acceptance_test.dart` (anchor → behaviour for sofa/desk/bed, focus/pause/end); `mochi_interaction_precache_test.dart` (renderer swap has a decoded image) | **PASS** |
| 07 | 历史数据与数据库 | `persistence_recovery_test.dart` → *v1 to v2 …*, *v2 to v3 …*, *the full v1 to v4 chain preserves every row*, *an already-current database is left alone*; `golden_flows_a_to_f_test.dart` → *F: an old database opens at the head without losing a focus record* | **PASS** |
| 08 | 备份与恢复 | `test/data/backup/backup_round_trip_test.dart` (11 tests: empty, populated, corrupt checksum, newer format, wrong schema, unknown column, duplicate row rollback, live session refusal, repeated restore, pack replace-not-merge, checksum stability) | **PASS (device)** |
| 09 | 不可用功能真实性 | `focus_setup_honest_rows_test.dart` → *the setup screen offers no toggle at all*, *white noise is stated, not offered*, *the reminder is stated, not switchable*, *the two rows agree with the settings page*; `phase7c_data_sync_test.dart` → test 3 (no fake switch; only the two real backup actions) | **PASS** |
| 10 | 使用体验与异常环境 | `screen_size_and_text_sweep_test.dart` → 360×800 / 393×852 / 412×915 at 1.0 and 1.3 text, plus the deliberate-overflow and reachability reverse proofs; `landscape_sweep.py` (device, previous round); `presentation_widgets_test.dart` (small-screen overlap) | **PARTIAL** |

## The honest gaps in FLOW-10

These are not covered by an automated assertion and are not claimed:

- **键盘弹出**: no test opens the soft keyboard and re-measures. The device
  walk in this round used `input text` on the create-task screen without
  asserting the resulting layout.
- **加载状态 / 操作失败**: individual pages have error paths, but there is no
  flow-level assertion that a failed load renders a retry rather than a blank.
- **前后台切换**: `persistence_recovery_test` covers the data consequences; the
  visual state on resume is device-only.
- **角色切换**: `multi_companion_test` covers selection and rendering identity;
  the on-device animation smoothness of a live switch was not re-recorded this
  round.

## Evidence of the device walk for FLOW-08

Files under `outputs/autonomous_final_delivery/device/`:

- `01_data_sync_page.png` — the two actions, both wired.
- `02_export_save_dialog.png` — the system `ACTION_CREATE_DOCUMENT` picker.
- `03_restore_preview.png` — the preview with counts and the irreversible
  warning.

The walk itself:

1. Exported on an empty database → `Downloads/cozyfocus-20261017-1810.cozybackup`,
   2207 bytes.
2. Created a task `backup-test` **after** the export.
3. Restored that backup → the preview reported 10 records → confirmed.
4. The task list was empty again: the restore replaced the dataset rather than
   merging.

That is the behaviour the brief asks for, observed on the device rather than
inferred from the unit tests.
