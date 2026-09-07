# Cozy Focus - DATA_MODEL.md

> Phase 0 Core Data Model Freeze | Generated 2026-09-07

---

## 1. FocusSession

The active/recent session. One active session at a time per user.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | Client-generated |
| user_id | UUID | NOT NULL, FK | |
| task_name | TEXT | NOT NULL | User-entered task label |
| category | TEXT | NOT NULL | FK to FocusCategory.id |
| mode | TEXT | NOT NULL | 'flow' / 'pomodoro' / 'custom' |
| target_seconds | INT | NOT NULL, DEFAULT 0 | 0 = unlimited (flow mode) |
| started_at | TIMESTAMPTZ | NOT NULL | Session start (UTC) |
| ended_at | TIMESTAMPTZ | NULLABLE | Set on completion/cancellation |
| pause_intervals | JSONB | NOT NULL, DEFAULT '[]' | Array of {pausedAt, resumedAt} |
| paused_seconds | INT | NOT NULL, DEFAULT 0 | Cached total pause duration |
| status | TEXT | NOT NULL | idle/running/paused/finishing/completed/cancelled/saved |
| note | TEXT | NULLABLE | User note after completion |
| mood | TEXT | NULLABLE | User mood after completion |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | pending/synced/conflict |

**Primary Key**: `id`
**Unique Constraint**: Only one session with status IN (running, paused, finishing) per user_id.
**Deletion Strategy**: Soft delete via status = 'cancelled'. Hard delete only on explicit user request + sync confirmation.
**Sync Strategy**: On save/update, insert into sync_outbox. SyncEngine upserts to Supabase by id.

---

## 2. FocusRecord

Immutable record of a completed and saved session. Created from FocusSession when status transitions to 'saved'.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | Same as originating FocusSession.id |
| user_id | UUID | NOT NULL | |
| task_name | TEXT | NOT NULL | |
| category | TEXT | NOT NULL | |
| mode | TEXT | NOT NULL | |
| target_seconds | INT | NOT NULL | |
| started_at | TIMESTAMPTZ | NOT NULL | |
| ended_at | TIMESTAMPTZ | NOT NULL | |
| elapsed_seconds | INT | NOT NULL | Computed: total wall - total paused |
| paused_seconds | INT | NOT NULL | |
| note | TEXT | NULLABLE | Editable after save |
| mood | TEXT | NULLABLE | Editable after save |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: `id`
**Idempotent**: Creating a FocusRecord with same id is a no-op (UPSERT).
**Deletion Strategy**: Soft delete flag. Never physically delete without user confirmation.
**Sync Strategy**: Outbox on create/update. Cloud upsert by id.
**Aggregation**: Weekly/Monthly/Yearly reports aggregate FROM this table. Never hardcode report data.

---

## 3. FocusCategory

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | e.g., 'study', 'work', 'read', 'exercise', 'custom_xxx' |
| user_id | UUID | NOT NULL | |
| name | TEXT | NOT NULL | Display name |
| icon | TEXT | NOT NULL | Icon identifier |
| color | TEXT | NOT NULL | Hex color |
| sort_order | INT | NOT NULL, DEFAULT 0 | |
| is_default | BOOL | NOT NULL, DEFAULT false | System-provided categories |
| created_at | TIMESTAMPTZ | NOT NULL | |

**Primary Key**: `id`
**Unique Constraint**: (user_id, name)
**Deletion Strategy**: Mark inactive; never delete if referenced by FocusRecord.

---

## 4. CraftJob

Active or completed crafting job.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| user_id | UUID | NOT NULL | |
| recipe_id | TEXT | NOT NULL | FK to CraftRecipe |
| progress_seconds | INT | NOT NULL, DEFAULT 0 | Focus seconds applied |
| required_seconds | INT | NOT NULL | From recipe |
| status | TEXT | NOT NULL | 'active' / 'completed' / 'cancelled' |
| started_at | TIMESTAMPTZ | NOT NULL | |
| completed_at | TIMESTAMPTZ | NULLABLE | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: `id`
**Idempotent Completion**: When progress_seconds >= required_seconds, complete ONCE. Mark completed_at. Generate ONE inventory item.
**Deletion Strategy**: Cancelled jobs retained for history.

---

## 5. CraftRecipe

Static recipe definitions. Can be bundled or fetched from server.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | e.g., 'wooden_shelf', 'cozy_lamp' |
| name | TEXT | NOT NULL | Display name |
| description | TEXT | NULLABLE | |
| icon | TEXT | NOT NULL | Asset path or identifier |
| required_seconds | INT | NOT NULL | Focus seconds needed |
| category | TEXT | NOT NULL | Furniture category |
| rarity | TEXT | NOT NULL | common/uncommon/rare/legendary |
| unlocked_by | TEXT | NULLABLE | Achievement or level requirement |

**Primary Key**: `id`
**Deletion Strategy**: Never delete. Mark deprecated if removed from active list.

---

