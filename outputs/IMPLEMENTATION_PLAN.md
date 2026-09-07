# Cozy Focus - IMPLEMENTATION_PLAN.md

> Phase 0 Implementation Plan | Generated 2026-09-07

---

## Phase Overview

```
Phase 0: Audit + Architecture Freeze (THIS DOCUMENT)
Phase 1: Domain + Data Layer
Phase 2: Focus Core (02 -> 03 -> 03A -> 03B -> 03C -> 04 -> 04A -> 04B -> 01)
Phase 3: Records & Reports (05A -> 05B -> 05C -> 05D -> 05 -> 06 -> 07 -> 08 -> 08A)
Phase 4: Craft / Room (09A -> 09B -> 09C -> 09)
Phase 5: Pet Progression (10 -> 10A -> 10B)
Phase 6: Pet Animation (11 -> 11A -> 11C -> 11B -> 11E -> 11F -> 11H -> 11I -> 11G -> 11J -> 11K -> 11D)
Phase 7: System (12 -> 13 -> 14 -> 15)
Phase 8: Full QA
```

---

## Phase 1: Domain + Data Layer

| Item | Detail |
|------|--------|
| **Goal** | Establish real data fact source before any UI |
| **Dependencies** | Phase 0 complete (this document) |
| **Design Docs** | implementation/01_schema_draft.sql, implementation/02_domain_interfaces.dart, reference/01_技术架构契约.md |
| **Prompts** | prompts/00_总控强提示词_Codex_V2.md |
| **Expected Files** | lib/data/local/database/, lib/domain/models/, lib/domain/repositories/, lib/domain/services/focus_session_engine.dart, lib/core/clock/ |
| **Tests** | Unit tests for FocusClock, FocusSessionEngine state transitions, Repository CRUD, RewardLedger idempotency |
| **Acceptance** | 1) Create active session 2) Background simulate -> elapsed recovers from timestamps 3) Pause/resume correct 4) completed/saved separation works 5) Same session reward cannot double-settle |
| **Risk** | Drift code generation setup; ensure build_runner works before proceeding |
| **Allowed for Later Models** | Implement concrete DAOs, add new columns with migration |
| **Frozen (No Later Changes Without Review)** | FocusSessionEngine state machine, FocusClock interface, RewardLedger PK design, Repository abstract interfaces |

---

## Phase 2: Focus Core

| Item | Detail |
|------|--------|
| **Goal** | Complete the start-to-finish focus session UI flow |
| **Order** | 02 -> 03 -> 03A -> 03B -> 03C -> 04 -> 04A -> 04B -> 01 |
| **Dependencies** | Phase 1 (all domain models, repositories, FocusSessionEngine) |
| **Design Docs** | designs/02, 03, 03A, 03B, 03C, 04, 04A, 04B, 01 .png |
| **Prompts** | prompts/02, 03, 03A, 03B, 03C, 04, 04A, 04B, 01 .md |
| **Expected Files** | lib/presentation/pages/focus_setup/, focus_active/, focus_complete/, home/; lib/presentation/controllers/ |
| **Tests** | Widget tests for each page, integration test for full flow: setup -> start -> bg -> resume -> pause -> end -> save -> reward -> home refresh |
| **Acceptance** | Gate 2 from execution plan: full flow from home to reward and back with real data |
| **Risk** | Background/lock screen behavior varies by OS; test on both iOS Simulator and Android Emulator |
| **Allowed for Later Models** | UI polish, animation hookup, theme refinement |
| **Frozen** | FocusSessionEngine integration, timestamp-based timing, reward idempotency flow |

---

## Phase 3: Records & Reports

| Item | Detail |
|------|--------|
| **Goal** | Real-data records, history, calendar, and aggregated reports |
| **Order** | 05A -> 05B -> 05C -> 05D -> 05 -> 06 -> 07 -> 08 -> 08A |
| **Dependencies** | Phase 2 (saved FocusRecords exist) |
| **Design Docs** | designs/05A-05D, 05, 06, 07, 08, 08A .png |
| **Prompts** | Corresponding prompts/ .md files |
| **Expected Files** | lib/presentation/pages/progress/, reports/; lib/domain/services/statistics_engine.dart |
| **Tests** | Unit tests for StatisticsEngine aggregation (daily, weekly, monthly, yearly); widget tests for each view; cross-month/cross-year edge cases |
| **Acceptance** | Gate 3: new session visible in today/history immediately; edit note/category/mood reflects in aggregation; calendar heatmap real; cross-date test pass |
| **Risk** | Timezone handling in aggregation; ensure UTC storage + local display |
| **Allowed for Later Models** | Chart styling, heatmap color tuning, 08A share card design |
| **Frozen** | StatisticsEngine aggregation logic, FocusRecord query interface |

---

## Phase 4: Craft / Room

| Item | Detail |
|------|--------|
| **Goal** | Craft system + inventory + room decoration with real data |
| **Order** | 09A -> 09B -> 09C -> 09 |
| **Dependencies** | Phase 2 (focus minutes generate craft_seconds via RewardLedger) |
| **Design Docs** | designs/09A, 09B, 09C, 09 .png |
| **Prompts** | Corresponding prompts/ .md files |
| **Expected Files** | lib/presentation/pages/craft/; lib/domain/services/craft_engine.dart, room_engine.dart |
| **Tests** | Unit tests for CraftEngine progress, completion idempotency; widget tests for craft list, details, inventory; integration for room drag-and-drop persistence |
| **Acceptance** | Gate 4: focus minutes advance craft; craft completes once; inventory accurate; room layout persists across restart |
| **Risk** | Room drag-and-drop UX complexity; keep simple for MVP |
| **Allowed for Later Models** | Room visual polish, new recipes, furniture art assets |
| **Frozen** | CraftEngine completion logic, inventory ledger, room persistence schema |

