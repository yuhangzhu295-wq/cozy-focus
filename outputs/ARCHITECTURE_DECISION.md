# Cozy Focus - ARCHITECTURE_DECISION.md

> Phase 0 Architecture Freeze | Generated 2026-09-07

---

## 1. Flutter App Structure

```
cozy_focus_app/
  lib/
    main.dart
    app.dart
    core/                          # Shared utilities, constants, theme, extensions
      clock/
        focus_clock.dart           # FocusClock: timestamp-based elapsed calculation
        focus_clock_impl.dart
      di/
        service_locator.dart       # Dependency injection (get_it or riverpod)
      theme/
      constants/
      extensions/
      l10n/                        # i18n
    domain/                        # Domain Layer (pure Dart, no Flutter imports)
      models/
        focus_session.dart
        focus_record.dart
        focus_category.dart
        craft_job.dart
        craft_recipe.dart
        inventory_item.dart
        room_item.dart
        pet.dart
        pet_progress.dart
        pet_memory.dart
        achievement.dart
        sync_state.dart
        reward_entry.dart
      repositories/                # Abstract repository interfaces
        focus_session_repository.dart
        focus_record_repository.dart
        craft_repository.dart
        inventory_repository.dart
        room_repository.dart
        pet_repository.dart
        reward_repository.dart
        sync_repository.dart
      services/                    # Domain services / use cases
        focus_session_engine.dart
        statistics_engine.dart
        craft_engine.dart
        room_engine.dart
        reward_service.dart
    data/                          # Data Layer
      local/
        database/
          app_database.dart        # Drift database definition
          tables/                  # Drift table definitions
          daos/                    # Drift DAOs
          migrations/
        data_sources/
          local_focus_data_source.dart
          local_craft_data_source.dart
          local_pet_data_source.dart
          local_room_data_source.dart
      remote/
        supabase/
          supabase_focus_data_source.dart
          supabase_sync_service.dart
          supabase_auth_service.dart
      repositories/                # Concrete repository implementations
        focus_session_repository_impl.dart
        focus_record_repository_impl.dart
        craft_repository_impl.dart
        inventory_repository_impl.dart
        room_repository_impl.dart
        pet_repository_impl.dart
        reward_repository_impl.dart
        sync_repository_impl.dart
    presentation/                  # Presentation Layer
      controllers/                 # ViewModels / Controllers (Riverpod providers)
        focus_session_controller.dart
        home_controller.dart
        progress_controller.dart
        craft_controller.dart
        room_controller.dart
        pet_controller.dart
        settings_controller.dart
      pages/
        home/                      # 01
        focus_setup/               # 02
        focus_active/              # 03, 03A, 03B, 03C
        focus_complete/            # 04, 04A, 04B
        progress/                  # 05, 05A, 05B, 05C, 05D
        reports/                   # 06, 07, 08, 08A
        craft/                     # 09, 09A, 09B, 09C
        pet/                       # 10, 10A, 10B
        settings/                  # 12
        empty_state/               # 14
      widgets/                     # Shared reusable widgets
      navigation/
        app_router.dart
    animation/                     # Pet Animation Layer
      pet_state_controller.dart
      pet_animation_engine.dart    # Abstract interface
      adapters/
        rive_pet_adapter.dart
        fallback_pet_adapter.dart
      models/
        pet_visual_state.dart
    services/                      # Platform services
      notification_service.dart    # 13
      sync_engine.dart             # 15
      app_lifecycle_service.dart   # Background/foreground/resume
  test/
  integration_test/
  assets/
    rive/                          # .riv files (when available)
    images/
    fonts/
```

---

## 2. Layer Responsibilities

### Domain Layer
- Pure Dart. No Flutter framework imports.
- Contains: models, abstract repository interfaces, domain services/engines.
- **FocusSessionEngine**: manages session state machine transitions.
- **StatisticsEngine**: aggregates FocusRecords into daily/weekly/monthly/yearly stats.
- **CraftEngine**: manages craft job progress, recipe validation, completion.
- **RoomEngine**: manages room item placement, collision, persistence.
- **RewardService**: idempotent reward settlement keyed by session_id.

### Data Layer
- Implements repository interfaces from Domain.
- **Local**: Drift (SQLite) database with typed DAOs, migrations, reactive streams.
- **Remote**: Supabase client for auth, sync, backup.
- **Outbox pattern**: local writes queue to `sync_outbox` table; SyncEngine processes when online.

### Presentation Layer
- Flutter widgets and pages.
- Controllers/ViewModels (Riverpod StateNotifier or Notifier).
- **NEVER** accesses database directly.
- **NEVER** calculates statistics or rewards.
- Only reads state from controllers and dispatches user intents.

