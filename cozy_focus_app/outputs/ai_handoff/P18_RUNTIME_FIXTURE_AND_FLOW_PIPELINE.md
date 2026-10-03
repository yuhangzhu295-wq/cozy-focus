# P18 — Runtime fixture harness, and Flow video readiness

Two goals: remove raw-SQLite manipulation from runtime QA, and keep the
video→sprite pipeline ready for when Flow video returns.

**No companion runtime behaviour was changed.** `assets/companions/` is
byte-identical to `HEAD`, and no product code path calls into anything built
here.

---

## 1. The problem this replaces

P17's walk verification needed a room with two anchors, and the only way to reach
that state was editing the SQLite file by hand. It failed three separate ways —
the WAL sidecar was left behind, the file was replaced while its journals existed,
and `adb shell "cat >"` truncated it. Every one of those looked identical from the
outside ("the app lost its data"), and only checking the **byte size on the
device** told them apart.

None were product defects. All three were fixture defects, and the fix is to stop
writing the database directly.

## 2. What was built

| File | What it is |
|---|---|
| `lib/dev/qa_fixture.dart` | The harness. Seeds predefined scenarios through the app's own repositories. |
| `lib/dev/qa_fixture_main.dart` | A debug-only entry point: seed, then run the shipping app. |
| `test/dev/qa_fixture_test.dart` | 22 tests: scenarios, idempotency, reset scoping, and release unreachability. |
| `PetDao.deleteMemoriesWithIdPrefix` | One narrow typed delete, added so reset can be complete. |

```
flutter run -t lib/dev/qa_fixture_main.dart --dart-define=QA_SCENARIO=room_two_anchors
```

Add `--dart-define=QA_RESET=true` to clear seeded state instead.

### It seeds through the real contracts, not around them

`IPetRepository`, `ICraftRepository` and the DAOs — the same instances the app
resolves from its providers. The fixture cannot produce a state the app itself
could not, which is the property a raw-SQL seed never had.

---

## 3. What the audit found

Four things shaped the design, and each was measured rather than assumed.

**The user identity has two sources of truth.** `currentUserIdProvider` is used by
craft, growth, records, reports and the focus pages — but `HomeController` and
`HomePage` read `localMvpUserId` directly, five call sites in all. So the obvious
isolation strategy ("seed a separate QA user and override the provider") would
have produced a **split-brain**: craft seeing one user, home another. The
harness therefore seeds the real user and isolates by an `qa_` **id prefix**
instead. The two-source split is a real finding in its own right and is left
alone here, because fixing it is a product change and this task is QA
infrastructure.

**`CompanionVitals` is not persistable.** It appears nowhere in `lib/data/` or
`lib/domain/` — it is in-memory presentation state that resets on launch. So the
brief's `LOW_ENERGY` scenario **cannot be a persisted fixture**, and a harness
that appeared to offer one would be lying. `happiness_score` and
`experience_points` are the real persisted counterparts, and `HIGH_MOOD` maps to
the former. Recorded as not-expressible rather than quietly skipped.

**`inventory_items` is unique on `(user_id, item_id)`.** The fixture hit
`UNIQUE constraint failed` the first time it was pointed at a database that
already had a sofa — a second row for an already-owned item is a *constraint
violation*, not a harmless duplicate. `_own` now checks first, which also means a
QA run never takes over a real item and `reset` never revokes one.

**`addMemory` is a plain insert, not an upsert.** Every other write the harness
uses is `insertOnConflictUpdate`; memories are not, so a second seed run would
throw on the primary key. The harness checks-then-inserts, which is what makes
`MEMORY_READY` idempotent.

## 4. Scenarios

| Scenario | Seeds |
|---|---|
| `base_pet` | The pet and progress `HomeController` adopts, with the same ids |
| `room_two_anchors` | Two catalog items owned and placed — the P17 walk fixture |
| `all_furniture_owned` | Every item in `FurnitureCatalog`, not a hard-coded list |
| `high_mood` | `happiness_score = 100` |
| `late_growth` | XP from `GrowthLevelCurve.xpForLevel(20)`, level derived from it |
| `craft_active` | A job from a real seeded recipe |
| `memory_ready` | Two memories the growth page can read |
| ~~`low_energy`~~ | **Not expressible** — see §3 |

**Source of truth (§6).** No furniture, growth or identity definition is
duplicated. `all_furniture_owned` walks `FurnitureCatalog.entities`, so adding
furniture updates the fixture automatically; `late_growth` calls
`xpForLevel`/`levelForXp`, so a curve change carries through; the pet ids are the
production ids.

**No generic editor (§5).** `QaScenario` is a closed enum, and an unknown name is
rejected rather than defaulted to something.

## 5. Release safety — enforced, not asserted

Three independent mechanisms:

1. **A separate entry point.** The release entry is `lib/main.dart`. Nothing under
   `lib/` outside `lib/dev/` imports the fixture, and a flag in `main.dart` was
   rejected because it would put fixture code *inside the release binary*.
