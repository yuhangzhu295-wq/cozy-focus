# Cozy Focus V4.1 Visual Polish — Required Agent Workflow

## Active execution contract

MAIN REVIEW MODEL: 11/gpt-5.6-sol
IMPLEMENTATION SUBAGENT: 11/gemini-3.8-flash-high
SPAWN: multi_agent_v1__spawn_agent with an explicit model string

The .codex/agents/gemini_implementer.toml file is LEGACY / NOT ACTIVE for
runtime by-name loading. It may remain as historical metadata.

## Ownership

PRIMARY / ROOT: 11/gpt-5.6-sol
- orchestrator
- bounded pre-review
- architecture owner
- post-implementation diff reviewer
- final gate
- MUST NOT edit application source

WRITE CHILD: gemini_implementer
- implementation
- tests
- review fixes
- build/format fixes
- MUST NOT approve itself

## One writer only

At most one spawned child thread is allowed.
Never run two write-capable agents in parallel.
Claude must not edit source while Gemini owns implementation.

## Monotonic stage state machine

NOT_STARTED
→ CLAUDE_PLAN_READY
→ GEMINI_IMPLEMENTING
→ GEMINI_IMPLEMENTED
→ WAITING_CLAUDE_REVIEW

Pass:
WAITING_CLAUDE_REVIEW
→ APPROVED_FOR_FINAL_GATE
→ APPROVED
→ STOP

Fail:
WAITING_CLAUDE_REVIEW
→ CHANGES_REQUIRED
→ GEMINI_FIXING
→ GEMINI_FIXED
→ WAITING_CLAUDE_REVIEW

Maximum repair rounds = 2.

After repair round 2, if any P0/P1 remains:
→ BLOCKED
→ STOP

Never return to NOT_STARTED / CLAUDE_PLAN_READY for the same stage.

## Required review timing

1. BEFORE coding: Claude creates a bounded implementation contract.
2. AFTER Gemini first implementation: Claude reviews actual diff only.
3. AFTER each Gemini fix: Claude reviews only open findings + repair diff.
4. FINAL GATE: Claude verifies P0/P1 = 0 and real validation evidence.

## Read budgets

Claude pre-review: max 12 read-only operations.
Claude diff review: max 10.
Gemini first implementation: first edit before read-only op 10.
Gemini review fix: first repair edit before read-only op 6.

## Duplicate-read prohibition

Without an intervening edit:
- same source file: max 2 reads
- same image: max 1 open
- same directory listing: max 1
- same git status/diff command: max 1

## Context compaction recovery

After compaction read ONLY:
1. outputs/ai_handoff/CURRENT_STAGE.json
2. git status --short
3. git diff --stat OR git log -3 --oneline, according to state

Then resume from CURRENT_STAGE.status.

Do NOT re-read all designs/docs or restart audit.

## One Goal = one Stage

When a stage becomes APPROVED or BLOCKED:
STOP the Goal.

Start the next stage in a fresh Goal/thread.
