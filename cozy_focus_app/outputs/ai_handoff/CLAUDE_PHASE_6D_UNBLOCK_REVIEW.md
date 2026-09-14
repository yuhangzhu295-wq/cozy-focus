# PHASE-6D-UNBLOCK Architecture/CI Review

- REVIEW_VERSION: 1.0
- DATE: 2026-09-15
- AUTHOR: claude-sonnet-4-6 (senior review subagent)
- SCOPE: Bounded review of PHASE-6D-UNBLOCK CI diagnosis and test-only repair
- IMPLEMENTS: No code changed, review only
- SOURCE_REPORT: outputs/ai_handoff/PHASE_6D_UNBLOCK_CI_REPORT.md
- SOURCE_SPEC: outputs/ai_handoff/PHASE_6D_SPEC.md
- FAILED_CI_RUN: 34855438291

---

## PROJECT_IDENTITY

- Project: cozy-focus (yuhangzhu295-wq/cozy-focus)
- Current approved stage: PHASE-6C (APPROVED, base_sha ef90233da8df47ec6e42d647303255f48935cef5)
- Remote HEAD under review: dbfa4ba9f443c10f9410f267897f07ace665716f
- Phase 6D spec status: Authored, awaiting implementation
- Rive asset status: PENDING_AUTHORING (carried from 6A/6B/6C)

---

## CI_ROOT_CAUSE

**Normalized Category: DATE_TIME_DEPENDENCY**

The diagnostician labeled the root cause TEST_FRAGILITY_DATE_DEPENDENCY.
This review normalizes the category to DATE_TIME_DEPENDENCY, which is the
canonical label for tests that break because they implicitly couple to wall-clock
time rather than a controlled clock.

The failure was not a product regression. It was a test that passed during calendar
Week 37 (Sep 7-13, 2026) and began failing the moment Week 38 started (Sep 14,
2026 UTC), because ReportsController initializes its selectedWeekStart from
DateTime.now() with no injection point:

    // reports_controller.dart, constructor super initializer
    super(ReportsState(
      selectedWeekStart: _getMonday(DateTime.now()),  // wall-clock, not FocusClock
      ...
    ))

This is structurally different from other controllers in the same file, which
accept a FocusClock injection. The controller accepts StatisticsEngine (which
presumably uses the injected clock downstream), but its own state initialization
bypasses the clock seam entirely.

The failing assertion:

    Expected: exactly one matching candidate
      Actual: _TextWidgetFinder:<Found 0 widgets with text "\u672c\u5468\u6700\u5f3a\u4e13\u6ce8\u65e5": []>

The widget is conditionally rendered only when bestDay != null && bestDay.totalSeconds > 0.
On Sep 14, selectedWeekStart resolved to 2026-09-14 (Week 38), where the seeded
records (Sep 7-8) are absent, so bestDay.totalSeconds == 0 and the widget was omitted.

---

## EVIDENCE

The diagnosis is well-supported. Evidence evaluated:

1. Structural confirmation: ReportsController constructor calls _getMonday(DateTime.now())
   directly. DateTime.now() is not mockable in the test container. Phase3TestClock is
   wired to focusClockProvider, but ReportsController does not read focusClockProvider
   during initialization.

2. Deterministic reproduction: The report claims 3/3 pre-fix failures and 3/3 post-fix
   passes. The wall-clock coupling is clearly causal: any run on or after Sep 14, 2026
   UTC would reproduce the failure without the fix.

3. Diff is exact: git diff HEAD confirms exactly the changes described in the report -
   no unrelated hunks, no whitespace artifacts, no production files touched.

4. Secondary viewport factor: The report correctly identifies that physicalSize =
   const Size(800, 1400) expansion was also needed, consistent with the existing
   pattern used in Screen 05C. The findText assertion for the share CTA would fail
   at default 800x600 due to ListView culling.

5. Classification accuracy: The diagnosis correctly rules out product regression.
   The triggering commit (dbfa4ba) only added ARCHITECTURE_ESCALATION.md with zero
   changes to production or test code.

---

## FIX_SCOPE

Assessment: MINIMAL and CORRECT. Test-only. No product behavior altered.

The repair consists of exactly two additions to Screen 06's test body:

1. Viewport expansion (3 lines) matching the identical pattern already used in
   Screen 05C. The tearDown is correctly included, preventing state leakage.

