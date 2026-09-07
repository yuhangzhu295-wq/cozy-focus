# SPEC_RECONCILIATION.md
# Cozy Focus — Phase 0.5: Spec ↔ Repository Reconciliation

> Generated: 2026-09-08 | Primary Spec: CozyFocus_Complete_Development_Pack_V2_20260907

---

## 事实源优先级（永久生效）

1. 根目录使用说明 + execution_order.json
2. reference/
3. implementation/
4. qa/
5. designs/
6. prompts/
7. GitHub current implementation
8. outputs/ (AI 生成派生文档，不能覆盖原始规格)

---

## 关键发现：规格包实际内容

经完整扫描，`CozyFocus_Complete_Development_Pack_V2_20260907` 实际文件如下：

### 根目录 ✅
- README.md ✅
- 00_使用方法_必读.md ✅
- 01_文件用途与对应关系.md ✅
- 02_Codex执行优先级与阶段计划.md ✅
- 03_逐文件投喂与执行模板.md ✅
- execution_order.json ✅
- **04_完成定义与验收方法.md** ⚠️ 文件名在列表中但实际内容未能确认（PowerShell 中文件名乱码）

### reference/
- 00_GitHub复用调研.md ✅（内容已读）
- **01_技术架构契约.md** ❌ 不存在于本地规格包
- **02_动态资产契约.md** ❌ 不存在于本地规格包

### implementation/ ✅
- 01_schema_draft.sql ✅（内容已读）
- 02_domain_interfaces.dart ✅（内容已读）

### qa/
- **00_全流程验收矩阵.md** ❌ qa/ 目录完全为空

### designs/ ✅ 30 个文件已确认
- 00B, 00C, 01, 02, 03B, 03C, 04, 04A, 04B
- 05, 05A, 05B, 05C, 05D, 06, 07, 08, 08A
- 09, 09A, 09B, 09C, 10, 10A, 10B
- 12, 13
- manifest.json
- motion_storyboards/ (11A–11K 共 11 个) ✅

### prompts/ ✅ 40 个文件
- 00_总控强提示词_Codex_V2.md ✅（内容已读）
- 01–15 对应页面 prompt 全部存在 ✅
- 11A–11K 动作 prompt 全部存在 ✅

---

## ⚠️ 注意：03_专注中.png 不在 designs/ 中

扫描到的 designs/ 文件中没有 03_专注中.png（有 03B 和 03C，没有 03）。
这是一个真实的设计图缺口，后续 Phase 2 实现页面 03 时需要注意。

---

## Phase 0 Outputs vs 规格包 逐项差异表

