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
  final Size imageSize;
  final double zoomScale;

  EditorOverlayPainter({
    this.drawPoints,
    this.currentTool = 'select',
    this.primaryColor = Colors.white,
    this.brushSize = 5,
    this.cropRect,
    this.shapePreview,
    required this.imageSize,
    this.zoomScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBrushPreview(canvas);
    _drawCropOverlay(canvas);
    _drawShapePreview(canvas);
  }

  // -----------------------------------------------------------------------
  // Brush / eraser preview
  // -----------------------------------------------------------------------
  void _drawBrushPreview(Canvas canvas) {
    if (drawPoints == null || drawPoints!.length < 2 ||
        (currentTool != 'brush' && currentTool != 'eraser')) {
      return;
    }
    final p = Paint()
      ..color = currentTool == 'eraser'
          ? Colors.red.withOpacity(0.3)
          : primaryColor
      ..strokeWidth = brushSize.toDouble()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(drawPoints![0].dx, drawPoints![0].dy);
    for (int i = 1; i < drawPoints!.length; i++) {
      path.lineTo(drawPoints![i].dx, drawPoints![i].dy);
    }
    canvas.drawPath(path, p);
    canvas.drawCircle(drawPoints![0], brushSize / 2,
        Paint()..color = primaryColor);
    canvas.drawCircle(drawPoints!.last, brushSize / 2,
        Paint()..color = primaryColor);
  }

  // -----------------------------------------------------------------------
  // Crop overlay
  // -----------------------------------------------------------------------
  void _drawCropOverlay(Canvas canvas) {
    if (currentTool != 'crop' || cropRect == null) return;
    final r = cropRect!;
    final bg = Paint()..color = Colors.black.withOpacity(0.4);
    final iw = imageSize.width;
    final ih = imageSize.height;
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, iw, r.top))
        ..addRect(Rect.fromLTWH(0, r.bottom, iw, ih - r.bottom))
        ..addRect(Rect.fromLTWH(0, r.top, r.left, r.height))
        ..addRect(Rect.fromLTWH(r.right, r.top, iw - r.right, r.height)),
      bg,
    );
    canvas.drawRect(r, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    // Handles at consistent screen size
    final hr = zoomScale > 0.01 ? 4.0 / zoomScale : 4.0;
    final hp = Paint()..color = Colors.white;
    for (final off in _handleOffsets(r)) {
      canvas.drawCircle(off, hr, hp);
      canvas.drawCircle(off, hr, Paint()
        ..color = const Color(0xFF6C63FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / zoomScale);
    }
  }

  // -----------------------------------------------------------------------
  // Shape preview
  // -----------------------------------------------------------------------
  void _drawShapePreview(Canvas canvas) {
    if (shapePreview == null || shapePreview!.length != 2 ||
        currentTool != 'shape') return;
    final s = shapePreview![0];
    final e = shapePreview![1];
    canvas.drawRect(
      Rect.fromPoints(s, e),
      Paint()
        ..color = primaryColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------
  List<Offset> _handleOffsets(Rect r) {
    return [
      r.topLeft, Offset(r.center.dx, r.top), r.topRight,
      Offset(r.left, r.center.dy), Offset(r.right, r.center.dy),
      r.bottomLeft, Offset(r.center.dx, r.bottom), r.bottomRight,
    ];
  }

  @override
  bool shouldRepaint(covariant EditorOverlayPainter old) {
    return drawPoints != old.drawPoints ||
        currentTool != old.currentTool ||
        primaryColor != old.primaryColor ||
        brushSize != old.brushSize ||
        cropRect != old.cropRect ||
        shapePreview != old.shapePreview ||
        imageSize != old.imageSize ||
        zoomScale != old.zoomScale;
  }
}
