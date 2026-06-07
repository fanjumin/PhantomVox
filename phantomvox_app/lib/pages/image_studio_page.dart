import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'image_studio_api.dart';
import 'image_studio_painter.dart';
// ignore: undefined_prefixed_name — dart:html only available on Flutter Web
import 'dart:html' as html show window;

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------
class ImageStudioPage extends StatefulWidget {
  const ImageStudioPage({super.key});
  @override
  State<ImageStudioPage> createState() => _ImageStudioPageState();
}

class _ImageStudioPageState extends State<ImageStudioPage> {
  final _api = ImageStudioApi();

  // -- Image state --
  ui.Image? _previewImage;
  Map<String, dynamic>? _info;
  bool _canUndo = false, _canRedo = false;
  int _undoCount = 0, _redoCount = 0;
  List<Map<String, dynamic>> _layers = [];
  bool _loading = true;
  String? _error;
  String? _previewB64;

  // -- Tool state --
  String _currentTool = 'select';
  String _shapeType = 'rect';
  int _brushSize = 5, _fontSize = 24;
  int _textStrokeWidth = 0, _textShadowBlur = 0;
  Color _textStrokeColor = Colors.black;
  Color _textShadowColor = const Color(0x8A000000); // black 54%
  String _fontFamily = 'sans-serif';
  double _opacity = 1.0;
  Color _primaryColor = Colors.white;

  // -- Pointer state --
  List<Offset>? _drawPoints;
  Offset? _drawStart;
  List<Offset>? _shapePreview;

  // -- Crop state --
  bool _cropMode = false;
  Rect? _cropRect;
  Offset? _cropStart;
  String? _cropEdge; // which edge/handle is being dragged: tl,t,tr,l,r,bl,b,br
  Offset? _cropDragOffset; // offset from rect topLeft when dragging to move

  // -- Text inline editing --
  bool _textMode = false;
  Offset? _textPos; // image-pixel position of the text box
  double _textW = 200, _textH = 50; // current text box size
  final _textCtrl = TextEditingController();
  final _textFocus = FocusNode();

  // -- Operation feedback --
  bool _opLoading = false;
  String _opLabel = '';
  CanvasCancelToken? _cancelToken;

  // -- InteractiveViewer --
  final TransformationController _tc = TransformationController();
  double _vpW = 0, _vpH = 0; // viewport size (set by LayoutBuilder)
  bool _needsInitFit = false;
  bool _vpReady = false;

  // -- Misc --
  Size? _lastCanvasSize;
  bool _mountedFlag = false;

  @override
  void initState() {
    super.initState();
    _mountedFlag = true;
    // Don't auto-create a canvas — wait for user to open an image or create one.
    _loading = false;
    _setupScrollZoom();
  }

  void _setupScrollZoom() {
    // Flutter Web: native mouse wheel → canvas zoom.
    html.window.onWheel.listen((e) {
      if (!_mountedFlag) return;
      final dy = e.deltaY;
      if (dy != 0.0) {
        _zoomByFactor(dy < 0 ? 1.1 : 1 / 1.1);
      }
    });
    // Enter → apply crop, Escape → cancel crop
    html.window.onKeyDown.listen((e) {
      if (!_mountedFlag) return;
      if (_currentTool == 'crop' && _cropRect != null) {
        if (e.key == 'Enter') {
          _applyCrop();
        } else if (e.key == 'Escape') {
          _cancelCrop();
        }
      }
    });
  }

  /// Zoom the canvas by [factor] (1.1 = zoom in, 1/1.1 = zoom out).
  /// Centered on current viewport center.
  void _zoomByFactor(double factor) {
    final old = _tc.value.getMaxScaleOnAxis();
    final newScale = (old * factor).clamp(0.1, 10.0);
    final cx = _vpW / 2, cy = _vpH / 2;
    final inv = Matrix4.inverted(_tc.value);
    final pre = MatrixUtils.transformPoint(inv, Offset(cx, cy));
    _tc.value = Matrix4.identity()
      ..translate(cx, cy)
      ..scale(newScale, newScale)
      ..translate(-pre.dx, -pre.dy);
    _safeSetState(() {});
  }

