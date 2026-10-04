# P27 — Final RC Gate

Feature freeze. Nothing new was built; this phase ran the gates, had the work
reviewed, and reported the result without improving it.

---

## 1. The automated gate

`tools/cozy_gate.py --full` — one command, 18 gates, producing
`AUTOMATED_PRODUCT_GATE.json` and `.md`.

Each gate that **can** be re-run shells out to the command that already exists —
`flutter test`, `flutter analyze`, `flutter build`, `git diff --check` — and
records what that command said. No gate re-implements a check, because a second
implementation would be a second source of truth and the two would drift.

Six gates cannot be re-run at all: `RELEASE_SIGNING`, `LAUNCHER_ICON`,
`OWNER_VISUAL_GATE`, `DEVICE_MATRIX`, `PRODUCT_DECISIONS` and
`FLOW_GENERATION` report a **standing owner or external state**. They say so in
their own evidence, and `gate_report_integrity_test.dart` fails if one of them
claims to have measured something. (An earlier revision of this report asserted
that *every* gate shelled out. That was not true, and the note was corrected.)

### Five statuses

`PASS` ran and succeeded · `FAIL` ran and did not · `BLOCKED` could not run, and
something outside engineering is why · `DEFERRED` not run by decision ·
`NOT_TESTED` exists but was not run this invocation.

**A blocked gate is reported as blocked.** `gate_report_integrity_test.dart`
proves the report cannot lie about itself: the counts must equal its own rows, no
non-`PASS` gate may lack evidence, and the three known-blocked gates must still
read `BLOCKED` — so greening one requires deliberately updating that test rather
than the report quietly changing.

### Result at `ce484a9`

| Gate | Status | Evidence |
|---|---|---|
| `FORMAT` | **PASS** | 269 files, 0 changed |
| `ANALYZE` | **PASS** | 0 issues |
| `UNIT_TESTS` | **PASS** | 1196/1196 |
| `INTEGRATION_TESTS` | **PASS** | 20/20 |
| `GOLDEN_FLOW` | **PASS** | 6/6 |
| `MIGRATION` | **PASS** | 15/15 |
| `LIFECYCLE` | **PASS** | 52/52 |
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
| `BEHAVIOR_AUTHORITY` | **FAIL** | `COUNT=2 (measured)` on sofa, desk, bookshelf |

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

**First verdict: P0 = 0, P1 = 3, P2 = 2.** It also verified the program's central
claim rather than taking it on trust: `git diff --stat 685667c..HEAD -- lib/` is
empty — **no production code changed across P19–P27**, only tests and tools.

### The review caught me reporting a fix that had never applied

The first round's five findings were addressed, and this document originally said
all five were fixed. **That was wrong about one of them.** The golden-flow
*"companion survives a restart"* assertion was edited by a scripted replacement
that silently failed to match after the formatter rewrapped the call. The fix was
reported as applied **without being verified**, and the assertion was still
vacuous.

The re-review found it. This is the second time in this program that an
independent reviewer caught a false "fixed" claim from me, and it is the failure
mode worth carrying forward: *a claim that an edit landed is itself a claim that
needs evidence.*

| # | Finding | Fix |
|---|---|---|
| P1 | `_test_gate` returned `FAIL` when a run **succeeded** but its output wording did not match the summary regex | the exit code is the authority, not the format — a Flutter SDK wording change would have turned a green run red |
| P1 | a missing `origin` branch was reported as its **git error text**, making `local_equals_remote` false for a reason unrelated to the tree | an explicit `UNAVAILABLE:` value and a `remote_ok` guard |
| P1 | the golden flow's *"companion survives a restart"* assertion re-selected the value and then asserted it was selected | it now reads back through `FileCompanionSelectionStore` over a real temp directory, **without selecting first** — verified on disk, not asserted in prose |
| P2 | `APP` was an absolute path pinned to one machine, so elsewhere every gate would FAIL and look like a broken product | derived from `__file__` |
| P2 | the parity coverage assertion compared an expression **against itself** and could never fail | it compares the catalog profiles against the action manifests, which can disagree |
| P2 | the temp-dir tearDown abandoned the directory silently when Windows held a file handle | it warns instead, so a real failure cannot hide behind it |

---

## 3. Final gate — `NO_GO`

The `final-gate` reviewer was given the gate report and the exact revisions and
returned **`FINAL_GATE: NO_GO`**, `P0 = 0`, `P1 = 1`.

The P1 had two halves, and they need separating:

**Half one — a defect in this program's own gate, fixed here.** The reviewer
found that `gate_behavior_authority()` returned `FAIL` with a **hard-coded**
`BEHAVIOR_AUTHORITY_COUNT = 2`. It measured nothing. It could not have noticed
the day the count changed, in either direction, and the report's note claimed
every gate shelled out to a real check. A gate that recites a finding is not a
gate.

It now runs `test/architecture/behavior_authority_test.dart`, which derives the
count from the catalog:

- **authority A** — the committed `companionAction`, which
  `CompanionActivity` documents as *"the semantic companion action the sprite
  player should present"*;
- **authority B** — `interactionPoints.first`, the value `RoomPage` actually
  forwards to the avatar, which is a property of the **item**.

B is not a function of A. An item with three actions can be shown exactly one
way, so the room can commit an action it cannot display. The measurement reports
`COUNT=2` and names the three items where it bites: **sofa, desk, bookshelf**.
It carries two negative verifications — an action-derived posture must yield 1,
and a synthetic divergence must be detected — so the measurement cannot degrade
into a constant either.

**Half two — the product divergence itself, still open.** The reviewer is right
that the mismatch is real, and it is the same finding. It is **not** fixed here,
because the fix direction *is* the D5 question. Forwarding the action instead of
the item role is a behaviour change, and choosing it before the owner answers
would be choosing the wrong one of two plausible products. The gate stays `FAIL`
and says why.

`NO_GO` is therefore the honest verdict at this revision: the engineering is
green, and one product question is unanswered.

---

## 4. What the program proved, and what it did not

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

## 5. Gates at this revision

| | |
|---|---|
| `LOCAL_HEAD` | `ce484a95b07a0db36f727c0a1592fa78030f86e0` |
| `REMOTE_HEAD` | `ce484a95b07a0db36f727c0a1592fa78030f86e0` |
| `LOCAL_EQUALS_REMOTE` | **YES** |
| production code changed | **none** |
| `FINAL_GATE` | **NO_GO** — `P0 = 0`, `P1 = 1` (D5) |
