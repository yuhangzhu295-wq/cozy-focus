import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// **Candidate** — a high-fidelity hand-drawn room, for visual comparison only.
///
/// ## Why this file exists
///
/// The photographic-room question was settled against *one* alternative: a
/// photographic room behind the 2D sprite reads as a sticker on a photo, so the
/// room has to be the same drawing style as the pet. That conclusion is sound.
///
/// **It does not follow that the simplified vector room is the only option**,
/// which is the inference this candidate exists to test. The third route is
/// *high-precision 2D hand-drawn room + the existing Mochi sprite + Flutter
/// layering*: same illustration language as the pet, but with the depth,
/// material detail and light that the shipped painter does not attempt.
///
/// So this is a candidate, not a replacement. Nothing production references it,
/// and it lives on its own branch until the owner chooses. The shipped room
/// (`cozy_room_backdrop.dart`) is untouched.
///
/// ## What "higher fidelity" means here, concretely
///
/// Against the shipped painter, which is flat shapes on a flat wall:
///
/// * a **two-plane corner** with a receding side wall, so the room has a third
///   dimension rather than being a backdrop;
/// * a **window with a view** — frame, mullions, sill, curtain — and the light
///   it actually casts, as a perspective pool on the floor that the floorboards
///   brighten inside;
/// * **floorboards with converging seams**, not a flat fill;
/// * furniture with **thickness and legs**, plus contact shadows that sit the
///   objects on the floor instead of floating them;
/// * **materials**: wood grain, woven rug with fringe, layered leaves with
///   highlights, glass and steam;
/// * **atmosphere**: dust motes inside the light shaft, a warm grade and a
///   vignette;
/// * a **steeper depth-of-field split** — the far plane is blurred harder than
///   the shipped painter's 2.3 sigma, the near plane is sharp.
///
/// ## What it deliberately does not do
///
/// No picture frames, posters or photographs on the wall. The owner's brief for
/// this route forbids them, and the upper-left wall has to stay quiet because
/// the app draws the greeting text over it in white.
class CozyRoomHandDrawn extends StatelessWidget {
  /// Where the desk surface starts, as a fraction of the scene's height.
  final double deskLine;

  /// Dims the whole scene, for use behind a running focus session.
  final double dim;

