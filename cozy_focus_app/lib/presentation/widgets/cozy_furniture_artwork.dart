import 'package:flutter/material.dart';

/// A small, presentation-only furniture illustration keyed by persisted item
/// ids. It deliberately has no ownership or placement behavior.
class CozyFurnitureArtwork extends StatelessWidget {
  final String itemId;
  final double size;

  const CozyFurnitureArtwork({
    super.key,
    required this.itemId,
    this.size = 72,
  });

  static const supportedItemIds = <String>{
    'sofa',
    'table',
    'bookshelf',
    'bed',
    'rug',
    'lamp',
    'cabinet',
    'desk',
    'plant_succulent',
    'special_trophy',
  };

  @override
  Widget build(BuildContext context) {
    final normalizedId = itemId.toLowerCase();
    return Semantics(
      image: true,
      label: _labelFor(normalizedId),
      child: ExcludeSemantics(
        child: SizedBox(
          key: Key('cozy-furniture-$normalizedId'),
          width: size,
          height: size,
          child: CustomPaint(
            painter: _FurnitureArtworkPainter(normalizedId),
          ),
        ),
      ),
    );
  }

  static String _labelFor(String itemId) {
    switch (itemId) {
      case 'sofa':
        return '小沙发插画';
      case 'table':
        return '圆桌插画';
      case 'bookshelf':
        return '书架插画';
      case 'bed':
        return '小床插画';
      case 'rug':
        return '格子地毯插画';
      case 'lamp':
        return '台灯插画';
      case 'cabinet':
        return '储物柜插画';
      case 'desk':
        return '书桌插画';
      case 'plant_succulent':
        return '多肉盆栽插画';
      case 'special_trophy':
        return '专注纪念徽章插画';
      case 'room':
        return '温馨房间插画';
      case 'workshop':
        return '制作工坊插画';
      default:
        return '家具插画';
    }
  }
}

class _FurnitureArtworkPainter extends CustomPainter {
  final String itemId;

  const _FurnitureArtworkPainter(this.itemId);

