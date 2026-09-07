# Cozy Focus - ARCHITECTURE_GUARDRAILS.md

> Phase 0 Architecture Guardrails | Generated 2026-09-07
>
> **ALL subsequent models/agents/developers MUST obey these rules.**
> Violations require explicit human approval before proceeding.

---

## 1. FocusSessionEngine Singleton

- **PROHIBITED**: Creating a second FocusSessionEngine, FocusTimer, SessionManager, or any equivalent service.
- There is exactly ONE FocusSessionEngine. It lives in the domain layer. It is injected via DI.
- If you need timer functionality, use the existing engine. If it's missing a method, extend it. Do not create a parallel implementation.

## 2. Statistics Must Be Aggregated

- **PROHIBITED**: Pages calculating their own statistics from raw data.
- **PROHIBITED**: Hardcoding statistics values, sample data, or placeholder numbers in any report view.
- All statistics (daily, weekly, monthly, yearly) MUST be computed by StatisticsEngine from real FocusRecord data.
- UI pages call StatisticsEngine or read from a controller that wraps it. They never query the database directly.

## 3. No Fake Data

- **PROHIBITED**: Using fake/mock/sample/hardcoded data in production UI.
- **PROHIBITED**: Placeholder text like "120 minutes" or "5 sessions" that doesn't come from real data.
- Empty state is a valid state. If there's no data, show the empty state (page 14). Do not invent data to make the UI look populated.
- Test fixtures are allowed ONLY in test files, never in lib/.

## 4. No Placeholder Buttons

- **PROHIBITED**: Buttons that show a label but do nothing when tapped.
- **PROHIBITED**: Navigation targets that lead to a "Coming Soon" or blank page.
- Every button must either: perform its real action, OR not be rendered at all.
- If a feature is not yet implemented, the button for it must not appear in the UI. Use feature flags or conditional rendering.

## 5. No TODO Masquerading as Features

- **PROHIBITED**: `// TODO: implement` inside a function that returns fake/default data and is called by production UI.
- TODOs are allowed only when the function either: throws UnimplementedError, or is genuinely not called by any production code path yet.
- A TODO comment next to a working stub that returns empty/default values IS allowed only if the UI correctly handles the empty/default case.

## 6. No Fake PASS

- **PROHIBITED**: Writing "PASS" or "All tests pass" without actually running the tests.
- **PROHIBITED**: Marking a test as passing when it was skipped, not run, or failed.
- If tests cannot be run (environment issue, missing simulator, etc.), write "NOT_RUN" with the reason.
- If a test fails, write "FAIL" with the error. Do not hide failures.

## 7. Animation Logic Isolation

- **PROHIBITED**: Scattering Rive input control (SMINumber, SMIBool, SMITrigger) across business pages.
- **PROHIBITED**: Pages directly calling setState on the Rive artboard or state machine.
- All animation control flows through: PetStateController -> PetAnimationEngine -> Adapter.
- Pages only call PetStateController methods (onSessionStarted, onSessionPaused, etc.).

## 8. No GIF-Dependent Business State

- **PROHIBITED**: Using GIF animation frame count, duration, or completion as a signal for business logic.
- **PROHIBITED**: Deriving session duration, reward amounts, or state transitions from animation state.
- Animation is a visual projection of business state, never the other way around.
- If animation stops, freezes, or is disabled (Reduced Motion), all business logic must still work correctly.

## 9. Idempotent Rewards

- **PROHIBITED**: Awarding XP, craft seconds, or inventory items more than once for the same session.
- RewardLedger uses session_id as PK. Duplicate settlement attempts are rejected at the database level.
- Fast repeated taps on the reward button must not create multiple entries.
- Re-navigating to the reward page must not re-trigger settlement.
- App restart after reward but before navigation must not re-trigger settlement.

## 10. Idempotent Session Completion

- **PROHIBITED**: Completing the same session multiple times.
- **PROHIBITED**: Creating multiple FocusRecords from a single FocusSession.
- FocusRecord.id = FocusSession.id. UPSERT semantics ensure idempotency.
- The completed -> saved transition happens exactly once.

## 11. Session Recovery on Restart

- **PROHIBITED**: Discarding an active session when the app restarts.
- **PROHIBITED**: Losing elapsed time on app restart, background, or process death.
- On cold start: check DB for session with status IN (running, paused). If found, offer recovery (03B).
- Elapsed time recalculated from timestamps. Never from a volatile counter.

## 12. No Cross-Module Destruction

- **PROHIBITED**: Modifying, refactoring, or breaking Module B while implementing Module A.
- Each phase/page implementation touches only its own files + shared interfaces.
- If a shared interface needs extension, the change must be backward-compatible.
- Unrelated improvements go to docs/non_scope_findings.md, not into the current PR.

## 13. Timer.periodic Is Display Only

- **PROHIBITED**: Using Timer.periodic, Timer, or any periodic callback as the source of truth for elapsed focus time.
- Timer.periodic may update the UI display. It must read from FocusClock.elapsed(), not increment a counter.
- If Timer.periodic stops, skips, or drifts, zero data is lost.

## 14. Design Images Are Reference Only

- **PROHIBITED**: Using design PNG files as full-page background images in the app.
- **PROHIBITED**: Overlaying interactive widgets on top of a static design screenshot.
- Design images define layout, visual hierarchy, colors, and component placement. The UI must be built with real Flutter widgets.

## 15. Local-First Data

- **PROHIBITED**: Requiring network connectivity for core focus flow (start, time, pause, complete, save).
- **PROHIBITED**: Blocking UI on network requests during active focus session.
- Local SQLite (Drift) is the fact source. Network sync is eventual and non-blocking.
- SyncEngine processes outbox in background. Failures retry silently.

## 16. Timestamp Storage

- **PROHIBITED**: Storing timestamps as local time without timezone information.
- All timestamps stored as UTC (timestamptz equivalent in SQLite: ISO 8601 UTC string or Unix epoch).
- Display layer converts to local timezone for user-facing text.

## 17. Report Data Integrity

- **PROHIBITED**: Pre-computing or caching report data that becomes stale when records change.
- Weekly/Monthly/Yearly reports MUST re-aggregate from FocusRecord on every view.
- Caching is allowed only as a performance optimization with proper invalidation when records change (Drift watch queries handle this naturally).

---

## Enforcement

Before merging any code change, verify:

1. `dart format --output=none --set-exit-if-changed .` passes
2. `flutter analyze` has zero errors
3. `flutter test` passes (or failures are documented)
4. No new violations of the above rules introduced
5. No files outside the current phase's scope modified without documented reason
