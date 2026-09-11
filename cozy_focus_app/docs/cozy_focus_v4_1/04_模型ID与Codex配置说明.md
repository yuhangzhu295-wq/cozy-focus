# 04 模型 ID 与 Codex 配置

推荐：

Root:
Claude Sonnet 4.6

Child writer:
gemini_implementer

当前 Gemini model ID：
`11/gemini-3.8-flash-high`

来自你当前 Codex UI 的模型标识。

如果以后 ID 变化：
只编辑：

`.codex/agents/gemini_implementer.toml`

中的：
`model = "..."`

Claude 默认不作为 spawned child，因为 Claude 就是 root。
这样可以减少一层 subagent context/token。
