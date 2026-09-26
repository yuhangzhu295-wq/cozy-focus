import 'package:flutter/material.dart';

/// Layered Mochi renderer.
///
/// Mochi used to be a single hand-written `CustomPainter` that redrew the whole
/// character for every design adjustment. The approved V4.1 character is a
/// painted illustration, so that approach could never reach the approved
/// appearance. Instead the approved art is split into independent layers
/// (see `tools/mochi_layers/extract_mochi_layers.py` and
/// `outputs/ai_handoff/MOCHI_LAYER_CONTRACT.md`) and this widget composes them
/// in z-order while animating each part on its own channel.
///
/// Division of responsibility:
///
/// * [PetMotionController] / [PetMotionSpec] own *when* and *how much* a channel
///   moves. This widget never schedules timers and never decides state.
/// * This renderer owns *where* each channel is applied to the approved art.
/// * Pages own neither. They pass a state and a size; ear rotation, sprout
///   follow-through and blink are not part of the public API.
///
/// Motion channels map onto the approved anatomy as follows:
///
/// | channel          | layer(s)                          | pivot              |
/// |------------------|-----------------------------------|--------------------|
/// | body scale/dy/rot| whole stack (by the caller)       | bottom-centre      |
/// | `headRotation`   | face + eyes + ears + sprout group | base of the head   |
/// | `earRotation`    | ear_left / ear_right (mirrored)   | each ear's root    |
/// | `eyeScaleY`      | eye_left / eye_right              | each eye's centre  |
/// | `tailRotation`   | sprout follow-through             | sprout stem        |
///
/// The approved sitting anatomy has no visible tail, so no tail layer is
/// invented; the tail channel is spent on sprout follow-through instead. The
/// approved eyes are closed happy arcs, so the blink channel reads as an eye
/// twitch rather than a full eyelid close.
class MochiLayeredRenderer extends StatelessWidget {
  /// Character box width in logical pixels. The height follows the approved
  /// art's own aspect ratio.
  final double size;

  /// Vertical squash applied to the eye strokes, `1.0` = neutral.
  final double eyeScaleY;

  /// Ear swing in radians, applied to both ears in opposite directions.
  final double earRotation;

  /// Sprout follow-through in radians.
  final double sproutRotation;

  /// Head-group counter-rotation in radians (delayed head response).
  final double headRotation;

  /// Head-group vertical lag in logical pixels.
  final double headDy;

  const MochiLayeredRenderer({
    super.key,
    required this.size,
    this.eyeScaleY = 1.0,
    this.earRotation = 0.0,
    this.sproutRotation = 0.0,
    this.headRotation = 0.0,
    this.headDy = 0.0,
  });

  /// Width : height of the extracted character crop.
  static const double assetAspect = MochiLayerAssets.aspect;

  double get height => size / assetAspect;

