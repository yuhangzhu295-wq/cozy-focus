# P24 — Multi-Companion Parity

```
P24_MULTI_COMPANION: PASS
```

`test/architecture/multi_companion_parity_test.dart` — 10 tests, built alongside
the coverage that already existed (`fourth_companion_contract_test.dart`,
`multi_companion_test.dart`, `companion_pack_completeness_test.dart`), none of
which this phase duplicated.

---

## 1. Five dimensions, compared against the dog as reference

| # | Dimension | Result |
|---|---|---|
| 1 | **action set** — every companion ships the same action ids | **PASS** — 13 each |
| 2 | **frame target** — same target and loop mode per action | **PASS** |
| 3 | **manifest completeness** — nothing declares itself unfinished | **PASS** |
| 4 | **asset inclusion** — every declared frame exists and ships | **PASS** |
| 5 | **runtime registration** — profile, action manifest, visual provider | **PASS** |

Dimension 4 checks two things that fail differently. A frame that is declared but
missing is caught by the integrity suite too. A companion whose **directory is not
named in `pubspec.yaml`** is not: Flutter does not recurse into subdirectories, so
the art is simply absent on device while every test that reads from disk still
passes. That is the silent one, and it is now a gate.

Dimension 5 checks all three registrations, because each is a different way to be
invisible: missing from the catalog and the director cannot schedule it; missing
from the action manifests and the sprite layer has nothing to draw; missing a
visual provider and nothing draws it at all.

---

## 2. Species branching is zero

Measured, not asserted by convention:

```
species comparisons anywhere in lib/:  0
species branches in lib/presentation/pages/:  0
species branches in the generic renderer:     0
```

The scan looks for **comparisons** — `== CompanionId.`, `!= CompanionId.`,
`case CompanionId.`, the same for `PetSpecies.`, and `== 'dog'`-style string
tests. It deliberately does **not** flag bare names, because two legitimate
patterns use them and flagging either would make the gate noise that gets
suppressed:

- `CompanionId.dog: _profile(...)` in `companion_manifest_data.dart` is a **map
  key** — a registration table, which is how the data should be expressed.
- `?? CompanionId.dog` in `companion_catalog.dart` is a **default** for an empty
  catalog.

The distinction is the whole point of the gate: a table says "here is what
exists", a branch says "if it is this one, do something different". Only the
second one makes a fourth companion need an edit.

### The negative proof

A scan that matches nothing is indistinguishable from one that cannot match, so
the proof feeds it both shapes:

| Input | Expected |
|---|---|
| `if (id == CompanionId.dog) return a;` | **branch** |
| `switch (id) { case CompanionId.cat: }` | **branch** |
| `if (species == 'rabbit') return b;` | **branch** |
| `CompanionId.dog: _profile(...),` | not a branch — a registration |
| `?? CompanionId.dog` | not a branch — a default |
| `// if (id == CompanionId.dog)` | not a branch — a comment |

---

## 3. A fourth companion needs no page or engine edit

This is already proven by `fourth_companion_contract_test.dart`, which builds a
test-only fox and shows it schedules behaviours, gets its own profile, resolves
its own pack, is drawn by its own provider, and **renders in a page with no page
change**.

The species-branch scan is the **structural** half of the same claim: a page that
branched on species could not host a fourth companion without an edit, and there
are none. The two together are the requirement — one demonstrates it, the other
shows nothing prevents it.

**One thing a real fourth companion *would* need**, stated plainly: a line in
`pubspec.yaml`. That is a build manifest rather than a page or engine edit, so it
does not violate the requirement — but it is a real step, it is easy to forget,
and dimension 4 now fails if it is forgotten. A *test-only* companion needs
nothing at all, because it never ships assets.

### The gate is data-driven, and says so

Every check loops over `CompanionManifestData.profiles.keys`, and a test asserts
that. A parity suite that hard-coded three names would keep passing while a fourth
went unchecked — which is the failure this file is most likely to suffer, so it is
guarded explicitly rather than left to the reader.

---

## 4. Gates

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | **PASS** — 267 files, 0 changed |
| `flutter analyze --fatal-infos --no-pub` | **PASS** — 0 issues |
| `flutter test --no-pub` | **PASS** — **1185 / 1185** (was 1175; +10) |
| `git diff --check` | **PASS** |

---

## 5. What this does not cover

- **Visual parity.** That all three are drawn *equally well* is
  `OWNER_VISUAL_GATE` (P21) and is not decided by any measurement here. These
  gates compare structure, not quality.
- **Behavioural parity.** The three share a director and a pose vocabulary, and
  `multi_companion_test.dart` covers that they do. This file does not re-derive
  it.
- **The fox is a fixture.** The fourth-companion proof uses an in-memory
  companion with no assets, so it demonstrates the *contract* rather than a
  shipped fourth pack.
