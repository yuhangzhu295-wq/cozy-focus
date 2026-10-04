# P27 — Final RC Gate

Feature freeze. Nothing new was built; this phase ran the gates, had the work
reviewed, and reported the result without improving it.

---

## 1. The automated gate

`tools/cozy_gate.py --full` — one command, 18 gates, producing
`AUTOMATED_PRODUCT_GATE.json` and `.md`.

It **shells out to the command that already exists** for each gate —
`flutter test`, `flutter analyze`, `flutter build`, `git diff --check` — and
records what that command said. No gate re-implements a check, because a second
implementation would be a second source of truth and the two would drift.

### Five statuses

`PASS` ran and succeeded · `FAIL` ran and did not · `BLOCKED` could not run, and
something outside engineering is why · `DEFERRED` not run by decision ·
`NOT_TESTED` exists but was not run this invocation.

**A blocked gate is reported as blocked.** `gate_report_integrity_test.dart`
proves the report cannot lie about itself: the counts must equal its own rows, no
non-`PASS` gate may lack evidence, and the three known-blocked gates must still
read `BLOCKED` — so greening one requires deliberately updating that test rather
than the report quietly changing.

### Result at `c8d8b89`

| Gate | Status | Evidence |
|---|---|---|
| `FORMAT` | **PASS** | 268 files, 0 changed |
| `ANALYZE` | **PASS** | 0 issues |
| `UNIT_TESTS` | **PASS** | 1190/1190 |
| `INTEGRATION_TESTS` | **PASS** | 20/20 |
| `GOLDEN_FLOW` | **PASS** | 6/6 |
| `MIGRATION` | **PASS** | 15/15 |
| `LIFECYCLE` | **PASS** | 46/46 |
| `ASSET_GATES` | **PASS** | 75/75 |
| `APK` | **PASS** | 29.5 MB (budget 34) |
| `AAB` | **PASS** | 48.1 MB (budget 55) |
| `DIFF_CHECK` | **PASS** | no whitespace errors |
| `RELEASE_SIGNING` | **BLOCKED** | `key.properties` absent; no keystore invented |
| `LAUNCHER_ICON` | **BLOCKED** | stock Flutter logo; no approved artwork |
| `FLOW_GENERATION` | **BLOCKED** | no video surface; Flow reports degradation |
| `OWNER_VISUAL_GATE` | **DEFERRED** | requires human judgement by construction |
| `DEVICE_MATRIX` | **DEFERRED** | done by hand each time, not by this script |
| `PRODUCT_DECISIONS` | **DEFERRED** | P25: 7 open, nothing implemented to close one |
| `BEHAVIOR_AUTHORITY` | **FAIL** | count is 2 against a gate of 1 |

```
11 PASS · 1 FAIL · 3 BLOCKED · 3 DEFERRED
```

**The one FAIL stays in the report.** Dropping it would make the report look
cleaner and mean less. It is P19's gate, open pending the P25 **D5** decision —
does tapping furniture choose the action or only the destination — and fixing it
before that answer would be fixing it the wrong way.

---

## 2. Independent review

A `code-reviewer` agent reviewed the program's additions with one instruction
worth repeating: *assume there are tests that would pass even if the production
code were broken.*

**Verdict: P0 = 0, P1 = 3, P2 = 2.**

It also **verified the program's central claim** rather than taking it on trust:
`git diff --stat 685667c..HEAD -- lib/` is empty. **No production code changed
across P19–P27** — nine commits, 2,067 lines, all tests and tools.

### All five findings were fixed

They were defects in this program's own tooling, so leaving known P1s would
contradict the point of the phase.

| # | Finding | Fix |
|---|---|---|
| P1 | `_test_gate` returned `FAIL` when a run **succeeded** but its output wording did not match the summary regex | the exit code is the authority, not the format — a Flutter SDK wording change would have turned a green run red |
| P1 | a missing `origin` branch was reported as its **git error text**, making `local_equals_remote` false for a reason unrelated to the tree | an explicit `UNAVAILABLE:` value and a `remote_ok` guard |
| P1 | the golden flow's *"companion survives a restart"* assertion re-selected the value and then asserted it was selected, over an **in-memory** store — it would have stayed green even if the file-backed store never persisted anything | it now reads back through `FileCompanionSelectionStore` over a real temp directory |
| P2 | `APP` was an absolute path pinned to one machine, so elsewhere every gate would FAIL and look like a broken product | derived from `__file__` |
| P2 | the parity coverage assertion compared an expression **against itself** and could never fail | it now compares the catalog profiles against the action manifests, which can disagree — the shape a half-registered companion takes |

The golden flow fix immediately exposed a second problem: the Windows temp-dir
cleanup failed on a held file handle and turned a **passing** test red. The
tearDown is now retry-tolerant, and the reason is stated so it cannot hide a real
failure later.

---

## 3. What the program proved, and what it did not

**Proved, with a gate that can fail:**

- the whole business chain, with cardinality that a slice test cannot see
  (one session → one record → one settlement → one reward)
- persistence across a real process death at six points, and migration from a
  real v1 database through the full chain
- that the companion animates, on a device, against a zero-noise control
- that the packs are structurally identical and no page or renderer branches on
  species
- that no periodic timer runs faster than 250 ms and frame callbacks stay bounded

**Not proved, and named as such:**

- whether the art reads well — `OWNER_VISUAL_GATE`, by construction not a
  measurement
- the device matrix as an unattended run — it exists as recorded hand evidence
- anything about a real process kill mid-transaction (WAL gives atomicity and the
  app relies on that rather than re-implementing it)

---

## 4. Gates at this revision

| | |
|---|---|
| `LOCAL_HEAD` | `c8d8b89fbaee2c31378cb2737a37587e55c0f559` |
| `REMOTE_HEAD` | `c8d8b89fbaee2c31378cb2737a37587e55c0f559` |
| `LOCAL_EQUALS_REMOTE` | **YES** |
| worktree | clean |
| production code changed | **none** |
