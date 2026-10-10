import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The warm room the home hero sits in, drawn rather than photographed.
///
/// ## Why this is painted
///
/// Every board draws the home screen as a room: a wall, a window with afternoon
/// light, a shelf with plants, a wooden desk in the foreground and a woven mat
/// under Mochi. This project recorded that as `BLOCKED_EXTERNAL` for several
/// passes on the grounds that "the repo has no asset for it" — which was true of
/// a *photograph* and false of the requirement. The app already draws all of its
/// own art procedurally (`mochi_layered_renderer.dart`, `mochi_pose_prop.dart`,
/// `cozy_furniture_artwork.dart`), so a room in the same idiom is a painter, not
/// a missing file. No photograph is cropped in, and nothing is traced from the
/// boards: the boards set the composition and the palette, and the shapes here
/// are the app's own.
///
/// ## What it deliberately is not
///
/// It is not a copy of the board's room. The board's room is a photographic
/// render with a dozen incidental objects; this is a flat illustration that has
/// to sit behind text and a pet at 411dp and stay quiet. So: five elements, one
/// light direction, and no object the app has no reason to draw.
///
/// The colours are the scene's own warm tones, not tokens from [AppColors],
/// because the palette is a UI palette — it has no wood in it. They were sampled
/// from board 01's window (`#FAE7BF`), shelf (`#946941`), desk (`#C89A61`) and
/// mat, then desaturated slightly so the cards in front of them keep the
/// contrast they have on the flat background.
class CozyRoomBackdrop extends StatelessWidget {
  /// How much of the scene's height is wall, 0..1. The desk fills the rest.
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
    // Decorative: it is the background of a screen whose content already says
    // what the screen is, so it must not add a stop to the accessibility tree.
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
///
/// The first version of this scene used the board's raw samples and it read as a
/// brown room with a dark band across it — the desk (`#C89A61`) sat behind white
/// cards and stole their contrast, and the mat was the same tan as the desk, so
/// the two merged. These are the same hues lifted toward the wall's value, which
/// keeps the scene quiet enough for the content on top of it.
class _Room {
  static const wallTop = Color(0xFFF6EDDD);
  static const wallBottom = Color(0xFFEFE4D0);
  static const light = Color(0xFFFCEFD4);
  static const lightCore = Color(0xFFFFFAEC);
  static const wood = Color(0xFFD9B183);
  static const woodDark = Color(0xFFBE9A70);
  static const woodLight = Color(0xFFE7CDA6);
  static const mat = Color(0xFFF2E7CD);
  static const matLine = Color(0xFFDCC9A2);
  static const pot = Color(0xFFE0B48C);
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
    _paintWindow(canvas, w, h, deskY);
    _paintLightShafts(canvas, w, h, deskY);
    _paintShelf(canvas, w, h);
    _paintDesk(canvas, w, h, deskY);
    _paintMat(canvas, w, h, deskY);
    _paintMug(canvas, w, h, deskY);
    _paintBooks(canvas, w, h, deskY);

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
  }

