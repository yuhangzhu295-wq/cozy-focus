# Cozy Focus - REUSE_MATRIX.md

> Phase 0 Open-Source Reuse Audit | Generated 2026-09-07

## Evaluation Criteria

| Decision | Meaning |
|----------|---------|
| **REUSE** | Add as pub.dev dependency directly |
| **ADAPT** | Use as design/pattern reference; extract patterns into own code |
| **REFERENCE_ONLY** | Read for product/architecture ideas; do NOT copy code |
| **REJECT** | Not suitable for this project |

---

## 1. rive-app/rive-flutter

| Field | Value |
|-------|-------|
| URL | https://github.com/rive-app/rive-flutter |
| License | MIT |
| Last Maintained | Active (2026, regular releases on pub.dev) |
| Tech Stack | Flutter, Rive Runtime, Skia |
| Reusable Modules | Rive widget, State Machine input control, ViewModel/data binding |
| Suitable as Dependency | Yes - official Rive runtime for Flutter |
| Design Pattern Reference | State Machine input driving, artboard lifecycle |
| Fork Recommended | No - use as dependency via `rive: ^x.x.x` |
| Commercial Risk | None (MIT) |
| **Decision** | **REUSE** |
| Notes | Core dependency for PetAnimationEngine -> RivePetAdapter. No .riv asset included in design pack; runtime only. |

## 2. flame-engine/flame

| Field | Value |
|-------|-------|
| URL | https://github.com/flame-engine/flame |
| License | MIT |
| Last Maintained | Active (major releases through 2026) |
| Tech Stack | Flutter, Dart, 2D game engine |
| Reusable Modules | Component system, sprite management, collision, camera |
| Suitable as Dependency | Conditional - only if Room Decoration (09) requires complex multi-entity scene |
| Design Pattern Reference | Component/ECS pattern for room items |
| Fork Recommended | No |
| Commercial Risk | None (MIT) |
| **Decision** | **REJECT (MVP)** |
| Notes | Room decoration in Cozy Focus is furniture grid placement, not a game scene. Standard Flutter widgets + CustomPainter + drag-and-drop suffice. Flame adds unnecessary bundle size and complexity. Re-evaluate only if room scene becomes a 2D interactive world. |

## 3. supabase/supabase-flutter

| Field | Value |
|-------|-------|
| URL | https://github.com/supabase/supabase-flutter |
| License | MIT |
| Last Maintained | Active (2026, regular pub.dev releases) |
| Tech Stack | Flutter, Supabase SDK (Auth, Postgres, Storage, Realtime) |
| Reusable Modules | Auth, Postgres REST/Realtime, Storage, RLS |
| Suitable as Dependency | Yes - for cloud sync, auth, remote data |
| Design Pattern Reference | Offline-first + sync pattern with RLS |
| Fork Recommended | No - use as dependency |
| Commercial Risk | None (MIT) |
| **Decision** | **REUSE** |
| Notes | Used for SyncEngine cloud side. Local-first with Drift as primary; Supabase handles account, sync, and backup. Not blocking for offline MVP. |

## 4. simolus3/drift

| Field | Value |
|-------|-------|
| URL | https://github.com/simolus3/drift |
| License | MIT |
| Last Maintained | Active (2026, stable releases) |
| Tech Stack | Flutter/Dart, SQLite, code generation |
| Reusable Modules | Type-safe queries, migrations, DAOs, reactive streams |
| Suitable as Dependency | Yes - local-first data layer foundation |
| Design Pattern Reference | DAO pattern, migration versioning |
| Fork Recommended | No - use as dependency |
| Commercial Risk | None (MIT) |
| **Decision** | **REUSE** |
| Notes | Core local DB. Maps directly to schema_draft.sql. Handles FocusSession, CraftJob, Inventory, RoomItem, RewardLedger, Pet tables. Outbox table for sync queue. |

## 5. antigones/flutter_pomodoro_cat

| Field | Value |
|-------|-------|
| URL | https://github.com/antigones/flutter_pomodoro_cat |
| License | MIT |
| Last Maintained | Inactive (last commit ~2020, old Flutter SDK) |
| Tech Stack | Flutter, basic timer, simple cat sprite |
| Reusable Modules | Timer state concept, pet-in-timer UX idea |
| Suitable as Dependency | No - outdated SDK, minimal architecture |
| Design Pattern Reference | Product concept only (pet + pomodoro combo) |
| Fork Recommended | No |
| Commercial Risk | None (MIT) |
| **Decision** | **REFERENCE_ONLY** |
| Notes | Useful only as conceptual validation that pet + focus timer works as a product. Code is too outdated and simple to reuse. Cozy Focus architecture is far more complex (state machine, Rive, craft, reports). |

## 6. Kabanya/Pomodoist

| Field | Value |
|-------|-------|
| URL | https://github.com/Kabanya/Pomodoist |
| License | AGPL-3.0-only |
| Last Maintained | Active (2025-2026) |
| Tech Stack | Flutter, Supabase, task management, reports |
| Reusable Modules | Task/focus/reports architecture, Supabase integration patterns |
| Suitable as Dependency | **NO - AGPL** |
| Design Pattern Reference | Yes - task management, report aggregation, session lifecycle |
| Fork Recommended | **NO - AGPL contaminates commercial closed-source** |
| Commercial Risk | **HIGH - AGPL-3.0 requires derivative works to be open-sourced** |
| **Decision** | **REFERENCE_ONLY** |
| Notes | Strong product/architecture reference for task categories, focus session lifecycle, and report views. STRICTLY read-only reference. Do NOT copy code, file structures, or substantial logic. Only learn from their product decisions and UX patterns. |

## 7. MaikuB/flutter_local_notifications

| Field | Value |
|-------|-------|
| URL | https://github.com/MaikuB/flutter_local_notifications |
| License | BSD-3-Clause |
| Last Maintained | Active (2026) |
| Tech Stack | Flutter, platform channels (iOS/Android) |
| Reusable Modules | Local notification scheduling, click handling, channel config |
| Suitable as Dependency | Yes |
| Design Pattern Reference | N/A |
| Fork Recommended | No |
| Commercial Risk | None (BSD-3) |
| **Decision** | **REUSE** |
| Notes | Standard Flutter notification package. Used for NotificationService: session reminders, completion alerts, background timer status. |

## 8. flutter_heatmap_calendar (pub.dev packages)

| Field | Value |
|-------|-------|
| URL | Multiple implementations on pub.dev |
| License | MIT (most forks) |
| Last Maintained | Variable |
| Tech Stack | Flutter, CustomPainter |
| Reusable Modules | GitHub-style contribution heatmap widget |
| Suitable as Dependency | Evaluate best maintained pub.dev package at implementation time |
| Design Pattern Reference | Heatmap rendering, date-intensity mapping |
| Fork Recommended | No |
| Commercial Risk | None (MIT) |
| **Decision** | **ADAPT** |
| Notes | For 05D Calendar View and 08 Year Report heatmap. May use a pub.dev package directly if well maintained, or build custom widget using the pattern. Data MUST come from real FocusRecord aggregation. |

---

## Summary

| Decision | Projects |
|----------|----------|
| **REUSE** (pub.dev dependency) | rive-flutter, supabase-flutter, drift, flutter_local_notifications |
| **ADAPT** (pattern extraction) | flutter_heatmap_calendar |
| **REFERENCE_ONLY** (ideas only) | flutter_pomodoro_cat, Pomodoist |
| **REJECT** | flame (MVP scope) |