### Animation Layer
- Separate from Presentation.
- **PetStateController**: translates business state into PetVisualState.
- **PetAnimationEngine**: abstract interface for driving animations.
- **RivePetAdapter**: concrete Rive implementation.
- **FallbackPetAdapter**: static/simple animation when .riv unavailable.

---

## 3. Data Flow (Strict)

```
UI (Widget)
    |
    v
Controller / ViewModel (Riverpod)
    |
    v
UseCase / Service (Domain)
    |
    v
Repository (Abstract Interface)
    |
    v
Local Data Source (Drift)  +  Remote Data Source (Supabase)
```

**Prohibited shortcuts:**
- UI -> Database (direct)
- UI -> SQL query
- Widget -> Repository (bypassing controller)
- Controller -> raw SQL

---

## 4. Core Engine Definitions

### FocusSessionEngine
- Owns the session state machine (idle -> running -> paused -> completed/cancelled -> saved).
- Calculates elapsed time from timestamps, NOT from Timer.periodic.
- Manages pause intervals array.
- Handles background/foreground/process-death recovery.
- Single source of truth for "how long has this session been."

### FocusRecordRepository
- CRUD for saved FocusRecords.
- Provides reactive streams for today/history/filtered queries.
- Aggregation queries for statistics.

### StatisticsEngine
- Takes FocusRecords and produces daily/weekly/monthly/yearly aggregations.
- NEVER uses hardcoded data.
- All stats derived from real FocusRecord table.

### CraftEngine
- Maps focus minutes to craft progress (from reward_ledger craft_seconds).
- Validates recipe requirements.
- Completes craft job -> creates inventory item (idempotent).

### RoomEngine
- Manages room item placement (x, y, scale, rotation, z_index).
- Persists layout to room_items table.
- Validates placement constraints.

### PetStateController
- Reads business state (session status, craft status, time of day, user interaction).
- Outputs PetVisualState enum to PetAnimationEngine.
- Overlays (blink, breath, ear twitch, tail wag) managed internally by animation layer.

### PetAnimationEngine
- Abstract interface (see domain_interfaces.dart).
- Methods: initialize, setState, setMood, setFocusProgress, setCraftProgress, setReducedMotion, triggerInteract, triggerCelebrate, dispose.

### NotificationService
- Wraps flutter_local_notifications.
- Schedules/cancels notifications for session end, break reminders.
- Handles notification click -> navigate to active session.

### SyncEngine
- Processes outbox queue when online.
- Idempotent upserts to Supabase.
- Conflict resolution: last-write-wins with server timestamp.
- Never blocks local operations.

---

## 5. State Management

**Decision: Riverpod**

Rationale:
- Compile-safe dependency injection.
- Reactive streams integrate naturally with Drift watch queries.
- Supports async providers for initialization.
- No runtime reflection.
- Well-maintained, widely adopted in Flutter ecosystem.

Alternative considered: Bloc. Riverpod preferred for less boilerplate in a project with many independent reactive data streams.

---

## 6. Local-First Data Architecture

```
                   +-------------------+
                   |   Supabase Cloud  |
                   |  (Auth + Backup)  |
                   +--------+----------+
                            ^
                            | SyncEngine (when online)
                            |
+---------------------------+---------------------------+
|                    Local SQLite (Drift)                |
|                                                       |
|  focus_sessions | craft_jobs | inventory_items         |
|  room_items | reward_ledger | pet_progress             |
|  sync_outbox (pending changes queue)                   |
|                                                       |
|  ** This is the FACT SOURCE for daily operations **   |
+-------------------------------------------------------+
```

- Local database is the daily operation fact source.
- Cloud handles account management and cross-device sync.
- Offline mode: all core features work without network.
- Online: SyncEngine drains outbox, pulls remote changes.

---

## 7. Recommended pub.dev Dependencies

| Package | Purpose | License |
|---------|---------|---------|
| `drift` + `drift_dev` + `sqlite3_flutter_libs` | Local SQLite ORM | MIT |
| `rive` | Rive animation runtime | MIT |
| `supabase_flutter` | Auth + cloud sync | MIT |
| `flutter_local_notifications` | Local notifications | BSD-3 |
| `flutter_riverpod` / `riverpod` | State management | MIT |
| `go_router` | Declarative routing | BSD-3 |
| `uuid` | UUID generation for primary keys | MIT |
| `intl` | i18n / date formatting | BSD-3 |
| `freezed` + `json_serializable` | Immutable models + serialization | MIT |
| `path_provider` | Local file paths | BSD-3 |
| `connectivity_plus` | Network status for sync | BSD-3 |
| `wakelock_plus` | Keep screen on during focus | BSD-3 |
