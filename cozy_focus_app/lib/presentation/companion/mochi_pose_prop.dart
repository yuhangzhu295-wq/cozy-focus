import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'mochi_pose_spec.dart';

/// Draws the fallback prop that gives a pose its distinct silhouette.
///
/// ## Fallback, and labelled as such
///
/// The V4.2.1 package states plainly that the transparent dog/cat/rabbit pose
/// packs are still a production task (`docs/08_Runtime_Asset_GAP.md`). Until
/// those exist, the poses have to differ by something other than a few degrees of
/// head pitch — the spec forbids passing a parameter tweak off as a macro action.
/// These props are drawn in code so the three focus silhouettes are genuinely
/// distinguishable, and the runtime reports `ASSET_GAP` for every one of them.
///
/// ## It cannot reach business state
///
/// This is a painter. It receives a kind, a size and a phase. It has no access to
/// XP, a session, a craft job or a repository, and it draws nothing that claims a
/// fact about them.
class MochiPoseProp extends StatelessWidget {
  final MochiPosePropKind kind;
  final double size;

  /// A `0 … 1` phase used for the gentle float of ambient props. Ignored when
  /// [reducedMotion] is set, which freezes the prop in place.
  final double phase;

  final bool reducedMotion;

  /// The colour scheme, so a dark focus screen can pass light ink.
  final Color inkColor;

  const MochiPoseProp({
    super.key,
    required this.kind,
    required this.size,
    this.phase = 0.0,
    this.reducedMotion = false,
    this.inkColor = AppColors.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    if (kind == MochiPosePropKind.none) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MochiPosePropPainter(
            kind: kind,
            phase: reducedMotion ? 0.0 : phase,
            inkColor: inkColor,
          ),
        ),
      ),
    );
  }
}

class _MochiPosePropPainter extends CustomPainter {
  final MochiPosePropKind kind;
  final double phase;
  final Color inkColor;

  _MochiPosePropPainter({
    required this.kind,
    required this.phase,
    required this.inkColor,
  });

