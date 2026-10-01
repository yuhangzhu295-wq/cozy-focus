/// The furniture catalog: what each object is, and what it is for.
///
/// ## The brief's own worked examples, as data
///
/// Every entry below is the brief's specification transcribed rather than
/// paraphrased. The sofa entry is the clearest case — the brief says:
///
/// ```text
/// SOFA
///   Interaction: sit, rest, nap
///   Trigger:     energy < 40 or player taps sofa
///   Effect:      energy +10, mood +5
///   Animation:   go sofa anchor, play sit animation
/// ```
///
/// which is exactly `FurnitureEntity(id: 'sofa', actions: [sit, rest, nap])`
/// with those triggers and that effect. Nothing in the code branches on the
/// string `'sofa'`; this table is the only place the object is described.
///
/// ## Why a Dart table rather than JSON
///
/// The runtime needs these *synchronously* — the room must know what a sofa does
/// on the first frame, without an `await` between app start and first paint, and
/// without every widget test having to pump an async load. The JSON manifests
/// under `assets/companion/` remain the authoring source for the *behaviour*
/// recipes; this is the object catalog, and
/// `furniture_catalog_test.dart` pins the two together where they overlap so
/// they cannot drift.
library;

import 'furniture_entity.dart';

/// The shipped furniture catalog.
abstract final class FurnitureCatalog {
  const FurnitureCatalog._();

  /// Every piece of furniture the companion can use, keyed by item id.
  static const Map<String, FurnitureEntity> entities = {
    'sofa': _sofa,
    'desk': _desk,
    'bookshelf': _bookshelf,
    'bed': _bed,
    'rug': _rug,
  };

  /// The sofa — the brief's resting place.
  ///
  /// Three actions, all gated on the player actually owning the sofa, so
  /// unlocking it is what *adds* the resting behaviour.
  static const FurnitureEntity _sofa = FurnitureEntity(
    id: 'sofa',
    type: FurnitureType.seating,
    label: '沙发',
    purpose: '累了就窝在这里，慢慢恢复精神',
    interactionPoints: ['seat'],
    actions: [
      FurnitureAction(
        id: 'sit',
        label: '坐下',
        companionAction: 'room_sit',
        triggers: [FurnitureTrigger.playerTap, FurnitureTrigger.energyLow],
        effect: FurnitureEffect(energy: 4, mood: 3),
        minDwell: Duration(seconds: 14),
        maxDwell: Duration(seconds: 28),
      ),
      FurnitureAction(
        id: 'rest',
        label: '休息',
        companionAction: 'pause_rest',
        triggers: [FurnitureTrigger.playerTap, FurnitureTrigger.energyLow],
        effect: FurnitureEffect(energy: 10, mood: 5),
        minDwell: Duration(seconds: 18),
        maxDwell: Duration(seconds: 32),
      ),
      FurnitureAction(
        id: 'nap',
        label: '打个盹',
        companionAction: 'sleep',
        triggers: [FurnitureTrigger.energyLow],
        effect: FurnitureEffect(energy: 22, mood: 6),
        minDwell: Duration(seconds: 26),
        maxDwell: Duration(seconds: 44),
      ),
    ],
  );

  /// The desk — where focus work happens.
  ///
  /// `study` is the action a running focus session selects automatically, which
  /// is the acceptance test *"focus mode: Mochi automatically uses desk"*.
  static const FurnitureEntity _desk = FurnitureEntity(
    id: 'desk',
    type: FurnitureType.workSurface,
    label: '书桌',
    purpose: '专注的时候，在这里陪你一起工作',
    interactionPoints: ['work'],
    actions: [
      FurnitureAction(
        id: 'write',
        label: '写字',
        companionAction: 'focus_write',
        triggers: [FurnitureTrigger.focusRunning, FurnitureTrigger.playerTap],
        effect: FurnitureEffect(focus: 12, energy: -6),
        minDwell: Duration(seconds: 16),
        maxDwell: Duration(seconds: 30),
      ),
      FurnitureAction(
        id: 'study',
        label: '学习',
        companionAction: 'focus_think',
        triggers: [FurnitureTrigger.focusRunning, FurnitureTrigger.playerTap],
        effect: FurnitureEffect(focus: 10, energy: -4),
        minDwell: Duration(seconds: 16),
        maxDwell: Duration(seconds: 30),
      ),
      FurnitureAction(
        id: 'craft',
        label: '做点小东西',
        companionAction: 'craft_work',
        triggers: [FurnitureTrigger.playerTap, FurnitureTrigger.idle],
        effect: FurnitureEffect(mood: 6, energy: -5),
        minDwell: Duration(seconds: 14),
        maxDwell: Duration(seconds: 26),
      ),
    ],
  );

