# Phase 2 Architecture Exception Report

> Generated: 2026-09-08 | Target Repo: cozy-focus | Phase: 2

---

## 1. Context & Motivation

During Phase 2 implementation of the Focus Core Flow (specifically **03B Background / Process Restart Restore** and **03C Early Finish / Completion**), an architectural gap was discovered in `FocusSessionEngine` and `FocusSession.isActive`:

When an active session was hydrated from local Drift storage via `FocusSessionEngine.restore(userId)`:
1. The engine marked the session's status as `FocusSessionStatus.restored`.
2. However, `FocusSession.isActive` previously evaluated only:
   ```dart
   bool get isActive =>
       status == FocusSessionStatus.running ||
       status == FocusSessionStatus.paused;
   ```
   This caused restored sessions to be treated as inactive by external checks.
3. More critically, `engine.pause()`, `engine.resume()`, `engine.complete()`, and `engine.cancel()` asserted that the session status was strictly `FocusSessionStatus.running` or `FocusSessionStatus.paused`.
   When a user reopened the app after process recreation and attempted to complete or cancel the restored session, `FocusSessionEngine` threw a fatal `StateError`:
   `Cannot complete session in status: FocusSessionStatus.restored`.

---

## 2. Modified Components

### A. `cozy_focus_app/lib/domain/models/focus_session.dart`
- **Original**:
  ```dart
  bool get isActive =>
      status == FocusSessionStatus.running ||
      status == FocusSessionStatus.paused;
  ```
- **Modified**:
  ```dart
  bool get isActive =>
      status == FocusSessionStatus.running ||
      status == FocusSessionStatus.paused ||
      status == FocusSessionStatus.restored;
  ```

### B. `cozy_focus_app/lib/domain/services/focus_session_engine.dart`
- **Modified methods**: `pause()`, `resume()`, `complete()`, `cancel()`.
- **Change**: Permitted `FocusSessionStatus.restored` as a valid source state for pause, resume, completion, and cancellation transitions.

---

## 3. Impact & Backward Compatibility

- **Domain Invariants Preserved**: Timestamps remain the sole source of truth for elapsed calculation; timer expiration and pause interval calculation are unaffected.
- **Data Integrity**: FocusRecord generation, reward idempotency, and repository persistence remain strictly enforced.
- **Phase 1 Regression**: All 14 original Phase 1 domain tests continue to pass 100%.

---

## 4. Verification Tests Added

- Added Test #8 in `test/presentation/focus_flow_test.dart`: `Restored session can be completed or cancelled without StateError`.
