# 05 每个 Stage 的实际操作

第一次：
1. 配好 `.codex/` + `AGENTS.md`
2. 新开 Goal
3. Root 选 Claude Sonnet 4.6
4. 粘贴 `workflow/运行当前Stage_给Claude主线程.txt`

之后 Claude 会按固定顺序：
PRE-REVIEW
→ Gemini implement
→ Claude review
→ Gemini fix（如果需要）
→ Claude review
→ 最多第二次 fix
→ Final Gate

看到 APPROVED：
停止当前 Goal，下一 Stage 新开 Goal。

看到 BLOCKED：
不要输入“继续”。
先处理 blocker。

这是为了防止继续烧 token。