  /// The bookshelf — reading, which advances knowledge.
  static const FurnitureEntity _bookshelf = FurnitureEntity(
    id: 'bookshelf',
    type: FurnitureType.storage,
    label: '书架',
    purpose: '翻翻书，慢慢认识更多东西',
    interactionPoints: ['front'],
    actions: [
      FurnitureAction(
        id: 'read',
        label: '看书',
        companionAction: 'focus_read',
        triggers: [FurnitureTrigger.playerTap, FurnitureTrigger.idle],
        effect: FurnitureEffect(
          focus: 8,
          mood: 4,
          energy: -3,
          knowledge: ['reading'],
        ),
        minDwell: Duration(seconds: 16),
        maxDwell: Duration(seconds: 30),
      ),
      FurnitureAction(
        id: 'search',
        label: '找一本书',
        companionAction: 'focus_think',
        triggers: [FurnitureTrigger.idle, FurnitureTrigger.playerTap],
        effect: FurnitureEffect(
          focus: 6,
          energy: -2,
          knowledge: ['exploring'],
        ),
        minDwell: Duration(seconds: 12),
        maxDwell: Duration(seconds: 22),
      ),
    ],
  );

  /// The bed — sleep, chosen at night or when energy is very low.
  static const FurnitureEntity _bed = FurnitureEntity(
    id: 'bed',
    type: FurnitureType.seating,
    label: '小床',
    purpose: '夜深了，睡一觉养足精神',
    interactionPoints: ['lie'],
    actions: [
      FurnitureAction(
        id: 'sleep',
        label: '睡觉',
        companionAction: 'sleep',
        triggers: [
          FurnitureTrigger.night,
          FurnitureTrigger.playerTap,
          FurnitureTrigger.energyLow,
        ],
        effect: FurnitureEffect(energy: 34, mood: 6),
        minDwell: Duration(seconds: 30),
        maxDwell: Duration(seconds: 60),
      ),
    ],
  );

  /// The rug — a second place to settle, with the softest effect.
  static const FurnitureEntity _rug = FurnitureEntity(
    id: 'rug',
    type: FurnitureType.seating,
    label: '地毯',
    purpose: '随便坐坐，晒晒暖暖的光',
    interactionPoints: ['seat'],
    actions: [
      FurnitureAction(
        id: 'sit',
        label: '坐一会儿',
        companionAction: 'room_sit',
        triggers: [FurnitureTrigger.idle, FurnitureTrigger.playerTap],
        effect: FurnitureEffect(energy: 3, mood: 4),
        minDwell: Duration(seconds: 12),
        maxDwell: Duration(seconds: 24),
      ),
    ],
  );

  /// The entity for [itemId], or `null` when the item is not furniture the
  /// companion can use.
  ///
  /// `null` rather than a default: an unknown id means the catalog has nothing
  /// to say, and inventing a generic entity would let a decoration become
  /// something the companion interacts with.
  static FurnitureEntity? forId(String itemId) => entities[itemId];

  /// Every item id the catalog knows, for diagnostics and tests.
  static Set<String> get itemIds => entities.keys.toSet();

  /// The catalog entries that define a given interaction-point role.
  static List<FurnitureEntity> withInteractionPoint(String role) => [
        for (final entity in entities.values)
          if (entity.interactionPoints.contains(role)) entity,
      ];
}