---

## Phase 5: Pet Progression

| Item | Detail |
|------|--------|
| **Goal** | Pet XP, level, bond, mood, outfit, collection - all from real data |
| **Order** | 10 -> 10A -> 10B |
| **Dependencies** | Phase 2 (RewardLedger XP), Phase 4 (inventory for outfits) |
| **Design Docs** | designs/10, 10A, 10B .png |
| **Prompts** | Corresponding prompts/ .md files |
| **Expected Files** | lib/presentation/pages/pet/; lib/domain/models/pet*.dart |
| **Tests** | Unit tests for XP->level calculation, bond accumulation; widget tests for growth/outfit/collection views |
| **Acceptance** | Gate 5: XP/Bond from domain rules; level not hardcoded; outfits from inventory; collection locked/unlocked real; persists across restart |
| **Risk** | Level progression balance; keep configurable via progression table |
| **Allowed for Later Models** | New pet species, additional outfits, mood decay tuning |
| **Frozen** | XP/level calculation interface, PetProgress schema |

---

## Phase 6: Pet Animation

| Item | Detail |
|------|--------|
| **Goal** | PetAnimationEngine + all 11 motion storyboards |
| **Order** | 11 (engine) -> 11A -> 11C -> 11B -> 11E -> 11F -> 11H -> 11I -> 11G -> 11J -> 11K -> 11D |
| **Dependencies** | Phase 5 (PetStateController needs pet state); PetAnimationEngine interface from Phase 0 |
| **Design Docs** | designs/motion_storyboards/11A-11K .png |
| **Prompts** | prompts/11, 11A-11K .md |
| **Expected Files** | lib/animation/ (engine, adapters, controllers) |
| **Tests** | Unit tests for state transitions; verify Reduced Motion disables non-essential overlays; verify background stops rendering |
| **Acceptance** | Gate 6: pages only set PetVisualState; Reduced Motion works; background pauses render; resume restores correct state; no fake .riv |
| **Risk** | .riv asset not available - FallbackPetAdapter must be complete and tested. Do NOT create fake .riv files. |
| **Allowed for Later Models** | Actual .riv integration when art asset delivered |
| **Frozen** | PetAnimationEngine interface, PetStateController mapping, overlay rules |

---

## Phase 7: System

| Item | Detail |
|------|--------|
| **Goal** | Settings, notifications, empty states, offline/sync |
| **Order** | 12 -> 13 -> 14 -> 15 |
| **Dependencies** | Phase 2 (notifications need active session), Phase 1 (sync outbox) |
| **Design Docs** | designs/12, 13, 14, 15 .png |
| **Prompts** | Corresponding prompts/ .md files |
| **Expected Files** | lib/presentation/pages/settings/, empty_state/; lib/services/notification_service.dart, sync_engine.dart |
| **Tests** | Integration tests for notification click -> session resume; offline focus -> save -> sync on reconnect |
| **Acceptance** | Gate 7: settings actually change behavior; notification navigates correctly; empty states show real empty (not fake data); airplane mode focus+save works; reconnect syncs |
| **Risk** | Platform-specific notification behavior (iOS vs Android permissions) |
| **Allowed for Later Models** | Notification wording, sync conflict resolution refinement |
| **Frozen** | SyncEngine outbox pattern, NotificationService interface |

---

## Phase 8: Full QA

| Item | Detail |
|------|--------|
| **Goal** | Complete P0 verification |
| **Dependencies** | All phases complete |
| **QA Doc** | qa/00_全流程验收矩阵.md (NOTE: this file is MISSING from the design pack - must be created) |
| **Commands** | `dart format .`, `flutter analyze`, `flutter test`, `flutter test integration_test` |
| **Acceptance** | All P0 items pass; no fake buttons/stats; no duplicate rewards; offline works; recovery works; unrun tests explicitly marked |

---

## Missing Files from Design Pack

The following files are referenced in execution_order.json and documentation but do NOT exist in the pack:

| File | Referenced By | Impact |
|------|--------------|--------|
| `reference/01_技术架构契约.md` | execution_order.json Phase 0, multiple prompts | HIGH - architecture constraints missing. Covered by this document's ARCHITECTURE_DECISION.md |
| `reference/02_动态资产契约.md` | execution_order.json Phase 0, animation prompts | HIGH - Rive asset contract missing. Covered by PET_ANIMATION_ARCHITECTURE.md |
| `qa/00_全流程验收矩阵.md` | execution_order.json Phase 0 and 8 | HIGH - acceptance criteria missing. Must be created in Phase 1 or early Phase 2 |
| `04_完成定义与验收方法.md` | Root docs, Phase 8 | MEDIUM - completion definition missing. Partially covered by 00_使用方法_必读.md section 7 |
| `designs/03_专注中.png` | prompts/03 | Verify: may exist with encoding-mangled name. Check on disk. |

**Recommendation**: Create stubs for missing files before Phase 1, or accept the replacement documents generated in this Phase 0.
