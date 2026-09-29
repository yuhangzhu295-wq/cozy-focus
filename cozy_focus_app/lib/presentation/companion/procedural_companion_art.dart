import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../animations/pet_motion_spec.dart';
import '../controllers/pet_motion_controller.dart';
import 'mochi_pose_prop.dart';
import 'mochi_pose_spec.dart';
import 'runtime/companion_pose.dart';

/// The anatomy that makes one companion look unlike another.
///
/// Deliberately small: ear shape, ear length, whiskers, tail. Those four are
/// enough for a viewer to tell a cat from a rabbit from a dog at avatar size,
/// and nothing here is a per-species *code path* — it is a data row.
class CompanionSilhouette {
  /// Ear shape.
  final CompanionEarShape earShape;

  /// Ear length as a fraction of the head radius.
  final double earLength;

  /// How far the ears tilt outward, in radians.
  final double earSplay;

  /// Whether the face carries whiskers.
  final bool hasWhiskers;

  /// The tail treatment.
  final CompanionTailShape tail;

  /// Fur colour.
  final Color furColor;

  /// Inner-ear colour.
  final Color innerEarColor;

  const CompanionSilhouette({
    required this.earShape,
    required this.earLength,
    required this.earSplay,
    required this.hasWhiskers,
    required this.tail,
    required this.furColor,
    required this.innerEarColor,
  });
}

enum CompanionEarShape {
  /// Soft, rounded, drooping to the sides.
  floppy,

  /// Short triangles, standing up.
  triangle,

  /// Long upright ovals.
  long,
}

enum CompanionTailShape {
  /// No visible tail.
  none,

  /// A thin, curved stroke.
  slenderCurve,

  /// A small round puff.
  puff,
}

/// Cat and rabbit silhouettes.
///
/// ## These are placeholders, and they say so
///
/// `docs/08_Runtime_Asset_GAP.md` states that the transparent cat and rabbit pose
/// packs are still a production task. The brief forbids substituting the dog's
/// artwork for them, so these companions are drawn as their own characters: a
/// cat is a cat, not a Mochi with different numbers.
///
/// They are honest placeholders — visibly the right *species*, visibly not
/// finished art — and every one of their poses is reported as `ASSET_GAP` rather
/// than presented as complete.
abstract final class CompanionSilhouettes {
  const CompanionSilhouettes._();

  static const CompanionSilhouette cat = CompanionSilhouette(
    earShape: CompanionEarShape.triangle,
    earLength: 0.62,
    earSplay: 0.42,
    hasWhiskers: true,
    tail: CompanionTailShape.slenderCurve,
    furColor: Color(0xFFF3E3D3),
    innerEarColor: Color(0xFFE9A9A0),
  );

  static const CompanionSilhouette rabbit = CompanionSilhouette(
    earShape: CompanionEarShape.long,
    earLength: 1.05,
    earSplay: 0.14,
    hasWhiskers: false,
    tail: CompanionTailShape.puff,
    furColor: Color(0xFFF6EFE6),
    innerEarColor: Color(0xFFEBC3C3),
  );
}

/// Draws a placeholder companion for a pose.
///
/// It reuses the same pose vocabulary and the same props as the approved Mochi
/// renderer, so the three companions genuinely share one presentation system —
/// only the leaf drawing differs, which is exactly the division the V4.2.1
/// architecture asks for.
///
/// ## Micro-motion is drawn here, not merely declared
///
/// Every companion's profile lists micro-motion channels (`breathe`, `blink`, …).
/// The approved Mochi renderer drives them with its own controllers; a
/// placeholder that drew a still image would make those declarations a lie, and
/// would leave a cat or rabbit visibly frozen next to a dog that breathes. So
/// this widget owns one breathing controller and one blink timer, using the same
/// [PetMotionSpec] constants the dog uses, and releases both with itself.
class ProceduralCompanionArt extends StatefulWidget {
  final CompanionSilhouette silhouette;
  final CompanionPose pose;
  final MochiPoseSpec poseSpec;
  final double size;
  final bool reducedMotion;

  /// Injectable blink cadence, so a test is deterministic. Production uses the
  /// natural random scheduler the rest of the motion layer uses.
  final IPetMotionScheduler? scheduler;

  const ProceduralCompanionArt({
    super.key,
    required this.silhouette,
    required this.pose,
    required this.poseSpec,
    required this.size,
    this.reducedMotion = false,
    this.scheduler,
  });

  @override
  State<ProceduralCompanionArt> createState() => _ProceduralCompanionArtState();
}