  const CozyRoomHandDrawn({
    super.key,
    this.deskLine = 0.60,
    this.dim = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _HdRoomPainter(deskLine: deskLine, dim: dim),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The candidate's palette.
///
/// Deliberately the same family as the shipped room and as Mochi itself — warm
/// creams, wood browns, one soft green — because "consistent with the pet" is
/// the whole point of the route. The values are pulled a little richer than the
/// shipped set: more separation between wall, floor and furniture, so the extra
/// detail has something to sit in.
abstract final class _Hd {
  // Walls: a warm plaster that fades toward the floor.
  static const wallTop = Color(0xFFB08F66);
  static const wallBottom = Color(0xFF9C7B52);
  static const wallSide = Color(0xFF8A6A46);
  static const skirting = Color(0xFFE3D2B4);

  // Window and the light it lets in.
  static const frame = Color(0xFFF2E6CE);
  static const frameShade = Color(0xFFD8C4A2);
  static const glassTop = Color(0xFFFFF6E2);
  static const glassBottom = Color(0xFFF3DFB6);
  static const outsideFar = Color(0xFFCFE0C4);
  static const outsideNear = Color(0xFFA8C79A);
  static const curtain = Color(0xFFF6EAD2);
  static const lightPool = Color(0xFFFFF0CC);

  /// The hottest tone in the scene: the window's own core, the lamp's halo and
  /// the dust motes all use it.
  static const lightCore = Color(0xFFFFFAEE);

  // Floor.
  static const floorA = Color(0xFFA9834F);
  static const floorB = Color(0xFF9A7748);
  static const floorSeam = Color(0xFF7C5F38);
  static const floorGloss = Color(0xFFFFE9BE);

  // Wood furniture.
  static const woodTop = Color(0xFFB08A5C);
  static const woodEdge = Color(0xFF8A6A46);
  static const woodDark = Color(0xFF6B4F31);
  static const grain = Color(0xFF9A7748);

  // Rug.
  static const rug = Color(0xFFCFB183);
  static const rugInner = Color(0xFFBE9E70);
  static const rugLine = Color(0xFFB08F66);

  // Plants.
  static const leafDark = Color(0xFF4E7A45);
  static const leaf = Color(0xFF5E8A52);
  static const leafLight = Color(0xFF7BA469);
  static const pot = Color(0xFFA97C55);
  static const potShade = Color(0xFF8C6444);

  // Small objects.
  static const ceramic = Color(0xFFF3EADB);
  static const ceramicShade = Color(0xFFD9CBB6);
  static const brass = Color(0xFFC9A063);
  static const paper = Color(0xFFF7F0E2);
  static const ink = Color(0xFF5A4632);
}

class _HdRoomPainter extends CustomPainter {
  final double deskLine;
  final double dim;

  _HdRoomPainter({required this.deskLine, required this.dim});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final deskY = h * deskLine;

    // The corner: the back wall ends here and the side wall recedes to the left.
    final cornerX = w * 0.30;
    // Where the two walls meet the floor, and where the eye converges.
    final vanish = Offset(w * 0.66, deskY * 0.74);

    _paintBackWall(canvas, w, h, deskY);
    _paintSideWall(canvas, w, h, deskY, cornerX, vanish);
    _paintSkirting(canvas, w, h, deskY, cornerX, vanish);
    _paintFloor(canvas, w, h, deskY, vanish);

    // ── far plane: blurred, but not so hard that the window dissolves ─────
    //
    // 2.6 rather than 3.1. The window is the room's light source and the
    // shipped room's strongest single element; at 3.1 its frame and view read
    // as a bright smudge, which is exactly the "smaller and dimmer" complaint.
    // The shelf is *not* in this layer any more - it has its own below.
    canvas.saveLayer(
      Rect.fromLTWH(-w * 0.1, -h * 0.1, w * 1.2, deskY + h * 0.08),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.6, sigmaY: 2.6),
    );
    _paintWindowGlow(canvas, w, h, deskY);
    _paintWindow(canvas, w, h, deskY);
    canvas.restore();

    // The shelf is on the far side wall, so it should be *slightly* soft - but
    // at the far plane's sigma its boards and spines collapsed into a smudge
    // with green streaks. Its own light blur keeps it behind the near plane
    // while leaving the silhouette readable.
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, cornerX + w * 0.06, deskY + h * 0.05),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 0.9, sigmaY: 0.9),
    );
    _paintShelf(canvas, w, h, deskY, cornerX, vanish);
    canvas.restore();

    // ── near plane: sharp ─────────────────────────────────────────────────
    _paintLightPool(canvas, w, h, deskY, vanish);
    _paintRug(canvas, w, h, deskY);
    _paintFloorPlant(canvas, w, h, deskY);
    _paintDesk(canvas, w, h, deskY);

    // ── light and falloff ─────────────────────────────────────────────────
    _paintShaft(canvas, w, h, deskY);
    _paintMotes(canvas, w, h, deskY);
    _paintGrade(canvas, w, h);
    _paintVignette(canvas, w, h);

    if (dim > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = AppColors.focusNightBg.withValues(alpha: dim),
      );
    }
  }

  // ── walls ───────────────────────────────────────────────────────────────

  void _paintBackWall(Canvas canvas, double w, double h, double deskY) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, deskY),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, deskY),
          [_Hd.wallTop, _Hd.wallBottom],
        ),
    );
    // A soft vertical bloom where daylight washes the plaster, left of the
    // window, so the wall is lit rather than tinted.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.34, 0, w * 0.40, deskY),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.54, deskY * 0.30),
          w * 0.52,
          [
            _Hd.lightPool.withValues(alpha: 0.30),
            _Hd.lightPool.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  /// The side wall, as a perspective wedge.
  ///
  /// This is the piece the shipped painter has no equivalent of: without it the
  /// scene is a backdrop, and with it the room has a corner to stand in.
  void _paintSideWall(Canvas canvas, double w, double h, double deskY,
      double cornerX, Offset vanish) {
    // The near edge starts *above* the frame. A side wall nearer the viewer is
    // taller, not shorter: the previous version ran from `deskY * 0.30` at
    // x = 0 up to 0 at the corner, which drew a dark diagonal band across the
    // top-left and read as a shadow laid over the room rather than as a wall.
    // With the near edge off-frame the plane fills the corner and the only
    // remaining edge is the vertical fold, which is the one that means
    // something.
    final path = Path()
      ..moveTo(0, -h * 0.10)
      ..lineTo(cornerX, 0)
      ..lineTo(cornerX, deskY)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, deskY * 0.4),
          Offset(cornerX, deskY),
          // The far end is a touch lighter: daylight from the window spills
          // along the wall, and without that the plane is a flat slab.
          [_Hd.wallSide, Color.lerp(_Hd.wallSide, _Hd.wallTop, 0.22)!],
        ),
    );
    // The inside corner, where the two planes meet: a soft dark seam sells the
    // fold more than a hard line does.
    canvas.drawLine(
      Offset(cornerX, 0),
      Offset(cornerX, deskY),
      Paint()
        ..color = _Hd.woodDark.withValues(alpha: 0.12)
        ..strokeWidth = w * 0.010
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintSkirting(Canvas canvas, double w, double h, double deskY,
      double cornerX, Offset vanish) {
    final boardH = deskY * 0.035;
    // Back wall's board.
    canvas.drawRect(
      Rect.fromLTWH(cornerX, deskY - boardH, w - cornerX, boardH),
      Paint()..color = _Hd.skirting.withValues(alpha: 0.55),
    );
    // The side wall's board, thinner because it is further away at its far end.
    final path = Path()
      ..moveTo(0, deskY + boardH * 0.6)
      ..lineTo(cornerX, deskY - boardH)
      ..lineTo(cornerX, deskY)
      ..lineTo(0, deskY + boardH * 1.8)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = _Hd.skirting.withValues(alpha: 0.38),
    );
  }

  // ── floor ───────────────────────────────────────────────────────────────

  /// Floorboards that converge on the vanishing point.
  ///
  /// The shipped room fills the floor with one flat colour. Boards give it a
  /// direction, which is what makes the perspective pool of light read as lying
  /// *on* the floor rather than being a bright patch of screen.
  void _paintFloor(
      Canvas canvas, double w, double h, double deskY, Offset vanish) {
    canvas.drawRect(
      Rect.fromLTWH(0, deskY, w, h - deskY),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, deskY),
          Offset(0, h),
          [_Hd.floorA, _Hd.floorB],
        ),
    );

    // Seams run nearly straight down the screen, very faint.
    //
    // The first revision radiated them from the vanishing point. That is the
    // textbook construction and it was a graphic disaster here: from a camera
    // looking slightly down at a floor the lines fanned out beneath the pet like
    // a sunburst, and became the loudest thing in the frame. A plank floor seen
    // from this angle reads as near-vertical seams with a slight spread, and at
    // this alpha they suggest boards without competing with the character.
    //
    // No cross seams either: the first revision drew those too and they read as
    // a lattice laid over the floor rather than as boards.
    final seam = Paint()
      ..color = _Hd.floorSeam.withValues(alpha: 0.10)
      ..strokeWidth = 1.0;
    for (var i = 0; i <= 7; i++) {
      final x = w * (i / 7.0);
      canvas.drawLine(
        Offset(w * 0.5 + (x - w * 0.5) * 0.35, deskY),
        Offset(x, h),
        seam,
      );
    }
  }

  // ── window ──────────────────────────────────────────────────────────────

  void _paintWindowGlow(Canvas canvas, double w, double h, double deskY) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, deskY),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.70, deskY * 0.30),
          w * 0.96,
          [
            _Hd.lightPool.withValues(alpha: 0.74),
            _Hd.lightPool.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  void _paintWindow(Canvas canvas, double w, double h, double deskY) {
    // 0.40 x 0.56 of the wall, not 0.34 x 0.50. The shipped room's window is
    // its strongest element and the candidate's was reading as a small bright
    // rectangle; the extra height is what gives the wall a way out and lets the
    // light pool below it have a believable source.
    final winW = w * 0.40;
    final winH = deskY * 0.56;
    final left = w * 0.50;
    final top = deskY * 0.10;
    final rect = Rect.fromLTWH(left, top, winW, winH);

    // Curtain behind, wider than the opening.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            left - w * 0.05, top - deskY * 0.03, w * 0.07, winH * 1.12),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = _Hd.curtain.withValues(alpha: 0.85),
    );

    // The view: sky at the top, greenery below, so the window is a way out
    // rather than a bright rectangle.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
          rect.deflate(w * 0.012), Radius.circular(w * 0.01)),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [_Hd.glassTop, _Hd.glassBottom],
        ),
    );
    // The core: the sky is not a flat wash, it is the brightest thing in the
    // room. Without this the enlarged window is merely bigger, not brighter.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(rect.left + winW * 0.34, rect.top + winH * 0.22),
          winW * 0.78,
          [
            _Hd.lightCore.withValues(alpha: 0.92),
            _Hd.lightCore.withValues(alpha: 0.0),
          ],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top + winH * 0.52, winW, winH * 0.48),
      Paint()..color = _Hd.outsideFar.withValues(alpha: 0.85),
    );
    // A few soft tree crowns, blurred by the far layer this is painted into.
    for (var i = 0; i < 3; i++) {
      final cx = rect.left + winW * (0.20 + i * 0.30);
      final cy = rect.top + winH * (0.62 + (i.isEven ? 0.0 : 0.07));
      canvas.drawCircle(
        Offset(cx, cy),
        winW * 0.16,
        Paint()..color = _Hd.outsideNear.withValues(alpha: 0.75),
      );
    }
    canvas.restore();

    // Frame: outer, then mullions, then sill.
    final frame = Paint()..color = _Hd.frame;
    canvas.drawRect(
      Rect.fromLTWH(left, top, winW, winH),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..color = _Hd.frame,
    );
    canvas.drawLine(
      Offset(rect.center.dx, top),
      Offset(rect.center.dx, top + winH),
      Paint()
        ..color = _Hd.frame
        ..strokeWidth = w * 0.013,
    );
    canvas.drawLine(
      Offset(left, top + winH * 0.46),
      Offset(left + winW, top + winH * 0.46),
      Paint()
        ..color = _Hd.frame
        ..strokeWidth = w * 0.013,
    );
    // Sill, with its own shadow underneath.
    canvas.drawRect(
      Rect.fromLTWH(
          left - w * 0.022, top + winH, winW + w * 0.044, deskY * 0.022),
      frame,
    );
    canvas.drawRect(
      Rect.fromLTWH(left - w * 0.022, top + winH + deskY * 0.022,
          winW + w * 0.044, deskY * 0.010),
      Paint()..color = _Hd.frameShade.withValues(alpha: 0.5),
    );
  }

  // ── shelf ───────────────────────────────────────────────────────────────

  void _paintShelf(Canvas canvas, double w, double h, double deskY,
      double cornerX, Offset vanish) {
    // On the side wall, so it is drawn as a receding box rather than a front-on
    // rectangle — the same object seen in perspective.
    final topY = deskY * 0.26;
    final boardH = deskY * 0.018;
    final nearX = cornerX * 0.94;
    final farX = cornerX * 0.16;

    // A backing panel behind the boards. Without it the spines were drawn
    // straight onto the wall and, once blurred, read as coloured streaks rather
    // than as objects standing on a shelf. The panel gives them a silhouette
    // to sit against and is what the eye uses to read "shelf".
    canvas.drawPath(
      Path()
        ..moveTo(farX, topY - deskY * 0.02)
        ..lineTo(nearX, topY + deskY * 0.03 - deskY * 0.02)
        ..lineTo(nearX, topY + deskY * 0.26 + deskY * 0.03 + boardH)
        ..lineTo(farX, topY + deskY * 0.26 + boardH)
        ..close(),
      Paint()..color = _Hd.woodDark.withValues(alpha: 0.55),
    );

    for (var i = 0; i < 2; i++) {
      final y = topY + i * deskY * 0.26;
      final path = Path()
        ..moveTo(farX, y)
        ..lineTo(nearX, y + deskY * 0.03)
        ..lineTo(nearX, y + deskY * 0.03 + boardH)
        ..lineTo(farX, y + boardH)
        ..close();
      canvas.drawPath(path, Paint()..color = _Hd.woodEdge);
      canvas.drawPath(
        Path()
          ..moveTo(farX, y)
          ..lineTo(nearX, y + deskY * 0.03)
          ..lineTo(nearX, y + deskY * 0.03 - boardH * 0.35)
          ..lineTo(farX, y - boardH * 0.35)
          ..close(),
        Paint()..color = _Hd.woodTop,
      );

      // Book spines standing on the board, in the warm palette. Widths vary so
      // it reads as a shelf rather than a bar chart.
      var x = farX + (nearX - farX) * 0.10;
      var k = 0;
      while (x < nearX - (nearX - farX) * 0.12) {
        final t = (x - farX) / (nearX - farX);
        // Slightly larger than before: at the old size the spines were a few
        // pixels wide after the blur and carried no shape at all.
        final spineW = (nearX - farX) * (0.044 + (k % 3) * 0.014);
        final spineH = deskY * (0.125 + (k % 4) * 0.018);
        final baseY = y + deskY * 0.03 * t + boardH;
        final tone = [
          _Hd.woodDark,
          _Hd.pot,
          _Hd.leafDark,
          _Hd.ceramicShade,
          _Hd.brass,
        ][k % 5];
        canvas.drawRect(
          Rect.fromLTWH(x, baseY - spineH, spineW, spineH),
          Paint()..color = tone.withValues(alpha: 0.92),
        );
        x += spineW * 1.22;
        k++;
      }
    }

    // One small potted plant on the upper board, for the green the brief asks
    // for on the shelf side.
    _leafCluster(
      canvas,
      Offset(farX + (nearX - farX) * 0.72, topY + deskY * 0.03),
      w * 0.035,
      lean: -0.4,
    );
  }

  // ── light ───────────────────────────────────────────────────────────────

  /// The window's light on the floor — as a soft pool, not a polygon.
  ///
  /// The first revision cast it as a perspective quad, which was geometrically
  /// right and looked wrong: its straight edges read as a bright shape laid over
  /// the scene, and once the shaft was drawn with straight edges too the floor
  /// had a visible lattice on it. Light with a hard outline is not light. This is
  /// a radial falloff with no edge to see, elongated along the direction the
  /// window faces so it still has a direction.
  void _paintLightPool(
      Canvas canvas, double w, double h, double deskY, Offset vanish) {
    final centre = Offset(w * 0.66, deskY + (h - deskY) * 0.52);
    final radius = w * 0.74;

    canvas.save();
    // Stretch along the light's direction: a rotated ellipse, which is what a
    // pool of light through a tall window actually looks like on a floor.
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(0.30);
    canvas.translate(-centre.dx, -centre.dy);

    canvas.drawRect(
      Rect.fromLTWH(-w, -h, w * 3, h * 3),
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          radius,
          [
            _Hd.lightPool.withValues(alpha: 0.30),
            _Hd.lightPool.withValues(alpha: 0.12),
            _Hd.lightPool.withValues(alpha: 0.0),
          ],
          [0.0, 0.55, 1.0],
        ),
    );
    // Gloss: a narrower, hotter core, so the boards read as polished inside the
    // light rather than as pale paint.
    canvas.drawRect(
      Rect.fromLTWH(-w, -h, w * 3, h * 3),
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          radius * 0.52,
          [
            _Hd.floorGloss.withValues(alpha: 0.16),
            _Hd.floorGloss.withValues(alpha: 0.0),
          ],
        ),
    );
    canvas.restore();
  }

  /// The air in front of the window, as one very soft column.
  ///
  /// No straight edges: the shipped room's shafts are soft wedges and they read
  /// well, but the first revision of this painter drew a hard-edged shaft on top
  /// of a hard-edged pool and the two together tiled the frame with diagonals.
  void _paintShaft(Canvas canvas, double w, double h, double deskY) {
    canvas.save();
    final centre = Offset(w * 0.70, deskY * 0.72);
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(0.22);
    canvas.translate(-centre.dx, -centre.dy);
    canvas.drawRect(
      Rect.fromLTWH(-w, -h, w * 3, h * 3),
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          w * 0.62,
          [
            _Hd.lightCore.withValues(alpha: 0.18),
            _Hd.lightCore.withValues(alpha: 0.0),
          ],
        ),
    );
    canvas.restore();
  }

  void _paintMotes(Canvas canvas, double w, double h, double deskY) {
    // Deterministic placement: a fixed seed so the scene is identical on every
    // rebuild. Random motes would shimmer on each frame and read as noise.
    final rng = math.Random(20261014);
    final paint = Paint()..color = _Hd.lightCore.withValues(alpha: 0.34);
    for (var i = 0; i < 26; i++) {
      final x = w * (0.38 + rng.nextDouble() * 0.62);
      final y = deskY * (0.10 + rng.nextDouble() * 1.55);
      if (y > h) continue;
      canvas.drawCircle(
          Offset(x, y), w * (0.0025 + rng.nextDouble() * 0.0035), paint);
    }
  }

  void _paintGrade(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w * 0.9, h),
          [
            _Hd.brass.withValues(alpha: 0.10),
            _Hd.wallSide.withValues(alpha: 0.05),
          ],
        ),
    );
  }

  void _paintVignette(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.5, h * 0.46),
          w * 0.92,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            _Hd.woodDark.withValues(alpha: 0.22),
          ],
          [0.0, 0.62, 1.0],
        ),
    );
  }

  // ── near furniture ──────────────────────────────────────────────────────

  void _paintRug(Canvas canvas, double w, double h, double deskY) {
    final rect = Rect.fromLTWH(
        w * 0.20, deskY + (h - deskY) * 0.30, w * 0.60, (h - deskY) * 0.52);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.04));

    // Contact shadow first, so the rug sits on the boards.
    canvas.drawRRect(
      rr.shift(Offset(0, h * 0.008)),
      Paint()
        ..color = _Hd.woodDark.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(rr, Paint()..color = _Hd.rug);
    // Woven rings.
    for (var i = 1; i <= 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(rect.width * 0.07 * i),
          Radius.circular(w * 0.03),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.006
          ..color =
              (i.isEven ? _Hd.rugInner : _Hd.rugLine).withValues(alpha: 0.55),
      );
    }
    // Fringe along the two short edges.
    final fringe = Paint()
      ..color = _Hd.rugInner
      ..strokeWidth = w * 0.004;
    for (var x = rect.left + w * 0.012; x < rect.right; x += w * 0.022) {
      canvas.drawLine(
          Offset(x, rect.bottom), Offset(x, rect.bottom + h * 0.012), fringe);
    }
  }

  void _paintFloorPlant(Canvas canvas, double w, double h, double deskY) {
    final base = Offset(w * 0.13, deskY + (h - deskY) * 0.30);
    final potW = w * 0.15;
    final potH = h * 0.085;
    // Pot: tapered, with a rim and a shadow on the floor.
    canvas.drawOval(
      Rect.fromCenter(
          center: base.translate(0, potH * 0.92),
          width: potW * 1.5,
          height: potH * 0.30),
      Paint()..color = _Hd.woodDark.withValues(alpha: 0.20),
    );
    final pot = Path()
      ..moveTo(base.dx - potW * 0.5, base.dy - potH)
      ..lineTo(base.dx + potW * 0.5, base.dy - potH)
      ..lineTo(base.dx + potW * 0.38, base.dy)
      ..lineTo(base.dx - potW * 0.38, base.dy)
      ..close();
    canvas.drawPath(pot, Paint()..color = _Hd.pot);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx + potW * 0.10, base.dy - potH)
        ..lineTo(base.dx + potW * 0.5, base.dy - potH)
        ..lineTo(base.dx + potW * 0.38, base.dy)
        ..lineTo(base.dx + potW * 0.06, base.dy)
        ..close(),
      Paint()..color = _Hd.potShade.withValues(alpha: 0.55),
    );
    canvas.drawRect(
      Rect.fromLTWH(base.dx - potW * 0.56, base.dy - potH * 1.10, potW * 1.12,
          potH * 0.16),
      Paint()..color = _Hd.pot,
    );

    _leafCluster(canvas, base.translate(0, -potH * 1.12), w * 0.16, lean: 0.15);
  }

  /// A layered leaf cluster: back leaves darker, front leaves lighter, each with
  /// a highlight stroke. Shared by the floor plant and the shelf pot so the two
  /// read as the same illustrator.
  void _leafCluster(Canvas canvas, Offset base, double size,
      {required double lean}) {
    final rng = math.Random(7 + (base.dx * 10).round());
    for (var layer = 0; layer < 3; layer++) {
      final tone = [_Hd.leafDark, _Hd.leaf, _Hd.leafLight][layer];
      final count = 5 + layer;
      for (var i = 0; i < count; i++) {
        final a = -math.pi / 2 + lean + (i - count / 2) * 0.30;
        final len =
            size * (0.62 + rng.nextDouble() * 0.38) * (1 - layer * 0.10);
        final tip = base +
            Offset(math.cos(a), math.sin(a)) * len +
            Offset(0, size * 0.10 * layer);
        final path = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            (base.dx + tip.dx) / 2 - math.sin(a) * len * 0.34,
            (base.dy + tip.dy) / 2 + math.cos(a) * len * 0.34,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            (base.dx + tip.dx) / 2 + math.sin(a) * len * 0.34,
            (base.dy + tip.dy) / 2 - math.cos(a) * len * 0.34,
            base.dx,
            base.dy,
          )
          ..close();
        canvas.drawPath(
          path,
          Paint()..color = tone.withValues(alpha: 0.80 + layer * 0.06),
        );
        canvas.drawLine(
          base,
          tip,
          Paint()
            ..color = _Hd.leafLight.withValues(alpha: 0.30)
            ..strokeWidth = size * 0.012,
        );
      }
    }
  }

  void _paintDesk(Canvas canvas, double w, double h, double deskY) {
    final topY = deskY;
    // Thin. The first revision drew a 3%-of-height slab with a heavy apron and
    // two wide legs, and because the pet's feet land on this line the desk read
    // as a table the pet was standing on rather than as a surface below it. The
    // shipped room's desk is a line for exactly this reason; the material detail
    // belongs in the objects on it, not in the slab.
    final topH = h * 0.014;

    // Contact shadow under the desk, so it sits on the floor.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, topY + topH + h * 0.010, w * 0.70, h * 0.012),
      Paint()
        ..color = _Hd.woodDark.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Slim legs, and only the hint of an apron: enough to read as furniture
    // without cutting the frame.
    for (final lx in [w * 0.34, w * 0.90]) {
      canvas.drawRect(
        Rect.fromLTWH(lx, topY + topH, w * 0.014, h * 0.085),
        Paint()..color = _Hd.woodDark.withValues(alpha: 0.85),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(w * 0.33, topY + topH, w * 0.59, h * 0.008),
      Paint()..color = _Hd.woodEdge.withValues(alpha: 0.75),
    );

    // Top: front edge (darker, it is in shade) and surface (lit).
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, topY, w * 0.70, topH),
      Paint()..color = _Hd.woodEdge,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, topY, w * 0.70, topH * 0.42),
      Paint()..color = _Hd.woodTop,
    );
    // Grain, a few long strokes rather than a texture.
    final grain = Paint()
      ..color = _Hd.grain.withValues(alpha: 0.30)
      ..strokeWidth = 1.0;
    for (var i = 0; i < 5; i++) {
      final y = topY + topH * (0.16 + i * 0.15);
      canvas.drawLine(
          Offset(w * 0.30, y), Offset(w * 0.96, y - h * 0.002), grain);
    }

    _deskBooks(canvas, w, h, topY);
    _deskLamp(canvas, w, h, topY);
    _deskMug(canvas, w, h, topY);
    _deskNotebook(canvas, w, h, topY);
  }

  void _deskBooks(Canvas canvas, double w, double h, double topY) {
    final x = w * 0.33;
    final baseY = topY + h * 0.002;
    final widths = [w * 0.13, w * 0.115, w * 0.125];
    final heights = [h * 0.011, h * 0.013, h * 0.010];
    final tones = [_Hd.leafDark, _Hd.pot, _Hd.ceramicShade];
    var y = baseY;
    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(
          x + i * w * 0.006, y - heights[i], widths[i], heights[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w * 0.004)),
        Paint()..color = tones[i],
      );
      // Page block on the fore edge.
      canvas.drawRect(
        Rect.fromLTWH(rect.right - w * 0.010, rect.top + h * 0.002, w * 0.008,
            rect.height - h * 0.004),
        Paint()..color = _Hd.paper.withValues(alpha: 0.9),
      );
      y -= heights[i];
    }
  }

  void _deskLamp(Canvas canvas, double w, double h, double topY) {
    final baseX = w * 0.88;
    final baseY = topY;
    // Warm halo on the wall behind the lamp. Small and very soft: the first
    // revision used a hard circle at radius 0.075w and it read as a disc pasted
    // on the wall rather than as a lamp's spill.
    canvas.drawCircle(
      Offset(baseX - w * 0.010, baseY - h * 0.042),
      w * 0.040,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(baseX - w * 0.010, baseY - h * 0.042),
          w * 0.040,
          [
            _Hd.lightCore.withValues(alpha: 0.34),
            _Hd.lightCore.withValues(alpha: 0.0),
          ],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(baseX - w * 0.020, baseY - h * 0.050, w * 0.040, h * 0.050),
      Paint()..color = _Hd.woodDark,
    );
    final shade = Path()
      ..moveTo(baseX - w * 0.052, baseY - h * 0.050)
      ..lineTo(baseX + w * 0.052, baseY - h * 0.050)
      ..lineTo(baseX + w * 0.036, baseY - h * 0.086)
      ..lineTo(baseX - w * 0.036, baseY - h * 0.086)
      ..close();
    canvas.drawPath(shade, Paint()..color = _Hd.brass);
    canvas.drawPath(
      shade,
      Paint()
        ..color = _Hd.lightCore.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.005,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(baseX, baseY - h * 0.004),
          width: w * 0.070,
          height: h * 0.008),
      Paint()..color = _Hd.woodDark,
    );
  }

  void _deskMug(Canvas canvas, double w, double h, double topY) {
    final cx = w * 0.60;
    final bodyTop = topY - h * 0.026;
    final rect = Rect.fromLTWH(cx - w * 0.030, bodyTop, w * 0.060, h * 0.026);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * 0.008)),
      Paint()..color = _Hd.ceramic,
    );
    // Shaded right side and a handle.
    canvas.drawRect(
      Rect.fromLTWH(cx + w * 0.010, bodyTop, w * 0.020, h * 0.026),
      Paint()..color = _Hd.ceramicShade.withValues(alpha: 0.6),
    );
    canvas.drawArc(
      Rect.fromLTWH(cx + w * 0.028, bodyTop + h * 0.005, w * 0.030, h * 0.016),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.007
        ..color = _Hd.ceramic,
    );
    // Two steam curls, thin and low-alpha.
    final steam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.004
      ..color = _Hd.ceramic.withValues(alpha: 0.45);
    for (var i = 0; i < 2; i++) {
      final sx = cx - w * 0.012 + i * w * 0.024;
      canvas.drawPath(
        Path()
          ..moveTo(sx, bodyTop - h * 0.004)
          ..quadraticBezierTo(
              sx + w * 0.014, bodyTop - h * 0.018, sx, bodyTop - h * 0.032),
        steam,
      );
    }
  }

  void _deskNotebook(Canvas canvas, double w, double h, double topY) {
    final rect = Rect.fromLTWH(w * 0.44, topY - h * 0.006, w * 0.13, h * 0.006);
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(-0.06);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.drawRect(rect, Paint()..color = _Hd.paper);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width * 0.10, rect.height),
      Paint()..color = _Hd.ink.withValues(alpha: 0.55),
    );
    canvas.restore();
    // A pen resting on it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.47, topY - h * 0.011, w * 0.10, h * 0.004),
        Radius.circular(w * 0.002),
      ),
      Paint()..color = _Hd.ink.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant _HdRoomPainter old) =>
      old.deskLine != deskLine || old.dim != dim;
}
