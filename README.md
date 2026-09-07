# Cozy Focus — Phase 0 Architecture Freeze

> **Flutter pomodoro + pet companion app**
> Mochi cat · Rive animations · Room decoration · Craft system · Drift local DB · Supabase sync

## Phase 0 Deliverables

| Document | Purpose |
|---|---|
| [REUSE_MATRIX.md](outputs/REUSE_MATRIX.md) | Open-source reuse audit |
| [ARCHITECTURE_DECISION.md](outputs/ARCHITECTURE_DECISION.md) | Layered architecture, engine definitions |
| [FOCUS_SESSION_STATE_MACHINE.md](outputs/FOCUS_SESSION_STATE_MACHINE.md) | Timestamp-based timer state machine |
| [DATA_MODEL.md](outputs/DATA_MODEL.md) | Core data models |
| [PET_ANIMATION_ARCHITECTURE.md](outputs/PET_ANIMATION_ARCHITECTURE.md) | PetStateController -> RivePetAdapter |
| [IMPLEMENTATION_PLAN.md](outputs/IMPLEMENTATION_PLAN.md) | Phased implementation plan |
| [ARCHITECTURE_GUARDRAILS.md](outputs/ARCHITECTURE_GUARDRAILS.md) | Hard constraints for all future agents |

## Status

- [x] Phase 0 complete
- [ ] Phase 1 pending user approval

## Tech Stack

- Flutter (iOS + Android)
- Drift (local SQLite)
- Supabase (auth + sync)
- Rive (Mochi cat animations)
- Riverpod (state management)
- go_router (navigation)
- flutter_local_notifications