2. **A structural guard test** that walks `lib/`, skips `lib/dev/`, and fails if
   any `import`/`export` directive references `dev/qa_fixture`. It scans
   directives rather than tokens: Dart cannot use a type without importing it, so
   this is complete — and unlike a token scan it does not fire on a doc comment
   that merely names the fixture, which the first version did.
3. **A runtime guard.** `seed()` throws outside `kDebugMode`.

No route, button or visible affordance was added to the shipping UI.

## 6. Idempotency and reset

**Idempotency (§7).** Every scenario is run twice in the test suite and the
counts compared, against the database and not just against each other: no
duplicate pet (the `pets` table is counted and must hold exactly 1), no duplicate
ownership, no duplicate memory ids.

On device, a second launch reports the **same** counts as the first —
`{inventory_owned: 2, room_items: 2}` — rather than doubling.

**Reset (§8).** Removes only rows carrying the `qa_` prefix:
room items are deleted, inventory is **revoked** by setting quantity to 0 (which
is the app's own ownership rule — `quantity > 0` means owned), and QA memories
are deleted. A test writes a production memory, a production owned item and a
production placement first, seeds, resets, and asserts all three survive. The
prefix is safe because production ids are `mem_<pet>_<type>_<ts>` and never start
with it — also pinned by a test.

## 7. Flow video readiness

The pipeline from P15 is unchanged in architecture; it gained one guard.

**`TEST_VIDEO != PRODUCTION_ART` is enforced, not documented.** A clip rendered
locally from already-approved frames exercises the whole chain — probe, decode,
select, alpha, normalise, QA — but the frames that come out are a round-trip of
art that already ships. Writing them over `assets/companions/` would silently
replace approved sprites with a re-encoded copy of themselves. So the tool now
takes `--source-kind`:

- `test_video` (default) **refuses to run** without `--out-root`.
- `flow_video` may write to production.

Verified both ways: the test clip is refused with the reason printed, and passes
with `--out-root`. `assets/companions/` is untouched.

**`FLOW_GENERATION` remains BLOCKED** (`P15` §6): the prompt box offers only an
image model, the settings trigger opens nothing, no video model appears in the
DOM, and Flow's own banner reports video generation degraded. No video was faked
and no substitute generator was used.

**First real target when Flow returns: `sit_down`.** P16 measured that the dog's
`sit_down` is `reverse(stand_up)` (0.0021 against the reversed sequence versus an
own inter-frame spread of 0.0863) and judged it visually acceptable but *not*
proven better. An independent video is what would settle it. The comparison gate
is defined and deliberately does not replace production assets automatically:

| Measure | How |
|---|---|
| anchor stability | `groundBaseline` / `centerAnchor` vs the contract, tolerance 2px |
| frame sharpness | Laplacian variance, relative to the clip's median |
| silhouette continuity | per-frame alpha IoU against the previous frame |
| identity consistency | the same signature check the QA uses |
| runtime placement | the frames on device, at multiple time points |
| once semantics | no loop closure required; keyframes are the action's poses |

Then **`VISUAL_OWNER_REVIEW`** — automatic metrics cannot decide which motion
reads better, and the brief says so.

## 8. Runtime evidence (§18)

Debug APK built from `lib/dev/qa_fixture_main.dart`, **uninstalled first** so no
prior state — including P17's hand-seeded rows — could contribute.

```
QA_SEED: QaSeedReport(room_two_anchors: base_pet, two_anchors;
         {inventory_owned: 2, room_items: 2, memories: 0})
```

| Step | Observed |
|---|---|
| Seed + launch | The room shows the companion seated on the rug, with the sofa placed — `p18_fixture_room.png` |
| Restart | `QA_SEED` reports **identical** counts; the room is unchanged — `p18_fixture_room_restart.png` |

No raw SQLite command was used at any point in this verification.

## 9. Gates — run fresh (§17)

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | **PASS** — 262 files, 0 changed |
| `flutter analyze --fatal-infos --no-pub` | **PASS** — 0 issues |
| `flutter test --no-pub` | **PASS** — **1142 / 1142** |
| `flutter build apk --debug` | **PASS** |
| `git diff --check` | **PASS** — only CRLF notices, no whitespace errors |

---

## 10. Status

```
RAW_SQLITE_REQUIRED_FOR_QA:   NO
DEBUG_FIXTURE_HARNESS:        PASS
RELEASE_FIXTURE_ACCESS:       NONE
FIXTURE_IDEMPOTENCY:          PASS

FLOW_VIDEO_SURFACE:           BLOCKED
VIDEO_TO_SPRITE_MECHANICS:    PASS
PRODUCTION_VIDEO_ART:         NOT_GENERATED
SIT_DOWN_VIDEO_TEST:          BLOCKED
WALK_VIDEO_TEST:              BLOCKED

FORMAT:                       PASS
ANALYZE:                      PASS
FULL_TESTS:                   1142/1142
APK:                          PASS
```

`SIT_DOWN_VIDEO_TEST` and `WALK_VIDEO_TEST` are `BLOCKED` rather than
`VISUAL_REVIEW_REQUIRED` because no video exists to review — the review gate is
defined and ready, and nothing has passed through it.
