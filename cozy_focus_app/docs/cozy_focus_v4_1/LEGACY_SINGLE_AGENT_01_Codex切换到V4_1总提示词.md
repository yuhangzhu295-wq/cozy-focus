# 01 Codex 切换到 V4.1 FINAL 总提示词

你现在执行 Cozy Focus：

**V4.1 FINAL VISUAL MIGRATION + PHASE 2–4 UI RECONCILIATION**

Repository:
https://github.com/yuhangzhu295-wq/cozy-focus

Current main baseline:
e7df460193ea799b2e0c0eba0b7010c120671834

注意：

“V4.1”是设计/方案包版本，
不是开发 Phase 4.1。

当前开发主线已经完成到 Phase 4 Code Gate。

━━━━━━━━━━━━━━━━━━━━
A. Source of Truth
━━━━━━━━━━━━━━━━━━━━

从本次开始：

1.
`docs/cozy_focus_v4_1/designs/pages/`

= 唯一页面视觉 Source of Truth。

2.
如果中文文件名发生 mojibake：

使用：

`docs/cozy_focus_v4_1/designs/pages_ascii/`

两者内容完全相同。

3.
`designs/overview/`

只解释：

IA / 页面索引。

禁止：

把 overview 裁图实现页面。

4.
以下全部降级：

V2 designs
旧 V3 designs
V4 pre-polish designs

状态：

LEGACY_REFERENCE

不得再作为视觉实现依据。

━━━━━━━━━━━━━━━━━━━━
B. 当前代码保护区
━━━━━━━━━━━━━━━━━━━━

当前 GitHub Phase 0–4 已通过多轮 Review 和 CI。

默认 KEEP：

- FocusClock
- FocusSessionEngine
- timestamp timer
- Drift DB / migrations
- currentUserIdProvider
- RewardLedger
- SettlementDao
- Reward same-session / different-session concurrency
- StatisticsEngine
- CraftEngine
- Inventory invariant
- Room atomic placement
- RoomGeometry
- 现有 Phase 1–4 tests
- Flutter GitHub Actions

禁止为了新 UI：

重写 Domain
重建数据库
重做统计公式
重写 settlement
重写 craft transaction

如果确实发现独立业务 bug：

先记录：

`outputs/V4_1_ARCHITECTURE_BLOCKER.md`

不要夹带修复。

━━━━━━━━━━━━━━━━━━━━
C. 产品 IA
━━━━━━━━━━━━━━━━━━━━

Bottom Navigation 只有：

首页
记录
成长

设置：

右上角齿轮。

### 首页

核心：

Mochi
大数字钟
Start Focus
轻量今日进度

禁止塞一堆快捷入口。

### Focus Flow

首页
→ 专注设置
→ 专注中
→ 暂停/恢复
→ 完成
→ 可选记录感受
→ 奖励反馈
→ 首页

Active / Pause / Recovery / Early-End / Complete：

不显示主 Bottom Navigation。

### Records

单一 Records route：

Today
History
Calendar
Reports

使用顶部 Tab。

Reports 内部：

Week
Month
Year

Wrapped：

从 Year 进入。

### Growth

单一 Growth route：

Mochi
Room
Dress
Collection

Craft List
Craft Detail
Room Inventory

全部是 Growth 内部状态 / panel。

禁止重新增加：

Inventory
Craft
Collection

主导航入口。

━━━━━━━━━━━━━━━━━━━━
D. 文案 / 国际化
━━━━━━━━━━━━━━━━━━━━

设计稿中的中文：

用于表达布局和交互。

实现必须走：

i18n / localization key。

Western launch 默认语言仍按产品配置处理。

禁止把设计稿中文直接散落硬编码在 Widget。

━━━━━━━━━━━━━━━━━━━━
E. 样例数字
━━━━━━━━━━━━━━━━━━━━

设计图里的：

25:00
12 分钟
+42
+120
826 h
1,892
18 / 36
Lv.5
21 / 30 min

全部是视觉样例。

实际必须来自：

FocusSession
FocusRecord
StatisticsEngine
RewardLedger
CraftJob
Inventory
PetProgress

禁止 sample constant 进入业务状态。

