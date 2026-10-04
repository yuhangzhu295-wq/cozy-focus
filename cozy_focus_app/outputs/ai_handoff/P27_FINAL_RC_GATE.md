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

### Result at `b911caa`

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
| `PRODUCT_DECISIONS` | **DEFERRED** | P25: 6 open, none defaulted on the owner's behalf |
| `BEHAVIOR_AUTHORITY` | **PASS** | `COUNT=1 (measured)` — D5 decided, see §3 |

```
12 PASS · 0 FAIL · 3 BLOCKED · 3 DEFERRED
```

**There is no FAIL left, and that is a change worth stating plainly.** This gate
read `FAIL` from P19 until the owner answered **D5** — *does tapping furniture
choose the action, or only where the companion goes?* The answer was *the action*,
the room was made action-authoritative, and the gate now passes on a **measured**
count of 1 rather than a remembered 2. §3 records what changed and how it is
verified.

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

## 3. Final gate — `NO_GO`, and what closed it

The `final-gate` reviewer was given the gate report and the exact revisions and
returned **`FINAL_GATE: NO_GO`**, `P0 = 0`, `P1 = 1`.

That verdict was correct at the revision it was given, and both halves of the P1
have since been addressed — one because it was a defect in this program's own
tooling, the other because the owner answered the question that gated it.

**Half one — a defect in this program's own gate, fixed.** The reviewer found
that `gate_behavior_authority()` returned `FAIL` with a **hard-coded**
`BEHAVIOR_AUTHORITY_COUNT = 2`. It measured nothing. It could not have noticed
the day the count changed, in either direction, and the report's note claimed
every gate shelled out to a real check. A gate that recites a finding is not a
gate.

It now runs `test/architecture/behavior_authority_test.dart`, which drives the
**real director** with the **real catalog** for every action the furniture can
commit, and asks what the presentation actually presents.

**Half two — the product divergence, closed by the owner's D5 decision.** The
reviewer was right that the mismatch was real. The fix direction *was* the D5
question, which is why it was not guessed at. **The owner decided: tapping
furniture chooses the action.** The room is now action-authoritative:

- `room_page` passes `simulation.companionAction` to `CompanionAvatar`;
- `CompanionAvatar` puts it on `CompanionContext.macroBehavior` — a field that
  already existed and that **nothing had ever read**, which is the clearest
  evidence the wiring was the intended design;
- `CompanionBehaviorDirector` presents a committed behaviour instead of picking a
  second one from the anchor's ambient recipe, and re-picks when the action
  changes at the same anchor (坐下 and 休息 share the `seat` anchor, so the slot
  alone cannot see the change).

**The measurement is the proof, and it was attacked in both directions.** With
the fix it prints `COUNT=1` and an empty override list. Disabling the director
branch makes it print `COUNT=2` and name the eight actions it overrides
(`sofa/rest→pause_rest`, `sofa/nap→sleep`, `desk/write→focus_write`, …). Removing
the line in `room_page` fails the page-level test in `room_presence_test.dart`.
Nothing here is asserted in prose.

**One gap is carried forward honestly.** `room_sit` — the sofa and the rug — has
no sprite sequence in any pack and renders through the Mochi rig, exactly as it
did before this change. Nothing regressed, and a dedicated sustained-sit sprite
remains an art task.

### Seen on a device, and what was not

Run on the Android emulator (`GoodnightPixel7Api34`, API 34) with the debug QA
fixture, which seeds through the real repositories. Screenshots are in
`outputs/ai_handoff/android_v1_runtime/`:

| Shot | What it shows |
|---|---|
| `d5_room_two_anchors_sit.png` | rug + sofa placed; the cat is seated on the cushion and the status reads 正在坐一会儿 |
| `d5_room_craft_at_desk.png` | all five items placed; the cat is at the desk and the status reads 正在做点小东西 |
| `d5_room_craft_frame_b.png`, `d5_room_craft_frame_c.png` | the same commitment, frames apart — the craft sequence is playing, not frozen |

**What this shows:** the action name in the status bar and the pose the avatar
draws agree. That is the D5 property, observed rather than inferred.

**What it does not show, stated plainly.** The furniture *use panel* — where the
player picks 坐下 / 休息 / 打个盹 — did not open under adb-synthesised input, on
any of the five items. The panel is not at fault: `p21_sofa_panel.png`, captured
earlier with a real touch, shows it working and listing all three actions. The
likely cause is that `input tap` reaches Flutter as a pan, which the room page
uses for dragging furniture. **So "pick 休息 and watch the pose change" was not
exercised on the device in this pass.** The pose is proven to follow the
committed action by
`test/presentation/companion/runtime/room_committed_action_test.dart`, but a test
is not a finger and the difference is worth keeping.

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
- that the room's committed actions read *distinctly* to a human — the wiring is
  proven, but whether 坐下 and 休息 are visually distinguishable is
  `OWNER_VISUAL_GATE`, and `room_sit` still renders through the rig rather than a
  dedicated sprite sequence

---

## 5. Gates at this revision

| | |
|---|---|
| `LOCAL_HEAD` | `b911caa` |
| `REMOTE_HEAD` | `b911caa` |
| `LOCAL_EQUALS_REMOTE` | **YES** |
| production code changed | **yes** — D5 only (see below) |
| `FINAL_GATE` | `NO_GO` at the revision reviewed; the P1 is now closed |

### The one production change

Every phase from P19 to P27 changed only tests and tools — `git diff --stat
685667c..HEAD -- lib/` was empty, and the independent review verified it. **D5 is
the exception and the only one.** Closing it required the room to actually be
action-authoritative, which is production behaviour, so `lib/` changed for the
first time in this program:

| File | Change |
|---|---|
| `lib/presentation/companion/runtime/companion_behavior_director.dart` | presents a committed behaviour; re-picks when it changes at the same anchor |
| `lib/presentation/companion/companion_avatar.dart` | new `companionAction` parameter, written to `CompanionContext.macroBehavior` |
| `lib/presentation/pages/room_page.dart` | passes `simulation.companionAction` |

It was made deliberately, against a decision the owner recorded, and it is
covered by seven new tests plus the measurement — not by a change in a document.
