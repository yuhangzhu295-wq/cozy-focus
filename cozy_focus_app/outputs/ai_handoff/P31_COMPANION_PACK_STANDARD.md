# P31 — Companion Pack Standard

Pack-first architecture (owner roadmap change, `P31_P40_PACK_FIRST_ROADMAP.md`).
Read-only architecture audit at `recovery/v4.2.1-rebuild` @ `4d9ac3f`.

**Supersedes `P31_CUSTOM_PET_SPIKE.md`**, which was written against the AI-first
framing. Its factual findings still stand and are folded in here: Vertex AI
credentials are absent on this machine, and built-in parity demands thirteen
actions.

```
PACK_STANDARD_DECISION:  EXTEND, DO NOT FORK
CONFLICTS_TO_STOP:       none
P31_GATE:                PASS for the standard; no runtime change was made
```

---

## The decision

**`CompanionAssetPack` is an in-memory aggregate, not a second file format.**

The brief said "do NOT create a parallel manifest format unless required". It is
not required. The existing pair already carries the pack:

- **`CompanionActionManifest`** — the playable action list: `companionId`,
  `posePack`, canvas, `groundBaseline`, `centerAnchor`, `actions` (each with
  ordered frame names, `fps`, `loopMode`, `targetFrameCount`, `interruptible`,
  `reducedMotionFrames`), `semanticFallback`, `drawAliases`.
- **`CompanionProfile`** — the identity: `id`, `displayName`, `posePack`,
  `tagline`, `traits`, behaviour weights, overlays, `roomAnchors`.

A pack is those two, validated and installed together. The runtime types do not
change shape; the *validation and loading* around them is what P32–P35 add.

### Field by field

| Wanted | Verdict |
|---|---|
| identity | **present** — `companionId` must match the profile key, checked at install |
| display name | **present** — `CompanionProfile.displayName` |
| sprite actions, fps, loop | **present** |
| anchors, canvas | **present** |
| species | **absent — must be added to `CompanionProfile`** |
| version | addable to the playable manifest |
| checksums | addable to the playable manifest |
| optional preview | addable |
| source | **belongs in an install record, not the pack** |

**Species is the one real gap.** Today `dog`/`cat`/`rabbit` are *identity* ids,
and they double as species only because there is one companion per species. The
moment two dogs can exist, an id cannot answer "what is this animal" — and the
motion semantics P33/P34 depend on that answer. So `species` goes on
`CompanionProfile` explicitly, and nothing may infer it from the id.

**Version and checksums go on the playable manifest**, read by
`CompanionActionManifest.fromJson` and *verified against the actual files* by the
installer. A field that is written but never read is decoration; the audit is
explicit that "the JSON field exists" is not "the runtime verified it". Note the
profiles JSON and the dog production contract already carry `"version": 1`, but
the three **playable** manifests carry none and no Dart type reads one.

**`source` is not pack data.** `BUILT_IN` / `LOCAL_IMPORT` / `LOCAL_COMPILE` /
`CLOUD_GENERATED` describes how a pack arrived. Putting it in the pack would
invite exactly the branching the architecture rule forbids, so it belongs to the
install record and the runtime never reads it.

---

## The pack's basis is the playable manifest, not the production contract

`SpriteAnimationManifest` describes *production intent*: target frame counts,
roles, `anchorTolerancePx`, and actions that may not exist yet. It is the right
contract for producing the built-in packs and the wrong thing to require of an
imported one — `cat` and `rabbit` have no production contract at all today.

So an imported pack is validated against `CompanionActionManifest` **and its real
frames**. If it also ships a production contract, the overlapping actions are
cross-checked for fps, loop, target count, canvas and anchors.

### A defect the audit found in the current tooling

`tools/manifest.py:106-115` derives `groundBaseline` and `centerAnchor` from the
**mean of the output frames' own `bottomY` / `centerX`**. If a whole set of frames
drifts together, the manifest and the images agree with each other while both are
wrong. P31 therefore requires that anchor and canvas be validated against an
**independently declared contract** — never against a value inferred from the
frames under test.

---

## Capability gating already expresses a partial pack

`CompanionActionAvailabilityResolver` already answers the three questions P33
needs:

- `schedulable` — the manifest names the pose and `resolve` finds frames for it
- `fallbackOnly` — named, but `specForRendering` finds no drawing of its own
- `planned` — the production contract lists it and the manifest has no frames; it
  never schedules

