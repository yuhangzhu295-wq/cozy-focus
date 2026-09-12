# V4.1 Closure Fix Plan

## BASE_SHA
52a91b119d518c2529c4d49722403ec1c41bdc67

## GOAL
Close the V4.1 migration gate by fixing the full-repository formatting failure, removing the Home Settings fake action, aligning Craft presentation with repeatable inventory quantities, adding focused S4 regression coverage, and correcting only workflow documentation that would mislead the next execution.

## FILES_ALLOWED_TO_MODIFY
- lib/presentation/pages/home_page.dart
- lib/presentation/pages/craft_list_page.dart
- lib/presentation/pages/craft_detail_page.dart
- test/presentation/presentation_widgets_test.dart
- Other narrowly related S4 test files only when required by the focused tests
- AGENTS.md
- .codex/config.toml
- outputs/ai_handoff/CURRENT_STAGE.json
- outputs/ai_handoff/GEMINI_CLOSURE_REPORT.md
- outputs/ai_handoff/V4_1_CLOSURE_PLAN.md
- Formatting-only changes required for the repository format gate

## FILES_PROTECTED
- FocusClock, FocusSessionEngine, RewardLedger, SettlementDao, StatisticsEngine
- Drift schema and currentUserIdProvider
- Room atomic placement, RoomGeometry, and placement transactions
- Craft progress contribution semantics
- Inventory ownership invariant and CraftEngine repeat-quantity semantics
- Unrelated Phase 0-4 application behavior and all Phase 5 scope

## FINDINGS_TO_CLOSE
- P1-1: make dart format --output=none --set-exit-if-changed . pass across the full repository.
- P1-2: remove or honestly disable the Home Settings gear; no empty onPressed and no Settings implementation.
- P1-3: an owned furniture item must not permanently block starting the same recipe again when no other job is active; preserve the one-active-job rule.
- P2-1: add focused S4 widget/regression coverage for Craft, Room, Inventory, CTAs, Settings, and exactly three bottom-navigation items.
- P2-2: update only active workflow instructions so they identify 11/gpt-5.6-sol as reviewer and 11/gemini-3.8-flash-high via explicit multi_agent_v1__spawn_agent; mark historical custom-agent references as legacy if retained.

## IMPLEMENTATION_STEPS
1. Verify the required Cozy Focus workspace before any source inspection.
2. Read this plan, CURRENT_STAGE.json, and only the named related files.
3. Make a real source/test edit before the eighth read-only operation.
4. Fix the Settings action and repeat-Craft presentation without changing protected domain semantics.
5. Add focused regression tests for the required real states and CTAs.
6. Apply required formatting, run targeted checks, then the complete local gate.
7. Write GEMINI_CLOSURE_REPORT.md with actual command evidence and return control for review.

## TESTS_REQUIRED
- dart format .
- dart format --output=none --set-exit-if-changed .
- flutter analyze --no-pub
- flutter test --no-pub
- flutter build apk --debug
- git diff --check
- Focused S4 widget/regression tests covering repeat craft, active-job exclusion, inventory quantity, room quantity placement, real CTAs, Settings, and exactly three bottom-nav items.

## REMOTE_CI_REQUIRED
After local review approval, push the closure commit and verify the latest HEAD's Flutter CI: Check formatting, Analyze, Run tests, Build APK (debug), and workflow conclusion must all be successful.

## ACCEPTANCE_CRITERIA
- P0 = 0 and P1 = 0 after main review.
- Full repository format gate passes.
- Analyze has no errors or warnings; all tests pass with the new total; debug APK builds.
- Settings has no fake clickable empty callback.
- Owned quantity remains visible/usable and repeat craft is available only when the single active-job rule permits it.
- Focused S4 regression tests are real and passing.
- Active workflow documentation no longer instructs the obsolete model/custom-agent execution.
- Latest GitHub Actions run for the pushed HEAD is green.

## NON_GOALS
- No Settings feature implementation.
- No changes to protected core semantics.
- No Phase 5, Pet Growth, Dress, Collection, Rive, Notifications, or Sync work.
