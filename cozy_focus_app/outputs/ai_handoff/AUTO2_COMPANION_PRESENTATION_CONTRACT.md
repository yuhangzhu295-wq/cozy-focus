# AUTO-2 Companion Presentation Contract

## Scope

AUTO-2 adds a pure, non-persisted presentation mapping. It does not add a
database table, an equipment system, a Rive asset, a timer, a provider, or a
new business rule.

## Authoritative Inputs

- Live focus state, when an already-restored focus controller provides it.
- Persisted HomeUIState.hasActiveSession for the home cold-start path.
- CraftState.activeJob for active craft state.
- FocusSessionUIState.elapsedSeconds and planned seconds when a future
  consumer needs focus progress.
- CraftJob.progressSeconds and CraftRecipe.requiredSeconds when a future
  consumer needs craft progress.
- PetProgress.level, PetProgress.experiencePoints, and
  PetProgress.happinessScore for display only.
- Widget-level reduced-motion accessibility information as a plain boolean.

## State Priority

1. A live session visual state wins.
2. A persisted active focus session maps to PetVisualState.focus.
3. An active craft job maps to PetVisualState.craft.
4. Otherwise the pet is idle.

Progress is a clamped ratio in the inclusive 0.0..1.0 range. A zero or
negative denominator returns 0.0. Happiness is the existing score clamped
to 0..100 and normalized to 0.0..1.0; this contract does not introduce
mood labels.

## Deferred Truths

- The home page intentionally does not subscribe to the one-second focus
  ticker in this slice. A later, measured refinement may provide live pause
  and celebration state without rebuilding the home page each tick.
- No real Rive asset exists. These values are substrate for a verified future
  adapter and do not claim Rive runtime completion.
- Equipment remains blocked because no product-authorized acquisition rule
  exists for the preview-only dress catalog.

## Review

Claude review for the AUTO-2 diff: P0 = 0, P1 = 0, P2 = 3.
Protected core changed: no.
