# MASTER_IMPLEMENTATION_INDEX.md
# Cozy Focus — 完整规格包 → 实现映射索引

> Generated: 2026-09-08 | 基于 CozyFocus_Complete_Development_Pack_V2_20260907

---

## 读取顺序（每次开始新 Phase 前必须重新确认）

```
execution_order.json
  → reference/00_GitHub复用调研.md
  → implementation/01_schema_draft.sql
  → implementation/02_domain_interfaces.dart
  → outputs/ARCHITECTURE_DECISION.md（等效 reference/01）
  → outputs/PET_ANIMATION_ARCHITECTURE.md（等效 reference/02）
  → 对应 designs/*.png
  → 对应 prompts/*.md
  → qa/（当文件创建后）
```

---

## Phase 0 — 仓库审计与架构冻结 ✅ COMPLETE

| 项目 | 文件 | 状态 |
|------|------|------|
| 复用矩阵 | outputs/REUSE_MATRIX.md | ✅ |
| 架构决策 | outputs/ARCHITECTURE_DECISION.md | ✅ |
| 状态机 | outputs/FOCUS_SESSION_STATE_MACHINE.md | ✅ |
| 数据模型 | outputs/DATA_MODEL.md | ✅ |
| 宠物动画架构 | outputs/PET_ANIMATION_ARCHITECTURE.md | ✅ |
| 实现计划 | outputs/IMPLEMENTATION_PLAN.md | ✅（已修正） |
| 架构护栏 | outputs/ARCHITECTURE_GUARDRAILS.md | ✅ |
| Spec 对齐 | outputs/SPEC_RECONCILIATION.md | ✅ |
| 主索引 | outputs/MASTER_IMPLEMENTATION_INDEX.md | ✅ (本文件) |

**待创建（Phase 1 前）**：
- `docs/reference_01_技术架构契约.md`（等效内容已在 ARCHITECTURE_DECISION.md）
- `docs/reference_02_动态资产契约.md`（等效内容已在 PET_ANIMATION_ARCHITECTURE.md）
- `docs/qa_00_全流程验收矩阵.md`（需要基于规格包精神创建）

---

## Phase 1 — Domain + Data Layer

| 项目 | Design | Prompt | Reference | Implementation | 预期代码位置 | QA Gate |
|------|--------|--------|-----------|----------------|------------|---------|
| FocusSession Model | — | 00_总控 | ARCHITECTURE_DECISION.md §4 | 01_schema_draft.sql + DATA_MODEL.md §1 | lib/domain/models/focus_session.dart | Gate 1: 创建session可写入 |
| FocusRecord Model | — | 00_总控 | ARCHITECTURE_DECISION.md §4 | DATA_MODEL.md §2 | lib/domain/models/focus_record.dart | Gate 1: session→record 转换 |
| FocusCategory Model | — | — | DATA_MODEL.md §3 | schema | lib/domain/models/focus_category.dart | — |
| CraftJob/Recipe/Inventory/Room | — | — | DATA_MODEL.md §4-7 | 01_schema_draft.sql | lib/domain/models/craft*.dart | Gate 4 |
| Pet/PetProgress/PetMemory | — | — | DATA_MODEL.md §8-10 | schema | lib/domain/models/pet*.dart | Gate 5 |
| Achievement/SyncOutbox/RewardLedger | — | — | DATA_MODEL.md §11-13 | schema | lib/domain/models/ | Gate 1/4/5 |
| Drift Database | — | — | ARCHITECTURE_DECISION.md §6 | 01_schema_draft.sql | lib/data/local/database/ | Gate 1: flutter test DAOs |
| FocusClock | — | — | 02_domain_interfaces.dart | FOCUS_SESSION_STATE_MACHINE.md | lib/core/clock/focus_clock.dart | Gate 1: elapsed 从时间戳恢复 |
| FocusSessionEngine | — | 00_总控 | FOCUS_SESSION_STATE_MACHINE.md | ARCHITECTURE_DECISION.md §4 | lib/domain/services/focus_session_engine.dart | Gate 1: 状态机完整测试 |
| RewardService (幂等) | — | 04B_奖励页面 | DATA_MODEL.md §13 | reward_ledger PK | lib/domain/services/reward_service.dart | Gate 1: 重复 settle 被拒绝 |
| StatisticsEngine | — | 05-08 prompts | ARCHITECTURE_DECISION.md §4 | — | lib/domain/services/statistics_engine.dart | Gate 3 |
| Repositories (abstract) | — | — | ARCHITECTURE_DECISION.md §2 | 02_domain_interfaces.dart | lib/domain/repositories/ | Gate 1 |
| Repositories (impl, Drift) | — | — | ARCHITECTURE_DECISION.md §6 | — | lib/data/repositories/ | Gate 1 |
| SyncEngine (outbox) | — | 15_离线_同步 | ARCHITECTURE_DECISION.md §4 | — | lib/services/sync_engine.dart | Gate 7 |