  /// One full gentle float, in logical pixels at the reference size.
  double _float(double amplitude) => math.sin(phase * 2 * math.pi) * amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    switch (kind) {
      case MochiPosePropKind.none:
        return;
      case MochiPosePropKind.openBook:
        _openBook(canvas, s);
      case MochiPosePropKind.notebook:
        _notebook(canvas, s);
      case MochiPosePropKind.thoughtBubbles:
        _thoughtBubbles(canvas, s);
      case MochiPosePropKind.tools:
        _tools(canvas, s);
      case MochiPosePropKind.sparkle:
        _sparkle(canvas, s, count: 2);
      case MochiPosePropKind.confetti:
        _confetti(canvas, s);
      case MochiPosePropKind.restZ:
        _restZ(canvas, s);
      case MochiPosePropKind.tapSpark:
        _tapSpark(canvas, s);
      case MochiPosePropKind.heart:
        _heart(canvas, s);
      case MochiPosePropKind.wave:
        _wave(canvas, s);
    }
  }

  // --- Props ---------------------------------------------------------------

  /// An open book held low and centred. The widest prop, and the only one with a
  /// strong horizontal line — that is what makes "reading" read instantly.
  void _openBook(Canvas canvas, double s) {
    final w = s * 0.50;
    final h = s * 0.20;
    final cx = s * 0.50;
    final cy = s * 0.735 + _float(0.8);

    final page = Paint()..color = AppColors.surface;
    final edge = Paint()
      ..color = inkColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.008);

    final left = Path()
      ..moveTo(cx, cy - h * 0.10)
      ..lineTo(cx - w / 2, cy - h * 0.42)
      ..lineTo(cx - w / 2, cy + h * 0.34)
      ..lineTo(cx, cy + h * 0.62)
      ..close();
    final right = Path()
      ..moveTo(cx, cy - h * 0.10)
      ..lineTo(cx + w / 2, cy - h * 0.42)
      ..lineTo(cx + w / 2, cy + h * 0.34)
      ..lineTo(cx, cy + h * 0.62)
      ..close();

    canvas.drawPath(left, page);
    canvas.drawPath(right, page);
    canvas.drawPath(left, edge);
    canvas.drawPath(right, edge);

    // Two rule lines per page, so it reads as text rather than as a folded card.
    final rule = Paint()
      ..color = inkColor.withValues(alpha: 0.30)
      ..strokeWidth = math.max(0.8, s * 0.006)
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 2; i++) {
        final y = cy - h * 0.02 + i * h * 0.22;
        canvas.drawLine(
          Offset(cx + side * w * 0.10, y),
          Offset(cx + side * w * 0.40, y - h * 0.12),
          rule,
        );
      }
    }
  }

  /// A notebook and pencil, low and to one side. Deliberately smaller and
  /// off-centre compared with the open book, so the two never read alike.
  void _notebook(Canvas canvas, double s) {
    final w = s * 0.30;
    final h = s * 0.17;
    final left = s * 0.52;
    final top = s * 0.700 + _float(0.5);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      Radius.circular(s * 0.014),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.surface);
    canvas.drawRRect(
      body,
      Paint()
        ..color = inkColor.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, s * 0.008),
    );

    final rule = Paint()
      ..color = inkColor.withValues(alpha: 0.32)
      ..strokeWidth = math.max(0.7, s * 0.005);
    for (var i = 0; i < 3; i++) {
      final y = top + h * (0.26 + i * 0.22);
      canvas.drawLine(
          Offset(left + w * 0.12, y), Offset(left + w * 0.88, y), rule);
    }

    // Pencil, angled across the page — the detail that separates "writing" from
    // "holding a small book".
    final pencil = Paint()
      ..color = AppColors.accentPeach
      ..strokeWidth = math.max(1.4, s * 0.014)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(left + w * 0.30, top - h * 0.30),
      Offset(left + w * 0.86, top + h * 0.52),
      pencil,
    );
    canvas.drawCircle(
      Offset(left + w * 0.30, top - h * 0.30),
      math.max(1.0, s * 0.010),
      Paint()..color = inkColor.withValues(alpha: 0.8),
    );
  }

  /// Three rising bubbles, upper-right. Nothing else in the pose table sits in
  /// that corner, so "thinking" is unmistakable and also clears the head.
  void _thoughtBubbles(Canvas canvas, double s) {
    final baseX = s * 0.76;
    final baseY = s * 0.28 + _float(1.4);

    final fill = Paint()..color = AppColors.surface.withValues(alpha: 0.95);
    final edge = Paint()
      ..color = inkColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, s * 0.007);

    const radii = [0.030, 0.048, 0.070];
    for (var i = 0; i < radii.length; i++) {
      final r = s * radii[i];
      final c = Offset(baseX - i * s * 0.055, baseY - i * s * 0.085);
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, edge);
    }
  }

  /// A small mallet and a spark, low-centre-right. Craft reads as *making*
  /// rather than as *writing* because the tool is held up, not laid flat.
  void _tools(Canvas canvas, double s) {
    final cx = s * 0.70;
    final cy = s * 0.66 + _float(1.0);

    final handle = Paint()
      ..color = inkColor.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1.6, s * 0.018)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy + s * 0.075),
      Offset(cx, cy - s * 0.045),
      handle,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - s * 0.075),
          width: s * 0.105,
          height: s * 0.055,
        ),
        Radius.circular(s * 0.010),
      ),
      Paint()..color = AppColors.accentPeach,
    );

    _star(canvas, Offset(cx - s * 0.085, cy - s * 0.125), s * 0.026,
        AppColors.accentGold);
  }

  /// Two four-point stars, upper-left. Used for the finishing beat and the
  /// unlock reaction.
  void _sparkle(Canvas canvas, double s, {required int count}) {
    final spots = <Offset>[
      Offset(s * 0.24, s * 0.26 + _float(1.6)),
      Offset(s * 0.80, s * 0.20 + _float(-1.2)),
      Offset(s * 0.68, s * 0.40),
    ];
    for (var i = 0; i < count && i < spots.length; i++) {
      _star(canvas, spots[i], s * 0.036, AppColors.accentGold);
    }
  }

  /// Confetti above the head. Deliberately spread wide and multi-coloured, so a
  /// celebration is visible even in a small room avatar.
  void _confetti(Canvas canvas, double s) {
    const colours = [
      AppColors.accentPeach,
      AppColors.accentGold,
      AppColors.primarySage,
      AppColors.catStudy,
    ];
    const positions = <Offset>[
      Offset(0.22, 0.20),
      Offset(0.38, 0.12),
      Offset(0.54, 0.18),
      Offset(0.70, 0.11),
      Offset(0.84, 0.21),
      Offset(0.30, 0.31),
      Offset(0.64, 0.30),
    ];
    for (var i = 0; i < positions.length; i++) {
      final p = positions[i];
      final dx = _float(1.8 + i * 0.35);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(s * p.dx + dx, s * p.dy),
            width: s * 0.030,
            height: s * 0.046,
          ),
          Radius.circular(s * 0.008),
        ),
        Paint()..color = colours[i % colours.length],
      );
    }
  }

  /// Two soft "Z" glyphs, upper-right — the resting marker.
  void _restZ(Canvas canvas, double s) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'z',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          color: AppColors.primarySage,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    for (var i = 0; i < 2; i++) {
      final scale = 0.85 + i * 0.30;
      painter.text = TextSpan(
        text: 'z',
        style: TextStyle(
          fontSize: s * 0.115 * scale,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          color: AppColors.primarySage.withValues(alpha: 0.85 - i * 0.22),
        ),
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(
          s * 0.72 + i * s * 0.075,
          s * 0.26 - i * s * 0.10 + _float(1.2 - i * 0.4),
        ),
      );
    }
  }

  /// A short exclamation above the head for a tap reaction.
  void _tapSpark(Canvas canvas, double s) {
    final cx = s * 0.78;
    final top = s * 0.20 + _float(1.2);

    final bar = Paint()
      ..color = AppColors.accentPeach
      ..strokeWidth = math.max(1.8, s * 0.020)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, top),
      Offset(cx, top + s * 0.085),
      bar,
    );
    canvas.drawCircle(
      Offset(cx, top + s * 0.125),
      math.max(1.4, s * 0.014),
      Paint()..color = AppColors.accentPeach,
    );
  }

  /// A single heart above the head — the long-press "轻抚" response.
  void _heart(Canvas canvas, double s) {
    final cx = s * 0.76;
    final cy = s * 0.24 + _float(1.4);
    final r = s * 0.052;

    final path = Path()
      ..moveTo(cx, cy + r * 0.85)
      ..cubicTo(cx - r * 1.7, cy - r * 0.30, cx - r * 0.75, cy - r * 1.45, cx,
          cy - r * 0.42)
      ..cubicTo(cx + r * 0.75, cy - r * 1.45, cx + r * 1.7, cy - r * 0.30, cx,
          cy + r * 0.85)
      ..close();

    canvas.drawPath(path, Paint()..color = AppColors.accentPeach);
  }

  /// A raised paw with two motion arcs, upper-right.
  void _wave(Canvas canvas, double s) {
    final cx = s * 0.76;
    final cy = s * 0.50 + _float(1.6);

    canvas.drawCircle(
      Offset(cx, cy),
      s * 0.048,
      Paint()..color = AppColors.surface,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      s * 0.048,
      Paint()
        ..color = inkColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, s * 0.007),
    );

    final arc = Paint()
      ..color = AppColors.accentGold.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.011)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final r = s * (0.075 + i * 0.045);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi * 0.75,
        math.pi * 0.45,
        false,
        arc,
      );
    }
  }

  /// A four-point star.
  void _star(Canvas canvas, Offset centre, double radius, Color colour) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? radius : radius * 0.36;
      final a = -math.pi / 2 + i * math.pi / 4;
      final p =
          Offset(centre.dx + r * math.cos(a), centre.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_MochiPosePropPainter old) =>
      old.kind != kind || old.phase != phase || old.inkColor != inkColor;
}
