# 01 Codex 切换到 V4 总提示词

你现在执行 Cozy Focus 的：

**V4 VISUAL MIGRATION + EXISTING UI RECONCILIATION**

Repository:
https://github.com/yuhangzhu295-wq/cozy-focus

Current main baseline:
e7df460193ea799b2e0c0eba0b7010c120671834

## A. Source of Truth

从本次开始：

1. `docs/cozy_focus_v4/designs/pages/`
   = 唯一页面视觉 Source of Truth。

2. 如果中文路径读取异常：
   使用完全等价的：
   `docs/cozy_focus_v4/designs/pages_ascii/`

3. `designs/overview/`
   仅用于理解 IA，禁止作为页面背景或逐像素实现依据。

4. V2 / 旧 V3 的 `designs/`
   全部降级为：
   `LEGACY_REFERENCE`

5. V2 的工程层：
   `reference/ implementation/ qa/`
   在不与 V4 冲突时仍然继承。

## B. 当前工程保护区

当前 GitHub 已经完成到 Phase 4，并经过修复/CI。

默认 KEEP：

- FocusSessionEngine / timestamp timer
- Drift local-first
- RewardLedger + SettlementDao
- Pet/Reward different-session concurrency fixes
- StatisticsEngine
- Craft / Inventory
- Room atomic placement
- Room geometry
- currentUserIdProvider
- GitHub Actions
- 已有测试

禁止因为换 UI 而重写这些。

## C. V4 信息架构

Bottom Navigation 只有：

- 首页
- 记录
- 成长

设置：
右上角齿轮。

### 首页

Mochi
+ 大数字钟
+ Start Focus
+ 今日轻量进度

### 专注流程

首页
→ 专注设置
→ 专注中
→ 暂停/恢复
→ 完成
→ 可选心情备注
→ 奖励反馈
→ 首页

专注中/暂停/确认/完成流程页面：

**不显示底部三导航。**

### 记录

一个 Records route 内部标签：

今日 / 历史 / 日历 / 报告

报告内部：

周 / 月 / 年

08A Wrapped 从年度报告进入。

### 成长

一个 Growth route 内部标签：

Mochi / 房间 / 装扮 / 图鉴

制作列表
制作详情
房间库存

全部属于 Growth 内部状态，
不能新增主导航入口。

## D. 第一步：只审计，不修改

读取当前代码和 V4 全部设计后创建：

`outputs/V4_UI_MIGRATION_AUDIT.md`

必须列出：

- 当前 routes
- 当前 bottom nav
- 每个现有页面对应的 V4 页面
- KEEP / UI_RECONCILE / NEW
- V2/V3 旧视觉依赖
- fake/hardcoded UI 风险
- 需要删除/合并的多余入口

完成 Audit 后才能修改。

## E. UI Migration 顺序

1. AppShell：
   Bottom Navigation 收敛为 3 个。

2. Focus：
   01 → 02 → 03 → 03A → 03B → 03C → 04 → 04A → 04B

3. Records：
   05 → 05A → 05B → 05C → 05D → 06 → 07 → 08 → 08A

4. Growth / existing Phase 4 presentation：
   09 → 09A → 09B → 09C

5. STOP。
   到这里先不要自动进入新的 Phase 5 Pet Domain 开发。

我要先检查 GitHub。

## F. 样例数据规则

设计图里：

25:00
75 分钟
+42
+120
826h
1,892
18/36
Lv.5

全部只是 layout sample。

必须来自：

FocusSession
FocusRecord
StatisticsEngine
RewardLedger
CraftJob
Inventory
PetProgress

禁止硬编码。

## G. 关键整改

- 04B：奖励自动结算，只展示反馈，不做“领取/去库存”假跳转。
- Records：Today/History/Calendar/Reports 用 tab，不新增路由层级堆叠。
- Growth：Room/Dress/Collection 用 tab。
- Inventory：降级为 Room 内部 panel。
- Settings：只从右上角进入。
- Empty state：是 Records 状态，不是新的主导航页。

## H. 验证

至少：

dart format .
flutter analyze
flutter test
flutter build apk --debug

新增 Widget/Integration test：

- Bottom nav 只有 3 个
- Focus active 不显示 bottom nav
- Records tabs 原地切换
- Reports 周/月/年原地切换
- Growth tabs 原地切换
- Reward 不存在 fake claim buttons
- Room inventory 不占 main nav
- sample data 不作为常量业务值

如果无法使用 Computer Control：

继续完成代码级、Widget、Integration、Build 验证。

真机/视觉点击放入：
`outputs/V4_MANUAL_VISUAL_BACKLOG.md`

禁止因此跳过可自动验证的代码。

## I. Commit

建议：

`chore(v4): migrate app shell to simplified three-tab IA`

`fix(v4-ui): reconcile phase 2-4 presentation with corrected designs`

完成 Phase 2–4 UI reconciliation 后：

STOP。

不要自动开始 Phase 5。
