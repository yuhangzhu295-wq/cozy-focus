# 当前真机截图（2026-10-18，2026-10-20 补拍）

这些图是**当前 HEAD 的 shipping entry point**（`lib/main.dart`）在
`emulator-5554`（Pixel 7 / API 34，1080×2400）上的真实截图，不是拼图、不是旧图重发。

**2026-10-20 复验：16 张展板与补充状态均已由独立审查代理（`final-gate`）明确判 PASS。**
机器可读判定在 `REVIEW_VERDICT.json`（`tools/cozy_gate.py` 的 `OWNER_VISUAL_GATE`
直接读它）；逐页证据与修复清单见
`outputs/autonomous_final_delivery/05_VISUAL_COMPARISON.md`。

这**不等于** `OWNER_VISUAL_APPROVED`：所有者仍保留最终画风审批权，尤其对 01/10 的
程序化房间与 04B 的留白。任何一页都不得在所有者确认前标 `OWNER_VISUAL_APPROVED`。

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

播种走的是 App 自己的仓库和**真实的结算路径**（`ITaskRepository`、
`IFocusSessionRepository`、`IFocusRecordRepository`、`IDistractionRepository`、
`RewardService`），不是手改 SQLite，也不是手写奖励行。所以它产生的是 App 自己真能
到达的状态——包括结算自己写的 memory、幸福感变化和制作进度：

| 内容 | 数量 |
|---|---|
| 任务 | 5（3 进行中、2 已完成），创建于 6 天前 |
| 今日安排 | 3（含 1 项已完成） |
| 已完成专注 | 7 段 / 255 分钟（15300 秒） |
| 分心笔记 | 5（4 待处理：生活 2 / 工作 1 / 学习 1；1 已处理） |
| 家具 | 5 件全部拥有并摆放 |
| Mochi | Lv.13 / 1275 XP / 255 分钟（实测值） |
| 伙伴记忆 | 10 条：1 条首次专注、7 条升级（Lv.2/4/6/8/9/11/13）、2 条长会话（两段 50 分钟各一条） |

幸福感停在 100 是规则本身：结算每次 +5，而起点已经是上限，`clamp(0,100)` 把它夹住
了——这是真实结算行为，不是播种写死。

`demo_day` 有五条测试约束它（全部做过反向证明）：

1. 每条 record 与它的 session 时长相等，且 session 存在——两个方向都查。
2. 奖励币与 XP 符合 `RewardService` 的规则（2 币/分钟、5 XP/分钟），宠物等级由
   `GrowthLevelCurve` 从 XP 推导，因为**测试读回账本而不是相信播种算的数**。
3. 结算产生的 memory 带上它自己的生产 id（`mem_<pet>_<type>_<ts>`）——这证明是
   奖励规则写的，不是播种编的。**每段会话按自己的结束时刻结算**，否则固定 QA 时钟会让
   两段 50 分钟会话的 `longSession` 记忆 id 相同，第二条被 `INSERT OR IGNORE` 静默丢弃
   （反向证明：改回共享时钟，测试报 `Actual: ['陪你专注了 50 分钟']`，少一条）。
4. 时间线因果成立：任务不会在创建前被专注，也不会在完成它的专注开始前被标记完成。
5. 重复播种不会翻倍；**中断后补播**只结算缺的那部分（删掉 2 段再播种，宠物只多拿
   那 2 段的 450 XP，而不是整周再来一遍）。反向证明：把旧的"整周重算"写回去，测试报
   `Expected: <450> Actual: <2235>`。

`reset()` 也修过两次。第一次按账本里 demo 会话的 `settledAt` 删 memory；第二次发现
`LIKE 'qa_demo_sess_%'` 里的 `_` 是 SQL 单字符通配符（也会匹配 `qaXdemo_sess_1`），
而且没有限定 user，所以改成**按确切 id 集合**删会话/记录/账本，并把宠物已经拿到的
XP 与分钟按账本里那几行精确回退。两种形态的 memory（结算产生的生产 id + `qa_` 前缀的）
都会清理，不再是二选一。测试覆盖：`mem_keep_me` 保留、`qaXdemo_sess_1` 保留、
seed→reset→seed 后 XP 回到 1275 而不是 2550、两条长会话记忆都在。

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
| `08_free_time.png` | 自由时间（休息） | 08 |
| `04_focus_running.png` | 专注中 | 04 |
| `03B_resume.png` | 后台回来后的恢复层 | 03B |
| `03C_end_confirm.png` | 提前结束确认 | 03C |
| `04B_reward.png` | 结算奖励 | 04B |
| `05_capture_sheet.png` | 分心收集箱浮层 | 05 |
| `06_complete.png` | 专注完成 | 04 |
| `06_focus_review.png` | 记录感受 | 04A |
| `06_focus_review_scrolled.png` | 记录感受（滚动后，「本次收获」完整可达） | 04A |
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
| `16_empty_state.png` | 任务列表空态（空库另拍） | 16 |

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

## 2026-10-20 补拍与修复

- **16 号空态已补拍**：用 `--dart-define=QA_RESET=true` 清空 QA 数据后拍摄
  （`16_empty_state.png`），随后重新播种 `demo_day` 并把设备留在 shipping build。
- **08 号自由时间已补拍**（`08_free_time.png`）。
- `04_focus_running.png` 之前误拍成恢复层（与 `03B_resume.png` 像素差 0.47%），
  已重拍为真实运行页（像素差 91.49%）。
- 02/03/06/07/09/01/04B/06A 已按当前 HEAD 重拍。
- 本轮修掉的 10 个缺陷（选中态、报告配色、月报轴、奖励页 Mochi、状态栏图标、
  预计奖励口径等）与逐条反向证明，见
  `outputs/autonomous_final_delivery/05_VISUAL_COMPARISON.md`。

## 仍未覆盖 / 已知差距

- 02/14/15 的 `_screen` 裁图是坏的（见上），没有修，因为整张展板可用。
- 01/10 的程序化房间与展板的照片级场景仍有美术差距（已决定不做照片房间）。
- 视觉结论：**16/16 展板 + 补充状态 REVIEW_APPROVED**（审查代理判定）；
  `OWNER_VISUAL_APPROVED` 仍待所有者最终画风审批。
