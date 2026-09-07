# Cozy Focus - FOCUS_SESSION_STATE_MACHINE.md

> Phase 0 Focus Timer Architecture Freeze | Generated 2026-09-07

---

## 1. Absolute Rule: Timestamp-Based Timing

**PROHIBITED**: `Timer.periodic` as the source of truth for elapsed time.

**REQUIRED**: All elapsed time calculated from timestamps:

```dart
Duration elapsed(FocusSessionSnapshot session, DateTime now) {
  final totalWall = now.difference(session.startedAt);
  final totalPaused = session.pauseIntervals.fold<Duration>(
    Duration.zero,
    (sum, interval) => sum + interval.duration(now),
  );
  return totalWall - totalPaused;
}
```

`Timer.periodic` is used ONLY for UI display refresh (updating the visible countdown). It has zero authority over the actual session duration.

---

## 2. State Machine

```
                          +-------+
                          | idle  |
                          +---+---+
                              |
                         user starts
                              |
                          +---v---+
               +--------->|running|<----------+
               |          +---+---+           |
               |              |               |
          user resumes    user pauses     app restored
               |              |          (was running)
               |          +---v---+           |
               +----------| paused|---------->+
                          +---+---+
                              |
                     user ends / timer expires
                              |
                        +-----v-----+
                        | finishing |
                        +-----+-----+
                              |
                    engine confirms completion
                              |
                        +-----v-----+
                        | completed |
                        +-----+-----+
                              |
                   +----------+----------+
                   |                     |
              user saves            user discards
                   |                     |
              +----v---+          +------v-----+
              | saved  |          | cancelled  |
              +--------+          +------------+

              +----------+
              | restored |  (transient: app comes back from death)
              +-----+----+
                    |
              resolves to running/paused/completed
                    |
              (appropriate state)
```

---

## 3. State Definitions

| State | Description | Persisted | UI Timer Active |
|-------|-------------|-----------|-----------------|
| `idle` | No active session. Ready to start. | No (default) | No |
| `running` | Focus session in progress. Timer counting. | Yes | Yes (display only) |
| `paused` | User manually paused. Timer frozen. | Yes | No |
| `finishing` | Timer expired or user ended. Transitional. | Yes | No |
| `completed` | Session finished. Awaiting user save/review. | Yes | No |
| `cancelled` | User abandoned session (or discarded sub-minimum). | Yes | No |
| `saved` | Record persisted to FocusRecord + rewards settled. | Yes | No |
| `restored` | Transient: app recovered from background/death. Resolves immediately. | No | No |

---

## 4. Session Data Model

```dart
class FocusSessionSnapshot {
  final String id;              // UUID
  final String userId;
  final String taskName;
  final String category;
  final FocusMode mode;         // flow / pomodoro / custom
  final int targetSeconds;      // 0 for flow mode (unlimited)
  final DateTime startedAt;     // monotonic-safe timestamp
  final DateTime? endedAt;
  final List<PauseInterval> pauseIntervals;
  final FocusSessionStatus status;
  final String? note;
  final String? mood;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncState;       // pending / synced / conflict
}

class PauseInterval {
  final DateTime pausedAt;
  final DateTime? resumedAt;

  Duration duration(DateTime now) {
    return (resumedAt ?? now).difference(pausedAt);
  }
}

enum FocusSessionStatus {
  idle, running, paused, finishing, completed, cancelled, saved
}

enum FocusMode { flow, pomodoro, custom }
```

---

## 5. Transition Rules

