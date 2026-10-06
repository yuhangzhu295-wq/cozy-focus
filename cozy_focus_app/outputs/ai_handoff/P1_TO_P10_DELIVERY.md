# CozyFocus 2.0 — P1–P10 交付说明

分支：`recovery/v4.2.1-rebuild`（未推送）
起始提交：`9bbd223`（P1 之前）
交付提交：`ba75fe3`
阶段提交：9 个，每个阶段一个，顺序为 P1 → P10。

---

## 一、这份交付是什么

把开发包 v2 的 16 张设计图，在**现有架构上增量实现**成可运行、可持久化、可重启的功能，而不是另起一套页面。

- 底部导航仍是 **首页 / 记录 / 成长** 三个一级 Tab（未改成 5 个）。
- 专注流程仍复用 `/focus/setup → active → complete → save → reward`，没有第二套 Focus Engine。
- 宠物仍走 `CompanionContext → CompanionBehaviorDirector → CompanionAnimationController → CompanionSpritePlayer`，动画层未改。
- 所有新数据都进现有 SQLite（schema 从 v4 升到 **v11**），每一步都有迁移测试。

## 二、16 张设计图落在哪里

| 设计 | 落点 |
|---|---|
| 01 首页 | 已有首页；P9 让首页主形象由真实业务状态驱动 |
| 02 任务 | `/records/tasks`，三个筛选 Tab（今天 / 进行中 / 已完成） |
| 03 今日计划 | `/records/today` 的「计划」视图（下一个任务卡 + 时间顺序列表） |
| 04 专注模式 | 专注页 + 设置页的模式切换（番茄钟 / 正计时 / 深度专注） |
| 05 分心收集箱 | 专注页「记一下」→ 底部浮层 |
| 06 专注复盘 | `/focus/save` 重写为复盘页（心情 / 做了什么 / 收获 / 下次继续） |
| 07 统计分析 | `/records/today` 的「统计」视图（日 / 周 / 月） |
| 08 自由时间 | `/rest`，首页「放松一下」进入 |
| 09 时间线 | `/records/today` 的「时间线」视图（计划 / 专注 / 休息 / 快速记录 同轴） |
| 10 宠物房间 | 已有房间功能，未改 |
| 11 新建任务 | `/records/tasks/new`，含「加入今日计划」开关 |
| 12 任务详情 | `/records/tasks/:id`，含「下次计划」与「加入今日计划」 |
| 13 分心箱清单 | `/records/inbox`，记录页进入 |
| 14 安排到今日计划 | `/records/tasks/:id/schedule` |
| 15 轻量设置 | 设置页「默认专注时长」变成真实可持久化设置 |
| 16 空状态 | 任务列表空状态：宠物形象 + 新建任务 + 开始第一次专注 |

## 三、8 个新功能的闭环

1. **任务域**：任务 / 子任务 / 分类 / 预估时长，真实读写。
2. **今日计划**：`task_schedules`，一天一条、唯一约束、级联删除；「今天」筛选是真实查询。
3. **专注计时模式**：`FocusTimingMode`（countdown / countUp / deepFocus）与 `FocusMode` 分开；深度专注由引擎拒绝暂停，不只是隐藏按钮。
4. **分心收集箱**：专注中速记，不打断计时（有测试断言 elapsed 不变、没有写入暂停区间）。
5. **专注复盘**：心情四个值（**无默认选中**）、收获标签、下次继续；旧 emoji 迁移为 id。
6. **时间线**：只读投影，**不新建事实表**，从 `task_schedules` / `focus_records` / `distraction_notes` / `rest_sessions` 聚合。
7. **统计分析**：总时长 / 次数 / 平均时长 / 每日柱状 / 任务分布，全部由记录算出，**没有任何设计稿示例数字被硬编码**。
8. **自由时间**：`rest_sessions` 独立事实表，休息不计入专注统计；宠物进入 `sleep`。

## 四、明确没做的事（以及为什么）

- **白噪音**（设计 04 / 15）：仓库里没有任何音频资源。一个播放不了任何声音的开关正是交付要求里禁止的假控件，因此没有实现。专注设置页原有的非交互提示行保持原样。
- **底部导航 5 个 Tab**（设计 15 / 16 的截图里是 5 个）：交付要求明确禁止，保持 3 个。
- **通知系统**：设置页仍是诚实的「尚未接入系统通知」文案，没有做成可点的假开关。

## 五、验证状态

- `dart format --set-exit-if-changed .` 通过
- `flutter analyze --fatal-infos` 无问题
- `flutter test` **1830 通过 / 0 失败**
- `flutter build apk --debug` 成功
- `git diff --check` 干净

### Golden Flow A–F

