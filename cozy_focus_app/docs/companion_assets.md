# Companion assets — layout and the rule that breaks builds

## Why this file exists

The companion sprite pipeline is correct in code and was silently broken in the
bundle. `assets/companions/cat/` shipped 14 frames and a manifest, but
`pubspec.yaml` did not list it, so every cat frame was absent from the built
bundle. Nothing failed: `CompanionSpritePlayer` degrades a missing frame to an
empty box, so the cat rendered blank instead of crashing.

This document records the layout and the one rule that prevents a recurrence.

## The rule

**Every directory under `assets/companions/` must be named in `pubspec.yaml`.**

Flutter does **not** recurse into subdirectories for asset directories. A
declared directory contributes only the files directly inside it. So
`assets/companions/` covers no companion pack, and adding a new pack is two
steps, not one:

1. create `assets/companions/<companionId>/`
2. add `- assets/companions/<companionId>/` under `flutter: assets:`

Skipping step 2 produces a pack that passes every test and draws nothing.

## Layout

```
assets/
  companion/            # behaviour + profile manifests (JSON, no frames)
    behavior_recipes.json
    companion_profiles.json
    room_interaction_recipes.json
  companions/           # sprite packs, one directory per companion
    dog/
      manifest.json     # authoring source: frames, fps, loop, targets
      <action>_NNN.png
    cat/
      manifest.json
      <action>_NNN.png
  mochi/base/           # the layered rig for the idle fallback
    body.png ear_left.png ear_right.png sprout.png
    face.png eye_left.png eye_right.png
    layers.json
```

> `companion/` (singular, JSON) and `companions/` (plural, PNGs) are different
> directories. They are one letter apart and easy to confuse.

## The two representations, and the parity test

Each manifest exists twice:

- `assets/companions/<id>/manifest.json` — the **authoring source**, written by
  the asset pipeline. Frame entries are bare filenames.
- `lib/presentation/companion/runtime/companion_action_manifest_data.dart` — a
  Dart **mirror** with resolvable asset paths.

The runtime reads the Dart table so the first frame never waits on an `await`.
That is only safe if the two cannot drift, which
`test/presentation/companion/runtime/companion_action_manifest_test.dart`
enforces field by field. **Changing one without the other fails the suite.**

## `targetFrameCount` is production intent, not a count of what exists

`targetFrameCount` is what the asset brief asks for. It is not a transcription
of how many frames are on disk.

Every action once declared a target equal to its frame count. That made
`isComplete` a tautology that could only return `true`, and the asset gate
printed `ACTIONS_PENDING_FRAMES: none` while `idle` shipped a single frame. A
single frame is a still image — V4.3 Phase 3 forbids single-PNG loops — so the
gate was reporting completion of something the brief forbids.

Two guards now prevent that:

- `CompanionActionSpec.minimumViableFrames` (2) floors the effective target, so
  a declaration cannot lower the bar.
- the completeness test fails an action that declares a 1-frame target beside
  a 1-frame sequence.

When new frames land, raise the *frames*, not the target.

## Canvas contract

All frames in a pack share one canvas, so a pose change cannot make the
companion jump. The values below are the **declared contract**, and each pack's
own `animation_manifest.json` is the authority for its own:

| field            | value |
|------------------|-------|
| canvas           | 512 × 512 |
| `groundBaseline` | 458 |
| `centerAnchor`   | 255 |
| tolerance        | 2 px |

Assets generated elsewhere (Google Flow and friends) must place the character's
feet on `y = 458` and its centre on `x = 255`, with a transparent background.
Frames that violate this are rejected by the dimension assertions in
`companion_action_manifest_test.dart`.

> **This table said 1024 × 1024 with 919 / 511 until P40.** Those numbers were
> never the contract; they were wrong in a way that would have sent someone
> authoring a pack on the wrong canvas, where every frame would then be refused.
> The contract is verified against the frames rather than the other way round:
> `python tools/audit_pack_geometry.py` measures all three shipped packs and
> reports their deviation, and `python tools/test_manifest_geometry.py` proves
> that a uniformly shifted set is refused.

## Adding a companion

There are two ways a companion arrives, and they have different steps.

### A companion we ship

1. create the pack directory and manifest
2. add it to `pubspec.yaml` ← the step that was missed for the cat
3. write its geometry contract — `animation_manifest.json` — **before** the
   frames, because it is the independent declaration the frames are checked
   against. Deriving it from the frames is the self-certification bug that
   `tools/manifest.py` used to have.
4. add the Dart mirror row (parity test enforces this)
5. register the visual provider in `companion_visual_registry.dart`

No page, director or renderer edit is involved. If one seems necessary, the
abstraction is being bypassed.

### A companion a user installs

**None of the above.** A user's pack is a `.cozy_pet` file that arrives at
runtime, and it is deliberately not part of the bundle:

- built with `python tools/cozy_pet_builder/build.py --input <dir> --pack-id …
  --name … --species … --output x.cozy_pet`, or assembled by hand;
- imported through the app's file picker, validated and installed into
  app-private storage;
- loaded from its own directory at runtime, so `pubspec.yaml` is not involved
  and adding one requires no rebuild.

It is held to the same geometry contract as a shipped pack — the builder reads
the contract for the species the user chose — but it is not added to
`pubspec.yaml`, the Dart mirror or the visual registry. That is the architecture
rule: after installation a pack goes through the same availability, provider and
player path as a built-in, and nothing branches on where it came from.