  @override
  Widget build(BuildContext context) {
    final box = Size(size, height);

    return SizedBox(
      width: box.width,
      height: box.height,
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _layer(MochiLayerAssets.body, key: MochiLayerKeys.body),
            // Everything above the neck shares the head channel.
            _headGroup(
              box,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _layer(
                    MochiLayerAssets.earLeft,
                    key: MochiLayerKeys.earLeft,
                    angle: -earRotation,
                    pivot: MochiLayerAssets.earLeftPivot,
                  ),
                  _layer(
                    MochiLayerAssets.earRight,
                    key: MochiLayerKeys.earRight,
                    angle: earRotation,
                    pivot: MochiLayerAssets.earRightPivot,
                  ),
                  _layer(
                    MochiLayerAssets.sprout,
                    key: MochiLayerKeys.sprout,
                    angle: sproutRotation,
                    pivot: MochiLayerAssets.sproutPivot,
                  ),
                  _layer(MochiLayerAssets.face, key: MochiLayerKeys.face),
                  _layer(
                    MochiLayerAssets.eyeLeft,
                    key: MochiLayerKeys.eyeLeft,
                    scaleY: eyeScaleY,
                    pivot: MochiLayerAssets.eyeLeftPivot,
                  ),
                  _layer(
                    MochiLayerAssets.eyeRight,
                    key: MochiLayerKeys.eyeRight,
                    scaleY: eyeScaleY,
                    pivot: MochiLayerAssets.eyeRightPivot,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headGroup(Size box, {required Widget child}) {
    final rotated = headRotation == 0.0
        ? child
        : Transform.rotate(
            angle: headRotation,
            alignment: MochiLayerAssets.headPivot,
            child: child,
          );
    if (headDy == 0.0) {
      return KeyedSubtree(key: MochiLayerKeys.headGroup, child: rotated);
    }
    return KeyedSubtree(
      key: MochiLayerKeys.headGroup,
      child: Transform.translate(offset: Offset(0, headDy), child: rotated),
    );
  }

  Widget _layer(
    String asset, {
    required Key key,
    double angle = 0.0,
    double scaleY = 1.0,
    Alignment? pivot,
  }) {
    Widget image = Image.asset(
      asset,
      key: key,
      width: size,
      height: height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );

    if (scaleY != 1.0 && pivot != null) {
      image = Transform.scale(
        scaleY: scaleY,
        alignment: pivot,
        child: image,
      );
    }
    if (angle != 0.0 && pivot != null) {
      image = Transform.rotate(angle: angle, alignment: pivot, child: image);
    }
    return image;
  }
}

/// Stable keys for the approved-art layers, so widget tests can address the
/// composition instead of the pixels.
abstract final class MochiLayerKeys {
  static const Key headGroup = Key('mochi-head-group');
  static const Key body = Key('mochi-layer-body');
  static const Key earLeft = Key('mochi-layer-ear-left');
  static const Key earRight = Key('mochi-layer-ear-right');
  static const Key sprout = Key('mochi-layer-sprout');
  static const Key face = Key('mochi-layer-face');
  static const Key eyeLeft = Key('mochi-layer-eye-left');
  static const Key eyeRight = Key('mochi-layer-eye-right');

  /// Every layer, in z-order.
  static const List<Key> all = <Key>[
    body,
    earLeft,
    earRight,
    sprout,
    face,
    eyeLeft,
    eyeRight,
  ];
}

/// Approved-art layer inventory.
///
/// Pivots are expressed as [Alignment] in the layer images' own coordinate
/// space, derived from the measured pivot pixels recorded in
/// `assets/mochi/base/layers.json`.
abstract final class MochiLayerAssets {
  static const String body = 'assets/mochi/base/body.png';
  static const String earLeft = 'assets/mochi/base/ear_left.png';
  static const String earRight = 'assets/mochi/base/ear_right.png';
  static const String sprout = 'assets/mochi/base/sprout.png';
  static const String face = 'assets/mochi/base/face.png';
  static const String eyeLeft = 'assets/mochi/base/eye_left.png';
  static const String eyeRight = 'assets/mochi/base/eye_right.png';

  /// Width : height of the character crop (`482 x 328` reference pixels).
  ///
  /// Regenerate after any change to the extraction regions:
  /// `python tools/mochi_layers/extract_mochi_layers.py` then take the values
  /// printed by `assets/mochi/base/layers.json`.
  static const double aspect = 482 / 328;

  /// How far the character's feet sit above the bottom edge of the square box
  /// `CompanionAvatar` centres it in, as a fraction of the box's side.
  ///
  /// The box is square and the character is centred inside it, so its bottom
  /// edge is **not** where the paws are. Two gaps stack:
  ///
  /// * centring a 328-tall crop in a 482-wide square leaves `(482 - 328) / 2 =
  ///   77` reference pixels of empty space above *and* below the crop;
  /// * `body.png`'s lowest inked row is 321 of 328, so another 6 rows below the
  ///   paws are empty.
  ///
  /// Together that is `(77 + 6) / 482 = 0.1722` of the box side — 15.8 pt on the
  /// 92 pt avatar the room uses. Anything that anchors the avatar by its *feet*
  /// has to add this back, or the character hovers by that much.
  ///
  /// Same provenance as [aspect]: the body bbox in
  /// `assets/mochi/base/layers.json`. `mochi_layer_contract_test` re-reads that
  /// file and fails if this stops matching, so a re-export cannot silently
  /// leave Mochi floating.
  static const double feetInsetFraction = 83 / 482;

  /// Neck / base of the head — the head group rotates here.
  static const Alignment headPivot = Alignment(-0.0456, 0.8415);

  static const Alignment sproutPivot = Alignment(-0.0332, -0.4512);
  static const Alignment earLeftPivot = Alignment(-0.61, -0.2439);
  static const Alignment earRightPivot = Alignment(0.6017, -0.0732);
  static const Alignment eyeLeftPivot = Alignment(-0.3485, 0.0305);
  static const Alignment eyeRightPivot = Alignment(0.1411, 0.1951);
}