| 流程 | 状态 |
|---|---|
| A 任务 → 详情 → 今日计划 → 专注 → 复盘 → 保存 → 记录 → 任务累计时长 → 统计 → 时间线 | ✅ `golden_flows_a_to_f_test.dart` |
| B 专注 → 记一下 → 分心记录 → 专注继续 → 完成 → 分心箱 → 转任务 | ✅ `distraction_flow_test.dart` |
| C 首页 → 放松一下 → 10 分钟 → 宠物休息 → 完成 → 时间线休息事件 | ✅ `free_time_flow_test.dart` |
| D 启动 → 专注 → 后台 → 恢复 → 时间正确 → 暂停 → 继续 → 完成 → 保存 → 重启后记录仍在 | ✅ `golden_flows_a_to_f_test.dart` |
| E 建任务 → 关 App → 重开 → 任务与今日计划仍在，统计一致 | ✅ `golden_flows_a_to_f_test.dart` |
| F 旧版本数据库 → 迁移 → 新版本 → FocusRecord 不丢 | ✅ `golden_flows_a_to_f_test.dart` + 各阶段迁移测试 |

## 六、测试期间发现并修掉的真实缺陷

这些都不是「测试写错了」，是代码错了，每条都配了回归测试：

1. **`AnalyticsRange` 没有值相等** → 作为 Riverpod family key 每次重建都是新的窗口，统计页永远停在加载态，而代码看起来完全正确。
2. **下拉刷新只刷新了计划** → 时间线与统计是投影，没有 controller 可 reload，用户下拉后数字不变。
3. **计划空状态遮住了时间线** → 没有安排的那一天切到「时间线」显示的是「今天还没有安排」，时间线 Tab 根本进不去。
4. **「下一个任务」卡片出现在时间线上** → 设计里时间线没有这张卡；P2 那个本该覆盖它的测试两种布局都能通过，是假绿。
5. **`FocusSession.elapsedSecondsAt` 在时钟倒退时抛异常** → `clamp(0, raw)` 上下界颠倒，NTP 校正 / 改时区 / 用户改设备时间都会让 1 秒的显示 ticker 抛错。
6. **`DriftRestDao.update` 覆盖了 `DatabaseAccessor.update`** → 同类里所有 `update(table)` 变成类型错误。
7. **宠物状态覆盖丢掉了 craft** → 第一版 P9 覆盖只返回 idle/focus/pause/sleep，把 avatar 自己推导的 craft 状态吃掉了，5 个既有测试失败；改成只回答 avatar 看不到的「是否在休息」。
8. **`TextEditingController` 在对话框还在退场时被 dispose** → 自定义时长弹窗抛「used after being disposed」。
9. **长文本按 code unit 截断会切断代理对** → 改成按 code point 截断，并加了 emoji 用例。

## 七、已知的观察项（未修，如实记录）

- `test/presentation/companion/pack/companion_import_page_test.dart` 里的
  「the name the pack declares is prefilled, and install writes it」在**全量并发跑**时失败过两次，
  单独跑连续 3 次都通过。成因未定位，未做任何「让它通过」的改动。

## 八、模拟器实机走查（2026-10-07 补做）

P1–P10 交付后，把 debug APK 装到 Pixel 7 / API 34 模拟器上，逐屏走查了：
记录域入口、今日计划三个视图（计划 / 时间线 / 统计）、任务列表空状态、新建任务、
专注设置、专注进行页、分心收集箱浮层、专注完成页、分心箱清单、休息页、设置页。

**走查抓到 3 个全套测试都没抓到的真实缺陷**，全部已修并配反向证明过的回归测试：

1. **专注设置页底部导航高亮的是「成长」**。这个流程从首页进入，同一流程的下一屏
   `focus_complete_page` 标的是「首页」。没有任何测试断言过导航高亮的是哪个 tab，
   只断言过导航存在。定位方式是读像素：设置页的「成长」标签用 `primarySage` 画，
   首页的「首页」标签也是 —— 源码里不该有的矛盾。
2. **记录页的分心箱计数在速记之后不刷新**，一直显示「还没有记录」，而分心箱里其实
   已经有那条笔记。计数来自一个 `FutureProvider`，答案被缓存到它被销毁为止。
   第一版修法（每次收件箱变动就 invalidate）弄坏了两条 controller 级测试——invalidate
   会排一个 Riverpod 任务，测试在同一 tick 结束就留下 pending timer。改成从收件箱
   controller 自身状态派生：单一真相来源、不排任务、还少一次查询。
3. **休息页四个时长排成 3+1**，设计稿是 2×2。`Wrap` 把 30 分钟单独挤到第二行，
   读起来像「列表 + 一个补充项」而不是四个等权选择。控件都在、都能点，正是休息页
   测试唯一检查的东西。

每个修复都有测试，且每个测试都做了反向证明：把修复还原，测试就红。计数的那个变异
用 `read` 替 `watch` —— 原始缺陷的同一个机制 —— 失败症状与线上一致。

修复后在模拟器上复验：记录页显示「1 条待处理」、休息时长是 2×2、专注设置页高亮
「首页」。

## 九、未做验证的部分

- 十六张设计图里，实机只走查了上面列出的屏幕；**其余页面的视觉仍未经人工确认**。
- 没有做性能测量（启动时间、帧率、包体）。