**执行依据**：execution_order.json phase=1

---

## Phase 2 — P0 Focus 核心闭环

工程顺序：`02 → 03 → 03A → 03B → 03C → 04 → 04A → 04B → 01`

| 编号 | 设计图 | Prompt | Reference | 预期代码 | QA Gate |
|------|--------|--------|-----------|---------|---------|
| 02 | designs/02_开始专注_任务设置.png | prompts/02_开始专注_任务设置_Codex强提示词.md | ARCHITECTURE_DECISION.md §3 | lib/presentation/pages/focus_setup/ | Gate 2: 创建 FocusSession |
| 03 | designs/03_专注中.png ⚠️**文件缺失** | prompts/03_专注中_Codex强提示词.md | FOCUS_SESSION_STATE_MACHINE.md | lib/presentation/pages/focus_active/ | Gate 2: 计时器真实，后台可恢复 |
| 03A | designs/03A_暂停状态.png ⚠️**文件名需确认** | prompts/03A_暂停状态_Codex强提示词.md | FOCUS_SESSION_STATE_MACHINE.md §pause | lib/presentation/pages/focus_active/ | Gate 2: pause/resume 正确 |
| 03B | designs/03B_后台_锁屏恢复.png | prompts/03B_后台_锁屏恢复_Codex强提示词.md | FOCUS_SESSION_STATE_MACHINE.md §restored | lib/services/app_lifecycle_service.dart | Gate 2: process death 可恢复 |
| 03C | designs/03C_提前结束确认.png | prompts/03C_提前结束确认_Codex强提示词.md | FOCUS_SESSION_STATE_MACHINE.md §cancelled | lib/presentation/pages/focus_active/ | Gate 2: 取消不产生无效 record |
| 04 | designs/04_专注完成.png | prompts/04_专注完成_Codex强提示词.md | ARCHITECTURE_DECISION.md §4 | lib/presentation/pages/focus_complete/ | Gate 2: completed 状态正确 |
| 04A | designs/04A_保存专注记录.png | prompts/04A_保存专注记录_Codex强提示词.md | DATA_MODEL.md §2 | lib/presentation/pages/focus_complete/ | Gate 2: FocusRecord 写入 DB |
| 04B | designs/04B_奖励页面.png | prompts/04B_奖励页面_Codex强提示词.md | DATA_MODEL.md §13 RewardLedger | lib/presentation/pages/focus_complete/ | Gate 2: 奖励幂等，重复点击安全 |
| 01 | designs/01_首页_宠物房间.png | prompts/01_首页_宠物房间_Codex强提示词.md | ARCHITECTURE_DECISION.md §4 | lib/presentation/pages/home/ | Gate 2: 保存后首页数据刷新 |

**执行依据**：execution_order.json phase=2

---

## Phase 3 — 记录与统计

工程顺序：`05A → 05B → 05C → 05D → 05 → 06 → 07 → 08 → 08A`

