# P31 — Custom Pet Technical Spike

Bounded spike, not a product commitment. Read-only architecture audit at
`recovery/v4.2.1-rebuild` @ `2b765ff`.

```
PROVIDER_ACCESS: BLOCKED_EXTERNAL
P31_GATE:        BLOCKED
```

**No implementation was done.** Two reasons, and the second is the more
important one.

## 1. The provider is unreachable

Probed before anything else, per §24:

```
GOOGLE_APPLICATION_CREDENTIALS   <unset>
GOOGLE_CLOUD_PROJECT             <unset>
VERTEX_AI_PROJECT                <unset>
ADC file (~/.config/gcloud/…)    ABSENT
gcloud                           NOT INSTALLED
google/vertex deps in pubspec    none
```

No credentials, no project, no CLI. The spec forbids substituting another paid
provider silently and forbids calling the Flow browser path complete. So the
photo → companion proposition is `BLOCKED_EXTERNAL`, and no amount of green
infrastructure work may be reported as a pass.

## 2. The audit found conflicts that must be settled before implementation

The spec says to stop before implementation if architecture conflicts exist. Two
do, and neither is a code problem — both are decisions.

**A three-action pack cannot be registered as a fourth built-in companion.**
`multi_companion_parity_test.dart:25-51,53-128` iterates the profiles and forces
every companion to ship **the same full action set, frame targets and loop modes
as the dog** — thirteen actions. P31 promises three. Registering a three-action
pack as a built-in would either fail that gate or require faking the other ten,
which the spec forbids outright. The audit's recommendation is to keep the spike's
three-action contract **isolated** from the built-in parity rule rather than
weaken the rule.

**`room_sit` still draws idle.** `animation_state_machine_data.dart:80-102`
projects `room_sit → idle`, `dog/manifest.json:231-255` has only a *semantic*
fallback and no `room_sit` frames, and `sit_down` is a one-shot transition into a
seated state, not a sustained sit. So "sit works" is not claimable today even for
the built-ins — the same gap P28 recorded. A spike that counts the last frame of
`sit_down`, or a renamed idle, as a sit would be reporting a fallback as success.

**A third observation, worth recording separately.** The room starts its travel
ticker immediately after `startTravel` (`room_page.dart:193-206`), and the
comment claims movement waits for `stand_up` — but `_onCompanionAnimationChanged`
(`room_page.dart:227-236`) is empty. So visible movement can overlap the stand-up
transition. Not a P31 blocker, but the comment is describing behaviour the code
does not implement.

## What the audit established, for when credentials arrive

**There is no generic visual provider.** `companion_visual_registry.dart:21-26`
registers `MochiVisualProvider`, `CatVisualProvider` and `RabbitVisualProvider`
by hand. A generated pack needs a new, thin adapter implementing the existing
`CompanionVisualProvider` (`posePackId`, `productionPoses`, `build`) — not a new
renderer, controller or player. The delegate chain
`CompanionAvatar → CompanionRenderer → provider → CompanionSpriteAvatar →
CompanionSpritePlayer` is already species-free, and
`fourth_companion_contract_test.dart:29-35,96-110,194-248` already proves a fourth
id renders with no page edit (its fox is procedural art and must never be cited as
photo evidence).

**Registration points for a new key**, all of which must agree on the same
identity: the pack manifest (`companionId`, `posePack`), the profile, the
`posePack → provider` lookup, the Dart mirror, and the bundle declaration in
`pubspec.yaml:58-69`. Note `dog`'s id and its pack id `mochi` differ — the two
must not be assumed equal.

**Tooling assumes exactly three packs.** `tools/manifest.py:109-123` maps
`posePack` over a three-entry dict; `tools/gen_manifest_dart.py:11-12,60-65`
hardcodes the same three and would not emit a mirror for a new key. Both need
widening before a fourth pack can be produced, and the audit warns that
`manifest.py` derives the baseline and centre from the *output* frames' mean
rather than from a pre-declared contract — which would let a drifted pack certify
itself.

**The provider boundary belongs outside Flutter.** `PetIdentityProvider` and
`PetMotionProvider` should be offline generation ports defined under `tools/`,
with the Vertex adapter owning project id, model id, storage and operation ids
inside that same offline boundary. Nothing under `lib/domain/` or
`lib/presentation/` may import them. The Flutter side consumes only a verified
local pack key, action ids and bundle paths.

**What is achievable without credentials:** the ports and their fakes, the
widened tooling and mirror paths, the isolated three-action contract, the thin
adapter, and runtime wiring proven with synthetic frames. That demonstrates the
*infrastructure*. It cannot demonstrate that a real pet's photos yield a stable
identity reference, and it must not be recorded as though it did.

## Spike exit criteria

1. Authorised photos of one real pet, with verifiable provenance from photo to
   identity reference to each action's raw output to the selected frames. Any
   action whose source is unknown, built-in art, or a test double does not count.
2. Real `idle`, in-place `walk`, and `sit_down` **plus a sustained sit**, at
   pre-declared frame counts, passing canvas / anchor / alpha / sharpness /
   motion-delta / loop-seam checks and a human identity review. `room_sit → idle`,
   a single frame, procedural silhouette, or another pack's fallback must not be
   counted as a sit.
3. Runtime evidence through the real `CompanionAvatar` / `CompanionRenderer` /
   animation controller / `CompanionSpritePlayer`: idle advancing frames, walk
   during travel, sitting on arrival, with world position owned solely by
   `LocomotionController` and no page-level species branching.
4. Without credentials the infrastructure subtask may close, but the P31
   proposition stays `BLOCKED_EXTERNAL` — even with every structural test green.

## Recommendation for P32

Do not open P32 on this evidence. P32 is the identity pipeline proper, and it
should wait until (a) Vertex access exists, and (b) the two conflicts above are
decided — specifically whether the spike's three-action pack is isolated from
built-in parity, and what "sit" is required to mean. Starting P32 without those
would bake a fallback into the identity contract.