2. Explicit week pinning (3 lines):

       await container
           .read(reportsControllerProvider.notifier)
           .loadWeeklyReport(DateTime(2026, 9, 8));

   This drives the controller to load Week 37 data before the widget mounts,
   overriding the constructor's DateTime.now() initialization.

3. New import (1 line): required by the call above. Minimal and appropriate.

Non-blocking concerns:
- The fix addresses the symptom (Week 38 drift) but not the structural root cause
  (missing FocusClock injection in ReportsController). The pinned constant
  DateTime(2026, 9, 8) is a stable anchor since it is fixed, but a proper fix
  would inject FocusClock into ReportsController's super-initializer.
- The explicit loadWeeklyReport call before pumpWidget is actually a positive side
  effect: the test now exercises the public API more intentionally.

---

## PROTECTED_CORE

All protected boundaries verified as SAFE:

| Boundary                                         | Status    |
|--------------------------------------------------|-----------|
| lib/domain/ (models, services, repositories)     | UNTOUCHED |
| lib/data/ (DAOs, DB schema, migrations)          | UNTOUCHED |
| FocusClock, FocusSessionEngine, RewardLedger     | UNTOUCHED |
| StatisticsEngine, CraftEngine, RewardService     | UNTOUCHED |
| lib/presentation/pages/                          | UNTOUCHED |
| lib/presentation/controllers/ (production files) | UNTOUCHED |
| COZY_RESCUE_RESULT.md                            | UNTOUCHED |
| CURRENT_STAGE.json                               | UNTOUCHED (PHASE-6C APPROVED) |
| Phase 6D implementation                          | NOT PRESENT |
| git commit / git push                            | NOT PERFORMED |

The single modified file is test/presentation/phase3_records_reports_test.dart.

---

## P0

No P0 issues found.

The CI diagnosis is causally correct and well-evidenced. The fix is minimal,
test-only, and does not alter any product behavior. Protected core boundaries
are intact. CURRENT_STAGE.json is undisturbed at PHASE-6C APPROVED.

---

## P1

**P1-01 [Structural Root Cause Not Addressed]**

ReportsController calls DateTime.now() directly in its super-initializer rather
than reading from the injected FocusClock. This is the structural root cause of
the DATE_TIME_DEPENDENCY failure class. The test fix patches around it without
repairing it. The same failure class can recur for other tests that rely on
ReportsController's default week/month/year initialization.

This is a P1 for future phases, not a blocker for this unblock. Recommend adding
a FocusClock injection point to ReportsController as tracked debt, ideally before
or during PHASE-6D implementation.

Location: lib/presentation/controllers/reports_controller.dart, constructor
super-initializer.

---

## P2

**P2-01 [Monthly/Yearly Tests Not Similarly Pinned]**

Screen 07 (MonthlyReportPage) and Screen 08 (YearlyReportPage) use the same
ReportsController and rely on the same DateTime.now() initialization for
monthlyYear/monthlyMonth/yearlyYear. Their tests currently pass because the
seeded records fall in Sep 2026, which is the current calendar month and year.
They would fail similarly if tests ran in a different calendar month or year.

Recommend adding explicit month/year pinning calls analogous to the Screen 06
fix before these break in production CI.

**P2-02 [Hard-coded Date Constant Not Documented]**

DateTime(2026, 9, 8) is a hard-coded absolute date in the test. This is acceptable
as a pragmatic anchor but should be documented with a comment explaining its
relationship to the seeded baseDate in setUp, so future maintainers understand
why the constant exists and what it pins.

---

## RECOMMENDATION

APPROVE the PHASE-6D-UNBLOCK repair for commit and push.

The CI diagnosis is causally correct, the root-cause category normalizes cleanly
to DATE_TIME_DEPENDENCY, the fix is test-only and minimal, and all protected
boundaries are intact.

Required before commit:
- Verify flutter test passes locally at current HEAD (today is 2026-09-15,
  one day after reported post-fix verification; fix should be stable across
  day boundaries since the pinned date is a constant).

Tracked debt (do not block commit on these):
- P1-01: Add FocusClock injection to ReportsController before or during PHASE-6D.
- P2-01: Add explicit pinning to Screen 07 and Screen 08 tests.
- P2-02: Add a comment anchoring DateTime(2026, 9, 8) to baseDate in setUp.

This review does not self-approve the final gate. Gate approval requires the
designated gatekeeper to separately verify the post-fix test run and sign off.
