# 03 — Golden Flow A–H evidence

The eight flows defined in `outputs/final_product_qa/03_BUSINESS_FLOW_EVIDENCE.md`
were **not modified, weakened or skipped**. They run as part of the full suite,
which was re-run in this round; the new FLOW-01…10 matrix is in
`02_BUSINESS_FLOW_MATRIX.md`.

## Where each flow lives

| Flow | Scenario | Test file |
|---|---|---|
| A | 任务 → 今日计划 → 专注 → 复盘 → 记录 → 累计 → 统计 → 时间线 | `test/integration/golden_flows_a_to_f_test.dart` (*A: task to plan to focus to review to records to stats to timeline*) |
| B | 专注 → 记一下 → 分心记录 → 专注继续 → 完成 → 分心箱 → 转任务 | `test/integration/distraction_flow_test.dart` (*the whole flow leaves the right rows behind*) |
| C | 首页 → 放松 → 休息 → 时间线 → 重启仍在 | `test/integration/free_time_flow_test.dart` (*the whole flow leaves a real rest behind*) |
| D | 专注 → 后台 → 恢复 → 暂停 → 继续 → 完成 → 保存 → 重启 | `test/integration/golden_flows_a_to_f_test.dart` (*D: background, resume, pause, resume, save, restart*) |
| E | 导入伙伴 → 安装 → 选择 → 重启 | `test/presentation/companion/multi_companion_test.dart` + `test/presentation/companion/pack/*` |
| F | 成长 → 房间 → 装扮 → 图鉴 | `test/presentation/companion/room_simulation_acceptance_test.dart` + `test/presentation/companion/multi_companion_test.dart` |
| G | 旧 Drift 库 → 迁移 → 数据完整性 | `test/integration/persistence_recovery_test.dart` (v1→v2→v3→v4 chain, current DB untouched) |
| H | 首次使用 → 建任务 → 专注 → 首条记录 | `test/integration/user_golden_flow_test.dart` (*a new player can discover and complete the whole loop*) |

## What the full run actually said

- Before the three new gap tests: **2134 / 2134 passed** (`flutter test`, this
  round).
- The new `test/integration/v1_flow_gaps_test.dart`: **3 / 3 passed**.
- `dart format`: 0 changed; `flutter analyze --fatal-infos`: 0 issues.
- The authoritative gate output is in `07_BUILD_AND_PERFORMANCE.md`; it is the
  command's own output, not a hand-written summary.

## Cardinality, which is what the slices cannot see

`test/integration/golden_flow_test.dart` asserts the chain the slices cannot:

> one session → exactly one record → exactly one settlement → exactly one reward.

It also asserts that a repeated save is refused, that the database itself
refuses a second record for one session, and that recovery of an abandoned
session settles it exactly once. Those are the duplicate-award failure modes,
and they are the reason a "the screen showed the right number" test is not
enough.

## Device-walked flows this round

The emulator walk in this round covered:

- **FLOW-08** end to end (export → create a task → restore → the task is gone),
  with the system file pickers and screenshots. See `06_BACKUP_RESTORE_REPORT.md`.
- **A/D/F** partially, through the room candidate screenshots and a real
  25:00 focus session started and ended on the room page (the session ran and
  the early-end dialog showed the elapsed time).

The remaining flows were not re-walked on the device this round; they are
covered by the tests above. That distinction is deliberate: a test is not a
device walk, and a device walk is not a regression suite.