  /// A window on the right, below the status bar and clear of the settings
  /// control at the top-right.
  ///
  /// The first version started at 7% of the band, which put it under the status
  /// bar and directly beneath the gear — a control sitting on a drawn object
  /// reads as a mistake. It now starts at 18% and stops above the desk.
  void _paintWindow(Canvas canvas, double w, double h, double deskY) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.63, h * 0.18, w * 0.33, deskY - h * 0.24),
      const Radius.circular(6),
    );

    // The glow spills past the frame, which is what makes the room read as lit
    // rather than as a picture of a window pasted on a wall.
    canvas.drawRect(
      Rect.fromLTWH(rect.left - w * 0.16, rect.top - h * 0.04,
          rect.width + w * 0.30, rect.height + h * 0.10),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _Room.light.withValues(alpha: 0.85),
            _Room.light.withValues(alpha: 0.0),
          ],
          stops: const [0.35, 1.0],
        ).createShader(
          Rect.fromLTWH(rect.left - w * 0.16, rect.top - h * 0.04,
              rect.width + w * 0.30, rect.height + h * 0.10),
        ),
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

    // Frame and mullions.
    final frame = Paint()
      ..color = _Room.woodDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rect, frame);
    final cx = rect.left + rect.width / 2;
    final cy = rect.top + rect.height / 2;
    canvas.drawLine(Offset(cx, rect.top), Offset(cx, rect.bottom), frame);
    canvas.drawLine(Offset(rect.left, cy), Offset(rect.right, cy), frame);
  }

  /// Two soft shafts falling from the window down to the desk.
  void _paintLightShafts(Canvas canvas, double w, double h, double deskY) {
    final paint = Paint()..color = _Room.light.withValues(alpha: 0.26);
    final top = h * 0.20;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.66, top)
        ..lineTo(w * 0.92, top)
        ..lineTo(w * 0.40, deskY)
        ..lineTo(w * 0.10, deskY)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.74, top)
        ..lineTo(w * 0.84, top)
        ..lineTo(w * 0.58, deskY)
        ..lineTo(w * 0.48, deskY)
        ..close(),
      paint..color = _Room.light.withValues(alpha: 0.18),
    );
  }

  /// A plank shelf on the left with two small plants.
  ///
  /// At 30% of the band this sat exactly behind the greeting's second line and
  /// the plants drew over the words — a P0, content obscured by decoration. It
  /// now sits at 45%, below the headline, and only reaches a third of the way
  /// across so it stays left of the pet.
  void _paintShelf(Canvas canvas, double w, double h) {
    final y = h * 0.45;
    final left = w * 0.0;
    final right = w * 0.30;

    // Bracket first, so the plank's edge covers where they meet.
    canvas.drawRect(
      Rect.fromLTWH(left + w * 0.04, y + 4, 5, h * 0.05),
      Paint()..color = _Room.woodDark,
    );
    canvas.drawRect(
      Rect.fromLTWH(right - w * 0.06, y + 4, 5, h * 0.05),
      Paint()..color = _Room.woodDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, right - left, 7),
        const Radius.circular(2),
      ),
      Paint()..color = _Room.wood,
    );

    _plant(canvas, Offset(left + w * 0.10, y), 1.0);
    _plant(canvas, Offset(left + w * 0.26, y), 0.78);
  }

  /// A potted plant standing on [base], where [scale] sets its size.
  void _plant(Canvas canvas, Offset base, double scale) {
    final potW = 16.0 * scale;
    final potH = 13.0 * scale;
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

    // Three leaves on short stems: enough to read as a plant at 40dp, and no
    // more detail than that.
    final stem = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = AppColors.primarySage;
    for (final a in const [-0.7, 0.0, 0.7]) {
      final tip = Offset(
        base.dx + math.sin(a) * 11 * scale,
        base.dy - potH - 13 * scale * math.cos(a * 0.5),
      );
      canvas.drawLine(Offset(base.dx, base.dy - potH), tip, stem);
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 11 * scale,
          height: 6.5 * scale,
        ),
        leaf,
      );
      canvas.restore();
    }
  }

  /// The desk across the foreground: a lit top edge and a darker front face.
  void _paintDesk(Canvas canvas, double w, double h, double deskY) {
    canvas.drawRect(
      Rect.fromLTWH(0, deskY, w, h - deskY),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Room.woodLight, _Room.wood],
        ).createShader(Rect.fromLTWH(0, deskY, w, h - deskY)),
    );
    // The highlight is what makes it a surface catching light rather than a
    // brown band.
    canvas.drawRect(
      Rect.fromLTWH(0, deskY, w, 3),
      Paint()..color = const Color(0xFFF0D9B4),
    );
    // A single grain line, low contrast, to stop the face reading as flat.
    canvas.drawLine(
      Offset(0, deskY + (h - deskY) * 0.45),
      Offset(w, deskY + (h - deskY) * 0.38),
      Paint()
        ..color = _Room.woodDark.withValues(alpha: 0.18)
        ..strokeWidth = 1.5,
    );
  }

  /// The woven mat Mochi rests on.
  void _paintMat(Canvas canvas, double w, double h, double deskY) {
    final centre = Offset(w * 0.5, deskY + (h - deskY) * 0.30);
    final rect = Rect.fromCenter(
      center: centre,
      width: w * 0.62,
      height: (h - deskY) * 0.62,
    );
    canvas.drawOval(rect, Paint()..color = _Room.mat);
    canvas.drawOval(
      rect.deflate(7),
      Paint()
        ..color = _Room.matLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  /// A mug, right of the mat, in the brand green the board draws it in.
  void _paintMug(Canvas canvas, double w, double h, double deskY) {
    final x = w * 0.80;
    final y = deskY + (h - deskY) * 0.26;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, 20, 22),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.primarySage);
    canvas.drawArc(
      Rect.fromLTWH(x + 17, y + 4, 12, 13),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..color = AppColors.primarySage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  /// Two stacked books, left of the mat.
  void _paintBooks(Canvas canvas, double w, double h, double deskY) {
    final baseY = deskY + (h - deskY) * 0.34;
    final x = w * 0.10;
    for (final (dy, width, colour) in const [
      (0.0, 42.0, Color(0xFFB98A63)),
      (-7.0, 34.0, Color(0xFF8FA98C)),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY + dy, width, 7),
          const Radius.circular(2),
        ),
        Paint()..color = colour,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.deskLine != deskLine || old.dim != dim;
}
