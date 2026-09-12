# Phase 5 Scope And Plan

## Baseline

- BASE_SHA: 5bcdf5e2d3f6ec18990dbdf744497ae3fa565d22
- APP_WORKDIR: C:/Users/zyu33/Documents/Codex/2026-09-07/new-chat/cozy_focus_app
- GIT_ROOT: C:/Users/zyu33/Documents/Codex/2026-09-07/new-chat
- Workspace contract: git rev-parse --show-prefix must be cozy_focus_app/.

## Current Phase 5 State

The bounded PHASE-5-PET-GROWTH slice is approved. Its real data-backed Mochi growth page is complete and must not be re-audited or reimplemented.

The V4.1 migration flow identifies the remaining Growth slices as:

1. Growth > Dress (this plan)
2. Growth > Collection (separate later slice)

Room, Craft, and Room Inventory are already completed V4.1 surfaces and are outside this slice.

## Authorized Next Slice

Implement only PHASE-5-PET-DRESS: a reachable Growth > Dress presentation slice aligned to the 10A_宠物装扮.png reference.

The page may provide:

- A Mochi identity/preview area using the existing pet/avatar presentation conventions.
- A bounded outfit catalog matching the current product reference.
- Truthful state labels and disabled actions while outfit ownership/equipment data is not present in the current domain/data layer.
- Navigation that preserves the existing exactly-three-item bottom navigation contract.

The page must not claim that an outfit is owned or equipped unless that state comes from an existing repository-backed contract. Do not invent persistence, ownership, equip mutations, or example progress values.

## Files Allowed To Modify

- lib/presentation/pages/ for the Dress page and tightly related presentation-only widgets.
- lib/presentation/controllers/ only for a narrowly scoped Dress presentation controller if the page needs one.
- lib/presentation/navigation/app_router.dart for the new route.
- test/presentation/ for focused Dress and navigation regression tests.
- outputs/ai_handoff/ for the implementation report and current bounded-stage metadata.

Do not modify domain, data, database, protected core, or existing Pet Growth implementation unless a compile-safe route import requires it.

## Protected And Explicitly Excluded Areas

- FocusClock, FocusSessionEngine, RewardLedger, SettlementDao, StatisticsEngine.
- Pet domain/data models and repositories.
- Room placement, CraftEngine, inventory ownership, and existing craft semantics.
- Rive, PetStateController, animation engine work, Settings, Notifications, Sync.
- Collection implementation in the same round.
- New backend or database schema for outfits.
- Full repository audit or reopening completed V4.1 slices.

## Required Tests

- Dress route resolves to the new page.
- Existing pet/avatar presentation remains truthful when pet data is absent.
- Outfit cards do not expose fake equip actions or fabricated ownership.
- Bottom navigation remains exactly three items and routes Home/Records/Growth correctly.
- Existing Mochi Growth and Phase 0-4 regression tests remain green.

## Required Local Gate

Run after implementation:

dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --no-pub
flutter test
flutter build apk --debug
git diff --check

The implementation subagent must report the new total test count and must not self-approve. The primary model reviews the actual diff and report before any commit or push.

## Acceptance Criteria

- Dress is reachable from a real route and renders without fabricated outfit data.
- No empty onPressed: () {} or other fake clickable action is introduced.
- No protected layer is changed.
- UI follows the existing app theme and keeps layout usable on narrow screens.
- Focused tests cover the new route and honest unavailable-data behavior.
- All required local gates pass.
- Remote CI for the exact pushed HEAD is green before this slice is marked approved.

## Next-Step Boundary

After this bounded Dress slice is approved, stop and wait for a new user-authorized goal. Do not begin Collection, Rive, Settings, Notifications, Sync, or Phase 6 automatically.
