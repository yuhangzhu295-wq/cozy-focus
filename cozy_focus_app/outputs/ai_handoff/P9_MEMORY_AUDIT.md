# P9 — Companion Memory: Architecture Audit

Baseline: branch `recovery/v4.2.1-rebuild`, HEAD `3b2f75c`, worktree clean,
`dart format` clean, `flutter analyze --fatal-infos` clean, suite 1071/1071.

---

## 1. CURRENT_STATE — the memory layer is built and entirely unused

The audit's headline finding is not "memory is missing". It is that memory is
**already modelled, persisted and exposed — and nothing calls it.**

### 1.1 What exists

| Layer | Artifact | Location |
|---|---|---|
| Model | `PetMemory { id, petId, memoryType, content, happenedAt }` | `lib/domain/models/pet_models.dart:43` |
| Table | `PetMemories` (PK `id`), registered in the schema | `lib/data/local/tables/pet_tables.dart:41`, `app_database.dart:35` |
| Write | `PetDao.addMemory` | `lib/data/local/daos/pet_dao.dart:54` |
| Read | `PetDao.findMemories(petId, {limit = 50})` | `lib/data/local/daos/pet_dao.dart:66` |
| Mapping | `PetDao._mapMemory` | `lib/data/local/daos/pet_dao.dart:105` |
| Repository | `DriftPetRepository.addMemory` / `.findMemories` | `lib/data/repositories/drift_pet_repository.dart:25,28` |
| Contract | `IPetRepository.addMemory` / `.findMemories` | `lib/domain/repositories/i_pet_repository.dart:10,11` |

`schemaVersion` is 4 and `PetMemories` is already part of it. **P9 needs no
migration and no new table.**

### 1.2 What does not exist

```
grep -rn "addMemory|findMemories" lib \
  | grep -v pet_dao.dart | grep -v drift_pet_repository.dart \
  | grep -v i_pet_repository.dart
→ (empty)
```

- **No producer.** Nothing in the application ever appends a memory. The only
  `addMemory` calls in the repo are the repository pass-through and the DAO
  implementation. Test fakes implement it as a no-op
  (`focus_session_engine_test.dart:103`, `phase2_review_test.dart:105`), which is
  how a dead method survives a green suite.
- **No consumer.** Nothing reads a memory. No page, controller, provider or
  presentation type mentions it.
- **No vocabulary.** `memoryType` is a bare `String` documented only by a
  trailing comment — `// e.g. "first_focus", "level_up", "long_session"`. There
  is no enum, no constant set, no validation, and therefore no definition of
  which types are legitimate. A typo would be stored happily and read back as a
  distinct type.

So the shape is the mirror image of the P8 findings: there, the UI promised
something the loop did not deliver. Here, the *storage* promises something the
application does not produce.

---

## 2. GAP

| # | Gap | Evidence |
|---|---|---|
| M1 | Nothing writes a memory | no `addMemory` call site in `lib/` |
| M2 | Nothing reads a memory | no `findMemories` call site in `lib/` |
| M3 | `memoryType` has no defined vocabulary | free `String`; one illustrative comment |
| M4 | No idempotency rule | unwritten; a re-settled session must not duplicate a memory |

---

## 3. DESIGN

### 3.1 Where a memory must be produced

Memory is a record of a fact that already happened, so it belongs **inside the
transaction that settles the fact** — not in a listener, not in presentation,
and not on a timer.

`SettlementDao.settleAtomically` is the right seam, and it already provides the
two properties M4 needs for free:

1. **Atomicity** — it runs in a single Drift `transaction { … }`, and it already
   resolves the `Pets` row inside that transaction (`settlement_dao.dart:70`),
   which is where `petId` comes from.
2. **Idempotency** — its first step is a ledger `INSERT OR IGNORE` followed by
   `SELECT changes()`. `wasInserted == false` means this call is a duplicate and
   it returns early. A memory appended after that gate therefore inherits
   exactly-once semantics keyed by `session_id`.

This satisfies M4 without inventing a new mechanism.

### 3.2 Scope — only memories that need no invented number

The shipped comment names three types. Two of them are fully determined by data
the transaction already holds; the third is not.

