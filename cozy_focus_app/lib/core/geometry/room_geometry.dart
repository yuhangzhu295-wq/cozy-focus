/// Pure geometry utilities for the Room canvas coordinate system.
///
/// Furniture positions are stored as normalised [0.0, 1.0] values relative
/// to the **room canvas** (not the full screen).  This file provides the
/// clamping logic so that items cannot be dragged beyond the visible area.
library;

/// Clamp [rawX] / [rawY] (normalised, 0.0–1.0) so that the rendered item
/// stays fully inside the canvas.
///
/// [canvasWidth] / [canvasHeight] — actual canvas pixel dimensions.
/// [itemWidth]  / [itemHeight]   — rendered item pixel dimensions (after scale).
({double x, double y}) clampNormalizedPosition({
  required double rawX,
  required double rawY,
  required double canvasWidth,
  required double canvasHeight,
  required double itemWidth,
  required double itemHeight,
}) {
  if (canvasWidth <= 0 || canvasHeight <= 0) return (x: rawX, y: rawY);

  final halfW = (itemWidth / 2).clamp(0, canvasWidth / 2) / canvasWidth;
  final halfH = (itemHeight / 2).clamp(0, canvasHeight / 2) / canvasHeight;

  final clampedX = rawX.clamp(halfW, 1.0 - halfW);
  final clampedY = rawY.clamp(halfH, 1.0 - halfH);

  return (x: clampedX, y: clampedY);
}
