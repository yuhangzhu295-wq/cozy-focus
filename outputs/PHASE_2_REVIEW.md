# PHASE_2_REVIEW.md

Status: **PHASE_2_REVIEW_APPROVED**
Review commit: eefe0c3417710f8918846e59bd584e2a21ba2a47
Fix commit: (see below — committed after this report)

---

## 1. Issues Found and Fixed

### Issue 1 — Fake reward removed (FIXED)
**File:** `lib/presentation/pages/focus_reward_page.dart`
**Problem:** Hardcoded "Wooden Chair 🪑 手工木质小椅子" — a fake crafted item.
**Fix:** Removed entirely. Page now shows real `focusCoinsEarned` and `experienceEarned`
from `RewardLedger`. Craft/Room section shows a legitimately locked state:
"制作工坊 — 制作系统将在 Phase 4 解锁。专注币已积累，届时可用于制作家具。"

### Issue 2 — Fake buttons removed (FIXED)
**File:** `lib/presentation/pages/focus_reward_page.dart`
**Problem:** "Place Now" and "View in Inventory" both called `context.go('/')` — fake navigation.
**Fix:** Both buttons replaced with a single honest "返回首页" button that correctly
reloads home data before navigating.

### Issue 3 + 4 — All save-page fields persisted (FIXED)
**File:** `lib/presentation/pages/focus_save_page.dart`, `focus_session_controller.dart`
**Problem:** `saveSession()` only passed `note`; `taskName`, `categoryId`, `mood` were discarded.
**Fix:** `saveSession()` now accepts and passes all four fields to `FocusSessionEngine.save()`.
`mood` is stored as a dedicated structured field on `FocusRecord`, NOT concatenated into `note`.

### Issue 5 — taskName added to FocusSession (FIXED)
**File:** `lib/domain/models/focus_session.dart`, `lib/domain/services/focus_session_engine.dart`
**Problem:** `taskName` not persisted on `FocusSession`, lost on process restart.
**Fix:** `taskName` added as nullable field. `FocusSessionEngine.start()` accepts `taskName`.
`copyWith()` updated. Schema migrated (v2).

### Issue 5 + 6 — taskName + mood added to FocusRecord (FIXED)
**File:** `lib/domain/models/focus_record.dart`, Drift DAO/table
**Problem:** Neither `taskName` nor `mood` existed as fields on `FocusRecord`.
**Fix:** Both added as nullable fields. `FocusRecordDao.insert()` and `_map()` updated.
Schema migration v2 adds both columns.

### Issue 6 — Category override on save (FIXED)
**File:** `lib/domain/services/focus_session_engine.dart`
**Problem:** `save()` always used the session's original `categoryId`.
**Fix:** `FocusSessionEngine.save()` accepts `categoryId` override; uses `categoryId ?? session.categoryId`.

### Issue 7 — FocusClock consistency (FIXED)
**File:** `lib/domain/models/focus_session.dart`, `lib/domain/services/focus_session_engine.dart`
**Problem:** `FocusSession.elapsedSeconds` getter used `DateTime.now()` for open sessions.
**Fix:** New `elapsedSecondsAt(DateTime now)` method added. `FocusSessionEngine.save()`
and `FocusSessionController._computeElapsed()` both call `session.elapsedSecondsAt(_clock.now())`.
The old `elapsedSeconds` getter is kept for backward-compat on closed sessions (uses `endAt`).

### Issue 8 — State machine consistency check (VERIFIED, NO CHANGE NEEDED)
The `restored` status correctly allows `pause`, `resume`, `complete`, and `cancel` in the engine.
No invariant violations found.

---

## 2. Test Results

### flutter analyze
```
No issues found! (ran in 8.5s)
```

### flutter test (full suite)
```
38/38 All tests passed!
```

Test breakdown:
- `test/domain/focus_clock_test.dart` — 1 test
- `test/domain/focus_session_engine_test.dart` — 8 tests (Gate 1, unchanged)
- `test/domain/focus_session_model_test.dart` — 5 tests (Gate 1, unchanged)
- `test/domain/phase2_review_test.dart` — 10 tests (NEW — Issue 10 coverage)
- `test/presentation/focus_flow_test.dart` — 8 tests
- `test/presentation/presentation_widgets_test.dart` — 6 tests

Gate 1 domain tests: **14/14 PASS** (no regression)

### Issue 10 new tests (phase2_review_test.dart)
1. taskName persisted on FocusSession via start() — PASS
2. taskName denormalized onto FocusRecord after save() — PASS
3. taskName override on save() replaces session taskName on FocusRecord — PASS
4. category override on save() lands on FocusRecord — PASS
5. mood stored as structured field, not concatenated into note — PASS
6. elapsedSecondsAt(clock.now()) matches FocusRecord.durationSeconds — PASS
7. reward coins based on same elapsed as FocusRecord duration — PASS
8. reward settlement idempotent - second settle rejected — PASS
9. app restart: new engine restores session with taskName intact — PASS
10. no craft/room/inventory items created by engine.save() — PASS

### flutter build apk --debug
```
Built build/app/outputs/flutter-apk/app-debug.apk
```
Build: PASS

### iOS build
NOT_RUN — Windows development environment. iOS scaffold intact and unmodified.

---

## 3. Schema Migration

Database schema bumped from v1 to v2.
Migration adds:
- `focus_sessions.task_name TEXT`
- `focus_records.task_name TEXT`
- `focus_records.mood TEXT`

---

## 4. Files Modified

### Domain
- `lib/domain/models/focus_session.dart` — added `taskName`, `elapsedSecondsAt()`
- `lib/domain/models/focus_record.dart` — added `taskName`, `mood`
- `lib/domain/services/focus_session_engine.dart` — `start()` accepts `taskName`; `save()` accepts `categoryId`, `taskName`, `mood`; uses `elapsedSecondsAt(_clock.now())`

### Data
- `lib/data/local/app_database.dart` — `schemaVersion = 2`, migration
- `lib/data/local/daos/focus_session_dao.dart` — `taskName` in upsert + map
- `lib/data/local/daos/focus_record_dao.dart` — `taskName` + `mood` in insert + map

### Presentation
- `lib/presentation/pages/focus_save_page.dart` — all fields persisted
- `lib/presentation/pages/focus_reward_page.dart` — fake items removed, fake buttons removed
- `lib/presentation/controllers/focus_session_controller.dart` — `saveSession()` passes all fields

### Tests
- `test/domain/phase2_review_test.dart` — NEW (Issue 10 coverage, 10 tests)
- `test/presentation/presentation_widgets_test.dart` — assertions updated to match real reward page

---

## 5. Known Remaining Gaps (not blockers for Phase 2 approval)

- Mood picker in save page currently uses emoji strings; a future Phase may introduce a
  structured `MoodType` enum with typed validation.
- `RewardService.settle()` uses `session.elapsedSeconds` (the backward-compat getter).
  For completed sessions `endAt` is non-null, so this is deterministic. A future refactor
  should switch to `elapsedSecondsAt(_clock.now())` for full test isolation.
- iOS build not validated — Windows environment. Must be validated before App Store submission.
- No Android emulator end-to-end run recorded — emulator not available in current environment.
  APK builds and all 38 unit/widget tests pass.

---

## 6. Architecture Exceptions

None. All Phase 2 review fixes were implemented without modifying frozen Phase 1 interfaces.
Domain layer extended only (additive changes). No `PHASE_2_ARCHITECTURE_EXCEPTION.md` required.

---

## Final Status

**PHASE_2_REVIEW_APPROVED**

Phase 3 may begin after independent confirmation.