  @override
  void dispose() {
    _mountedFlag = false;
    _cancelToken?.cancel();
    _tc.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_mountedFlag) setState(fn);
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!_mountedFlag) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        duration: Duration(seconds: isError ? 4 : 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 40, left: 100, right: 100),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Image operations
  // -----------------------------------------------------------------------
  Future<void> _initCanvas() async {
    try {
      final r = await _api.post('/api/v1/editor/new', {'width': 800, 'height': 600});
      await _updateState(r);
      _refreshLayers();
    } catch (e) {
      _safeSetState(() {
        _loading = false;
        _error = 'Cannot connect to server: $e';
      });
      _showSnack('$e', isError: true);
    }
  }

  Future<void> _updateState(Map<String, dynamic> r) async {
    final info = r['info'] as Map<String, dynamic>? ?? r;
    _safeSetState(() {
      _loading = false;
      _info = info;
      _previewB64 = r['base64'] as String? ?? info['base64'] as String?;
      final h = r['history'] as Map<String, dynamic>? ?? {};
      _canUndo = h['can_undo'] ?? false;
      _canRedo = h['can_redo'] ?? false;
      _undoCount = h['undo_count'] ?? 0;
      _redoCount = h['redo_count'] ?? 0;
      _error = null;
    });
    if (_previewB64 != null) await _loadImage(_previewB64!);
  }

  Future<void> _loadImage(String b64) async {
    if (b64.length > 50000000) {
      _safeSetState(() {
        _loading = false;
        _error = 'Image too large (${b64.length} chars, max 50MB)';
      });
      return;
    }
    final token = CanvasCancelToken();
    _cancelToken?.cancel();
    _cancelToken = token;

    try {
      final bytes = base64Decode(b64);
      final c = Completer<ui.Image>();
      ui.decodeImageFromList(Uint8List.fromList(bytes), (img) {
        if (!c.isCompleted) c.complete(img);
      });
      final img = await c.future.timeout(const Duration(seconds: 15));
      if (token.isCancelled) return;
      _safeSetState(() {
        _loading = false;
        _previewImage = img;
      });
      // Schedule fit-to-viewport
      if (_vpW > 0 && _vpH > 0) {
        _needsInitFit = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_mountedFlag && _needsInitFit) _fitToViewport();
        });
      }
    } on TimeoutException {
      if (token.isCancelled) return;
      _safeSetState(() {
        _loading = false;
        _error = 'Image decode timed out';
      });
    } catch (e) {
      if (token.isCancelled) return;
      _safeSetState(() {
        _loading = false;
        _error = 'Decode error: $e';
      });
    }
  }

  void _fitToViewport() {
    if (_previewImage == null || _vpW <= 0 || _vpH <= 0) return;
    final iw = _previewImage!.width.toDouble();
    final ih = _previewImage!.height.toDouble();
    if (iw <= 0 || ih <= 0) return;
    final scaleX = (_vpW - 40) / iw;
    final scaleY = (_vpH - 40) / ih;
    final s = math.min(scaleX, scaleY).clamp(0.01, 10.0);
    final dx = (_vpW - iw * s) / 2;
    final dy = (_vpH - ih * s) / 2;
    _tc.value = Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(dx, dy, 0);
    _needsInitFit = false;
  }

  /// Convert Listener localPosition (which is already in image-pixel space
  /// because Flutter's hit-testing factors out InteractiveViewer's transform)
  /// to image pixel coordinates. With InteractiveViewer, this is an identity transform.
  Offset _screenToImage(Offset screenPos) => screenPos;

  // -----------------------------------------------------------------------
  // Tool helpers
  // -----------------------------------------------------------------------
  Future<void> _wrap(Future<void> Function() fn, {String label = 'Processing...', String? successMsg}) async {
    _safeSetState(() {
      _error = null;
      _opLoading = true;
      _opLabel = label;
    });
    try {
      await fn();
      if (successMsg != null) _showSnack(successMsg);
    } on ApiException catch (e) {
      _safeSetState(() => _error = e.message);
      _showSnack(e.message, isError: true);
    } catch (e) {
      _safeSetState(() => _error = '$e');
      _showSnack('$e', isError: true);
    } finally {
      _safeSetState(() => _opLoading = false);
    }
  }

  Future<void> _filter(String name) => _wrap(() async {
    final r = await _api.post('/api/v1/editor/filter', {'name': name, 'preview_only': true});
    await _updateState(r);
  }, label: 'Applying $name...');

  Future<void> _transformVoid(String name, Map<String, dynamic> p) => _wrap(() async {
    final r = await _api.post('/api/v1/editor/$name', {...p, 'preview_only': true});
    await _updateState(r);
  }, label: '$name...');

  Future<void> _adjustVoid(String name, Map<String, dynamic> p) => _wrap(() async {
    final r = await _api.post('/api/v1/editor/adjust', {'type': name, ...p, 'preview_only': true});
    await _updateState(r);
  }, label: 'Adjusting...');

  Future<void> _undo() => _wrap(() async {
    final r = await _api.post('/api/v1/editor/undo', {});
    await _updateState(r);
    _refreshLayers();
  }, label: 'Undo...');

  Future<void> _redo() => _wrap(() async {
    final r = await _api.post('/api/v1/editor/redo', {});
    await _updateState(r);
    _refreshLayers();
  }, label: 'Redo...');

  void _createCanvas() => _wrap(() async {
    final r = await _api.post('/api/v1/editor/new', {'width': 800, 'height': 600});
    await _updateState(r);
    _refreshLayers();
  }, label: 'New canvas...', successMsg: 'New canvas created');

  Future<void> _openImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List? bytes;
      if (file.bytes != null) bytes = file.bytes;
      if (bytes == null) return;
      final b64 = base64Encode(bytes);
      await _wrap(() async {
        final r = await _api.post('/api/v1/editor/load', {'image': b64});
        await _updateState(r);
        _refreshLayers();
      }, label: 'Opening image...', successMsg: 'Image loaded');
    } catch (e) {
      _showSnack('Open failed: $e', isError: true);
    }
  }

  Future<void> _saveImage() async {
    if (_previewB64 == null) return;
    await _wrap(() async {
      final r = await _api.post('/api/v1/editor/save', {'fmt': 'png'});
      if (r['status'] == 'ok') {
        _showSnack('Saved: ${r['path']}');
      }
    }, label: 'Saving...');
  }

  Future<void> _refreshLayers() async {
    try {
      final r = await _api.get('/api/v1/layer/info');
      _safeSetState(() => _layers = List<Map<String, dynamic>>.from(r['layers'] ?? []));
    } catch (e) {
      debugPrint('_refreshLayers failed: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Pointer event handlers
  // -----------------------------------------------------------------------
  void _onPointerDown(PointerDownEvent event) {
    final imgPos = _screenToImage(event.localPosition);
    _safeSetState(() {
      _drawStart = imgPos;

      if (_currentTool == 'brush' || _currentTool == 'eraser') {
        _drawPoints = [imgPos];
      } else if (_currentTool == 'fill') {
        _apiFill(imgPos);
      } else if (_currentTool == 'eyedropper') {
        _apiEyedropper(imgPos);
      } else if (_currentTool == 'gradient') {
        _applyQuickGradient(imgPos);
      } else if (_currentTool == 'crop') {
        _onCropDown(imgPos);
      } else if (_currentTool == 'text') {
        _onTextDown(imgPos);
      } else if (_currentTool == 'shape') {
        _shapePreview = [imgPos];
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final imgPos = _screenToImage(event.localPosition);
    _safeSetState(() {
      if ((_currentTool == 'brush' || _currentTool == 'eraser') && _drawPoints != null) {
        _drawPoints!.add(imgPos);
      } else if (_currentTool == 'crop') {
        _onCropMove(imgPos);
      } else if (_currentTool == 'shape' && _drawStart != null) {
        _shapePreview = [_drawStart!, imgPos];
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    final imgPos = _screenToImage(event.localPosition);
    if ((_currentTool == 'brush' || _currentTool == 'eraser') && _drawPoints != null && _drawPoints!.length >= 2) {
      _apiDrawBrush(_drawPoints!);
    }
    if (_currentTool == 'shape' && _drawStart != null) {
      _apiDrawShape(_drawStart!, imgPos);
    }
    if (_currentTool == 'crop') {
      _onCropUp(imgPos);
    }
    _safeSetState(() {
      _drawPoints = null;
      _drawStart = null;
      _shapePreview = null;
    });
  }

  // -----------------------------------------------------------------------
  // Crop tool — interactive rect on canvas
  // -----------------------------------------------------------------------
  void _setTool(String t) {
    _safeSetState(() {
      _currentTool = t;
      if (t == 'crop' && _previewImage != null) {
        _cropMode = true;
        _cropRect = Offset.zero & Size(_previewImage!.width.toDouble(), _previewImage!.height.toDouble());
        _cropEdge = null;
        _cropDragOffset = null;
      } else {
        _cropMode = false;
        _cropRect = null;
        _cropStart = null;
        _cropEdge = null;
        _cropDragOffset = null;
      }
    });
  }

  void _onCropDown(Offset imgPos) {
    if (_cropRect != null) {
      // Hit test handles
      final scale = _tc.value.getMaxScaleOnAxis();
      final hr = scale > 0.0 ? 8.0 / scale : 8.0;
      for (final entry in _cropHandles(_cropRect!)) {
        if ((imgPos - (entry[1] as Offset)).distance <= hr) {
          _cropEdge = entry[0] as String;
          return;
        }
      }
      // Hit test interior → move
      if (_cropRect!.contains(imgPos)) {
        _cropDragOffset = Offset(imgPos.dx - _cropRect!.left, imgPos.dy - _cropRect!.top);
        return;
      }
    }
    // Start new rect
    _cropStart = imgPos;
    _cropRect = null;
    _cropEdge = null;
  }

  void _onCropMove(Offset imgPos) {
    final maxW = _previewImage?.width.toDouble() ?? 0;
    final maxH = _previewImage?.height.toDouble() ?? 0;

    if (_cropEdge != null && _cropRect != null) {
      // Resize — adjust the specific edge
      Rect r = _cropRect!;
      switch (_cropEdge) {
        case 'tl': r = Rect.fromLTRB(imgPos.dx, imgPos.dy, r.right, r.bottom); break;
        case 't':  r = Rect.fromLTRB(r.left, imgPos.dy, r.right, r.bottom); break;
        case 'tr': r = Rect.fromLTRB(r.left, imgPos.dy, imgPos.dx, r.bottom); break;
        case 'l':  r = Rect.fromLTRB(imgPos.dx, r.top, r.right, r.bottom); break;
        case 'r':  r = Rect.fromLTRB(r.left, r.top, imgPos.dx, r.bottom); break;
        case 'bl': r = Rect.fromLTRB(imgPos.dx, r.top, r.right, imgPos.dy); break;
        case 'b':  r = Rect.fromLTRB(r.left, r.top, r.right, imgPos.dy); break;
        case 'br': r = Rect.fromLTRB(r.left, r.top, imgPos.dx, imgPos.dy); break;
      }
      _cropRect = _clampRect(r, maxW, maxH);
    } else if (_cropDragOffset != null && _cropRect != null) {
      // Move
      final newLeft = (imgPos.dx - _cropDragOffset!.dx).clamp(0, maxW - _cropRect!.width) as double;
      final newTop = (imgPos.dy - _cropDragOffset!.dy).clamp(0, maxH - _cropRect!.height) as double;
      _cropRect = Rect.fromLTWH(newLeft, newTop, _cropRect!.width, _cropRect!.height);
    } else if (_cropStart != null) {
      // Draw new rect
      _cropRect = Rect.fromPoints(_cropStart!, imgPos);
    }
  }

  void _onCropUp(Offset imgPos) {
    // Don't auto-apply — wait for user to confirm via button or Enter key.
    // The crop rect stays visible for adjustment.
    _cropEdge = null;
    _cropDragOffset = null;
    _cropStart = null;
  }

  void _applyCrop() {
    if (_cropRect != null && _cropRect!.width > 10 && _cropRect!.height > 10) {
      _transformVoid('crop', {
        'x': _cropRect!.left.round(),
        'y': _cropRect!.top.round(),
        'w': _cropRect!.width.round(),
        'h': _cropRect!.height.round(),
      });
    }
    _cropEdge = null;
    _cropDragOffset = null;
    _cropStart = null;
    _cropRect = null;
  }

  void _cancelCrop() {
    // Reset to full image
    if (_previewImage != null) {
      _cropRect = Offset.zero & Size(_previewImage!.width.toDouble(), _previewImage!.height.toDouble());
    }
    _cropEdge = null;
    _cropDragOffset = null;
    _cropStart = null;
  }

  Rect _clampRect(Rect r, double mw, double mh) {
    return Rect.fromLTRB(
      r.left.clamp(0.0, mw),
      r.top.clamp(0.0, mh),
      r.right.clamp(0.0, mw),
      r.bottom.clamp(0.0, mh),
    );
  }

  List<List<dynamic>> _cropHandles(Rect r) {
    return [
      ['tl', r.topLeft], ['t', Offset(r.center.dx, r.top)],
      ['tr', r.topRight], ['l', Offset(r.left, r.center.dy)],
      ['r', Offset(r.right, r.center.dy)],
      ['bl', r.bottomLeft], ['b', Offset(r.center.dx, r.bottom)],
      ['br', r.bottomRight],
    ];
  }

  // -----------------------------------------------------------------------
  // Text tool — inline editing
  // -----------------------------------------------------------------------
  void _onTextDown(Offset imgPos) {
    // If already editing, don't create a new box — tap passes to TextField
    if (_textMode) return;
    _textCtrl.clear();
    _safeSetState(() {
      _textMode = true;
      _textPos = Offset(
        imgPos.dx.clamp(0, (_previewImage?.width ?? 800) - _textW - 1),
        imgPos.dy.clamp(0, (_previewImage?.height ?? 600) - _textH - 1),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mountedFlag) _textFocus.requestFocus();
    });
  }

  void _confirmText() {
    if (_textCtrl.text.isNotEmpty && _textPos != null) {
      _apiAddText(_textCtrl.text, _textPos!);
    }
    _safeSetState(() {
      _textMode = false;
      _textPos = null;
    });
  }

  Future<void> _apiAddText(String txt, Offset pos) => _wrap(() async {
    final c = [_primaryColor.red, _primaryColor.green, _primaryColor.blue];
    final sc = [_textStrokeColor.red, _textStrokeColor.green, _textStrokeColor.blue];
    final shc = [_textShadowColor.red, _textShadowColor.green, _textShadowColor.blue];
    final r = await _api.post('/api/v1/editor/text', {
      'text': txt, 'x': pos.dx.round(), 'y': pos.dy.round(),
      'font_size': _fontSize, 'color': c, 'opacity': _opacity,
      'stroke_width': _textStrokeWidth, 'stroke_color': sc,
      'shadow_blur': _textShadowBlur, 'shadow_color': shc,
      'preview_only': true,
    });
    await _updateState(r);
  }, label: 'Adding text...', successMsg: 'Text added');

  // -----------------------------------------------------------------------
  // Brush / Shape / Fill / Eyedropper
  // -----------------------------------------------------------------------
  Future<void> _apiDrawBrush(List<Offset> pts) => _wrap(() async {
    final p = pts.map((p) => [p.dx.round(), p.dy.round()]).toList();
    final isEraser = _currentTool == 'eraser';
    final c = isEraser
        ? [0, 0, 0]
        : [_primaryColor.red, _primaryColor.green, _primaryColor.blue];
    final body = <String, dynamic>{
      'points': p, 'color': c, 'size': _brushSize, 'opacity': _opacity,
    };
    if (isEraser) body['mode'] = 'eraser';
    final r = await _api.post('/api/v1/editor/draw', {...body, 'preview_only': true});
    await _updateState(r);
  }, label: 'Drawing...');

  Future<void> _apiDrawShape(Offset s, Offset e) => _wrap(() async {
    final c = [_primaryColor.red, _primaryColor.green, _primaryColor.blue];
    final x = math.min(s.dx, e.dx).round().clamp(0, 99999);
    final y = math.min(s.dy, e.dy).round().clamp(0, 99999);
    final w = (e.dx - s.dx).abs().round().clamp(1, 99999);
    final h = (e.dy - s.dy).abs().round().clamp(1, 99999);
    final r = await _api.post('/api/v1/editor/shape', {
      'shape_type': _shapeType, 'x': x, 'y': y, 'w': w, 'h': h, 'fill_color': c,
      'preview_only': true,
    });
    await _updateState(r);
  }, label: 'Drawing shape...');

  Future<void> _apiFill(Offset pos) => _wrap(() async {
    final c = [_primaryColor.red, _primaryColor.green, _primaryColor.blue];
    final r = await _api.post('/api/v1/editor/fill', {
      'x': pos.dx.round(), 'y': pos.dy.round(), 'color': c,
      'preview_only': true,
    });
    await _updateState(r);
  }, label: 'Filling...');

  Future<void> _apiEyedropper(Offset pos) => _wrap(() async {
    final r = await _api.post('/api/v1/editor/eyedropper', {
      'x': pos.dx.round(), 'y': pos.dy.round(),
    });
    if (r['status'] == 'ok') {
      final c = r['color'];
      _safeSetState(() => _primaryColor = Color.fromARGB(
          c['a'] ?? 255, c['r'] ?? 255, c['g'] ?? 255, c['b'] ?? 255));
    }
  }, label: 'Picking color...');

  // Quick gradient: uses current primary/secondary colors, no dialog
  void _applyQuickGradient(Offset pos) {
    // Use position as a clue for direction: if closer to left edge → horizontal
    final iw = _previewImage?.width.toDouble() ?? 800;
    final dir = pos.dx < iw / 3 ? 'horizontal' : 'vertical';
    _wrap(() async {
      final r = await _api.post('/api/v1/editor/gradient', {
        'color1': [_primaryColor.red, _primaryColor.green, _primaryColor.blue],
        'color2': [0, 0, 0],
        'direction': dir,
        'preview_only': true,
      });
      await _updateState(r);
    }, label: 'Gradient...', successMsg: 'Gradient applied');
  }

  // -----------------------------------------------------------------------
  // Inline text drag (text box move + resize)
  // -----------------------------------------------------------------------
  void _onTextDragStart(DragStartDetails d) {}

  void _onTextDragMove(DragUpdateDetails d) {
    if (_textPos == null) return;
    final scale = _tc.value.getMaxScaleOnAxis();
    final pixelDelta = d.delta / scale;
    final maxW = _previewImage?.width.toDouble() ?? 800;
    final maxH = _previewImage?.height.toDouble() ?? 600;
    _safeSetState(() {
      _textPos = Offset(
        (_textPos!.dx + pixelDelta.dx).clamp(0, maxW - _textW),
        (_textPos!.dy + pixelDelta.dy).clamp(0, maxH - _textH),
      );
    });
  }

  void _onTextDragEnd(DragEndDetails d) {}

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        toolbarHeight: 34,
        backgroundColor: const Color(0xFF0D0D1A),
        title: Text('Image Studio',
            style: TextStyle(fontSize: 12, color: Colors.grey[300])),
        actions: [
          if (_info != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_info!['width']}x${_info!['height']}  ${_info!['layers']}ly',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          IconButton(
              icon: const Icon(Icons.undo, size: 15),
              onPressed: _canUndo ? _undo : null,
              tooltip: 'Undo'),
          IconButton(
              icon: const Icon(Icons.redo, size: 15),
              onPressed: _canRedo ? _redo : null,
              tooltip: 'Redo'),
          IconButton(
              icon: const Icon(Icons.save, size: 15),
              onPressed: _saveImage,
              tooltip: 'Save'),
          IconButton(
              icon: const Icon(Icons.open_in_new, size: 15),
              onPressed: _openImage,
              tooltip: 'Open'),
          IconButton(
              icon: const Icon(Icons.add, size: 15),
              onPressed: _createCanvas,
              tooltip: 'New'),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _previewImage == null ? _emptyState() : _editorLayout(),
          if (_opLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    color: const Color(0xFF1A1A2E),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                              strokeWidth: 3),
                          const SizedBox(height: 8),
                          Text(_opLabel,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _createCanvas,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Canvas'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: _openImage,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Image')),
          const SizedBox(height: 8),
          Text('or drag & drop an image here',
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _editorLayout() {
    return Row(children: [
      _toolbar(),
      Expanded(
        child: Column(children: [
          _optionsBar(),
          Expanded(child: _canvas()),
          _statusBar(),
        ]),
      ),
      _rightPanel(),
    ]);
  }

  // -----------------------------------------------------------------------
  // Toolbar — 2-column, 98px, matching architecture doc layout
  // -----------------------------------------------------------------------
  String? _pendingActionTool; // non-null triggers action on next _execActionTool call

  void _execActionTool(String tool) {
    if (_pendingActionTool != tool) return;
    _pendingActionTool = null;
    switch (tool) {
      case 'resize':
        _showResizeDialog();
        break;
      case 'rotate':
        _showRotateSubActions();
        break;
      case 'adjust':
        _showAdjustDialog();
        break;
      case 'gray':
        _filter('grayscale');
        break;
      case 'sepia':
        _filter('sepia');
        break;
      case 'blur':
        _filter('blur');
        break;
      case 'invert':
        _filter('invert');
        break;
      case 'sharpen':
        _filter('sharpen');
        break;
      case 'edge':
        _filter('edge_detect');
        break;
      case 'denoise':
        _transformVoid('denoise', {});
        break;
      case 'clahe':
        _adjustVoid('clahe', {'clip_limit': 2.0});
        break;
      case 'autowb':
        _adjustVoid('auto_wb', {'strength': 1.0});
        break;
      case 'remove-bg':
        _transformVoid('remove-bg', {});
        break;
      case 'ai-enhance':
        _transformVoid('ai-enhance', {});
        break;
      case 'ai-restore':
        _transformVoid('ai-restore', {});
        break;
      case 'upscale':
        _showUpscaleDialog();
        break;
      case 'lineart':
        _transformVoid('lineart', {'method': 'canny'});
        break;
      case 'hdr':
        _transformVoid('hdr', {});
        break;
    }
  }

  Widget _toolbar() {
    // [id, icon, tooltip, isAction?, actionName]
    const tools = <List<dynamic>>[
      // ── Interactive tools ──
      ['crop',       Icons.crop,                 'Crop',                      false, null],
      ['text',       Icons.text_fields,          'Add text',                  false, null],
      ['brush',      Icons.brush,                'Brush',                     false, null],
      ['eraser',     Icons.auto_fix_off,         'Eraser',                    false, null],
      ['shape',      Icons.category_outlined,    'Shape',                     false, null],
      ['resize',     Icons.photo_size_select_small, 'Resize',                 true,  'resize'],
      ['rotate',     Icons.rotate_right,         'Rotate',                    true,  'rotate'],
      ['adjst',      Icons.tune,                 'Adjust',                    true,  'adjust'],
      // ── Filters ──
      ['gray',       Icons.filter_b_and_w,       'Grayscale',                 true,  'gray'],
      ['sepia',      Icons.color_lens,           'Sepia',                     true,  'sepia'],
      ['blur',       Icons.blur_on,              'Blur',                      true,  'blur'],
      ['invert',     Icons.invert_colors,        'Invert',                    true,  'invert'],
      ['sharpen',    Icons.blur_circular,        'Sharpen',                   true,  'sharpen'],
      ['edge',       Icons.auto_fix_high,        'Edge detect',              true,  'edge'],
      // ── Enhancement ──
      ['denoise',    Icons.noise_control_off,    'Denoise',                   true,  'denoise'],
      ['clahe',      Icons.contrast,             'CLAHE',                     true,  'clahe'],
      ['autowb',     Icons.wb_sunny,             'Auto WB',                   true,  'autowb'],
      ['rmbg',       Icons.image_not_supported,  'Remove BG',                 true,  'remove-bg'],
      ['gradient',   Icons.gradient,             'Gradient',                  false, null],
      // ── AI tools ──
      ['ai-enhance', Icons.auto_fix_high,        'AI Enhance',               true,  'ai-enhance'],
      ['ai-restore', Icons.face,                 'Face Restore',              true,  'ai-restore'],
      ['upscale',    Icons.zoom_in,              'Upscale',                   true,  'upscale'],
      ['lineart',    Icons.auto_fix_high,        'Lineart',                   true,  'lineart'],
      ['hdr',        Icons.brightness_high,      'HDR Tone',                  true,  'hdr'],
    ];
    final colCount = 2;
    final rows = <List<List<dynamic>>>[];
    for (int i = 0; i < tools.length; i += colCount) {
      rows.add(tools.sublist(i, (i + colCount).clamp(0, tools.length)));
    }
    return Container(
      width: 98,
      color: const Color(0xFF0D0D1A),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: rows.expand((row) {
              return [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: row.map((t) {
                    final id = t[0] as String;
                    final icon = t[1] as IconData;
                    final tip = t[2] as String;
                    final isAction = t[3] as bool;
                    final active = _currentTool == id;
                    return Tooltip(
                        message: tip,
                        child: GestureDetector(
                          onTap: () {
                            if (isAction) {
                              // Action tool — trigger directly
                              final actionName = t[4] as String;
                              _pendingActionTool = actionName;
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (_mountedFlag) {
                                  _execActionTool(actionName);
                                }
                              });
                            } else {
                              _setTool(id);
                              if (id == 'eraser') _brushSize = 20;
                            }
                          },
                          child: Container(
                            width: 49,
                            height: 34,
                            color: active
                                ? const Color(0xFF6C63FF).withOpacity(0.3)
                                : null,
                            alignment: Alignment.center,
                            child: Icon(icon,
                                size: 16,
                                color: active
                                    ? const Color(0xFF6C63FF)
                                    : Colors.grey),
                          ),
                        ));
                  }).toList(),
                ),
                // separator line between rows
                Container(height: 1, color: const Color(0xFF16213E)),
              ];
            }).toList()),
      ),
    );
  }

  void _showRotateSubActions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Rotate',
            style: TextStyle(color: Colors.white, fontSize: 13)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _actionBtn('Rotate 90° CW', () {
            Navigator.pop(ctx);
            _transformVoid('rotate', {'angle': 90});
          }),
          _actionBtn('Rotate 90° CCW', () {
            Navigator.pop(ctx);
            _transformVoid('rotate', {'angle': -90});
          }),
          _actionBtn('Rotate 180°', () {
            Navigator.pop(ctx);
            _transformVoid('rotate', {'angle': 180});
          }),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)))
        ],
      ),
    );
  }

  void _showFlipSubActions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Flip',
            style: TextStyle(color: Colors.white, fontSize: 13)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _actionBtn('Flip Horizontal', () {
            Navigator.pop(ctx);
            _transformVoid('flip', {'direction': 'horizontal'});
          }),
          _actionBtn('Flip Vertical', () {
            Navigator.pop(ctx);
            _transformVoid('flip', {'direction': 'vertical'});
          }),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)))
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16213E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Options bar — tool-specific params + opacity
  // -----------------------------------------------------------------------
  Widget _optionsBar() {
    return Container(
      height: 28,
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        if (_currentTool == 'brush' || _currentTool == 'shape')
          _slider('Size', _brushSize, 1, 50, (v) => _brushSize = v),
        if (_currentTool == 'text')
          const SizedBox(width: 40), // placeholder for text
        const SizedBox(width: 6),
        GestureDetector(
            onTap: _pickColor,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _primaryColor,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
        const SizedBox(width: 4),
        Text(
          '${_primaryColor.red},${_primaryColor.green},${_primaryColor.blue}',
          style: const TextStyle(fontSize: 8, color: Colors.grey)),
        if (_currentTool == 'shape') ...[
          const SizedBox(width: 4),
          _miniBtn('Rect', _shapeType == 'rect', () => _shapeType = 'rect'),
          _miniBtn('Ellipse', _shapeType == 'ellipse',
              () => _shapeType = 'ellipse'),
          _miniBtn('Line', _shapeType == 'line', () => _shapeType = 'line'),
          _miniBtn('Circle', _shapeType == 'circle',
              () => _shapeType = 'circle'),
        ],
        if (_currentTool == 'text' && _textMode) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            height: 14,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 12,
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: _confirmText,
              tooltip: 'Confirm text',
            ),
          ),
          SizedBox(
            width: 14,
            height: 14,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 12,
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _safeSetState(() {
                _textMode = false;
                _textPos = null;
              }),
              tooltip: 'Cancel',
            ),
          ),
        ],
        // Opacity slider — always visible
        const Spacer(),
        _sliderFloat('Opacity', _opacity, 0.0, 1.0, (v) => _opacity = v),
      ]),
    );
  }

  Widget _sliderFloat(String label, double v, double min, double max, ValueChanged<double> onChange) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:',
            style: const TextStyle(fontSize: 8, color: Colors.grey)),
        SizedBox(
            width: 40,
            child: Slider(
                value: v,
                min: min,
                max: max,
                onChanged: (x) => _safeSetState(() => onChange(x)))),
        Text('${(v * 100).round()}%',
            style: const TextStyle(fontSize: 8, color: Colors.white)),
      ],
    );
  }

  Widget _slider(String label, int v, int min, int max, ValueChanged<int> onChange) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:',
            style: const TextStyle(fontSize: 8, color: Colors.grey)),
        SizedBox(
            width: 40,
            child: Slider(
                value: v.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                onChanged: (x) => _safeSetState(() => onChange(x.round())))),
        Text('$v', style: const TextStyle(fontSize: 8, color: Colors.white)),
      ],
    );
  }

  Widget _miniBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6C63FF) : Colors.transparent,
          border: Border.all(color: Colors.grey[700]!),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 8,
                color: active ? Colors.white : Colors.grey)),
      ),
    );
  }

  /// Full-width text field with label for tool property input.
  Widget _txtField(String label, String value, ValueChanged<String> onChanged) {
    return Row(children: [
      Text('$label:', style: const TextStyle(fontSize: 8, color: Colors.grey)),
      const SizedBox(width: 4),
      SizedBox(
        width: 40, height: 16,
        child: TextField(
          controller: TextEditingController(text: value),
          style: const TextStyle(fontSize: 8, color: Colors.white, height: 1),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onSubmitted: (v) => _safeSetState(() => onChanged(v)),
        ),
      ),
    ]);
  }

  /// Mini text field with label prefix (used inline in a Row).
  Widget _miniTxt(String label, String value, double width, ValueChanged<String> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey)),
      SizedBox(
        width: width, height: 14,
        child: TextField(
          controller: TextEditingController(text: value),
          style: const TextStyle(fontSize: 7, color: Colors.white, height: 1),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onSubmitted: (v) => _safeSetState(() => onChanged(v)),
        ),
      ),
    ]);
  }

  /// Pick a color and call [onPicked] with the result.
  Future<void> _pickColorCustom(void Function(Color) onPicked) async {
    int r = _primaryColor.red, g = _primaryColor.green, b = _primaryColor.blue;
    final rC = TextEditingController(text: '$r');
    final gC = TextEditingController(text: '$g');
    final bC = TextEditingController(text: '$b');
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Pick Color',
            style: TextStyle(color: Colors.white, fontSize: 11)),
        content: SizedBox(
          width: 180,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _colorRow('R', rC, (v) {
              final n = int.tryParse(v);
              if (n != null) { r = n.clamp(0, 255); }
            }),
            _colorRow('G', gC, (v) {
              final n = int.tryParse(v);
              if (n != null) { g = n.clamp(0, 255); }
            }),
            _colorRow('B', bC, (v) {
              final n = int.tryParse(v);
              if (n != null) { b = n.clamp(0, 255); }
            }),
            const SizedBox(height: 8),
            Container(
              width: double.infinity, height: 20,
              decoration: BoxDecoration(
                color: Color.fromARGB(255, r, g, b),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, Color.fromARGB(255, r, g, b)),
              child: const Text('Select',
                  style: TextStyle(color: Color(0xFF6C63FF)))),
        ],
      ),
    );
    if (picked != null) {
      _safeSetState(() => onPicked(picked));
    }
  }

  Widget _colorRow(String label, TextEditingController ctrl, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text('$label:', style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }

  // -----------------------------------------------------------------------
  // Canvas — InteractiveViewer
  // -----------------------------------------------------------------------
  Widget _canvas() {
    return LayoutBuilder(builder: (ctx, constraints) {
      if (constraints.maxWidth > 0 &&
          (constraints.maxWidth != _vpW ||
              constraints.maxHeight != _vpH ||
              !_vpReady)) {
        _vpW = constraints.maxWidth;
        _vpH = constraints.maxHeight;
        if (_needsInitFit && _previewImage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_mountedFlag && _needsInitFit) _fitToViewport();
          });
        }
      }
      final iw = _previewImage!.width.toDouble();
      final ih = _previewImage!.height.toDouble();
      final canPanZoom = _currentTool == 'select';
      final canScaleZoom = _currentTool == 'select' || _currentTool == 'crop';

      return ClipRect(
        child: InteractiveViewer(
          transformationController: _tc,
          boundaryMargin: const EdgeInsets.all(200),
          minScale: 0.1,
          maxScale: 10.0,
          constrained: false,
          panEnabled: canPanZoom,
          scaleEnabled: canScaleZoom,
          child: SizedBox(
            width: iw,
            height: ih,
            child: Stack(
              children: [
                // Image
                if (_previewImage != null)
                  RawImage(
                    image: _previewImage!,
                    fit: BoxFit.none,
                    filterQuality: FilterQuality.medium,
                  ),
                // Tool overlays (wrapped in IgnorePointer for visuals)
                IgnorePointer(
                  child: CustomPaint(
                    painter: EditorOverlayPainter(
                      drawPoints: _drawPoints,
                      currentTool: _currentTool,
                      primaryColor: _primaryColor,
                      brushSize: _brushSize,
                      cropRect: _cropMode ? _cropRect : null,
                      shapePreview: _shapePreview,
                      imageSize: Size(iw, ih),
                      zoomScale: _tc.value.getMaxScaleOnAxis(),
                      textContent: _textMode ? _textCtrl.text : null,
                      textPosition: _textPos,
                      textColor: _primaryColor,
                      textSize: _fontSize.toDouble(),
                      textStrokeWidth: _textStrokeWidth,
                      textStrokeColor: _textStrokeColor,
                      textShadowBlur: _textShadowBlur,
                      textShadowColor: _textShadowColor,
                      textOpacity: _opacity,
                    ),
                    size: Size(iw, ih),
                  ),
                ),
                // Gesture layer
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                  ),
                ),
                // Inline text editing overlay
                if (_textMode && _textPos != null)
                  Positioned(
                    left: _textPos!.dx,
                    top: _textPos!.dy,
                    width: _textW,
                    height: _textH,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TextField(
                            controller: _textCtrl,
                            focusNode: _textFocus,
                            autofocus: true,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _fontSize.toDouble(),
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0x221A1A2E), // near-transparent so text preview shows through
                              contentPadding: const EdgeInsets.all(4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(2),
                                borderSide: const BorderSide(
                                    color: Color(0xFF6C63FF), width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(2),
                                borderSide: const BorderSide(
                                    color: Color(0xFF6C63FF), width: 1.5),
                              ),
                              isDense: true,
                            ),
                            onChanged: (_) => _safeSetState(() {}),
                            onSubmitted: (_) => _confirmText(),
                          ),
                        ),
                        // Drag handle
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: _onTextDragMove,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6C63FF),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(1),
                                  bottomLeft: Radius.circular(4),
                                ),
                              ),
                              child: const Icon(
                                Icons.drag_indicator,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // -----------------------------------------------------------------------
  // Status bar — zoom %, image size, tool, memory
  // -----------------------------------------------------------------------
  Widget _statusBar() {
    final iw = _previewImage?.width ?? 0;
    final ih = _previewImage?.height ?? 0;
    final zoom = _tc.value.getMaxScaleOnAxis();
    final zoomPct = (zoom * 100).round();
    return Container(
      height: 20,
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Text('Zoom: $zoomPct%',
            style: const TextStyle(fontSize: 9, color: Colors.white54)),
        const SizedBox(width: 12),
        Text('${iw} × ${ih}',
            style: const TextStyle(fontSize: 9, color: Colors.white38)),
        const SizedBox(width: 12),
        Text('Tool: $_currentTool',
            style: const TextStyle(fontSize: 9, color: Colors.white38)),
        const Spacer(),
        if (_error != null)
          Flexible(
            child: Text(_error!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: Colors.red[300])),
          ),
      ]),
    );
  }

  // -----------------------------------------------------------------------
  // Right panel — tool properties + AI tools + history (doc spec)
  // -----------------------------------------------------------------------
  Widget _rightPanel() {
    return Container(
      width: 170,
      color: const Color(0xFF0D0D1A),
      child: Column(children: [
        // Layers section
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          child: Row(children: [
            const Text('Layers',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
            const Spacer(),
            _iconBtn(Icons.add, () => _wrap(() async {
              await _api.addLayer();
              await _refreshLayers();
            }, label: 'Add layer...', successMsg: 'Layer added')),
            _iconBtn(Icons.delete_outline, () => _wrap(() async {
              await _api.deleteLayer();
              await _refreshLayers();
            }, label: 'Delete layer...', successMsg: 'Layer deleted')),
          ]),
        ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            itemCount: _layers.length,
            itemBuilder: (ctx, i) {
              final l = _layers[_layers.length - 1 - i];
              final vis = l['visible'] ?? true;
              return Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _toggleVisibility(i),
                    child: Icon(vis ? Icons.visibility : Icons.visibility_off,
                        size: 11, color: Colors.grey)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l['name'] ?? 'Layer ${_layers.length - i}',
                      style: const TextStyle(fontSize: 8, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(l['opacity'] * 100).round()}%',
                    style:
                        const TextStyle(fontSize: 7, color: Colors.grey),
                  ),
                ]),
              );
            },
          ),
        ),
        const Divider(height: 1, color: Color(0xFF16213E)),

        // TOOL PROPERTIES — context-sensitive
        _sectionTitle('TOOL PROPS'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(children: [
            // Color
            Row(children: [
              const Text('Color', style: TextStyle(fontSize: 8, color: Colors.grey)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _pickColor,
                child: Container(
                  width: 20, height: 16,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '#${_primaryColor.red.toRadixString(16).padLeft(2,"0")}'
                '${_primaryColor.green.toRadixString(16).padLeft(2,"0")}'
                '${_primaryColor.blue.toRadixString(16).padLeft(2,"0")}',
                style: const TextStyle(fontSize: 8, color: Colors.white54),
              ),
            ]),
            const SizedBox(height: 4),
            // Size slider (for brush/shape/eraser)
            if (_currentTool == 'brush' || _currentTool == 'shape' || _currentTool == 'eraser')
              Row(children: [
                const Text('Size', style: TextStyle(fontSize: 8, color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: _brushSize.toDouble(), min: 1, max: 50,
                    onChanged: (v) => _safeSetState(() => _brushSize = v.round()),
                  ),
                ),
                Text('$_brushSize', style: const TextStyle(fontSize: 8, color: Colors.white)),
              ]),
            // Text tool properties — all text fields for precise input
            if (_currentTool == 'text') ...[
              const SizedBox(height: 4),
              // Font size
              _txtField('Font', _fontSize.toString(), (v) {
                final n = int.tryParse(v);
                if (n != null) _fontSize = n.clamp(1, 500);
              }),
              // Color (RGB fields next to swatch)
              Row(children: [
                const Text('Color', style: TextStyle(fontSize: 8, color: Colors.grey)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _miniTxt('R', '${_primaryColor.red}', 20, (v) {
                  final n = int.tryParse(v);
                  if (n != null) _primaryColor = _primaryColor.withRed(n.clamp(0, 255));
                }),
                _miniTxt('G', '${_primaryColor.green}', 20, (v) {
                  final n = int.tryParse(v);
                  if (n != null) _primaryColor = _primaryColor.withGreen(n.clamp(0, 255));
                }),
                _miniTxt('B', '${_primaryColor.blue}', 20, (v) {
                  final n = int.tryParse(v);
                  if (n != null) _primaryColor = _primaryColor.withBlue(n.clamp(0, 255));
                }),
              ]),
              const SizedBox(height: 4),
              // Stroke width + color
              Row(children: [
                _miniTxt('Str', '$_textStrokeWidth', 20, (v) {
                  final n = int.tryParse(v);
                  if (n != null) _textStrokeWidth = n.clamp(0, 100);
                }),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _pickColorCustom((c) => _textStrokeColor = c),
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: _textStrokeColor,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              // Shadow blur + color
              Row(children: [
                _miniTxt('Shad', '$_textShadowBlur', 20, (v) {
                  final n = int.tryParse(v);
                  if (n != null) _textShadowBlur = n.clamp(0, 100);
                }),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _pickColorCustom((c) => _textShadowColor = c),
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: _textShadowColor,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              // Opacity
              _txtField('Opacity', (_opacity * 100).round().toString(), (v) {
                final n = int.tryParse(v);
                if (n != null) _opacity = n.clamp(0, 100) / 100.0;
              }),
            ],
            // Shape type (for shape tool)
            if (_currentTool == 'shape') ...[
              const SizedBox(height: 4),
              Row(children: [
                _miniBtn('Rect', _shapeType == 'rect', () => _shapeType = 'rect'),
                const SizedBox(width: 2),
                _miniBtn('Ellipse', _shapeType == 'ellipse', () => _shapeType = 'ellipse'),
                const SizedBox(width: 2),
                _miniBtn('Line', _shapeType == 'line', () => _shapeType = 'line'),
                const SizedBox(width: 2),
                _miniBtn('Circle', _shapeType == 'circle', () => _shapeType = 'circle'),
              ]),
            ],
            // Crop confirm/cancel (for crop tool)
            if (_currentTool == 'crop' && _cropRect != null) ...[
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  width: 50, height: 20,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 9),
                    ),
                    onPressed: _applyCrop,
                    child: const Text('Apply'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50, height: 20,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 9),
                    ),
                    onPressed: _cancelCrop,
                    child: const Text('Cancel'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
        const Divider(height: 1, color: Color(0xFF16213E)),

        // AI TOOLS
        _sectionTitle('AI TOOLS', accent: true),
        _btnRow(
          labels: const ['Enhance', 'Restore', 'Upscale', 'Lineart'],
          callbacks: [
            () => _transformVoid('ai-enhance', {}),
            () => _transformVoid('ai-restore', {}),
            () => _transformVoid('upscale', {'scale': 2}),
            () => _transformVoid('lineart', {'method': 'canny'}),
          ],
        ),
        _btnRow(
          labels: const ['HDR', 'Rm BG', 'Inpaint', 'BlurReg'],
          callbacks: [
            () => _transformVoid('hdr', {}),
            () => _transformVoid('remove-bg', {}),
            () => _transformVoid('inpaint-erase', {'x':10,'y':10,'w':100,'h':100,'radius':3}),
            () => _transformVoid('blur-region', {'x':0,'y':0,'w':100,'h':100,'ksize':15}),
          ],
        ),
        const Divider(height: 1, color: Color(0xFF16213E)),

        // HISTORY
        _sectionTitle('HISTORY'),
        _btnRow(
          labels: const ['↩ Undo', '↪ Redo', 'Undo#', 'Redo#'],
          callbacks: [
            _canUndo ? () => _undo() : () {},
            _canRedo ? () => _redo() : () {},
            () => _showSnack('Undo stack: ${_undoCount}'),
            () => _showSnack('Redo stack: ${_redoCount}'),
          ],
        ),

        // OPERATIONS — collapsible action buttons (below the primary panels)
        const Divider(height: 1, color: Color(0xFF16213E)),
        _sectionTitle('QUICK OPS'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              _btnRow(
                labels: const ['Blur', 'Sharpen', 'Sepia', 'Emboss'],
                callbacks: [
                  () => _filter('blur'), () => _filter('sharpen'),
                  () => _filter('sepia'), () => _filter('emboss'),
                ],
              ),
              _btnRow(
                labels: const ['Edge', 'Invert', 'Grayscale', 'Median'],
                callbacks: [
                  () => _filter('edge_detect'), () => _filter('invert'),
                  () => _filter('grayscale'), () => _filter('median_blur'),
                ],
              ),
              _btnRow(
                labels: const ['Bright', 'Contrast', 'Saturate', 'Hue'],
                callbacks: [
                  () => _adjustVoid('brightness', {'factor': 1.3}),
                  () => _adjustVoid('contrast', {'factor': 1.3}),
                  () => _adjustVoid('saturation', {'factor': 1.3}),
                  () => _adjustVoid('hue', {'shift': 30}),
                ],
              ),
              _btnRow(
                labels: const ['CLAHE', 'Auto WB', 'Denoise', 'SmartSh'],
                callbacks: [
                  () => _adjustVoid('clahe', {'clip_limit': 2.0}),
                  () => _adjustVoid('auto_wb', {'strength': 1.0}),
                  () => _transformVoid('denoise', {}),
                  () => _transformVoid('smart-sharpen', {}),
                ],
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // -----------------------------------------------------------------------
  // Right panel sub-widgets
  // -----------------------------------------------------------------------
  Widget _sectionTitle(String t, {bool accent = false}) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFF16213E),
      alignment: Alignment.centerLeft,
      child: Text(t,
          style: TextStyle(
            fontSize: 8,
            color: accent ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF),
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          )),
    );
  }

  Widget _btnRow({
    required List<String> labels,
    required List<VoidCallback> callbacks,
  }) {
    assert(labels.length == callbacks.length && labels.length == 4,
        '_btnRow requires exactly 4 labels and 4 callbacks');
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
          children: List.generate(4, (i) {
        return Expanded(
          child: GestureDetector(
            onTap: callbacks[i],
            child: Container(
              height: 22,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[800]!),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(labels[i],
                  style:
                      TextStyle(fontSize: 8, color: Colors.grey[300])),
            ),
          ),
        );
      })),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(icon, size: 12, color: Colors.grey),
      ),
    );
  }

  Future<void> _toggleVisibility(int di) async {
    final ri = _layers.length - 1 - di;
    if (ri < 0 || ri >= _layers.length) return;
    final l = _layers[ri];
    await _wrap(() async {
      final r = await _api.post('/api/v1/editor/layer-props', {
        'layer': ri,
        'visible': !(l['visible'] ?? true),
      });
      await _updateState(r);
      _refreshLayers();
    }, label: 'Toggling...');
  }

  void _showAdjustDialog() {
    if (_info == null) return;
    double bright = 1.0, contrast = 1.0, sat = 1.0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Adjust',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          content: SizedBox(
            width: 250,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _adjustSlider('Brightness', bright, 0.0, 3.0, (v) => setDlgState(() => bright = v)),
              _adjustSlider('Contrast', contrast, 0.0, 3.0, (v) => setDlgState(() => contrast = v)),
              _adjustSlider('Saturation', sat, 0.0, 3.0, (v) => setDlgState(() => sat = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              _adjustVoid('brightness', {'factor': bright});
              _adjustVoid('contrast', {'factor': contrast});
              _adjustVoid('saturation', {'factor': sat});
            }, child: const Text('Apply', style: TextStyle(color: Color(0xFF6C63FF)))),
          ],
        ),
      ),
    );
  }

  Widget _adjustSlider(String label, double val, double min, double max, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))),
      Expanded(child: Slider(value: val, min: min, max: max, onChanged: onChanged)),
      SizedBox(width: 30, child: Text(val.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 10))),
    ]);
  }

  void _showUpscaleDialog() {
    int scale = 2;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('AI Upscale',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Increase image resolution:',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _miniBtn('2x', scale == 2, () => setDlgState(() => scale = 2)),
              const SizedBox(width: 8),
              _miniBtn('4x', scale == 4, () => setDlgState(() => scale = 4)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              _transformVoid('upscale', {'scale': scale});
            }, child: const Text('Upscale', style: TextStyle(color: Color(0xFF6C63FF)))),
          ],
        ),
      ),
    );
  }

  void _showResizeDialog() {
    if (_info == null) return;
    final wCtrl = TextEditingController(text: '${_info!['width']}');
    final hCtrl = TextEditingController(text: '${_info!['height']}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Resize',
            style: TextStyle(color: Colors.white, fontSize: 13)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Width', wCtrl),
              _field('Height', hCtrl),
            ]),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _transformVoid('resize', {
                  'width': int.tryParse(wCtrl.text) ?? 100,
                  'height': int.tryParse(hCtrl.text) ?? 100,
                });
              },
              child: const Text('Resize',
                  style: TextStyle(color: Color(0xFF6C63FF))))
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Future<void> _pickColor() async {
    final p = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Pick Color',
            style: TextStyle(color: Colors.white, fontSize: 11)),
        content: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hex input
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Hex #',
                  labelStyle: TextStyle(color: Colors.grey, fontSize: 10),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 6, vertical: 6),
                ),
                onChanged: (v) {
                  final h = int.tryParse(v.replaceAll('#', ''), radix: 16);
                  if (h != null) {
                    // Preview will be updated on Select
                  }
                },
              ),
              const SizedBox(height: 8),
              // Quick palette
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  Colors.white, Colors.black,
                  Colors.red, Colors.green, Colors.blue,
                  Colors.yellow, Colors.orange, Colors.purple,
                  Colors.cyan, Colors.pink, Colors.teal, Colors.brown,
                  Colors.amber, Colors.indigo, Colors.lime, Colors.deepOrange,
                ].map((c) => GestureDetector(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c,
                      border: Border.all(
                          color: Colors.grey[700]!, width: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
              // Preview + Select
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, _primaryColor),
              child: const Text('Select',
                  style: TextStyle(color: Color(0xFF6C63FF)))),
        ],
      ),
    );
    if (p != null) _safeSetState(() => _primaryColor = p);
  }

  Future<void> _showFonts() async {
    try {
      final r = await _api.get('/api/v1/editor/fonts');
      final fonts = r['fonts'] as List<dynamic>? ?? [];
      if (!_mountedFlag) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Available Fonts',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          content: SizedBox(
            width: 200,
            height: 300,
            child: ListView.builder(
              itemCount: fonts.length,
              itemBuilder: (ctx, i) {
                final f = fonts[i] as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text(
                    '${f['name'] ?? 'Unknown'}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11),
                  ),
                  subtitle: Text(
                    'family: ${f['family'] ?? ''}  style: ${f['style'] ?? ''}',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 8),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close',
                    style: TextStyle(color: Color(0xFF6C63FF))))
          ],
        ),
      );
    } catch (e) {
      _showSnack('Failed to load fonts: $e', isError: true);
    }
  }

  Future<void> _showInfo() async {
    try {
      final r = await _api.get('/api/v1/editor/info');
      if (!_mountedFlag) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Document Info',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          content: Text(
            'Size: ${r['width']} × ${r['height']}\n'
            'Layers: ${r['layers']}\n'
            'Visible: ${r['visible_layers']}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close',
                    style: TextStyle(color: Color(0xFF6C63FF))))
          ],
        ),
      );
    } catch (e) {
      _showSnack('$e', isError: true);
    }
  }
}
