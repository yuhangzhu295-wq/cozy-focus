# Rabbit Wiring Verification

- Branch: `recovery/v4.2.1-rebuild`
- Device: `emulator-5554` / `GoodnightPixel7Api34`, debug APK from this HEAD
- Evidence: `outputs/ai_handoff/android_v1_runtime/rabbit_wiring_*.png`

The question this answers: **is the rabbit's sprite pack actually reachable in the
running app, or is it only files on disk?**

---

## 1. The wiring was already there — and it is data-driven

`RabbitVisualProvider` reads `CompanionActionManifestData.forCompanion('rabbit')`
and derives its covered poses from the manifest:

```dart
Set<CompanionPose> _spritePosesFor(String companionKey) {
  final manifest = CompanionActionManifestData.forCompanion(companionKey);
  if (manifest == null) return const <CompanionPose>{};
  return { for (final pose in CompanionPose.values)
             if (manifest.hasExactAction(pose)) pose };
}
```

So a pack that lands later widens the covered set **with no code edit** — which is
the extension contract the architecture claims. No registration was missing and
none had to be added.

## 2. Verified on device

Built, installed, selected 小兔 in the companion picker, and inspected the room.

- The picker lists all three companions; the rabbit's entry renders from its own
  pack once the pack is read.
- **In the room the rabbit draws from its sprite frames** — the generated art
  (cream body, long pink-lined ears, open book), not the procedural silhouette
  (`rabbit_wiring_07_room.png`).

## 3. The fallback is the designed behaviour, not a defect

A later screenshot shows the rabbit drawn procedurally
(`rabbit_wiring_08_room_name.png`). That is the documented rule working:

```dart
final Widget art = spriteSpec != null && !spriteSpec!.isEmpty
    ? CompanionSpritePlayer(...)
    : ProceduralCompanionArt(...);
```

A production sequence wins for the poses it covers; the procedural silhouette
draws every pose it does not. The rabbit ships 6 of 13 actions, so poses it lacks
draw procedurally. It never borrows another companion's frames.

**Pinned as a test** in `companion_pack_completeness_test`:

- `CompanionSpriteArt.resolveFor('rabbit', CompanionPose.idle)` is non-null with
  6 frames — the shipped pose is reachable.
- `resolveFor('rabbit', CompanionPose.sleep)` is null — an unshipped pose falls
  back rather than substituting.
- `resolveFor('dog', CompanionPose.sleep)` is non-null — the control, so the null
  above is about the rabbit and not about the lookup.

---

## 4. A real defect found while verifying

The room's status line read **"Mochi 在房间里晃悠"** while the selected companion
was 小兔. `_activityLabel` in `furniture_use_panel.dart` hardcoded "Mochi" in all
six of its sentences.

`CompanionVitalsBar` is a `StatelessWidget` that never received the companion's
name, so it had nothing else to use. It now takes `companionName`, the room page
passes `companionDisplayNameProvider`, and all six sentences use it.

Verified on device after the fix: **"小兔 在房间里晃悠"**
(`rabbit_wiring_08_room_name.png`).

This is the same class of defect the cat and rabbit exist to expose: the app was
built around one companion and named it in prose. The sprite path was already
data-driven; the copy was not.

---

## 5. State

| | actions | frames |
|---|---|---|
| dog | 13 | 49 |
| cat | 13 | 49 |
| **rabbit** | **6** | **27** |

Rabbit complete: `idle` 6/6, `walk` 6/6, `sit_down` 4/4, `stand_up` 4/4,
`craft_work` 4/4, `focus_read` 3/3.

Remaining, blocked on Flow's rate limit: `focus_think` (3), `focus_write` (4),
`celebrate` (5), `tap_react` (3), `pet_react` (3), `sleep` (2), `pause_rest` (2).