## 6. InventoryItem

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| user_id | UUID | NOT NULL | |
| item_id | TEXT | NOT NULL | FK to CraftRecipe.id or reward item id |
| quantity | INT | NOT NULL, DEFAULT 0 | |
| unlocked_at | TIMESTAMPTZ | NULLABLE | First acquisition time |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: (user_id, item_id)
**Idempotent**: Craft completion increments quantity by 1. Duplicate completion attempts check CraftJob.status first.
**Deletion Strategy**: Quantity decrement on room placement (if consumable). Never delete row.

---

## 7. RoomItem

Placed furniture in the user's room.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | Placement instance id |
| user_id | UUID | NOT NULL | |
| item_id | TEXT | NOT NULL | FK to InventoryItem.item_id |
| x | DOUBLE | NOT NULL | Position x |
| y | DOUBLE | NOT NULL | Position y |
| scale | DOUBLE | NOT NULL, DEFAULT 1.0 | |
| rotation | DOUBLE | NOT NULL, DEFAULT 0.0 | Radians |
| z_index | INT | NOT NULL, DEFAULT 0 | Layer order |
| placed_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: `id`
**Deletion Strategy**: Remove placement -> delete row + increment inventory quantity.

---

## 8. Pet

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| user_id | UUID | NOT NULL | |
| species | TEXT | NOT NULL | 'mochi' (initial; extensible) |
| name | TEXT | NOT NULL | User-given name |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: `id`
**Unique Constraint**: (user_id, species) for MVP (one pet per species).

---

## 9. PetProgress

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| pet_id | UUID | PK, FK to Pet.id | |
| xp | INT | NOT NULL, DEFAULT 0 | Total accumulated XP |
| level | INT | NOT NULL, DEFAULT 1 | Derived from XP thresholds |
| bond | INT | NOT NULL, DEFAULT 0 | Bond/friendship points |
| mood | DOUBLE | NOT NULL, DEFAULT 0.5 | 0.0-1.0 |
| total_focus_seconds | INT | NOT NULL, DEFAULT 0 | Lifetime focus time with this pet |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: `pet_id`
**Level Calculation**: Level derived from XP using a progression table. NOT hardcoded.
**Mood Decay**: Mood decays over time if no focus sessions. Calculated on read, not by background timer.

---

## 10. PetMemory

Notable pet events / milestones.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| pet_id | UUID | NOT NULL, FK | |
| event_type | TEXT | NOT NULL | 'level_up', 'first_craft', 'streak_7', etc. |
| event_data | JSONB | NULLABLE | Additional event-specific data |
| occurred_at | TIMESTAMPTZ | NOT NULL | |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: `id`
**Unique Constraint**: (pet_id, event_type, occurred_at) to prevent duplicate milestone entries.

---

## 11. Achievement

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | e.g., 'first_focus', 'streak_7', 'craft_10' |
| user_id | UUID | NOT NULL | |
| unlocked | BOOL | NOT NULL, DEFAULT false | |
| unlocked_at | TIMESTAMPTZ | NULLABLE | |
| progress | INT | NOT NULL, DEFAULT 0 | Current progress toward unlock |
| target | INT | NOT NULL | Required progress to unlock |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: (id, user_id)
**Idempotent**: Unlocking an already-unlocked achievement is a no-op.

---

## 12. SyncState / sync_outbox

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| table_name | TEXT | NOT NULL | Which table this change belongs to |
| record_id | TEXT | NOT NULL | PK of the changed record |
| operation | TEXT | NOT NULL | 'upsert' / 'delete' |
| payload | JSONB | NOT NULL | Serialized record |
| created_at | TIMESTAMPTZ | NOT NULL | |
| attempts | INT | NOT NULL, DEFAULT 0 | Retry count |
| last_error | TEXT | NULLABLE | |
| status | TEXT | NOT NULL, DEFAULT 'pending' | pending/processing/synced/failed |

**Primary Key**: `id`
**Idempotent**: Duplicate outbox entries for same (table_name, record_id, operation) are deduplicated.
**Deletion Strategy**: Delete synced entries after confirmation. Retain failed for retry.

---

## 13. RewardLedger

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| session_id | UUID | PK | FK to FocusSession.id - ONE reward per session |
| user_id | UUID | NOT NULL | |
| xp | INT | NOT NULL, DEFAULT 0 | XP earned |
| craft_seconds | INT | NOT NULL, DEFAULT 0 | Craft progress seconds earned |
| settled_at | TIMESTAMPTZ | NOT NULL | When rewards were applied |
| sync_state | TEXT | NOT NULL, DEFAULT 'pending' | |

**Primary Key**: `session_id`
**Idempotent**: PK ensures one reward per session. Duplicate settlement attempts are rejected.
**No Double Rewards**: Fast repeated taps, app restarts, re-navigation to reward page all safe.

---

## Key Design Principles

1. **All time fields are UTC** (timestamptz). Display layer converts to local.
2. **All IDs are client-generated UUIDs**. No auto-increment. Enables offline creation.
3. **Every mutable table has sync_state**. Outbox pattern for eventual consistency.
4. **Reports are ALWAYS aggregated from FocusRecord**. Never pre-computed or hardcoded.
5. **Rewards are idempotent**. session_id as PK in reward_ledger prevents duplicates.
6. **Soft delete preferred**. Physical deletion only after sync confirmation.
7. **Pause intervals stored as structured data**. Not a simple counter.