class _ProceduralCompanionArtState extends State<ProceduralCompanionArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;
  late final IPetMotionScheduler _scheduler;
  Timer? _blinkTimer;
  Timer? _blinkEndTimer;
  bool _eyesClosed = false;

  @override
  void initState() {
    super.initState();
    _scheduler = widget.scheduler ?? DefaultPetMotionScheduler();
    _breathe = AnimationController(
      vsync: this,
      duration: PetMotionSpec.breatheCycle,
    );
    if (!widget.reducedMotion) {
      _breathe.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  @override
  void didUpdateWidget(covariant ProceduralCompanionArt old) {
    super.didUpdateWidget(old);
    // Reduced motion can be switched while the companion is on screen.
    if (old.reducedMotion != widget.reducedMotion) {
      if (widget.reducedMotion) {
        _breathe.stop();
        _breathe.value = 0.0;
        _cancelBlink();
        _eyesClosed = false;
      } else {
        _breathe.repeat(reverse: true);
        _scheduleBlink();
      }
    }
  }

  @override
  void dispose() {
    _cancelBlink();
    _breathe.dispose();
    super.dispose();
  }

  void _cancelBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    _blinkEndTimer?.cancel();
    _blinkEndTimer = null;
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(_scheduler.nextBlinkInterval(), () {
      if (!mounted || widget.reducedMotion) return;
      setState(() => _eyesClosed = true);
      _blinkEndTimer?.cancel();
      _blinkEndTimer = Timer(PetMotionSpec.blinkDuration, () {
        if (!mounted) return;
        setState(() => _eyesClosed = false);
        _scheduleBlink();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.reducedMotion
        ? MochiPoseSpecs.damped(widget.poseSpec)
        : widget.poseSpec;
    final size = widget.size;

    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, _) {
        // A breath is a small scale about the base, never a translation: the
        // companion must not appear to float off its furniture.
        final breathScale = widget.reducedMotion
            ? 1.0
            : PetMotionSpec.breatheScaleMin +
                (PetMotionSpec.breatheScaleMax -
                        PetMotionSpec.breatheScaleMin) *
                    _breathe.value;

        return Transform.scale(
          scale: breathScale,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: _SilhouettePainter(
                      silhouette: widget.silhouette,
                      spec: spec,
                      phase: 0.0,
                      eyesClosed: _eyesClosed,
                    ),
                  ),
                ),
                if (spec.prop != MochiPosePropKind.none)
                  MochiPoseProp(
                    kind: spec.prop,
                    size: size,
                    phase: _breathe.value,
                    reducedMotion: widget.reducedMotion,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  final CompanionSilhouette silhouette;
  final MochiPoseSpec spec;
  final double phase;

  /// Whether the blink channel has the eyes shut this frame.
  final bool eyesClosed;

  _SilhouettePainter({
    required this.silhouette,
    required this.spec,
    required this.phase,
    this.eyesClosed = false,
  });

  double _float(double amplitude) => math.sin(phase * 2 * math.pi) * amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s * 0.5;
    // The head sits in the upper two thirds; the body fills the base.
    final headR = s * 0.235;
    final headCy = s * 0.545 + spec.headDy + _float(1.0);
    final headCx = cx + _float(0.6);

    _body(canvas, s, cx);
    _tail(canvas, s, cx);

    canvas.save();
    canvas.translate(headCx, headCy);
    canvas.rotate(spec.headRotation);
    canvas.translate(-headCx, -headCy);

    _ears(canvas, s, headCx, headCy, headR);
    _head(canvas, s, headCx, headCy, headR);
    _face(canvas, s, headCx, headCy, headR);

    canvas.restore();
  }

  void _body(Canvas canvas, double s, double cx) {
    final rect = Rect.fromCenter(
      center: Offset(cx + _float(0.4), s * 0.815 + spec.bodyDy * 0.5),
      width: s * 0.52,
      height: s * 0.36,
    );
    canvas.drawOval(
      rect,
      Paint()..color = silhouette.furColor,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFF3B3630).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, s * 0.010),
    );
  }

  void _tail(Canvas canvas, double s, double cx) {
    switch (silhouette.tail) {
      case CompanionTailShape.none:
        return;
      case CompanionTailShape.slenderCurve:
        final path = Path()
          ..moveTo(cx + s * 0.24, s * 0.88)
          ..quadraticBezierTo(
            cx + s * 0.44,
            s * 0.84,
            cx + s * 0.40 + _float(1.2),
            s * 0.62,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = silhouette.furColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.0, s * 0.030)
            ..strokeCap = StrokeCap.round,
        );
      case CompanionTailShape.puff:
        canvas.drawCircle(
          Offset(cx + s * 0.26, s * 0.855),
          s * 0.058,
          Paint()..color = const Color(0xFFFFFFFF),
        );
        canvas.drawCircle(
          Offset(cx + s * 0.26, s * 0.855),
          s * 0.058,
          Paint()
            ..color = const Color(0xFF3B3630).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, s * 0.008),
        );
    }
  }

  void _ears(
      Canvas canvas, double s, double headCx, double headCy, double headR) {
    for (final side in [-1.0, 1.0]) {
      final baseX = headCx + side * headR * 0.55;
      final baseY = headCy - headR * 0.72;
      canvas.save();
      canvas.translate(baseX, baseY);
      canvas.rotate(side * silhouette.earSplay);

      switch (silhouette.earShape) {
        case CompanionEarShape.floppy:
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(0, headR * 0.30),
              width: headR * 0.72,
              height: headR * 1.05,
            ),
            Paint()..color = silhouette.furColor,
          );
        case CompanionEarShape.triangle:
          final h = headR * silhouette.earLength;
          final path = Path()
            ..moveTo(-headR * 0.34, headR * 0.18)
            ..lineTo(0, -h)
            ..lineTo(headR * 0.34, headR * 0.18)
            ..close();
          canvas.drawPath(path, Paint()..color = silhouette.furColor);
          final inner = Path()
            ..moveTo(-headR * 0.17, headR * 0.06)
            ..lineTo(0, -h * 0.66)
            ..lineTo(headR * 0.17, headR * 0.06)
            ..close();
          canvas.drawPath(inner, Paint()..color = silhouette.innerEarColor);
        case CompanionEarShape.long:
          final h = headR * silhouette.earLength;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(0, -h * 0.42),
              width: headR * 0.44,
              height: h,
            ),
            Paint()..color = silhouette.furColor,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(0, -h * 0.42),
              width: headR * 0.22,
              height: h * 0.78,
            ),
            Paint()..color = silhouette.innerEarColor,
          );
      }
      canvas.restore();
    }
  }

  void _head(
      Canvas canvas, double s, double headCx, double headCy, double headR) {
    canvas.drawCircle(
      Offset(headCx, headCy),
      headR,
      Paint()..color = silhouette.furColor,
    );
    canvas.drawCircle(
      Offset(headCx, headCy),
      headR,
      Paint()
        ..color = const Color(0xFF3B3630).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, s * 0.010),
    );
  }

  void _face(
      Canvas canvas, double s, double headCx, double headCy, double headR) {
    final ink = Paint()
      ..color = const Color(0xFF3B3630)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, s * 0.013)
      ..strokeCap = StrokeCap.round;

    // Eyes: closed happy arcs, squashed by the pose's eye channel so a resting
    // companion visibly closes them.
    // A blink closes the eyes whatever the pose says: it is a micro-motion, not
    // a pose change, so it composes with the pose rather than replacing it.
    final eyeOpen = eyesClosed ? 0.0 : spec.eyeScaleY.clamp(0.0, 1.4);
    final eyeR = headR * 0.20;
    for (final side in [-1.0, 1.0]) {
      final ex = headCx + side * headR * 0.36;
      final ey = headCy + headR * 0.04;
      if (eyeOpen < 0.25) {
        canvas.drawLine(
          Offset(ex - eyeR * 0.7, ey),
          Offset(ex + eyeR * 0.7, ey),
          ink,
        );
      } else {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(ex, ey),
            width: eyeR * 1.7,
            height: eyeR * 1.5 * eyeOpen,
          ),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          ink,
        );
      }
    }

    // Blush.
    final blush = Paint()
      ..color = const Color(0xFFF0A9A0).withValues(alpha: 0.55);
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headCx + side * headR * 0.60, headCy + headR * 0.30),
          width: headR * 0.34,
          height: headR * 0.22,
        ),
        blush,
      );
    }

    // Mouth: a small open smile.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCx, headCy + headR * 0.36),
        width: headR * 0.34,
        height: headR * 0.30,
      ),
      0,
      math.pi,
      false,
      ink,
    );

    if (silhouette.hasWhiskers) {
      final whisker = Paint()
        ..color = const Color(0xFF3B3630).withValues(alpha: 0.45)
        ..strokeWidth = math.max(0.9, s * 0.007)
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        for (var i = 0; i < 2; i++) {
          final y = headCy + headR * (0.28 + i * 0.20);
          canvas.drawLine(
            Offset(headCx + side * headR * 0.62, y),
            Offset(headCx + side * headR * 1.16, y - headR * (0.10 - i * 0.16)),
            whisker,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) =>
      old.silhouette != silhouette || old.spec != spec || old.phase != phase;
}
