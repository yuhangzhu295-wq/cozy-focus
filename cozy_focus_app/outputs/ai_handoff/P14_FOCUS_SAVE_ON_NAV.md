# P14 — Leaving the completion page by the tab bar dropped the save

Found by running a real focus session on the **release** build rather than
trusting the suite, and fixed in `8fe6b84`.

---

## 1. What the user saw

1. Start a session, let it run a few minutes, end it.
2. The completion page says **恭喜获得奖励 +20 专注币 / +20 Mochi XP** and prints
   the real elapsed time.
3. Tap **记录** instead of 完成并返回首页.
4. The records page answers **0 分钟 / 专注次数 0 次 / 共 0 次**, and 成长 shows
   **0 / 100 XP**.

The rewards were real but had not been written yet.

## 2. The mechanism

A session is written to the database by `FocusSessionEngine.save`, which the
completion page calls from **完成并返回首页** (`_handleFinish`). The bottom tab bar
calls `context.go` directly, so leaving that way skipped the save entirely.

`FocusSessionEngine.complete` only moves the session to `finishing` and sets
`endAt` — it writes no record and settles nothing. So the session sat in
`finishing` until something else picked it up.

**Two things did pick it up**, which is why the data was never actually lost:

- the **home page's** recovery hook (`_recoverAbandonedSessions`, on mount), and
- `FocusSessionEngine.recoverAbandonedSessions`, called at app launch.

Both live on paths the user may not take. Landing on 记录 or 成长 does neither.

### Correction to my own first read

I initially called this **data loss**. It was not, and a restart proved it: the
session reappeared with its minutes and a 1-day streak
(`p12_rel_06_records_after_restart.png`). The defect is that the user is shown
rewards and then a stale zero — which reads as broken — not that the work is
gone.

## 3. The first fix was wrong, and the test caught it

The obvious repair was to call `recoverAbandonedSessions` from the nav — it is
named for exactly this, "persist any session left in `finishing`". It is a
**no-op** from the completion page, and deliberately so:

```dart
final abandoned = unfinished.where((s) =>
    s.status == FocusSessionStatus.finishing &&
    s.id != _currentSession?.id);   // <-- skips the in-memory session
```

The engine refuses to touch the session held in memory, because the user may be
sitting on the save page editing it and recovery must not pre-empt their input.
That is correct behaviour; it just means recovery is the wrong tool here.

`app_bottom_nav_test.dart` failed on the first run and said so. Without it the
fix would have shipped looking reasonable and doing nothing.

## 4. The fix

`AppBottomNav` is now a `ConsumerWidget` and calls **`saveSession()`** — the same
thing 完成并返回首页 does — before navigating.

- **Gated on `isCompleted`**, which is true only while a session is `finishing`
  or `completed` and false once it is `saved`. An ordinary tab tap therefore does
  no database work at all, which the third test pins.
- **A failed save is swallowed** rather than trapping the user on the page: the
  session stays `finishing` and the existing recovery paths still settle it. The
  user asked to leave; refusing would be worse than deferring.
- The save runs **before** navigation, so the destination reads settled truth.

## 5. Tests — three distinct claims

| Test | Claim |
|---|---|
| tapping a tab persists a finished session before navigating | the record is written, with the real elapsed time, and the tap still navigates |
| the session is settled, not merely recorded | the reward is applied — `experiencePoints > 0` and the focus minutes — not just the record |
| an ordinary tab tap does no session work | the `isCompleted` gate holds, so the common path stays free |

The second needed a seeded pet row: `RewardService.settle` only applies XP
`if (pet != null)`, which is right for a database that has never been onboarded
but means a settlement test that skips the seed asserts nothing.

Full suite: **1120 / 1120**.

## 6. Device verification — the before and after

Release APK, `emulator-5554`, fresh install, same flow both times: start a
session → end it → leave by the **记录** tab.

| | Records page after leaving by the tab |
|---|---|
| **Before** (`p12_rel_05_records.png`) | 0 分钟 · 专注次数 **0 次** · 共 **0 次** · 0 XP |
| **After** (`p14_fix_02_records.png`) | **1 次** · **1 天** streak · 共 **1 次** · the session listed |

The 0 分钟 in the "after" capture is correct rather than a leftover: the session
was ended inside the same minute, so no whole minute elapsed.

---

## 7. Why this is worth recording

This is the fourth defect in this project found by *looking at the running app*
rather than by reading code or trusting a green suite — after the uncontrolled
clock, the router leak, and the hardcoded "Mochi" in the room. The suite was
1117/1117 green while the shipping artifact showed a user "+20 XP" and then 0.

It is also the second time a plausible-looking fix was wrong for a reason only a
test could show: `recoverAbandonedSessions` reads like the right call and is a
documented no-op in this position.
