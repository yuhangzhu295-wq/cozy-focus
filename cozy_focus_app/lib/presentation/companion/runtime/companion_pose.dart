/// The pose vocabulary the runtime can ask a visual provider to draw.
///
/// A pose is the *semantic* unit: "Mochi is reading", "Mochi is resting". It is
/// not a frame, a file, or a transform. Which asset (if any) satisfies a pose for
/// a given companion is the [CompanionAssetResolver]'s question, never a page's.
///
/// The set is the union of the macro behaviours in
/// `docs/01_Companion_Runtime_Architecture_SPEC.md` §3, the overlay poses in §3,
/// and the minimum pose pack in `docs/02_Pose_Asset_First_制作方案.md`.
///
/// `roomWork` is included to honour `docs/06_Room_Craft_Collection_Recipe_SPEC.md`
/// (desk → room_work) even though §3's macro list omits it; the discrepancy is
/// recorded rather than silently resolved.
enum CompanionPose {
  // --- Macro poses ---------------------------------------------------------
  idle('idle'),
  prepare('prepare'),
  focusRead('focus_read'),
  focusWrite('focus_write'),
  focusThink('focus_think'),
  microRest('micro_rest'),
  glance('glance'),
  finish('finish'),
  craftWork('craft_work'),
  roomSit('room_sit'),
  roomRead('room_read'),
  roomSleep('room_sleep'),
  roomWork('room_work'),
  roomRelax('room_relax'),
  celebrate('celebrate'),
  rest('pause_rest'),
  sleep('sleep'),

  // --- Overlay poses -------------------------------------------------------
  tapReact('tap_react'),
  petReact('pet_react'),
  greeting('greeting'),
  unlockReact('unlock_react');

  /// The snake_case wire id, matching the recipe/profile manifests.
  final String id;

  const CompanionPose(this.id);

  /// Parses a wire id. Returns `null` for an unknown id rather than throwing —
  /// a manifest that names a pose this build does not know must degrade to "no
  /// pose", not crash the presentation layer.
  static CompanionPose? fromId(String? id) {
    if (id == null) return null;
    for (final pose in CompanionPose.values) {
      if (pose.id == id) return pose;
    }
    return null;
  }

  /// Whether this pose is a temporary overlay rather than a macro behaviour.
  bool get isOverlay =>
      this == CompanionPose.tapReact ||
      this == CompanionPose.petReact ||
      this == CompanionPose.greeting ||
      this == CompanionPose.unlockReact;
}
