# P33 — Partial Pack + Capability Gating

Pack-first roadmap (`P31_P40_PACK_FIRST_ROADMAP.md`). Branch
`recovery/v4.2.1-rebuild`.

**Status: COMPLETE, verified on the device.** 1446/1446 tests, format clean,
analyze clean. Latest slice `036e13b`.

## The requirement, and what it actually was

> Do **not** require all production actions. `BehaviorDirector` must never select
> a missing capability. The UI shows truthful action completeness. **Do not
> silently count a fallback as an available action.**

A read-only audit came back with a verdict of **false**, and it was right: the
director's gate worked, and the gate was fed the wrong data.

`CompanionActionAvailabilityResolver.resolve` reads the compiled-in table, which
knows the three shipped companions. An installed pack is not in it, so the
resolver fell back to the **dog** — handing a pack thirteen capabilities while the
pack's own artwork was honest about the poses it does not ship. The pack was asked
for `focus_read` and drew an empty box.

Every existing test passed throughout. They hand the director a *synthetic*
`CompanionActionAvailability`, which proves the gate works and says nothing about
whether the gate is fed the truth.

## The fix, and why it is one lookup

`resolveForManifest` is now the single implementation. A built-in arrives with the
compiled-in manifest and its animation contract; an installed pack arrives with
the manifest read from its own directory and **no contract**, because a contract
is a statement about artwork we produced and there is none for a pack a user
brought — defaulting it to the dog's would report the dog's plan as the pack's
plan, the same defect in a different field.

`companionAvailabilityProvider` does the routing, and the director, the avatar and
the furniture panel all ask it. `resolve` keeps its built-in fallback and is
documented as built-ins only.

The negative proof is pinned as a test rather than described: for one installed
partial pack, the raw resolver says it can `focus_read` and the provider says it
cannot.

## The second defect, found by reading the first fix's output

The import preview for a pack shipping `idle` and `walk` reported eight actions as
"will be drawn as something else". Reading that honestly meant asking whether they
really are — and they were not.

A pack declaring `semanticFallback: {"focus_read": "idle"}` was **schedulable** for
`focus_read` (the behaviour side honours the declaration) and drew **nothing**
(`specForRendering` deliberately refuses to fall through to idle). So the
companion vanished for the whole of a focus session.

That refusal is right about the *implicit* idle and wrong about a *declared*
fallback. The two are different promises: a declared fallback is the pack saying
"if you ask for this, draw that" — an instruction, and honouring it is not a
substitution. `declaredFallbackFor` is now the middle step of `resolve` without
the implicit end, and the provider consults it last.

## Truthful completeness

`CompanionPackCompleteness` reports three answers, not two:

| | meaning |
|---|---|
| **ready** | the pack ships this action's own frames |
| **fallback** | the pack names it and will draw something else |
| **missing** | the pack never mentions it |

Folding `fallback` into `ready` overstates the pack; folding it into `missing`
understates what the companion can do. The reference is the app's own production
action vocabulary, taken as a union across contracts rather than a hardcoded list,
so it grows when the cat and rabbit get contracts of their own.

Shown on the import preview — before the user commits — and on the companion card,
through one shared widget so the two screens cannot answer differently.

## Verified on the device

A partial pack built by `tools/make_demo_pack.py --actions idle,walk`:

- import preview reads **动作 2 / 13**, with the note naming the three missing
  actions and the eight declared as drawn-as-something-else;
- the companion list shows **13 / 13** green for the complete pack and **2 / 13**
  amber for the partial one, side by side;
- the numbers reconcile exactly: 2 ready + 8 fallback + 3 missing = 13.

## Two vocabularies that overlap and neither contains the other

The contract's 13 actions include `walk`, `sit_down` and `stand_up`, which are
**animation states rather than poses** — drawable by id, absent from a pose-keyed
answer. So a pack shipping all thirteen reports ten *schedulable poses*, not
thirteen. Pinned by a test with the reason, because the next person to compare
those two numbers will otherwise read it as a bug.

## What P33 deliberately did not do

- **No second behaviour authority.** The provider is still one generic class
  parameterised by data; the director is still the only thing that picks.
- **No parity for user packs.** `multi_companion_parity_test` is an admission
  requirement for a companion *we ship*, and its built-in-only scope now says so
  with the reason: extending it to a user's pack would either fail every honest
  pack or push someone into faking actions to satisfy a test.
- **No substitute art.** Where a pack has nothing and declares nothing, the
  provider still draws nothing. Borrowing a built-in's frames would report a
  companion that is not there.

## Carried forward

- The furniture panel's *offer* is now gated on the pack's real capabilities, but
  the room's decision loop still records and applies a furniture effect before the
  director sees the committed action. The audit flagged it; it is a room-runtime
  change rather than a gating one and belongs with P35.
- `tools/productionise.py measure()` still reads `split()[-1]` as alpha, which is
  the palette index on the indexed PNGs the packs ship. P34 owns it.
- The cat and rabbit still have no geometry contract, so `manifest.py` refuses
  them. P34.
- `docs/companion_assets.md` is still stale (1024×1024 / 919 / 511 claimed;
  512×512 / ~458 / 255 real).

## Process notes

- A widget test that renders a pack reads frames from disk, and waiting on a
  file-backed image stream **hangs** rather than fails. That is why
  `PackBackedCompanionVisualProvider.specFor` is extracted from `build`: the
  decision is assertable without a widget tree, and the three-way choice between
  "draw the state", "draw the pose" and "draw nothing" is where the bugs were.
- The device's completeness badge is what found the second defect. A report that
  makes a claim is also a question about whether the claim is true.
