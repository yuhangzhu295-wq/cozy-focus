# Dress Product Decision & System Status

## 1. Factual System State

- **UI Status**: `PetDressPage` has exactly 4 preview entries (`basic_collar`, `cozy_scarf`, `beret_hat`, `gentleman_bowtie`) with disabled action button rendering `未连接` (`onPressed: null`).
- **Domain & Persistence Architecture**:
  - No outfit domain model or equipment slot enum exists in `lib/domain/models/`.
  - No DAO, repository, or Drift database table / migration exists in `lib/data/local/`.
  - No acquisition rule, unlock condition, ownership persistence, or production accessory binding exists.
- **Collection & Inventory State**:
  - Inventory quantity in Drift `inventory` table is the sole source of truth for collection ownership.
  - 8 of 10 collection catalog entries are craftable through `kCraftRecipeCatalog`.
  - 2 collection catalog entries (`sakura_branch`, `crystal_ball`) currently have no writer (no craft recipe or grant mechanism).

---

## 2. USER_DECISION_REQUIRED

Before any dress, equipment, or accessory feature can be implemented, product decisions are required for the following items:

1. **Launch Catalog & Item IDs**: Specification of the initial outfit catalog items, stable string IDs, names, icons/assets, and descriptions.
2. **Equipment Slots**: Enumeration of valid equipment slots (e.g. `head`, `neck`, `body`, etc.) and mutual exclusion rules.
3. **Acquisition Model**: Rules determining how outfits are obtained (focus milestones, craft recipes, coin shop, or achievements).
4. **Consumption & Duplicates**: Policy on whether outfits are unique permanent unlocks or consumable/stackable inventory items.
5. **Default Outfit**: What outfit/accessories (if any) the pet equips by default at initial launch.
6. **Unlock Conditions**: Level, growth stage, or companion affinity requirements for equipping outfits.
7. **Persistence Architecture**: Database schema definition for storing user-owned outfits and currently equipped items per slot.
8. **Rive Attachment & Rendering Contract**: Definition of how equipped accessories attach to the companion (e.g. Rive artboard layers, bones, nested artboards, or Flutter layer overlays).
