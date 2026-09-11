# Cozy Focus V4.1 Visual Polish — Subagent Final FULL

这是当前推荐交给 Codex 的 V4.1 Visual Polish 包。

## 新执行架构

Claude Sonnet 4.6 = 主线程 / 主审查 / Final Gate  
Gemini 3.8 Flash High = 子代理 / 编码 / 修复

不是两个模型互相反复分析。

固定流程：

Claude PRE-REVIEW
→ Gemini 编码
→ Claude DIFF REVIEW
→ 如不通过，Gemini 只修 findings
→ Claude 再审
→ 最多两轮修复
→ Final Gate
→ APPROVED 或 BLOCKED
→ STOP

## 为什么这样改

旧长 Goal 已出现：
- 6 小时反复读取
- 2 亿级 token
- context compaction 后重新审计
- 没有真实代码 diff

V4.1 Subagent Final 强制：
- 一个 Goal 只跑一个 Stage
- 一个时间只有一个代码写手
- Gemini 10 次只读内必须开始写
- Claude 只审 bounded scope / actual diff
- 最多两轮自动返修
- 第 2 轮仍有 P0/P1 就 BLOCKED 停止
- context compaction 只从 CURRENT_STAGE.json 恢复

## 安装

将整个方案包放：
`docs/cozy_focus_v4_1/`

将包中的：
`.codex/`
`AGENTS.md`

复制到 Git 仓库根目录。

然后新开 Codex Goal，主模型选：
**Claude Sonnet 4.6**

粘贴：
`workflow/运行当前Stage_给Claude主线程.txt`

## Visual Source of Truth

`designs/pages/`  
或编码兼容备用：
`designs/pages_ascii/`

只选一套，不要两套都读。

Motion:
`designs/motion/`

## Gemini model ID

包内当前使用：
`11/gemini-3.8-flash-high`

若你 Codex 模型选择器显示不同的精确 ID，只修改：
`.codex/agents/gemini_implementer.toml`
中的 `model = ...`。

## 当前远程基线

`e7df460193ea799b2e0c0eba0b7010c120671834`

## 开发阶段拆分

- V4.1-S1 AppShell + Home
- V4.1-S2A Focus Setup/Active/Pause/Recovery/Early-End
- V4.1-S2B Complete/Note/Reward
- V4.1-S3A Records core
- V4.1-S3B Reports + Wrapped
- V4.1-S4 Room/Craft reconciliation

S4 APPROVED 后先停，检查 GitHub，再进入 Phase 5。
