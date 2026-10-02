# P8 Final Gate — Collection + Craft + Room Loop

- Branch: `recovery/v4.2.1-rebuild`
- HEAD at gate: `0a2fdb97f88639e10879be811ca5ee5b7e610018`
- Mode: FINAL-GATE
- Result: **PASS**, with four items explicitly left open (all owner decisions
  or out-of-scope-by-choice, none of them defects)

---

## 1. What P8 found

The loop was already closed. Focus settles coins and XP, the craft engine
accumulates focus seconds onto one job, job completion is the only writer of
inventory, the collection reads real quantities, and P7 closed placement. What
was missing was not an arrow but four claims the loop never delivered.

| Gap | Kind | Disposition |
|---|---|---|
| G1 `ingredientCosts` dead, while the craft page promised materials would be prepared during focus | false claim in the UI | **claim FIXED**; mechanic open |
| G2 focus coins earned and displayed, never spendable | dangling economy | **open** — needs an owner decision |
| G3 two collection entries unobtainable, yet counted in the progress total | unsatisfiable completion claim | **FIXED** |
| G4 seven of eight items carry a different name in the collection than in the recipe | two hand-kept lists | **open** — needs an owner decision |

---

## 2. What P8 shipped

| Commit | Content |
|---|---|
| `624f2a8` | The audit, the three scopes with their costs, and the characterisation tests |
| `342a4e7` | The two truthfulness fixes |
| `0d0a14f` | The device closure record and evidence |
| `0a2fdb9` | The flaky-test fix and its classification |

**G1 (claim half).** `制作材料` no longer says materials will be prepared during
focus; it says the recipe needs no extra materials, which is true. The mechanic
is not implemented, so the sentence stays accurate.

**G3.** `CollectionCatalogItem` gained `obtainable`; the two preview entries are
marked; the progress total counts only obtainable entries; their cards read
`未开放` rather than `未收集`. The bar can now reach 100%.

No economy was invented. No balance number was chosen. No change to
`CraftEngine`, the settlement transaction, the Drift schema, or any recipe seed.

---

## 3. Local gates

| Gate | Result |
|---|---|
| `dart format` | **PASS** — 253 files, 0 changed |
| `flutter analyze --fatal-infos` | **PASS** — 0 issues |
| `flutter test` | **PASS** — 1071 / 1071 |
| Full suite stability | **PASS** — three consecutive runs, 1071/1071 each, zero failures |
| `flutter build apk --debug` | **PASS** — md5 `441572c1b9628be5db836f57100c8692` |
| `git diff --check` | **PASS** |

Test count moved 1039 → 1071 across P7 + P8 (+32).

---

## 4. Device verification

Recorded in full in `P8_DEVICE_CLOSURE.md`; driven on `emulator-5554` /
`GoodnightPixel7Api34`.

- Collection reports **`2 / 8`** and **`已收集 25%`** — exactly 2/8.
- The two preview entries read **`未开放`**.
- Craft detail reads **「这个配方不需要额外材料，专注时间就是它的成本」**.
- P7's placement toolbar was verified on a device for the first time: two rows
  render, 放大 took a sofa from scale 1.0 to 1.4 with a visibly larger sprite,
  隐藏 left a faint ghost and flipped its icon to 显示 while the other sofa
  stayed opaque, and the state was restored.

---

## 5. Flaky tests — resolved

Two widget tests failed intermittently (5 failures in 6 runs). Root cause was
one defect with two symptoms: `CompanionAvatar` did not control its inputs.

- It read `DateTime.now()` instead of the injected `FocusClock`, so the
  time-of-day band — and therefore the ambient behaviour pool — depended on when
  the suite ran. **This was a product bug too**, not only a test problem.
- It built its director with the default system RNG, leaving no seam for a
  widget test, contradicting the runtime's own documented rule.

Both fixed; production behaviour is unchanged because `focusClockProvider`
returns `SystemFocusClock`. Classification in `FLAKY_TEST_CLASSIFICATION.md`.

---

## 6. Open items

| # | Item | Owner decision needed? |
|---|---|---|
| 1 | **G2** — give focus coins a spend path | yes: the sink and its price |
| 2 | **G4** — unify the craft and collection names | yes: which list wins |
| 3 | **G1 mechanic** — implement materials | yes: source, drop rate, cost per recipe |
| 4 | **P4B visual gate** — whether the sprite art reads well | yes: human eyes; cannot be automated |
| 5 | Global `appRouter` shared across tests in a file | no: deferred to P13 with its own verification |
| 6 | Room simulation's tick reads `DateTime.now()` | no: by design, documented |

Items 1–3 are the same three options the P8 design doc lays out as A, B and C.
Nothing was implemented on a default.

---

## 7. Review findings

- **P0: 0**
- **P1: 0** — the only red in the suite was the flake, and it is fixed and
  verified stable across three full runs.
- **P2: 6** — the open items above; all recorded, none blocking.

---

## 8. Verdict

P8 is **closed**. The loop no longer makes a claim it cannot deliver; the two
claims that could be made true without inventing an economy now are; the rest is
documented, guarded by tests that fail loudly if the gaps change, and left for
the owner.