  static const _wood = Color(0xFFC9915D);
  static const _woodDark = Color(0xFF96613E);
  static const _woodLight = Color(0xFFE8C697);
  static const _sage = Color(0xFF5F9970);
  static const _sageLight = Color(0xFFDDECD9);
  static const _cream = Color(0xFFFFF9ED);
  static const _outline = Color(0xFF6F5846);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale);
    switch (itemId) {
      case 'sofa':
        _sofa(canvas);
      case 'table':
        _table(canvas);
      case 'bookshelf':
        _bookshelf(canvas);
      case 'bed':
        _bed(canvas);
      case 'rug':
        _rug(canvas);
      case 'lamp':
        _lamp(canvas);
      case 'cabinet':
        _cabinet(canvas);
      case 'desk':
        _desk(canvas);
      case 'plant_succulent':
        _succulent(canvas);
      case 'special_trophy':
        _trophy(canvas);
      case 'room':
        _room(canvas);
      case 'workshop':
        _workshop(canvas);
      default:
        _crate(canvas);
    }
    canvas.restore();
  }

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  Paint get _stroke => Paint()
    ..color = _outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _roundRect(Canvas canvas, Rect rect, double radius, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      _fill(color),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      _stroke,
    );
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color, double width) {
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round);
  }

  void _sofa(Canvas canvas) {
    _line(canvas, const Offset(22, 76), const Offset(18, 88), _woodDark, 5);
    _line(canvas, const Offset(78, 76), const Offset(82, 88), _woodDark, 5);
    _roundRect(canvas, const Rect.fromLTWH(16, 44, 68, 34), 12, _sage);
    _roundRect(canvas, const Rect.fromLTWH(20, 29, 60, 29), 13, _sageLight);
    _roundRect(canvas, const Rect.fromLTWH(25, 48, 24, 21), 7, _cream);
    _roundRect(canvas, const Rect.fromLTWH(51, 48, 24, 21), 7, _cream);
  }

  void _table(Canvas canvas) {
    canvas.drawOval(const Rect.fromLTWH(15, 28, 70, 32), _fill(_woodLight));
    canvas.drawOval(const Rect.fromLTWH(15, 28, 70, 32), _stroke);
    _line(canvas, const Offset(30, 54), const Offset(24, 87), _woodDark, 7);
    _line(canvas, const Offset(70, 54), const Offset(76, 87), _woodDark, 7);
    _line(canvas, const Offset(50, 55), const Offset(50, 87), _woodDark, 7);
  }

  void _bookshelf(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(22, 12, 56, 76), 5, _wood);
    for (final y in [35.0, 58.0]) {
      _line(canvas, Offset(26, y), Offset(74, y), _woodDark, 4);
    }
    final books = <Rect>[
      const Rect.fromLTWH(30, 18, 8, 14),
      const Rect.fromLTWH(41, 16, 9, 16),
      const Rect.fromLTWH(54, 19, 12, 13),
      const Rect.fromLTWH(29, 40, 12, 15),
      const Rect.fromLTWH(45, 39, 8, 16),
      const Rect.fromLTWH(57, 41, 12, 14),
    ];
    final colors = [_sageLight, _cream, _woodLight, _cream, _sage, _woodLight];
    for (var i = 0; i < books.length; i++) {
      canvas.drawRect(books[i], _fill(colors[i]));
    }
    _roundRect(canvas, const Rect.fromLTWH(30, 64, 40, 16), 3, _woodLight);
  }

  void _bed(Canvas canvas) {
    _line(canvas, const Offset(21, 45), const Offset(18, 87), _woodDark, 6);
    _line(canvas, const Offset(79, 45), const Offset(82, 87), _woodDark, 6);
    _roundRect(canvas, const Rect.fromLTWH(16, 48, 68, 30), 7, _wood);
    _roundRect(canvas, const Rect.fromLTWH(21, 42, 58, 26), 8, _cream);
    _roundRect(canvas, const Rect.fromLTWH(25, 45, 23, 12), 5, _sageLight);
    _roundRect(canvas, const Rect.fromLTWH(16, 25, 10, 43), 4, _woodDark);
  }

  void _rug(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(11, 32, 78, 38), 20, _sageLight);
    final clip = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 32, 78, 38),
        const Radius.circular(20),
      ));
    canvas.save();
    canvas.clipPath(clip);
    for (var x = 15.0; x < 90; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, 32, 8, 38), _fill(_sage));
    }
    for (var y = 35.0; y < 70; y += 15) {
      _line(canvas, Offset(11, y), Offset(89, y), _woodLight, 4);
    }
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 32, 78, 38),
        const Radius.circular(20),
      ),
      _stroke,
    );
  }

  void _lamp(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(29, 72, 42, 12), 6, _wood);
    _line(canvas, const Offset(50, 70), const Offset(50, 42), _woodDark, 6);
    final shade = Path()
      ..moveTo(27, 42)
      ..lineTo(39, 18)
      ..lineTo(61, 18)
      ..lineTo(73, 42)
      ..close();
    canvas.drawPath(shade, _fill(_woodLight));
    canvas.drawPath(shade, _stroke);
    canvas.drawCircle(const Offset(50, 42), 7, _fill(_cream));
  }

  void _cabinet(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(20, 15, 60, 72), 5, _wood);
    _roundRect(canvas, const Rect.fromLTWH(26, 21, 48, 43), 3, _woodLight);
    _line(canvas, const Offset(50, 21), const Offset(50, 64), _woodDark, 3);
    canvas.drawCircle(const Offset(44, 43), 2.5, _fill(_woodDark));
    canvas.drawCircle(const Offset(56, 43), 2.5, _fill(_woodDark));
    _roundRect(canvas, const Rect.fromLTWH(26, 69, 48, 12), 3, _woodLight);
  }

  void _desk(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(14, 38, 72, 15), 5, _woodLight);
    _line(canvas, const Offset(25, 52), const Offset(20, 87), _woodDark, 6);
    _line(canvas, const Offset(75, 52), const Offset(80, 87), _woodDark, 6);
    _roundRect(canvas, const Rect.fromLTWH(54, 25, 20, 13), 3, _sage);
    _line(canvas, const Offset(64, 38), const Offset(64, 48), _woodDark, 3);
  }

  void _succulent(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(28, 64, 44, 20), 7, _woodLight);
    _line(canvas, const Offset(31, 66), const Offset(69, 66), _woodDark, 3);
    for (final leaf in [
      const Rect.fromLTWH(38, 35, 17, 35),
      const Rect.fromLTWH(26, 42, 28, 17),
      const Rect.fromLTWH(47, 42, 28, 17),
      const Rect.fromLTWH(38, 23, 17, 34),
    ]) {
      canvas.drawOval(leaf, _fill(_sage));
      canvas.drawOval(leaf, _stroke);
    }
  }

  void _trophy(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(32, 24, 36, 32), 8, _woodLight);
    _line(canvas, const Offset(32, 31), const Offset(18, 31), _woodDark, 4);
    _line(canvas, const Offset(68, 31), const Offset(82, 31), _woodDark, 4);
    _line(canvas, const Offset(50, 56), const Offset(50, 73), _woodDark, 5);
    _roundRect(canvas, const Rect.fromLTWH(31, 73, 38, 11), 5, _wood);
    final star = Path()
      ..moveTo(50, 30)
      ..lineTo(54, 39)
      ..lineTo(64, 40)
      ..lineTo(56, 46)
      ..lineTo(59, 55)
      ..lineTo(50, 50)
      ..lineTo(41, 55)
      ..lineTo(44, 46)
      ..lineTo(36, 40)
      ..lineTo(46, 39)
      ..close();
    canvas.drawPath(star, _fill(_sage));
  }

  void _room(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(12, 15, 42, 38), 5,
        const Color(0xFFBFE0D6));
    _line(canvas, const Offset(33, 16), const Offset(33, 52), Colors.white, 3);
    _line(canvas, const Offset(13, 34), const Offset(53, 34), Colors.white, 3);
    _rug(canvas);
    _plant(canvas, const Offset(74, 53), 0.65);
  }

  void _workshop(Canvas canvas) {
    _crate(canvas);
    _line(canvas, const Offset(25, 23), const Offset(75, 23), _woodDark, 5);
    _line(canvas, const Offset(36, 12), const Offset(36, 33), _woodDark, 4);
    _line(canvas, const Offset(64, 12), const Offset(64, 33), _woodDark, 4);
    _line(canvas, const Offset(50, 22), const Offset(50, 11), _sage, 4);
  }

  void _crate(Canvas canvas) {
    _roundRect(canvas, const Rect.fromLTWH(20, 29, 60, 52), 7, _woodLight);
    _line(canvas, const Offset(25, 40), const Offset(75, 70), _woodDark, 4);
    _line(canvas, const Offset(75, 40), const Offset(25, 70), _woodDark, 4);
    _plant(canvas, const Offset(50, 39), 0.45);
  }

  void _plant(Canvas canvas, Offset origin, double scale) {
    _line(canvas, origin, Offset(origin.dx, origin.dy - 20 * scale), _sage, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(origin.dx - 7 * scale, origin.dy - 14 * scale),
        width: 13 * scale,
        height: 8 * scale,
      ),
      _fill(_sageLight),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(origin.dx + 7 * scale, origin.dy - 20 * scale),
        width: 13 * scale,
        height: 8 * scale,
      ),
      _fill(_sage),
    );
  }

  @override
  bool shouldRepaint(covariant _FurnitureArtworkPainter oldDelegate) =>
      oldDelegate.itemId != itemId;
}
