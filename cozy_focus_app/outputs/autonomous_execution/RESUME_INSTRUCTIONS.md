# RESUME_INSTRUCTIONS — one entry point

## What to do

1. `cd /c/Users/zyu33/Documents/Codex/2026-09-07/new-chat/cozy_focus_app`
2. Read `outputs/autonomous_execution/CHECKPOINT.md` and `MASTER_STATE.json`.
3. Re-verify the git state — do **not** trust the recorded HEAD:

   ```
   git rev-parse --abbrev-ref HEAD; git rev-parse HEAD
   git rev-parse origin/recovery/v4.2.1-rebuild; git status --short
   ```

   If HEAD differs from `MASTER_STATE.git.head`, the last window did more than it
   recorded: read `git log --oneline` since that SHA and update the state before
   continuing. Never reset to a recorded SHA.
4. Take the first `IN_PROGRESS` task in `TASK_QUEUE.json`; if none, the first
   `PENDING` one whose dependencies are met.
5. Work the loop: LOAD STATE → SELECT → EXECUTE → VERIFY → FIX → REVERIFY →
   COMMIT → UPDATE CHECKPOINT → SELECT NEXT.
6. Update `MASTER_STATE.json` and `TASK_QUEUE.json` **after each work unit**, not
   at the end of the window.

## What this environment can and cannot do about continuing

**Can:** Zcode provides persistent automation that outlives a session — a recurring
workspace schedule (`CronCreate`) and an idle-time queue (`OffPeakCreate`). Both
survive app restarts and re-enter this project with a complete instruction rather
than a nudge, so work resumes without the owner re-describing it. A recurring
schedule is registered for this project; see `MASTER_STATE.json` → `continuation`.

**Cannot:** nothing here extends a single conversation's context. When the budget
runs low, the honest move is what the brief asks: finish the smallest atomic task,
run its test, save the result, update the state files, commit, and record the next
step — then let the schedule pick it up.

## The stop condition

Do not stop because an hour passed, a batch finished, tests passed, or an APK was
built. The program is complete only when all sixteen pages have been compared,
every fixable visual difference is fixed, the golden flows pass, the timing and
database consistency checks pass, the companion matches its business state, the
full suite is green, the debug APK builds, no fixable P0/P1 is open, and the state
files match the real HEAD. Then output `ENGINEERING_COMPLETE` — and never
`OWNER_VISUAL_APPROVED` or `STORE_RELEASE_READY` without the owner.