| 项目 | 原始规格包 | Phase 0 outputs | 状态 | 最终采用 |
|------|-----------|----------------|------|---------|
| **技术架构：层级结构** | 总控 prompt + 01_文件用途 定义 UI→Controller→UseCase→Repository→DB | ARCHITECTURE_DECISION.md 完整定义了相同层级 | MATCH | 规格包 + outputs 一致 |
| **状态管理** | 规格包未明确指定（只说 Riverpod 是推荐方向之一） | ARCHITECTURE_DECISION.md 明确选 Riverpod | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 Riverpod，已与规格包精神一致 |
| **本地数据库** | 规格包指定 Drift（implementation/01_schema_draft.sql 即 Drift 草案） | ARCHITECTURE_DECISION.md 选 Drift | MATCH | Drift |
| **Schema：focus_sessions** | 规格包 schema 有 paused_seconds，无 pause_intervals JSONB | DATA_MODEL.md 增加了 pause_intervals JSONB | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 DATA_MODEL.md 版本，更完整 |
| **Schema：craft_jobs** | 规格包有基础字段，无 updated_at/sync_state | DATA_MODEL.md 添加了 updated_at/sync_state | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 DATA_MODEL.md |
| **Schema：inventory_items** | 规格包基础字段 | DATA_MODEL.md 一致，添加 updated_at | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 DATA_MODEL.md |
| **Schema：room_items** | 规格包有基础字段 | DATA_MODEL.md 一致，添加 updated_at/sync_state | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 DATA_MODEL.md |
| **Schema：reward_ledger** | 规格包定义 session_id PK（幂等） | DATA_MODEL.md MATCH | MATCH | 一致 |
| **Domain Interfaces** | 02_domain_interfaces.dart 定义 PetAnimationEngine + FocusClock | ARCHITECTURE_DECISION.md 扩展了完整 engine 定义 | OUTPUT_IMPROVEMENT_ACCEPTED | 以规格包接口为基础，采用 outputs 扩展 |
| **FocusSession 状态机** | execution_order.json + 总控 prompt 定义：idle→running→paused→completed/cancelled→saved | FOCUS_SESSION_STATE_MACHINE.md 添加 finishing/restored 状态 | OUTPUT_IMPROVEMENT_ACCEPTED | 采用扩展版，更完整 |
| **计时器事实源** | 规格包明确禁止 Timer.periodic，使用时间戳 | FOCUS_SESSION_STATE_MACHINE.md MATCH | MATCH | 时间戳方案 |
| **Supabase 同步** | 规格包指定 Supabase + Outbox 模式 | ARCHITECTURE_DECISION.md MATCH | MATCH | 一致 |
| **Pet 物种 / 角色** | 设计图中 Mochi 是狗（dog），规格包未明确标注 species | Phase 0 outputs 错误写为 "Mochi cat" | **SPEC_WINS** | **修正：species='dog'，characterId='mochi'，domain 保持通用 Pet** |
| **Pet 动画架构** | domain_interfaces.dart 定义 PetAnimationEngine + PetVisualState | PET_ANIMATION_ARCHITECTURE.md MATCH | MATCH | 一致 |
| **Pet FallbackPetAdapter** | 规格包要求无 .riv 时 fallback + 禁止伪造 | PET_ANIMATION_ARCHITECTURE.md MATCH | MATCH | 一致 |
| **FocusRecord** | 规格包 schema 草案基础版 | DATA_MODEL.md 完整定义 | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 DATA_MODEL.md |
| **Statistics** | 规格包明确：从真实 FocusRecord 聚合，禁止写死 | ARCHITECTURE_DECISION.md / IMPLEMENTATION_PLAN.md MATCH | MATCH | 一致 |
| **Craft/Inventory/Room** | 规格包 schema 草案 + prompts 详细说明 | DATA_MODEL.md 扩展完整 | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 DATA_MODEL.md |
| **RewardLedger 幂等** | 规格包明确：session_id 为 PK，幂等防止重复 | DATA_MODEL.md MATCH | MATCH | 一致 |
| **Achievement** | 规格包 prompts 提到，schema 未出现 | DATA_MODEL.md 定义了 Achievement 表 | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 DATA_MODEL.md |
| **PetMemory** | 规格包 prompts 提到，schema 未出现 | DATA_MODEL.md 定义了 PetMemory 表 | OUTPUT_IMPROVEMENT_ACCEPTED | 采用 DATA_MODEL.md |
| **QA 验收矩阵** | qa/00_全流程验收矩阵.md ❌ 文件不存在 | IMPLEMENTATION_PLAN.md 错误地说"文件缺失，必须创建" | **SPEC_WINS（文件确实不存在，需要创建）** | Phase 1 前必须创建 qa/00_全流程验收矩阵.md |
| **reference/01_技术架构契约.md** | ❌ 文件不存在 | IMPLEMENTATION_PLAN.md 正确识别为缺失 | MATCH（缺失判断正确） | ARCHITECTURE_DECISION.md 作为等效替代，Phase 1 前补充创建 |
| **reference/02_动态资产契约.md** | ❌ 文件不存在 | IMPLEMENTATION_PLAN.md 正确识别为缺失 | MATCH（缺失判断正确） | PET_ANIMATION_ARCHITECTURE.md 作为等效替代，Phase 1 前补充创建 |
| **页面顺序** | execution_order.json + 02_Codex执行优先级.md 明确定义 | IMPLEMENTATION_PLAN.md MATCH | MATCH | 一致 |
| **动画顺序（11A-11K）** | 02_Codex执行优先级.md 推荐: 11A→11C→11B→11E→11F→11H→11I→11G→11J→11K→11D | PET_ANIMATION_ARCHITECTURE.md 一致 | MATCH | 一致 |
| **离线优先** | 规格包明确：离线可完成核心流程 | ARCHITECTURE_DECISION.md MATCH | MATCH | 一致 |
| **Flame** | 规格包 reference/00 说"MVP 不强制" | REUSE_MATRIX.md REJECT（MVP）MATCH | MATCH | MVP 不引入 |
| **i18n/Accessibility** | 规格包总控 prompt 明确要求 | ARCHITECTURE_GUARDRAILS.md 包含 | MATCH | 一致 |

---

## 必须修正的错误

### 错误 1：Mochi 物种
- **原始错误**：outputs/ 多处写"Mochi cat"
- **正确事实**：设计图中 Mochi 是狗（dog）
- **修正**：所有后续代码中 `species = PetSpecies.dog`，`characterId = 'mochi'`
- **Domain 保持通用**：`Pet`、`PetRepository`，不允许写 `CatRepository`

### 错误 2：IMPLEMENTATION_PLAN.md "Missing Files" 判断
- **qa/00_全流程验收矩阵.md**：确实不存在，IMPLEMENTATION_PLAN.md 判断正确
- **reference/01_技术架构契约.md**：确实不存在，IMPLEMENTATION_PLAN.md 判断正确
- **reference/02_动态资产契约.md**：确实不存在，IMPLEMENTATION_PLAN.md 判断正确
- **结论**：IMPLEMENTATION_PLAN.md 的 Missing Files 部分判断**全部正确**，但措辞需调整为"文件不在规格包中，需要创建为正式文档"而非"必须由 AI 生成"

### 错误 3：03_专注中.png 缺失
- designs/ 中不存在 03_专注中.png（只有 03B 和 03C）
- Phase 2 实现页面 03 时需要向用户确认或从 03B/03C 推断

---

## 结论：Phase 0 outputs 整体质量

- 架构设计与规格包精神**高度一致**
- 主要问题是 Mochi 物种错误（cat → dog）
- "Missing Files" 判断实际上**是正确的**（这些文件确实不在规格包里）
- DATA_MODEL.md 对 schema 草案做了有价值的完善，全部 ACCEPTED
