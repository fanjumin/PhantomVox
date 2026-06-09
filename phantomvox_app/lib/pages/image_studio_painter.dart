import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Renders tool overlays on the image canvas.
class EditorOverlayPainter extends CustomPainter {
  final List<Offset>? drawPoints;
  final String currentTool;
  final Color primaryColor;
  final int brushSize;
  final Rect? cropRect;
  final List<Offset>? shapePreview;
  final String shapeType;
  final Size imageSize;
  final double zoomScale;

  final String? selectionType;
  final Rect? selectionRect;
  final List<Offset>? selectionPoints;

  final Offset? gradientStart;
  final Offset? gradientEnd;
  final bool isDraggingGradient;

  EditorOverlayPainter({
    this.drawPoints, this.currentTool = 'select',
    this.primaryColor = Colors.white, this.brushSize = 5,
    this.cropRect, this.shapePreview, this.shapeType = 'rect',
    required this.imageSize, this.zoomScale = 1.0,
    this.selectionType, this.selectionRect, this.selectionPoints,
    this.gradientStart, this.gradientEnd, this.isDraggingGradient = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBrushPreview(canvas); _drawCropOverlay(canvas);
    _drawShapePreview(canvas); _drawSelection(canvas);
    _drawGradientPreview(canvas);
  }

  void _drawBrushPreview(Canvas canvas) {
    if (drawPoints == null || drawPoints!.length < 2 ||
        (currentTool != 'brush' && currentTool != 'eraser')) return;
    final p = Paint()
      ..color = currentTool == 'eraser' ? Colors.red.withOpacity(0.3) : primaryColor
      ..strokeWidth = brushSize.toDouble()
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPoints(ui.PointMode.polygon, drawPoints!, p);
  }

  void _drawCropOverlay(Canvas canvas) {
    if (cropRect == null) return; final r = cropRect!;
    if (r.width <= 0 || r.height <= 0) return;
    final dim = Paint()..color = const Color(0x80000000);
    final outer = Path()..addRect(Offset.zero & imageSize);
    outer.addRect(r); outer.fillType = PathFillType.evenOdd;
    canvas.drawPath(outer, dim);
    final sw = math.max(1.5, 1.0 / zoomScale);
    canvas.drawRect(r, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = sw);
    final hr = 8.0 / zoomScale;
    for (final off in _handles(r)) {
      canvas.drawCircle(off, hr, Paint()..color = Colors.white);
      canvas.drawCircle(off, hr, Paint()..color = const Color(0xFF6C63FF)..style = PaintingStyle.stroke..strokeWidth = 0.5);
    }
  }

  List<Offset> _handles(Rect r) => [r.topLeft, Offset(r.center.dx, r.top), r.topRight,
    Offset(r.left, r.center.dy), Offset(r.right, r.center.dy),
    r.bottomLeft, Offset(r.center.dx, r.bottom), r.bottomRight];

  void _drawShapePreview(Canvas canvas) {
    if (shapePreview == null || shapePreview!.length != 2 || currentTool != 'shape') return;
    final s = shapePreview![0], e = shapePreview![1], rect = Rect.fromPoints(s, e);
    final p = Paint()..color = primaryColor.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    if (shapeType == 'ellipse' || shapeType == 'circle') { canvas.drawOval(rect, p); return; }
    if (shapeType == 'line' || shapeType == 'arrow') { canvas.drawLine(s, e, p); return; }
    if (shapeType == 'polygon') {
      final path = Path()..moveTo(rect.center.dx, rect.top)..lineTo(rect.right, rect.center.dy)
        ..lineTo(rect.center.dx, rect.bottom)..lineTo(rect.left, rect.center.dy)..close();
      canvas.drawPath(path, p); return;
    }
    canvas.drawRect(rect, p);
  }

  void _drawSelection(Canvas canvas) {
    if (selectionType == null) return;
    final sw = math.max(1.5, 1.0 / zoomScale);
    Path? sel;
    if (selectionType == 'rect' && selectionRect != null && selectionRect!.width > 2) {
      _dimOut(canvas, Path()..addRect(selectionRect!)); sel = Path()..addRect(selectionRect!);
    } else if (selectionType == 'ellipse' && selectionRect != null && selectionRect!.width > 2) {
      _dimOut(canvas, Path()..addOval(selectionRect!)); sel = Path()..addOval(selectionRect!);
    } else if (selectionType == 'lasso' && selectionPoints != null && selectionPoints!.length >= 3) {
      final path = Path()..addPolygon(selectionPoints!, true); _dimOut(canvas, path); sel = path;
    } else if (selectionType == 'poly' && selectionPoints != null && selectionPoints!.length >= 2) {
      sel = Path()..addPolygon(selectionPoints!, false);
    }
    if (sel == null) return;
    canvas.drawPath(sel, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = sw);
    canvas.drawPath(sel, Paint()..color = const Color(0xFF6C63FF)..style = PaintingStyle.stroke..strokeWidth = sw / 2);
  }

  void _dimOut(Canvas canvas, Path inner) {
    final outer = Path()..addRect(Offset.zero & imageSize);
    outer.addPath(inner, Offset.zero); outer.fillType = PathFillType.evenOdd;
    canvas.drawPath(outer, Paint()..color = const Color(0x40000000));
  }

  void _drawGradientPreview(Canvas canvas) {
    if (currentTool != 'gradient' || !isDraggingGradient || gradientStart == null) return;
    final end = gradientEnd ?? gradientStart!;
    final dashed = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(gradientStart!, end, dashed);
    // Draw start dot (white) and end dot (with arrow)
    canvas.drawCircle(gradientStart!, 3, Paint()..color = Colors.white);
    canvas.drawCircle(end, 3, Paint()..color = const Color(0xFF6C63FF));
    // Small arrow at end
    final dir = (end - gradientStart!);
    if (dir.distance > 10) {
      final angle = math.atan2(dir.dy, dir.dx);
      final arrowLen = 6.0;
      final arrow = Paint()..color = Colors.white..strokeWidth = 1.0;
      canvas.drawLine(end, Offset(
        end.dx - arrowLen * math.cos(angle - 0.5),
        end.dy - arrowLen * math.sin(angle - 0.5),
      ), arrow);
      canvas.drawLine(end, Offset(
        end.dx - arrowLen * math.cos(angle + 0.5),
        end.dy - arrowLen * math.sin(angle + 0.5),
      ), arrow);
    }
  }

  @override
  bool shouldRepaint(covariant EditorOverlayPainter old) =>
      drawPoints != old.drawPoints || currentTool != old.currentTool ||
      primaryColor != old.primaryColor || brushSize != old.brushSize ||
      cropRect != old.cropRect || shapePreview != old.shapePreview ||
      imageSize != old.imageSize || zoomScale != old.zoomScale ||
      selectionType != old.selectionType || selectionRect != old.selectionRect ||
      selectionPoints != old.selectionPoints || shapeType != old.shapeType ||
      gradientStart != old.gradientStart || gradientEnd != old.gradientEnd ||
      isDraggingGradient != old.isDraggingGradient;
}

// ── Checkerboard background ─────────────────────────────────────────
class CheckerboardPainter extends CustomPainter {
  final Size size;
  CheckerboardPainter({required this.size});
  @override
  void paint(Canvas canvas, Size s) {
    const tile = 8.0; final p = Paint();
    for (double y = 0; y < size.height; y += tile)
      for (double x = 0; x < size.width; x += tile) {
        p.color = ((x / tile).floor() + (y / tile).floor()) % 2 == 0 ? const Color(0xFFCCCCCC) : const Color(0xFFAAAAAA);
        canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), p);
      }
  }
  @override bool shouldRepaint(covariant CheckerboardPainter old) => size != old.size;
}

