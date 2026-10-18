# 当前真机截图（2026-10-18）

这 27 张图是**当前 HEAD 的 shipping entry point**（`lib/main.dart`）在
`emulator-5554`（Pixel 7 / API 34，1080×2400）上的真实截图，不是拼图、不是旧图重发。

**它们没有通过视觉验收。** 按所有者 2026-10-18 的规则，一页只有审查代理同时看过设计
展板与这张截图、并明确说 PASS 才算过关。这批图是**送审材料**，不是结论。任何一页都
不得标 `VISUAL_VERIFIED` 或 `OWNER_VISUAL_APPROVED`。

## 数据来源：可复现的 `demo_day`

上一轮审查把「空数据库」读成了「功能缺失」——分心箱的类别 chip 只为有内容的类别出现，
空的时候一个都不出现；任务卡副标题只在任务有备注时出现。为了让截图展示一个有内容的
产品，这批图使用 `lib/dev/qa_fixture.dart` 新增的 `demo_day` 场景播种：

```text
flutter build apk --debug -t lib/dev/qa_fixture_main.dart \
    --dart-define=QA_SCENARIO=demo_day
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# 启动一次，等待 logcat 出现 QA_SEED，然后重新安装 lib/main.dart 的包
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

播种走的是 App 自己的仓库（`ITaskRepository`、`IFocusSessionRepository`、
`IFocusRecordRepository`、`IDistractionRepository`、`IRewardLedgerRepository`），
不是手改 SQLite，所以不会产生 App 自己到不了的状态：

| 内容 | 数量 |
|---|---|
| 任务 | 5（3 进行中、2 已完成） |
| 今日安排 | 3（含 1 项已完成） |
| 已完成专注 | 7 段 / 255 分钟（另有截图时真实完成的一段 3 分钟） |
| 分心笔记 | 5（4 待处理：生活 2 / 工作 1 / 学习 1；1 已处理） |
| 家具 | 5 件全部拥有并摆放 |
| Mochi | Lv.13 / 1275 XP / 255 分钟 / 幸福感 82% |

`demo_day` 有两条测试保证它自洽：记录与 session 时长逐条相等、奖励币与 XP 符合
`RewardService` 的规则（2 币/分钟、5 XP/分钟）、宠物等级由 `GrowthLevelCurve` 从 XP
推导；重复播种不会把一周翻倍（变异验证过：去掉守卫后 XP 从 1275 变 2550，测试变红）。

## 截图清单

| 文件 | 页面 | 对应的设计展板 |
|---|---|---|
| `01_home.png` | 首页（当前任务、时长选择、开始专注） | 01 |
| `02_records.png` | 记录中心（今日） | 05 |
| `02_task_list.png` | 任务列表（今天） | 02 |
| `03_today_plan.png` | 今日计划（列表） | 03 |
| `09_timeline.png` | 今日计划（时间线） | 09 |
| `03_growth.png` | 成长页 | 10 |
| `10_room.png` | Mochi 的小房间（5 件家具） | 10 |
| `10A_dress_up.png` | 装扮（空态：装扮系统未接数据） | 10A |
| `08_collection.png` | 收藏图鉴（5/8） | 10B |
| `04_focus_running.png` | 专注中 | 04 |
| `03B_resume.png` | 后台回来后的恢复层 | 03B |
| `03C_end_confirm.png` | 提前结束确认 | 03C |
| `04B_reward.png` | 结算奖励 | 04B |
| `05_capture_sheet.png` | 分心收集箱浮层 | 05 |
| `06_complete.png` | 专注完成 | 04 |
| `06_focus_review.png` | 记录感受 | 04A |
| `05C_record_detail.png` | 记录详情 | 05C |
| `05_history.png` | 历史记录 | 05B |
| `05D_calendar.png` | 日历 | 05D |
| `06_weekly_report.png` | 周报 | 06 |
| `07_monthly_report.png` | 月报 | 07 |
| `11_create_task.png` | 新建任务 | 11 |
| `12_task_detail.png` | 任务详情 | 12 |
| `13_inbox.png` | 分心箱清单 | 13 |
| `14_schedule_to_today.png` | 安排到今日计划 | 14 |
| `15_settings.png` | 设置 | 15 |
| `15_data_sync.png` | 数据与同步（本地备份 / 恢复入口） | 15 |

展板原件在 `outputs/visual_qa/reference/`（16 张，文件名带 `_screen.png` 的是裁出的
手机区域；其中 02/14/15 的 `_screen` 裁切是坏的——20×32、88×24、28×56——比对时请用
整张展板，不要用这三张裁图）。

## 这批图暴露并已修掉的两个缺陷

1. **分心箱的类别筛选被挤到屏幕外。** 真实数据下这一行有 7 枚 chip（3 个状态 + 4 个
   类别），原来是横向 `ListView`，`工作 (1)` 落在 1080 宽屏幕之外，没有任何提示说这行
   可以横滑。改成 `Wrap` 后两行全部可见。
2. **「自定义」时长 chip 比同排的四枚高 25px。** 预设 chip 是「数字 + 单位」两行，
   自定义是一行，`Wrap` 默认按顶部对齐，于是它浮在上面。改为
   `WrapCrossAlignment.center`。

两条都有断言，并各自做过反向证明（把旧行为改回去，测试确实变红）：

- `every category filter is on screen, not scrolled off the edge` —— 恢复横向溢出后报
  `work is outside the viewport`；恢复 `alignment: Alignment.center` 后报
  `stretched to the full line instead of hugging its label`。
- `the custom chip sits on the same baseline as the presets` —— 去掉
  `WrapCrossAlignment.center` 后报 `25 and 自定义 are not on the same baseline`（测试
  面 9.5px，真机 25px）。

## 未覆盖

- **16 号展板（任务列表空态）没有当前截图。** 空态需要空数据库，与 `demo_day` 互斥；
  它由 widget 测试与 `outputs/final_product_qa` 的旧证据覆盖，本轮没有重拍。
- 02/14/15 的 `_screen` 裁图是坏的（见上），没有修，因为整张展板可用。
- **视觉结论：未取得。** 详见
  `outputs/autonomous_final_delivery/05_VISUAL_COMPARISON.md` 的「送审通道」一节。