| From | To | Trigger | Side Effects |
|------|----|---------|-------------|
| idle | running | User taps Start | Set startedAt = DateTime.now(); persist to DB; start UI timer; notify PetStateController(focus) |
| running | paused | User taps Pause | Add PauseInterval(pausedAt: now); persist; notify PetStateController(pause) |
| paused | running | User taps Resume | Set current pauseInterval.resumedAt = now; persist; notify PetStateController(focus) |
| running | finishing | Timer expires OR user taps End | Set endedAt = now; persist |
| paused | finishing | User taps End while paused | Close current pauseInterval; set endedAt = now; persist |
| finishing | completed | Engine validates minimum duration met | Update status; notify PetStateController(celebrate); show completion UI |
| finishing | cancelled | Elapsed < minimum threshold | Update status; return to idle |
| completed | saved | User saves record (04A) | Create FocusRecord; settle rewards (idempotent); update sync_outbox; notify PetStateController(idle) |
| completed | cancelled | User discards | Update status; return to idle |
| restored | running/paused/completed | App recovers from background/death | Read persisted session; recalculate elapsed from timestamps; resolve to correct state |

---

## 6. Recovery Scenarios

### 6.1 Foreground -> Background -> Foreground
- On background: persist current state + timestamp to DB.
- On foreground: read persisted session; recalculate elapsed from (now - startedAt - totalPaused).
- UI timer resumes with correct value. No data loss.

### 6.2 Lock Screen
- Same as background. Timer display freezes but elapsed is recalculated on unlock.
- Optional: schedule local notification at target time.

### 6.3 App Suspended by System
- State already persisted. On next launch: check for active session in DB.
- If found: enter `restored` state, recalculate, resume.

### 6.4 Process Killed (Force Close / OOM)
- State already persisted (every transition writes to DB).
- On cold start: query DB for session with status `running` or `paused`.
- If found: show restoration dialog (03B design), recalculate elapsed, offer resume/end.

### 6.5 Cross-Midnight
- Elapsed calculation is pure arithmetic on timestamps. No date boundary logic needed.
- Report aggregation handles date attribution when saving the record.

### 6.6 Cross-Timezone
- All timestamps stored as UTC (timestamptz).
- Display converts to local timezone.
- Elapsed = UTC arithmetic. Timezone changes do not affect duration.

### 6.7 System Time Change
- Risk: user manually sets clock backward.
- Mitigation: on resume, if calculated elapsed is negative or implausibly large, flag the session for manual review.
- Consider `SystemClock` / monotonic clock where platform supports it.
- Never trust elapsed < 0. Clamp to last known good value.

### 6.8 Device Reboot During Session
- Same as process killed. Persisted state survives reboot.
- On next app launch: detect active session, offer recovery.

---

## 7. FocusClock Contract

```dart
/// The ONLY authority on "how long has this session been."
/// UI Timer.periodic calls this to get display value.
/// RewardService calls this to determine earned minutes.
abstract interface class FocusClock {
  /// Calculate elapsed focus time from session timestamps.
  /// [session] contains startedAt, pauseIntervals, endedAt.
  /// [now] is the current time (injected for testability).
  Duration elapsed(FocusSessionSnapshot session, DateTime now);
}

class FocusClockImpl implements FocusClock {
  @override
  Duration elapsed(FocusSessionSnapshot session, DateTime now) {
    final effectiveEnd = session.endedAt ?? now;
    final wallTime = effectiveEnd.difference(session.startedAt);
    final pausedTime = session.pauseIntervals.fold<Duration>(
      Duration.zero,
      (sum, interval) => sum + interval.duration(effectiveEnd),
    );
    final result = wallTime - pausedTime;
    // Clamp: never return negative (clock manipulation protection)
    return result.isNegative ? Duration.zero : result;
  }
}
```

---

## 8. UI Timer Role (Display Only)

```dart
// In FocusActiveController:
Timer.periodic(const Duration(seconds: 1), (_) {
  // This timer ONLY updates the display.
  // It does NOT increment a counter.
  final elapsed = _focusClock.elapsed(_currentSession, DateTime.now());
  state = state.copyWith(displayElapsed: elapsed);
});
```

If the UI timer drifts, skips, or stops, zero data is lost. The session's actual duration is always recoverable from timestamps.