A pack with only `idle`, `walk` and `sleep` can be represented honestly **today**:
list only those actions, and do not copy the built-in fallback tables. Writing
`celebrate → idle` into a partial pack would make the resolver treat celebrate as
a schedulable behaviour — a fake feature, which is precisely what P33 forbids.

Two caveats the audit surfaced, both of which P33 must state in its own terms:

1. **`fallbackOnly` only checks whether the render resolved to null.** A valid
   `drawAliases` entry returns another action's frames and is therefore **not**
   marked `fallbackOnly`. So "how many distinct actions does this pack really
   have" cannot be answered by `fallbackOnly` alone.
2. **An ungrounded context is given `idle` even when availability does not
   include it.** A pack without a decodable `idle` would therefore fail in a way
   that looks like a rendering bug. **A decodable `idle` is the minimum install
   requirement.**

When a missing pose is requested, the director filters the candidate pool and, if
it empties, reports `isUsingFallback` and degrades to idle. That behaviour is
correct and needs no change — P33 only has to prove it holds for a partial pack.

---

## What installation would require, and what is not P31

The audit was clear that **this is not yet an installable pack**, and P31 must not
pretend otherwise:

- the action lookup is a **Dart const mirror compiled into the binary**
  (`companion_action_manifest_data.dart`), not read from disk;
- frames are read by `AssetImage` / `Image.asset`, so a directory cannot simply be
  handed to the existing player;
- `fromJson` is deliberately **lenient** — it defaults missing canvas, anchors and
  unknown loop modes. That is right for trusted built-in data and is **not** an
  untrusted-import validator. Install validation must be a separate, strict step.

Four boundaries P32–P35 will need, recorded here so P31's standard is actionable:

1. **Install validation** — identity agreement, unique ids, relative paths and
   directory escape, file existence, SHA-256, decodable transparent PNG, size and
   anchors, at least two frames per action, fps, loop, fallback/alias targets.
2. **`PackBackedCompanionVisualProvider`** — one generic provider over the existing
   `CompanionVisualProvider` interface. The registry's `register` already accepts
   instances; production simply constructs three compile-time classes today.
3. **A file-frame decoding entry** — the player's precache is `AssetImage` and its
   paint is `Image.asset`, both hardcoded. Needed to load installed packs without
   rewriting timing, loop mode or reduced-motion handling.
4. **Installed-pack state** — availability is read statically and cached by the
   director, and the avatar reads catalog/registry once at init. Installing a pack
   must rebuild those, or a new companion will not appear until restart.

None of that is P31's work. P31 defines the standard; it does not install.

---

## Test scope: the parity conflict is real and must be scoped

The previous audit's finding is **confirmed**: `multi_companion_parity_test.dart`
iterates every static profile and forces each to ship the **same thirteen actions,
frame targets and loop modes as the dog**, and separately forces pubspec
directories, on-disk frames and static registration. `companion_pack_completeness_test.dart`
does the same for the built-in three.

That rule is right for the **built-in packs** and wrong as an admission
requirement for a user's partial pack. P33's isolation must be explicit rather
than a weakening: built-in parity keeps its full-strength gate, and user packs get
their own contract that asserts *honesty about what is missing* instead of
*completeness*.

Also noted: `companion_action_manifest_test.dart:39-72` does not currently compare
`drawAliases` or `reducedMotionFrames`, and the docs at `docs/companion_assets.md`
are stale — they state every pack must be added to `pubspec.yaml` and show a
1024×1024 canvas with 919/511 anchors, while the real JSON is 512×512 with ~458/255.
Acceptance is per pack contract; nothing should hardcode those numbers.

---

## Conflicts

**None that stop P31.** The existing playable manifest, profile, registry and
shared director are enough to fix a standard without rebuilding the game or forking
the action format.

Three decisions must be written down before P31 can be called complete, and they
are the ones that would otherwise be resolved by accident later:

1. **`species` is separate from the companion id**, and lives on the profile.
2. **Relative paths, format version, checksums and strict validation rules are
   specified**, with "the field exists" never treated as "the runtime verified it".
3. **User partial packs and the built-in three are tested under different
   contracts**, so neither weakens the other.

And the source-independence rule must land where it matters: after installation
every pack goes through the same availability, provider and player path. No
`LocalPetRuntime`, no `CloudPetRuntime`, no switching engines by origin.
