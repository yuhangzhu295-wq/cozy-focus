import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The warm room the pet sits in, drawn rather than photographed.
///
/// ## Why this is painted
///
/// Every board draws these screens as a room: a wall, a window with afternoon
/// light, a shelf with plants, a wooden desk in the foreground and a woven mat
/// under the pet. This project recorded that as `BLOCKED_EXTERNAL` for several
/// passes on the grounds that "the repo has no asset for it" — which was true of
/// a *photograph* and false of the requirement.
///
/// **Image generation was then actually probed rather than assumed**:
/// `tools/qa/probe_image_generation.py` reports that Volcano Ark is reachable but
/// the available key is an access-key id rather than a bearer token, and the
/// OpenAI key is rejected. So there is no generation path here, and the room is a
/// painter — the same way every other piece of this app's art is made.
///
/// Nothing is cropped in from the boards and nothing is traced from them: the
/// boards set the composition and the palette, the shapes are the app's own.
///
/// ## Depth, which is what the boards actually have
///
/// The boards' rooms are soft behind the pet and sharp in front of it, and the
/// first version of this painter had no depth at all — flat shapes on a flat
/// wall, which is why it read as a diagram of a room rather than a room. The far
/// elements are now painted into a blurred layer and the near ones sharp, and a
/// light bloom and a vignette sit over the whole thing.
class CozyRoomBackdrop extends StatelessWidget {
  /// Where the desk surface starts, as a fraction of the scene's height.
  final double deskLine;

  /// Dims the whole scene, for use behind a running focus session.
  final double dim;

  const CozyRoomBackdrop({
    super.key,
    this.deskLine = 0.60,
    this.dim = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Decorative: the screens using it already say what they are, so it must not
    // add a stop to the accessibility tree.
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _RoomPainter(deskLine: deskLine, dim: dim),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The scene's own tones. Named here rather than in [AppColors] because they are
/// illustration colours: no control, text or border may use them.
class _Room {
  static const wallTop = Color(0xFFF7EFE0);
  static const wallBottom = Color(0xFFEDE0C9);
  static const wallShade = Color(0xFFE4D4B8);
  static const light = Color(0xFFFDF1D6);
  static const lightCore = Color(0xFFFFFBF0);
  static const wood = Color(0xFFD9B183);
  static const woodDark = Color(0xFFBE9A70);
  static const woodLight = Color(0xFFEBD5B2);
  static const mat = Color(0xFFF3E8CF);
  static const matLine = Color(0xFFDCC9A2);
  static const pot = Color(0xFFE0B48C);
  static const leaf = Color(0xFF6F9B62);
}

class _RoomPainter extends CustomPainter {
  final double deskLine;
  final double dim;

  _RoomPainter({required this.deskLine, required this.dim});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final deskY = h * deskLine;

    _paintWall(canvas, size, w, h);

    // ── far layer, blurred ────────────────────────────────────────────────
    // A blurred backdrop is what separates "a room" from "shapes on a wall".
    // The boards' rooms are out of focus behind the pet.
    canvas.saveLayer(
      Rect.fromLTWH(-w * 0.1, -h * 0.1, w * 1.2, deskY + h * 0.1),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.3, sigmaY: 2.3),
    );
    _paintWindowGlow(canvas, w, h, deskY);
    _paintShelf(canvas, w, h);
    _paintWindow(canvas, w, h, deskY);
    canvas.restore();

    // ── near layer, sharp ─────────────────────────────────────────────────
    _paintDesk(canvas, w, h, deskY);
    _paintMat(canvas, w, h, deskY);
    _paintBooks(canvas, w, h, deskY);
    _paintMug(canvas, w, h, deskY);

    // ── light and falloff ─────────────────────────────────────────────────
    _paintShafts(canvas, w, h, deskY);
    _paintVignette(canvas, w, h);

    if (dim > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = AppColors.focusNightBg.withValues(alpha: dim),
      );
    }
  }