// ── Ruler (document coordinate ruler, uses _tc matrix) ──────────────
class RulerPainter extends CustomPainter {
  final bool horizontal;
  final Matrix4 matrix; // _tc.value for scale/offset
  final double rulerLen; // rendered size

  RulerPainter({required this.horizontal, required this.matrix, required this.rulerLen});

  @override
  void paint(Canvas canvas, Size size) {
    if (rulerLen <= 0) return;
    final tickLen = horizontal ? size.height : size.width;
    if (tickLen <= 0) return;

    // Use entry(0,0) for uniform 2D scale (getMaxScaleOnAxis is wrong for zoom < 1)
    final scale = matrix.entry(0, 0);
    final offset = horizontal ? matrix.getTranslation().x : matrix.getTranslation().y;
    if (scale <= 0) return;

    // Tick step: maintain ~50 screen px between ticks
    final step = _niceStep(50.0 / scale);
    if (step <= 0) return;

    final tick = Paint()..color = const Color(0xFF666666)..strokeWidth = 1.0;
    final minor = Paint()..color = const Color(0xFF444444)..strokeWidth = 0.5;
    final textS = ui.TextStyle(color: const Color(0xFF999999), fontSize: 8);

    // Iterate over document pixel values, convert to screen position
    // Screen position = docPx * scale + offset
    // Start from first docPx that's visible (or negative if scrolled)
    final firstDoc = (-offset / scale / step).floor() * step;

    for (double docPx = firstDoc; ; docPx += step) {
      final sp = docPx * scale + offset;
      if (sp > rulerLen + 5) break;
      if (sp < -5) continue;

      // Major tick
      if (horizontal) canvas.drawLine(Offset(sp, 0), Offset(sp, tickLen), tick);
      else canvas.drawLine(Offset(0, sp), Offset(tickLen, sp), tick);

      // Label (show all, including negative for alignment)
      final label = docPx.toInt().toString();
      if (horizontal) {
        final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 8))
          ..pushStyle(textS)..addText(label);
        final para = pb.build()..layout(const ui.ParagraphConstraints(width: 50));
        canvas.drawParagraph(para, Offset(sp - 25, 1));
      } else {
        final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.right, fontSize: 8))
          ..pushStyle(textS)..addText(label);
        final para = pb.build()..layout(ui.ParagraphConstraints(width: tickLen - 4));
        canvas.drawParagraph(para, Offset(2, sp - 5));
      }

      // Minor ticks (10 per step)
      for (int i = 1; i < 10; i++) {
        final mDoc = docPx + i * step / 10;
        final msp = mDoc * scale + offset;
        if (msp < -2 || msp > rulerLen + 2) continue;
        if (horizontal) canvas.drawLine(Offset(msp, 0), Offset(msp, tickLen * 0.5), minor);
        else canvas.drawLine(Offset(0, msp), Offset(tickLen * 0.5, msp), minor);
      }
    }
  }

  double _niceStep(double target) {
    if (target <= 1) return 1;
    if (target <= 2) return 2;
    if (target <= 5) return 5;
    if (target <= 10) return 10;
    if (target <= 20) return 20;
    if (target <= 25) return 25;
    if (target <= 50) return 50;
    if (target <= 100) return 100;
    if (target <= 200) return 200;
    return 500;
  }

  @override
  bool shouldRepaint(covariant RulerPainter old) =>
      horizontal != old.horizontal || rulerLen != old.rulerLen ||
      matrix.entry(0, 0) != old.matrix.entry(0, 0) ||
      matrix.getTranslation().x != old.matrix.getTranslation().x ||
      matrix.getTranslation().y != old.matrix.getTranslation().y;
}