| 编号 | 设计图 | Prompt | 预期代码 | QA Gate |
|------|--------|--------|---------|---------|
| 05A | designs/05A_今日记录.png | prompts/05A_今日记录_Codex强提示词.md | lib/presentation/pages/progress/ | Gate 3: 新 session 立即可见 |
| 05B | designs/05B_历史记录.png | prompts/05B_历史记录_Codex强提示词.md | lib/presentation/pages/progress/ | Gate 3: 历史筛选/分页正确 |
| 05C | designs/05C_记录详情.png | prompts/05C_记录详情_Codex强提示词.md | lib/presentation/pages/progress/ | Gate 3: 编辑 note/category/mood 刷新 |
| 05D | designs/05D_日历视图.png | prompts/05D_日历视图_Codex强提示词.md | lib/presentation/pages/progress/ | Gate 3: 日历热度真实 |
| 05 | designs/05_Progress总览.png | prompts/05_Progress_总览_Codex强提示词.md | lib/presentation/pages/progress/ | Gate 3: 总览聚合正确 |
| 06 | designs/06_周报.png | prompts/06_周报_Codex强提示词.md | lib/presentation/pages/reports/ | Gate 3: 周报从真实 record 聚合 |
| 07 | designs/07_月报.png | prompts/07_月报_Codex强提示词.md | lib/presentation/pages/reports/ | Gate 3: 跨月测试通过 |
| 08 | designs/08_年度报告.png | prompts/08_年度报告_Codex强提示词.md | lib/presentation/pages/reports/ | Gate 3: 年度报告，heatmap 真实 |
| 08A | designs/08A_年度 Wrapped_分享.png | prompts/08A_年度_Wrapped_分享_Codex强提示词.md | lib/presentation/pages/reports/ | Gate 3: 分享卡片从真实数据生成 |

---

## Phase 4 — Craft / Inventory / Room

工程顺序：`09A → 09B → 09C → 09`

| 编号 | 设计图 | Prompt | 预期代码 | QA Gate |
|------|--------|--------|---------|---------|
| 09A | designs/09A_家具制作列表.png | prompts/09A_家具制作列表_Codex强提示词.md | lib/presentation/pages/craft/ | Gate 4: recipe 列表真实 |
| 09B | designs/09B_制作详情.png | prompts/09B_制作详情_Codex强提示词.md | lib/presentation/pages/craft/ | Gate 4: progress 从专注分钟推进 |
| 09C | designs/09C_Inventory 库存.png | prompts/09C_Inventory_库存_Codex强提示词.md | lib/presentation/pages/craft/ | Gate 4: inventory 数量真实 |
| 09 | designs/09_房间装修.png | prompts/09_房间装修_Codex强提示词.md | lib/presentation/pages/craft/ | Gate 4: 布局持久化，重启不丢 |

---

## Phase 5 — Pet Progression

工程顺序：`10 → 10A → 10B`

| 编号 | 设计图 | Prompt | 预期代码 | QA Gate |
|------|--------|--------|---------|---------|
| 10 | designs/10_宠物成长.png | prompts/10_宠物成长_Codex强提示词.md | lib/presentation/pages/pet/ | Gate 5: XP/Bond 从 ledger 计算 |
| 10A | designs/10A_宠物装扮.png | prompts/10A_宠物装扮_Codex强提示词.md | lib/presentation/pages/pet/ | Gate 5: 装扮来自 inventory |
| 10B | designs/10B_收藏图鉴.png | prompts/10B_收藏图鉴_Codex强提示词.md | lib/presentation/pages/pet/ | Gate 5: locked/unlocked 真实 |

---

## Phase 6 — Pet Animation Engine

工程顺序：`11（engine） → 11A → 11C → 11B → 11E → 11F → 11H → 11I → 11G → 11J → 11K → 11D`

**第一步：先建 Engine，再接动作**