━━━━━━━━━━━━━━━━━━━━
F. 第一阶段：只审计
━━━━━━━━━━━━━━━━━━━━

在任何代码修改之前：

读取：

- V4.1 README
- 00–04 docs
- execution_order_v4_1.json
- manifest_v4_1.json
- designs/pages
- 当前 GitHub 页面/route/controller
- outputs Phase 1–4 reports

创建：

`outputs/V4_1_UI_MIGRATION_AUDIT.md`

逐页列：

KEEP
UI_RECONCILE
NEW
BLOCKED

同时列：

- 当前 BottomNavigation
- 当前 routes
- 重复页面入口
- 旧 V2/V3 视觉残留
- fake/hardcoded UI
- 设计与当前 UI 差异

Audit 完成后才能改代码。

━━━━━━━━━━━━━━━━━━━━
G. UI Reconcile 顺序
━━━━━━━━━━━━━━━━━━━━

Step 1:
AppShell / 3-tab navigation

Step 2:
01
02
03
03A
03B
03C
04
04A
04B

Step 3:
05
05A
05B
05C
05D
06
07
08
08A

Step 4:
09
09A
09B
09C

完成 Step 4 后：

STOP。

先不要进入新的 Phase 5 Pet Growth Domain。

等我检查 GitHub。

━━━━━━━━━━━━━━━━━━━━
H. 已知 V2 回归风险
━━━━━━━━━━━━━━━━━━━━

必须确认不会重新出现：

- Wooden Chair reward hardcode
- fake Place Now
- fake View Inventory
- fake gallery Snackbar
- `365 日`
- null mood 自动伪造成开心
- local_user/default_user 分裂
- Room 超量摆放
- drag 每帧 DB write
- sample stats hardcode

━━━━━━━━━━━━━━━━━━━━
I. 设计实现要求
━━━━━━━━━━━━━━━━━━━━

PNG 不能作为 Flutter background image。

必须真实拆组件：

Layout
Card
Button
Tab
Chart
Room item
Mochi visual layer

支持：

Safe Area
Dynamic Type
VoiceOver
TalkBack
Reduced Motion

重点：

页面简洁。

不因为“设计看起来有内容”就增加无必要按钮。

━━━━━━━━━━━━━━━━━━━━
J. 自动测试
━━━━━━━━━━━━━━━━━━━━

必须增加或更新测试：

1.
Bottom nav exactly 3 items.

2.
Focus active / pause / recovery / early-end:
no main bottom nav.

3.
Records:
Today / History / Calendar / Reports
same route/state family.

4.
Reports:
Week / Month / Year
tab switch.

5.
Growth:
Mochi / Room / Dress / Collection
same route/state family.

6.
Room inventory:
not a main navigation destination.

7.
Reward:
no fake claim button.

8.
sample values:
not business constants.

9.
All previous Phase 1–4 tests:
still PASS.

━━━━━━━━━━━━━━━━━━━━
K. 最终执行
━━━━━━━━━━━━━━━━━━━━

真实执行：

dart format .

dart format --output=none --set-exit-if-changed .

flutter analyze

flutter test

flutter build apk --debug

如果 Computer Control 不可用：

代码级 / Widget / Integration / Build 继续完成。

人工视觉项写：

`outputs/V4_1_MANUAL_VISUAL_BACKLOG.md`

禁止假 PASS。

━━━━━━━━━━━━━━━━━━━━
L. 输出
━━━━━━━━━━━━━━━━━━━━

创建：

`outputs/V4_1_UI_RECONCILIATION_REPORT.md`

记录：

- pages changed
- routes changed
- Domain files touched
- test count
- analyze
- APK
- screenshots NOT_RUN / PASS
- remaining manual items

如果修改了保护区 Domain/Data：

必须逐条解释理由。

━━━━━━━━━━━━━━━━━━━━
M. Commit
━━━━━━━━━━━━━━━━━━━━

建议：

chore(v4.1): migrate app shell to simplified three-tab IA

fix(v4.1-ui): reconcile phase 2-4 presentation with final designs

完成并 push main 后：

STOP。

禁止自动开始 Phase 5。
