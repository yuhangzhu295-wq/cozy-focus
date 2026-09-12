# Phase 5 Pet Growth Implementation Plan

## BASE_SHA

ee51b1500fbc16b17e6c3c08261fa0ea5f1cb203

## GOAL

Implement the first bounded Phase 5 slice: Growth > Mochi. Provide a real, data-backed growth screen for the existing Pet and PetProgress domain without expanding into Dress, Collection, Rive, Settings, Notifications, or Sync.

## WORKSPACE_CONTRACT

APP_WORKDIR: C:/Users/zyu33/Documents/Codex/2026-09-07/new-chat/cozy_focus_app
GIT_ROOT: C:/Users/zyu33/Documents/Codex/2026-09-07/new-chat
git rev-parse --show-toplevel must return the parent new-chat repository.
git rev-parse --show-prefix must return cozy_focus_app/.
Do not run git init.

## SCOPE

- Replace the /growth placeholder with a usable Mochi growth page.
- Read the current user pet and progress through Riverpod and IPetRepository.
- Show real name, level, experience, focus minutes, happiness, and a truthful empty/loading state when data is absent.
- Keep the page visually aligned with the existing Cozy Focus theme and the Phase 5 Mochi reference.
- Preserve the existing three-item bottom navigation and route contract.

## FILES_ALLOWED_TO_MODIFY

- lib/presentation/pages/ (new Mochi growth page only)
- lib/presentation/controllers/ (new bounded growth provider/controller only)
- lib/presentation/navigation/app_router.dart (replace the growth placeholder route target)
- test/presentation/ (focused Phase 5 Mochi growth widget/provider tests)
- outputs/ai_handoff/PHASE_5_PET_GROWTH_REPORT.md
- outputs/ai_handoff/CURRENT_STAGE.json

## FILES_PROTECTED

- lib/domain/models/pet_models.dart
- lib/domain/repositories/i_pet_repository.dart
- lib/data/, Drift schema, DAOs, migrations, and repositories
- FocusClock, FocusSessionEngine, RewardLedger, RewardService, StatisticsEngine
- Room, Craft, Inventory, placement, navigation item count, and existing Phase 0-4 behavior
- Dress, Collection, Rive, Settings, Notifications, and Sync implementation
- analysis_options.yaml and CI workflows

## REQUIRED_BEHAVIOR

- Existing PetProgress values must be rendered from repository data, never hard-coded as demo progress.
- Missing pet/progress must render an honest first-use/empty state, not fabricated level or XP.
- XP progress must be bounded and robust when values are incomplete or exceed a displayed threshold.
- The page must remain testable with an overridden petRepositoryProvider and current-user provider.
- No fake clickable controls. Any CTA must navigate to an implemented route or be disabled/omitted.
- Do not add persistence or new domain semantics in this slice.

## TESTS_REQUIRED

- Data-backed rendering of pet name, level, XP, focus minutes, and happiness.
- Missing-data empty state.
- /growth resolves to the Mochi page instead of the placeholder.
- Existing bottom navigation remains exactly three items and existing regression tests pass.

## LOCAL_GATE

Run dart format ., dart format --output=none --set-exit-if-changed ., flutter analyze --fatal-infos --no-pub (or document fallback), flutter test, flutter build apk --debug, and git diff --check.

## REPORT

Before returning, write outputs/ai_handoff/PHASE_5_PET_GROWTH_REPORT.md with BASE_SHA, changed files, tests, local gate results, and blockers. Do not self-approve.