  void _paintWall(Canvas canvas, Size size, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Room.wallTop, _Room.wallBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Where the wall meets the floor, shaded rather than lined: a hard line
    // would read as a wall of a different height on every screen size.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.52, w, h * 0.48),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _Room.wallShade.withValues(alpha: 0.0),
            _Room.wallShade.withValues(alpha: 0.55),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.52, w, h * 0.48)),
    );
  }

  /// The light spilling out of the window, painted before the frame so the glow
  /// is behind it.
  void _paintWindowGlow(Canvas canvas, double w, double h, double deskY) {
    final rect = Rect.fromLTWH(w * 0.55, h * 0.06, w * 0.55, deskY * 0.95);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _Room.light.withValues(alpha: 0.95),
            _Room.light.withValues(alpha: 0.45),
            _Room.light.withValues(alpha: 0.0),
          ],
          stops: const [0.25, 0.6, 1.0],
        ).createShader(rect),
    );
  }

  /// A window on the right, below the status bar and clear of the settings chip.
  void _paintWindow(Canvas canvas, double w, double h, double deskY) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          w * 0.63, h * 0.18, w * 0.33, math.max(24, deskY - h * 0.24)),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Room.lightCore, _Room.light],
        ).createShader(rect.outerRect),
    );
    final frame = Paint()
      ..color = _Room.woodDark.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawRRect(rect, frame);
    final cx = rect.left + rect.width / 2;
    final cy = rect.top + rect.height / 2;
    canvas.drawLine(Offset(cx, rect.top), Offset(cx, rect.bottom), frame);
    canvas.drawLine(Offset(rect.left, cy), Offset(rect.right, cy), frame);
  }

  /// A plank shelf on the left with two small plants, below the headline.
  void _paintShelf(Canvas canvas, double w, double h) {
    final y = h * 0.42;
    const left = 0.0;
    final right = w * 0.30;

    final bracket = Paint()..color = _Room.woodDark.withValues(alpha: 0.8);
    canvas.drawRect(
        Rect.fromLTWH(left + w * 0.05, y + 4, 4, h * 0.045), bracket);
    canvas.drawRect(
        Rect.fromLTWH(right - w * 0.06, y + 4, 4, h * 0.045), bracket);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, right - left, 6),
        const Radius.circular(2),
      ),
      Paint()..color = _Room.wood,
    );
    // A darker underside, so the plank has thickness even blurred.

    _plant(canvas, Offset(left + w * 0.10, y), 1.0);
    _plant(canvas, Offset(left + w * 0.24, y), 0.76);
  }

  void _plant(Canvas canvas, Offset base, double scale) {
    final potW = 15.0 * scale;
    final potH = 12.0 * scale;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(base.dx - potW / 2, base.dy - potH, potW, potH),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      ),
      Paint()..color = _Room.pot,
    );
    final stem = Paint()
      ..color = _Room.leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = _Room.leaf;
    for (final a in const [-0.7, 0.0, 0.7]) {
      final tip = Offset(
        base.dx + math.sin(a) * 10 * scale,
        base.dy - potH - 12 * scale * math.cos(a * 0.5),
      );
      canvas.drawLine(Offset(base.dx, base.dy - potH), tip, stem);
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: 10 * scale, height: 6 * scale),
        leaf,
      );
      canvas.restore();
    }
  }

  /// The desk across the foreground: a lit top edge and a shaded front face.
  void _paintDesk(Canvas canvas, double w, double h, double deskY) {
    final face = Rect.fromLTWH(0, deskY, w, h - deskY);
    canvas.drawRect(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Room.woodLight, _Room.wood, _Room.woodDark],
          stops: [0.0, 0.45, 1.0],
        ).createShader(face),
    );
    // The highlight is what makes it a surface catching light rather than a band.
    canvas.drawRect(
      Rect.fromLTWH(0, deskY, w, 2.5),
      Paint()..color = const Color(0xFFF6E4C4),
    );
    // One soft grain line, low contrast, so the face is not flat.
    canvas.drawPath(
      Path()
        ..moveTo(0, deskY + (h - deskY) * 0.52)
        ..quadraticBezierTo(
            w * 0.5, deskY + (h - deskY) * 0.42, w, deskY + (h - deskY) * 0.50),
      Paint()
        ..color = _Room.woodDark.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// The woven mat the pet rests on.
  void _paintMat(Canvas canvas, double w, double h, double deskY) {
    final centre = Offset(w * 0.5, deskY + (h - deskY) * 0.26);
    final rect = Rect.fromCenter(
      center: centre,
      width: w * 0.60,
      height: (h - deskY) * 0.56,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _Room.mat,
            _Room.mat.withValues(alpha: 0.85),
            _Room.matLine.withValues(alpha: 0.5),
          ],
          stops: const [0.55, 0.85, 1.0],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect.deflate(6),
      Paint()
        ..color = _Room.matLine.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  void _paintMug(Canvas canvas, double w, double h, double deskY) {
    final x = w * 0.79;
    final y = deskY + (h - deskY) * 0.24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 19, 21), const Radius.circular(3)),
      Paint()..color = AppColors.primarySage,
    );
    canvas.drawArc(
      Rect.fromLTWH(x + 16, y + 4, 11, 12),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..color = AppColors.primarySage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );
  }

  void _paintBooks(Canvas canvas, double w, double h, double deskY) {
    final baseY = deskY + (h - deskY) * 0.32;
    final x = w * 0.10;
    for (final (dy, width, colour) in const [
      (0.0, 40.0, Color(0xFFB98A63)),
      (-6.5, 32.0, Color(0xFF8FA98C)),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY + dy, width, 6.5),
          const Radius.circular(2),
        ),
        Paint()..color = colour,
      );
    }
  }

  /// Two soft shafts falling from the window toward the desk.
  void _paintShafts(Canvas canvas, double w, double h, double deskY) {
    final paint = Paint()..color = _Room.light.withValues(alpha: 0.20);
    final top = h * 0.22;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.66, top)
        ..lineTo(w * 0.90, top)
        ..lineTo(w * 0.44, deskY)
        ..lineTo(w * 0.16, deskY)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.74, top)
        ..lineTo(w * 0.83, top)
        ..lineTo(w * 0.60, deskY)
        ..lineTo(w * 0.51, deskY)
        ..close(),
      paint..color = _Room.light.withValues(alpha: 0.13),
    );
  }

  /// The scene falls off at its edges, which is what stops it reading as a flat
  /// panel behind the content.
  void _paintVignette(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            const Color(0x00000000),
            _Room.wallShade.withValues(alpha: 0.30),
          ],
          stops: const [0.62, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.deskLine != deskLine || old.dim != dim;
}