| Type | Derivable from | Needs an invented number? |
|---|---|---|
| `first_focus` | ledger row count for the user, inside the txn | **no** — "the first" is 1 |
| `level_up` | `GrowthLevelCurve.levelForXp(oldXp)` vs `(newXp)`; the DAO already reads `progress.experiencePoints` and writes a derived level | **no** — the threshold is the curve |
| `long_session` | session length vs a threshold | **YES** — what counts as long is a product number |

**In scope for P9: `first_focus` and `level_up`.** Both are unambiguous, both are
real facts already inside the transaction, and neither requires choosing a
number.

**Out of scope, deliberately:** `long_session` (needs a threshold), and any
`first_craft` / `unlock` / `first_placement` type (each needs a decision about
which moments deserve to be memorable — and a memory system that records
everything remembers nothing).

### 3.3 The vocabulary (M3)

Add the allowed types as constants **next to the model**, not as loose strings at
call sites, so the producer, the reader and a test all name the same thing. A
`String` column is kept — no schema change — but the set is closed in Dart.

### 3.4 What memory must NOT become

The standing constraints from P4A and P7 apply unchanged:

- **Not a second scheduler.** Memory is written inside an existing transaction;
  it starts no timer, and it does not touch `CompanionBehaviorDirector`.
- **Not a second business state machine.** A memory is derived from a fact the
  transaction already settled; it never decides anything.
- **Not a reward.** It grants no XP, coins, items or unlocks, and cannot reach
  those types. Recording that something happened must not change what happened.
- **Presentation reads it; it never writes it.** The consumer side is read-only.

### 3.5 Architecture-reviewer contract

1. **What existing class already owns this job?** `SettlementDao.settleAtomically`
   owns settlement; `PetDao` owns pet persistence. No new persistence class.
2. **Why can't it be safely extended?** It can — the memory table is already in
   the schema and already reachable from the pet DAO. The only change to
   `SettlementDao` is adding `PetMemories` to its `@DriftAccessor` table list so
   it can write inside the transaction. That is a code-generation change, not a
   migration.
3. **Would new state duplicate business truth?** No. A memory is a *record of* a
   settled fact, not a second copy of it, and it is never read back to make a
   decision.
4. **Where is the single source of truth?** The ledger, pet progress, and the
   `PetMemories` table. Memory is append-only and derived; nothing else is
   authoritative for it.
5. **How will it be tested?** In-memory Drift through the real settlement path —
   see §4.
6. **What files must remain untouched?** `CompanionBehaviorDirector`, the
   presentation runtime, `CraftEngine`'s inventory invariant, the room placement
   path, and every existing table definition.

---

## 4. TEST_PLAN

| # | Assertion | Guards |
|---|---|---|
| 1 | A first settled session appends exactly one `first_focus` memory | M1 |
| 2 | A second settled session appends **no** second `first_focus` | M1, M4 |
| 3 | Re-settling the same session appends nothing (idempotent) | M4 |
| 4 | A settlement that crosses a level boundary appends one `level_up` | M1 |
| 5 | A settlement that does not cross a boundary appends no `level_up` | correctness |
| 6 | The memory's `petId` is the real pet, and `happenedAt` is the settlement time | data integrity |
| 7 | Settling appends no memory of a type outside the closed vocabulary | M3 |
| 8 | Memory writes change no XP, coin, inventory or craft value beyond what settlement already did | business isolation |
| 9 | `findMemories` returns newest-first and honours `limit` | M2 read path |
| 10 | The non-atomic fallback path in `RewardService` behaves the same | path parity |

Plus: full suite, `dart format`, `flutter analyze --fatal-infos`.

---

## 5. RISK

| Risk | Mitigation |
|---|---|
| Memory becomes a second reward | It writes one row and no other type is reachable from it; test 8 pins this |
| A duplicate memory on re-settlement | The ledger gate already returns early; tests 2 and 3 pin it |
| The two settlement paths diverge | Test 10 covers the fallback path explicitly |
| Scope creep into "record everything" | §3.2 names the closed scope; `long_session` and the `first_*` family are out |
| A future type is added as a bare string | §3.3 closes the vocabulary in Dart and test 7 enforces it |

---

## 6. WHAT P9 WILL NOT DO

- No new table, no migration, no schema change.
- No change to what settlement awards.
- No memory-driven behaviour change in the companion.
- No `long_session` threshold, and no decision about which moments are
  memorable beyond the two that are self-defining.