| 步骤 | 文件 | Prompt | Reference | 预期代码 |
|------|------|--------|-----------|---------|
| Engine 总规范 | designs/11_宠物动效总规范.png | prompts/11_宠物动态总规范_Codex强提示词.md | PET_ANIMATION_ARCHITECTURE.md | lib/animation/ |
| 11A Idle Breathe | motion_storyboards/11A_Idle_Breathe.png | prompts/11A_Idle_Breathe_Codex强提示词.md | PET_ANIMATION_ARCHITECTURE.md §overlay | lib/animation/adapters/ |
| 11C Blink | motion_storyboards/11C_Blink.png | prompts/11C_Blink_Codex强提示词.md | — | lib/animation/adapters/ |
| 11B Idle Sway | motion_storyboards/11B_Idle_Sway.png | prompts/11B_Idle_Sway_Codex强提示词.md | — | lib/animation/adapters/ |
| 11E Tail Wag | motion_storyboards/11E_Tail_Wag.png | prompts/11E_Tail_Wag_Codex强提示词.md | — | lib/animation/adapters/ |
| 11F Focus Work | motion_storyboards/11F_Focus_Work.png | prompts/11F_Focus_Work_Codex强提示词.md | — | lib/animation/adapters/ |
| 11H Pause | motion_storyboards/11H_Pause.png | prompts/11H_Pause_Codex强提示词.md | — | lib/animation/adapters/ |
| 11I Celebrate | motion_storyboards/11I_Celebrate.png | prompts/11I_Celebrate_Codex强提示词.md | — | lib/animation/adapters/ |
| 11G Craft | motion_storyboards/11G_Craft.png | prompts/11G_Craft_Codex强提示词.md | — | lib/animation/adapters/ |
| 11J Sleep | motion_storyboards/11J_Sleep.png | prompts/11J_Sleep_Codex强提示词.md | — | lib/animation/adapters/ |
| 11K Greeting | motion_storyboards/11K_Greeting.png | prompts/11K_Greeting_Codex强提示词.md | — | lib/animation/adapters/ |
| 11D Ear Twitch | motion_storyboards/11D_Ear_Twitch.png | prompts/11D_Ear_Twitch_Codex强提示词.md | — | lib/animation/adapters/ |

**Gate 6**：
- 页面只能 set PetVisualState，不能直接控制 Rive input
- Reduced Motion 生效
- 无 .riv 时 FallbackPetAdapter 正常工作
- background 暂停渲染，resume 恢复正确状态

---

## Phase 7 — 系统完整性

工程顺序：`12 → 13 → 14 → 15`

| 编号 | 设计图 | Prompt | 预期代码 | QA Gate |
|------|--------|--------|---------|---------|
| 12 | designs/12_Profile_Settings.png | prompts/12_Profile_Settings_Codex强提示词.md | lib/presentation/pages/settings/ | Gate 7: 设置真实生效 |
| 13 | designs/13_通知_锁屏.png | prompts/13_通知_锁屏_Codex强提示词.md | lib/services/notification_service.dart | Gate 7: 点击通知回到 session |
| 14 | designs/14_空数据状态.png ⚠️**需确认是否存在** | prompts/14_空数据状态_Codex强提示词.md | — | Gate 7: 空态真实，无 fake data |
| 15 | designs/15_离线_同步状态.png ⚠️**需确认是否存在** | prompts/15_离线_同步状态_Codex强提示词.md | ARCHITECTURE_DECISION.md §6 | Gate 7: 飞行模式可用，重连幂等同步 |

---

## Phase 8 — 全量 QA

| 项目 | 文件 | 状态 |
|------|------|------|
| QA 矩阵 | docs/qa_00_全流程验收矩阵.md（需要创建） | ⚠️ 待创建 |
| 格式化 | dart format . | 必须运行 |
| 静态分析 | flutter analyze | 必须运行 |
| 单元测试 | flutter test | 必须运行 |
| 集成测试 | flutter test integration_test | 必须运行 |
| iOS 模拟器 | 关键闭环截图比对 | 必须运行 |
| Android 模拟器 | 关键闭环截图比对 | 必须运行 |

---

## 关键约束总结（面向后续所有 Agent/Model）

1. **Mochi 是狗**：`species = PetSpecies.dog`，`characterId = 'mochi'`
2. **计时器**：`elapsed = endAt - startAt - sum(pauseIntervals)`，禁止 `Timer.periodic` 累加
3. **统计**：永远从 FocusRecord 聚合，禁止写死数据
4. **奖励**：`reward_ledger.session_id` 为 PK，幂等防重复
5. **UI 数据流**：UI → Controller → UseCase → Repository → DB，不允许跳层
6. **动画**：只能 set PetVisualState，不能在页面散落控制 Rive
7. **测试**：未运行必须明确写"未运行"，禁止假 PASS
8. **设计图**：视觉基准，禁止整张贴成背景
