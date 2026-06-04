import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

/// Tool interaction modes
enum ToolMode { none, crop, resize, rotate, adjust, text, brush, eraser, shape }

class ImageEditorPage extends StatefulWidget {
  const ImageEditorPage({super.key});
  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  final ApiService _api = ApiService();
  Uint8List? _imageBytes;
  Map<String, dynamic>? _info;
  bool _loading = false;
  String _status = 'No image loaded. Click Open to start.';

  // ── Tool mode ──────────────────────────────────────
  ToolMode _toolMode = ToolMode.none;

  // Crop state
  double? _selX, _selY, _selW, _selH;
  double? _dragStartX, _dragStartY;
  String? _dragHandle;

  // Image display area
  final GlobalKey _imgKey = GlobalKey();
  Size? _displaySize;

  // Zoom
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;

  // Adjust sliders
  double _brightness = 1.0, _contrast = 1.0, _saturation = 1.0;

  Map<String, dynamic> _caps = {};

  // ── Text tool state ──────────────────────────────
  double? _textX, _textY;
  final TextEditingController _textCtrl = TextEditingController();
  double _textSize = 32;
  Color _textColor = Colors.white;
  bool _enableStroke = false;
  double _strokeWidth = 2;
  Color _strokeColor = Colors.black;
  bool _enableShadow = false;
  double _shadowBlur = 4;
  Color _shadowColor = Colors.black54;
  List<Map<String, dynamic>> _fonts = [];
  Map<String, dynamic>? _selectedFont;

  // ── Brush/Eraser state ──────────────────────────
  List<List<Offset>> _brushStrokes = [];  // current strokes (client-side preview)
  List<Offset> _currentStroke = [];
  bool _isDrawing = false;
  double _brushSize = 5;
  double _brushOpacity = 1.0;
  Color _brushColor = Colors.white;
  double _eraserSize = 15;

  // ── Shape state ─────────────────────────────────
  Offset? _shapeStart;
  Offset? _shapeEnd;
  String _shapeType = 'rect';
  Color _shapeFillColor = const Color(0x00000000); // transparent by default
  Color _shapeStrokeColor = Colors.white;
  double _shapeStrokeWidth = 2;
  bool _shapeFill = false;

  // ── Undo/Redo state ─────────────────────────────
  bool _canUndo = false;
  bool _canRedo = false;

  // Color swatches
  static const List<Color> _colorSwatches = [
    Colors.white, Colors.black, Colors.red, Colors.orange,
    Colors.yellow, Colors.green, Colors.blue, Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _loadCaps();
    _loadFonts();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCaps() async {
    try {
      final c = await _api.get('/api/v1/editor/capabilities');
      if (mounted) setState(() => _caps = c);
    } catch (_) {}
  }

  Future<void> _loadFonts() async {
    try {
      final f = await _api.get('/api/v1/editor/fonts');
      if (mounted && f is List) {
        setState(() {
          _fonts = f.cast<Map<String, dynamic>>();
          _selectedFont = _fonts.isNotEmpty ? _fonts[0] : null;
        });
      }
    } catch (_) {}
  }

  void _setImage(String b64) {
    _imageBytes = base64Decode(b64);
    _status = '${_info?['width'] ?? '?'} × ${_info?['height'] ?? '?'} · ${_info?['format'] ?? ''}';
    _exitToolMode();
    if (mounted) setState(() {});
  }

  // ── API call ──────────────────────────────────────

  Future<void> _callEdit(String endpoint, Map<String, dynamic> body) async {
    setState(() => _loading = true);
    try {
      final r = await _api.post(endpoint, body: body);
      if (r['status'] == 'ok') {
        _info = r['info'] as Map<String, dynamic>?;
        _setImage(r['base64'] as String);
        _refreshHistory(r);
      } else if (mounted) {
        _showMsg(r['error'] ?? 'Error');
      }
    } catch (e) {
      if (mounted) _showMsg('$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _refreshHistory(Map<String, dynamic> r) {
    if (r.containsKey('history')) {
      final h = r['history'] as Map<String, dynamic>;
      setState(() {
        _canUndo = h['can_undo'] == true;
        _canRedo = h['can_redo'] == true;
      });
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ── Undo / Redo ──────────────────────────────────

  Future<void> _undo() async {
    setState(() => _loading = true);
    try {
      final r = await _api.post('/api/v1/editor/undo', body: {});
      if (r['status'] == 'ok') {
        _info = r['info'] as Map<String, dynamic>?;
        _setImage(r['base64'] as String);
        _refreshHistory(r);
      }
    } catch (e) { _showMsg('$e'); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _redo() async {
    setState(() => _loading = true);
    try {
      final r = await _api.post('/api/v1/editor/redo', body: {});
      if (r['status'] == 'ok') {
        _info = r['info'] as Map<String, dynamic>?;
        _setImage(r['base64'] as String);
        _refreshHistory(r);
      }
    } catch (e) { _showMsg('$e'); }
    if (mounted) setState(() => _loading = false);
  }

  // ── Open / Export ───────────────────────────────

  Future<void> _openImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    setState(() {
      _loading = true;
      _canUndo = false;
      _canRedo = false;
      _zoomLevel = 1.0;
      _panOffset = Offset.zero;
    });
    try {
      final r = await _api.post('/api/v1/editor/load', body: {'path': path});
      if (r['status'] == 'ok') {
        _info = r['info'] as Map<String, dynamic>?;
        _setImage(r['base64'] as String);
      } else {
        _showMsg(r['error'] ?? 'Load failed');
      }
    } catch (e) { _showMsg('$e'); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _exportImage() async {
    final path = await FilePicker.platform.saveFile(
      type: FileType.image,
      fileName: 'exported_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (path == null) return;
    try {
      final r = await _api.post('/api/v1/editor/export', body: {'path': path});
      if (r['status'] == 'ok') _showMsg('Exported');
      else _showMsg(r['error'] ?? 'Export failed');
    } catch (e) { _showMsg('$e'); }
  }

  // ── Tool mode management ─────────────────────────

  void _exitToolMode() {
    setState(() {
      _toolMode = ToolMode.none;
      _selX = _selY = _selW = _selH = null;
      _dragHandle = null;
      _textX = _textY = null;
      _currentStroke = [];
      _brushStrokes = [];
      _isDrawing = false;
      _shapeStart = _shapeEnd = null;
    });
  }

  void _enterCrop() {
    if (_imageBytes == null) return;
    if (_toolMode == ToolMode.crop) { _exitToolMode(); return; }
    _exitToolMode();
    final w = (_info?['width'] as num?)?.toDouble() ?? 100;
    final h = (_info?['height'] as num?)?.toDouble() ?? 100;
    setState(() {
      _toolMode = ToolMode.crop;
      _selX = 0; _selY = 0;
      _selW = w; _selH = h;
    });
  }

  void _applyCrop() {
    if (_selX == null || _selY == null || _selW == null || _selH == null) return;
    _callEdit('/api/v1/editor/crop', {
      'x': _selX!.round(), 'y': _selY!.round(),
      'w': _selW!.round(), 'h': _selH!.round(),
    });
    _exitToolMode();
  }

  void _enterResize() {
    if (_imageBytes == null) return;
    if (_toolMode == ToolMode.resize) { _exitToolMode(); return; }
    _exitToolMode();
    setState(() => _toolMode = ToolMode.resize);
  }

  void _enterAdjust() {
    if (_imageBytes == null) return;
    if (_toolMode == ToolMode.adjust) { _exitToolMode(); return; }
    _exitToolMode();
    setState(() {
      _toolMode = ToolMode.adjust;
      _brightness = 1.0; _contrast = 1.0; _saturation = 1.0;
    });
  }

  void _applyAdjust() {
    final body = <String, dynamic>{};
    if (_brightness != 1.0) body['brightness'] = _brightness;
    if (_contrast != 1.0) body['contrast'] = _contrast;
    if (_saturation != 1.0) body['saturation'] = _saturation;
    if (body.isEmpty) return;
    _callEdit('/api/v1/editor/adjust', body);
    _exitToolMode();
  }

  void _enterRotate() {
    if (_imageBytes == null) return;
    if (_toolMode == ToolMode.rotate) { _exitToolMode(); return; }
    _exitToolMode();
    setState(() => _toolMode = ToolMode.rotate);
  }

  void _enterText() {
    if (_imageBytes == null) return;
    if (_toolMode == ToolMode.text) { _exitToolMode(); return; }
    _exitToolMode();
    setState(() {
      _toolMode = ToolMode.text;
      _textX = _textY = null;
    });
  }

  void _enterBrush() {
    if (_imageBytes == null) return;
    if (_toolMode == ToolMode.brush) { _exitToolMode(); return; }
    _exitToolMode();
    setState(() {
      _toolMode = ToolMode.brush;
      _brushSize = 5;
      _brushColor = Colors.white;
    });
  }

  void _enterEraser() {
    if (_imageBytes == null) return;
    if (_toolMode == ToolMode.eraser) { _exitToolMode(); return; }
    _exitToolMode();
    setState(() {
      _toolMode = ToolMode.eraser;
      _eraserSize = 15;
    });
  }

  void _enterShape() {
    if (_imageBytes == null) return;
    if (_toolMode == ToolMode.shape) { _exitToolMode(); return; }
    _exitToolMode();
    setState(() {
      _toolMode = ToolMode.shape;
      _shapeStart = _shapeEnd = null;
    });
  }

  // ── Text: click on canvas ───────────────────────
  void _onTextCanvasTap(Offset localPos) {
    if (_toolMode != ToolMode.text) return;
    final pos = _screenToImage(localPos);
    if (pos == null) return;
    setState(() {
      _textX = pos.dx;
      _textY = pos.dy;
    });
  }

  void _applyText() {
    if (_textX == null || _textY == null || _textCtrl.text.trim().isEmpty) {
      _showMsg('Click on the image first, then type your text.');
      return;
    }
    final body = <String, dynamic>{
      'text': _textCtrl.text.trim(),
      'x': _textX!.round(),
      'y': _textY!.round(),
      'font_size': _textSize.round(),
      'color': [_textColor.red, _textColor.green, _textColor.blue],
      'stroke_width': _enableStroke ? _strokeWidth.round() : 0,
    };
    if (_enableStroke) {
      body['stroke_color'] = [_strokeColor.red, _strokeColor.green, _strokeColor.blue];
    }
    if (_enableShadow) {
      body['shadow_blur'] = _shadowBlur.round();
      body['shadow_color'] = [_shadowColor.red, _shadowColor.green, _shadowColor.blue];
    }
    if (_selectedFont != null) {
      body['font_path'] = _selectedFont!['path'];
    }
    _callEdit('/api/v1/editor/text', body);
    setState(() {
      _textX = _textY = null;
      _textCtrl.clear();
    });
  }

  // ── Brush: draw on canvas ──────────────────────
  void _onBrushStart(DragStartDetails d) {
    if (_toolMode != ToolMode.brush && _toolMode != ToolMode.eraser) return;
    final pos = _screenToImage(d.localPosition);
    if (pos == null) return;
    _isDrawing = true;
    _currentStroke = [pos];
  }

  void _onBrushUpdate(DragUpdateDetails d) {
    if (!_isDrawing) return;
    final pos = _screenToImage(d.localPosition);
    if (pos == null) return;
    _currentStroke.add(pos);
    setState(() {}); // redraw overlay
  }

  void _onBrushEnd(DragEndDetails d) async {
    if (!_isDrawing || _currentStroke.length < 1) return;
    _isDrawing = false;
    final pts = _currentStroke.map((o) => [o.dx.round(), o.dy.round()]).toList();
    _currentStroke = [];
    setState(() {});
    if (_toolMode == ToolMode.brush) {
      await _callEdit('/api/v1/editor/draw', {
        'points': pts,
        'color': [_brushColor.red, _brushColor.green, _brushColor.blue],
        'size': _brushSize.round(),
        'opacity': _brushOpacity,
      });
    } else {
      // Eraser: draw with black (bg color) or large white brush
      await _callEdit('/api/v1/editor/draw', {
        'points': pts,
        'color': [255, 255, 255], // white eraser
        'size': _eraserSize.round(),
        'opacity': 1.0,
      });
    }
  }

  // ── Shape: drag on canvas ──────────────────────
  void _onShapeStart(DragStartDetails d) {
    if (_toolMode != ToolMode.shape) return;
    final pos = _screenToImage(d.localPosition);
    if (pos == null) return;
    _shapeStart = pos;
    _shapeEnd = pos;
  }

  void _onShapeUpdate(DragUpdateDetails d) {
    if (_shapeStart == null) return;
    final pos = _screenToImage(d.localPosition);
    if (pos == null) return;
    setState(() => _shapeEnd = pos);
  }

  void _onShapeEnd(DragEndDetails d) async {
    if (_shapeStart == null || _shapeEnd == null) return;
    final x = _shapeStart!.dx.round();
    final y = _shapeStart!.dy.round();
    double w = _shapeEnd!.dx - _shapeStart!.dx;
    double h = _shapeEnd!.dy - _shapeStart!.dy;
    if (w.abs() < 5 && h.abs() < 5) {
      _shapeStart = _shapeEnd = null;
      setState(() {});
      return;
    }
    final body = <String, dynamic>{
      'type': _shapeType,
      'x': w >= 0 ? x : (x + w.round()),
      'y': h >= 0 ? y : (y + h.round()),
      'w': w.abs().round(),
      'h': h.abs().round(),
      'stroke_color': [_shapeStrokeColor.red, _shapeStrokeColor.green, _shapeStrokeColor.blue],
      'stroke_width': _shapeStrokeWidth.round(),
    };
    if (_shapeFill) {
      body['fill_color'] = [_shapeFillColor.red, _shapeFillColor.green, _shapeFillColor.blue];
    }
    _shapeStart = _shapeEnd = null;
    setState(() {});
    await _callEdit('/api/v1/editor/shape', body);
  }

  // ── Crop drag logic ────────────────────────────

  void _onCropPanStart(DragStartDetails d) {
    final pos = _screenToImage(d.localPosition);
    if (pos == null) return;
    _dragHandle = _hitTestHandle(pos);
    if (_dragHandle != null) {
      _dragStartX = pos.dx; _dragStartY = pos.dy;
      return;
    }
    if (pos.dx >= (_selX ?? 0) && pos.dx <= (_selX ?? 0) + (_selW ?? 0) &&
        pos.dy >= (_selY ?? 0) && pos.dy <= (_selY ?? 0) + (_selH ?? 0)) {
      _dragHandle = 'move';
      _dragStartX = pos.dx - (_selX ?? 0);
      _dragStartY = pos.dy - (_selY ?? 0);
      return;
    }
    _dragHandle = 'new';
    _dragStartX = pos.dx; _dragStartY = pos.dy;
    _selX = pos.dx; _selY = pos.dy; _selW = 0; _selH = 0;
  }

  void _onCropPanUpdate(DragUpdateDetails d) {
    final pos = _screenToImage(d.localPosition);
    if (pos == null) return;
    final imgW = (_info?['width'] as num?)?.toDouble() ?? 0.0;
    final imgH = (_info?['height'] as num?)?.toDouble() ?? 0.0;
    final cx = pos.dx.clamp(0.0, imgW);
    final cy = pos.dy.clamp(0.0, imgH);

    setState(() {
      if (_dragHandle == 'new' || _dragHandle == 'move') {
        if (_dragHandle == 'new') {
          _selW = (cx - (_selX ?? 0.0)).abs().clamp(10.0, imgW);
          _selH = (cy - (_selY ?? 0.0)).abs().clamp(10.0, imgH);
        } else {
          final dx = cx - (_dragStartX ?? 0.0);
          final dy = cy - (_dragStartY ?? 0.0);
          _selX = dx.clamp(0.0, imgW - (_selW ?? 0.0));
          _selY = dy.clamp(0.0, imgH - (_selH ?? 0.0));
        }
        return;
      }
      double l = (_selX ?? 0).toDouble(), r = l + (_selW ?? 0).toDouble();
      double t = (_selY ?? 0).toDouble(), b = t + (_selH ?? 0).toDouble();
      if (_dragHandle == 'tl' || _dragHandle == 'ml' || _dragHandle == 'bl') l = cx;
      if (_dragHandle == 'tr' || _dragHandle == 'mr' || _dragHandle == 'br') r = cx;
      if (_dragHandle == 'tl' || _dragHandle == 'tm' || _dragHandle == 'tr') t = cy;
      if (_dragHandle == 'bl' || _dragHandle == 'bm' || _dragHandle == 'br') b = cy;
      if (r - l < 10) return;
      if (b - t < 10) return;
      _selX = l.clamp(0.0, imgW); _selY = t.clamp(0.0, imgH);
      _selW = (r - l).clamp(10.0, imgW - _selX!);
      _selH = (b - t).clamp(10.0, imgH - _selY!);
    });
  }

  void _onCropPanEnd(DragEndDetails _) { _dragHandle = null; }

  /// Convert screen coordinates to image pixel coordinates
  Offset? _screenToImage(Offset screenPos) {
    if (_info == null) return null;
    final imgW = (_info!['width'] as num).toDouble();
    final imgH = (_info!['height'] as num).toDouble();
    final renderBox = _imgKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final size = renderBox.size;
    final scale = (size.width / imgW) < (size.height / imgH)
        ? size.width / imgW
        : size.height / imgH;
    final drawW = imgW * scale;
    final drawH = imgH * scale;
    final ox = (size.width - drawW) / 2;
    final oy = (size.height - drawH) / 2;
    final px = (screenPos.dx - ox) / scale;
    final py = (screenPos.dy - oy) / scale;
    if (px < 0 || py < 0 || px > imgW || py > imgH) return null;
    return Offset(px, py);
  }

  String? _hitTestHandle(Offset pos) {
    const hs = 12.0;
    if (_selX == null) return null;
    final l = _selX!, r = _selX! + _selW!;
    final t = _selY!, b = _selY! + _selH!;
    if ((pos - Offset(l, t)).distance < hs) return 'tl';
    if ((pos - Offset(r, t)).distance < hs) return 'tr';
    if ((pos - Offset(l, b)).distance < hs) return 'bl';
    if ((pos - Offset(r, b)).distance < hs) return 'br';
    if ((pos - Offset((l + r) / 2, t)).distance < hs) return 'tm';
    if ((pos - Offset((l + r) / 2, b)).distance < hs) return 'bm';
    if ((pos - Offset(l, (t + b) / 2)).distance < hs) return 'ml';
    if ((pos - Offset(r, (t + b) / 2)).distance < hs) return 'mr';
    return null;
  }

  Rect? _selectionLayoutRect() {
    if (_selX == null || _displaySize == null || _info == null) return null;
    final imgW = (_info!['width'] as num).toDouble();
    final imgH = (_info!['height'] as num).toDouble();
    final ds = _displaySize!;
    final scale = (ds.width / imgW) < (ds.height / imgH)
        ? ds.width / imgW : ds.height / imgH;
    final drawW = imgW * scale;
    final drawH = imgH * scale;
    final ox = (ds.width - drawW) / 2;
    final oy = (ds.height - drawH) / 2;
    return Rect.fromLTWH(
      ox + _selX! * scale, oy + _selY! * scale,
      _selW! * scale, _selH! * scale,
    );
  }

  Offset? _textLayoutPos() {
    if (_textX == null || _displaySize == null || _info == null) return null;
    final imgW = (_info!['width'] as num).toDouble();
    final imgH = (_info!['height'] as num).toDouble();
    final ds = _displaySize!;
    final scale = (ds.width / imgW) < (ds.height / imgH)
        ? ds.width / imgW : ds.height / imgH;
    final drawW = imgW * scale;
    final drawH = imgH * scale;
    final ox = (ds.width - drawW) / 2;
    final oy = (ds.height - drawH) / 2;
    return Offset(ox + _textX! * scale, oy + _textY! * scale);
  }

  Rect? _shapeLayoutRect() {
    if (_shapeStart == null || _shapeEnd == null || _displaySize == null || _info == null) return null;
    final imgW = (_info!['width'] as num).toDouble();
    final imgH = (_info!['height'] as num).toDouble();
    final ds = _displaySize!;
    final scale = (ds.width / imgW) < (ds.height / imgH)
        ? ds.width / imgW : ds.height / imgH;
    final drawW = imgW * scale;
    final drawH = imgH * scale;
    final ox = (ds.width - drawW) / 2;
    final oy = (ds.height - drawH) / 2;
    double x1 = ox + _shapeStart!.dx * scale;
    double y1 = oy + _shapeStart!.dy * scale;
    double x2 = ox + _shapeEnd!.dx * scale;
    double y2 = oy + _shapeEnd!.dy * scale;
    return Rect.fromLTRB(x1, y1, x2, y2);
  }

  // ── Quick actions ──────────────────────────────

  void _quickFilter(String f) => _callEdit('/api/v1/editor/filter', {'filter': f});

  // ══════════════ BUILD ═══════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        toolbarHeight: 38,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Image Studio',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            // Undo/Redo — prominent, with labels
            _undoBtn(),
            const SizedBox(width: 2),
            _redoBtn(),
          ],
        ),
        actions: [
          _topBtn('Open', Icons.folder_open, _openImage),
          _topBtn('Export', Icons.save_alt, _exportImage),
          if (_imageBytes != null) ...[
            _topBtn('Flip H', Icons.flip, () => _callEdit('/api/v1/editor/flip', {'direction': 'horizontal'})),
            _topBtn('Flip V', Icons.flip, () => _callEdit('/api/v1/editor/flip', {'direction': 'vertical'})),
          ],
        ],
      ),
      body: _imageBytes == null ? _buildEmptyState() : _buildEditorBody(),
    );
  }

  Widget _undoBtn() {
    return GestureDetector(
      onTap: _canUndo ? _undo : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _canUndo ? const Color(0xFF2A2A4E) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(4),
          border: _canUndo ? Border.all(color: const Color(0xFF6C63FF), width: 0.5) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.undo, size: 12, color: _canUndo ? Colors.white : Colors.grey.shade700),
          const SizedBox(width: 3),
          Text('Undo', style: TextStyle(fontSize: 10, color: _canUndo ? Colors.white : Colors.grey.shade700)),
        ]),
      ),
    );
  }

  Widget _redoBtn() {
    return GestureDetector(
      onTap: _canRedo ? _redo : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _canRedo ? const Color(0xFF2A2A4E) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(4),
          border: _canRedo ? Border.all(color: const Color(0xFF6C63FF), width: 0.5) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.redo, size: 12, color: _canRedo ? Colors.white : Colors.grey.shade700),
          const SizedBox(width: 3),
          Text('Redo', style: TextStyle(fontSize: 10, color: _canRedo ? Colors.white : Colors.grey.shade700)),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.image, size: 64, color: Color(0xFF3A3A5E)),
        const SizedBox(height: 12),
        Text('Click Open to load an image',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _buildEditorBody() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // ── LEFT TOOLBAR ──
              _buildLeftToolbar(),
              // ── CANVAS ──
              Expanded(child: _buildCanvas()),
              // ── RIGHT SIDEBAR ──
              _buildRightSidebar(),
            ],
          ),
        ),
        // ── STATUS BAR ──
        _buildStatusBar(),
      ],
    );
  }

  // ════════════ LEFT TOOLBAR ═══════════════════════

  Widget _buildLeftToolbar() {
    return Container(
      width: 52,
      color: const Color(0xFF1A1A2E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          _toolIcon(Icons.crop, 'Crop', ToolMode.crop, _enterCrop),
          _toolIcon(Icons.text_fields, 'Text', ToolMode.text, _enterText),
          _toolIcon(Icons.brush, 'Brush', ToolMode.brush, _enterBrush),
          _toolIcon(Icons.auto_fix_high, 'Eraser', ToolMode.eraser, _enterEraser),
          _toolIcon(Icons.category, 'Shape', ToolMode.shape, _enterShape),
          _divider(),
          _toolIcon(Icons.photo_size_select_large, 'Resize', ToolMode.resize, _enterResize),
          _toolIcon(Icons.rotate_right, 'Rotate', ToolMode.rotate, _enterRotate),
          _toolIcon(Icons.tune, 'Adjust', ToolMode.adjust, _enterAdjust),
          _divider(),
          _toolIcon(Icons.filter_b_and_w, 'Gray', null, () => _quickFilter('grayscale')),
          _toolIcon(Icons.color_lens, 'Sepia', null, () => _quickFilter('sepia')),
          _toolIcon(Icons.blur_on, 'Blur', null, () => _quickFilter('blur')),
          _toolIcon(Icons.invert_colors, 'Invert', null, () => _quickFilter('invert')),
          _divider(),
          _toolIcon(Icons.noise_control_off, 'Denoise', null,
              () => _callEdit('/api/v1/editor/denoise', {'strength': 3})),
          if (_caps['remove_bg'] == true)
            _toolIcon(Icons.image_not_supported, 'Rm BG', null,
                () => _callEdit('/api/v1/editor/remove-bg', {})),
        ]),
      ),
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: 32, height: 1, color: const Color(0xFF3A3A5E),
    );
  }

  Widget _toolIcon(IconData icon, String label, ToolMode? mode, VoidCallback onTap) {
    final active = mode != null && _toolMode == mode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 38,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF3A3A7E) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: active ? Border.all(color: const Color(0xFF6C63FF), width: 1) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: active ? const Color(0xFF6C63FF) : Colors.white60),
            Text(label, style: TextStyle(fontSize: 7, color: active ? Colors.white : Colors.white38)),
          ]),
        ),
      ),
    );
  }

  // ════════════ CANVAS ═══════════════════════════

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        _displaySize = constraints.biggest;
        return Stack(
          children: [
            // Image with zoom + pan
            Positioned.fill(
              child: GestureDetector(
                onScaleStart: (d) {},
                onScaleUpdate: (d) {
                  setState(() {
                    _zoomLevel = (_zoomLevel * d.scale).clamp(0.1, 5.0);
                    _panOffset += d.focalPointDelta;
                  });
                },
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(_panOffset.dx, _panOffset.dy)
                    ..scale(_zoomLevel),
                  alignment: Alignment.center,
                  child: Center(
                    child: FittedBox(
                      key: _imgKey,
                      fit: BoxFit.contain,
                      child: GestureDetector(
                        onPanStart: (d) {
                          if (_toolMode == ToolMode.crop) _onCropPanStart(d);
                          else if (_toolMode == ToolMode.brush || _toolMode == ToolMode.eraser) _onBrushStart(d);
                          else if (_toolMode == ToolMode.shape) _onShapeStart(d);
                        },
                        onPanUpdate: (d) {
                          if (_toolMode == ToolMode.crop) _onCropPanUpdate(d);
                          else if (_toolMode == ToolMode.brush || _toolMode == ToolMode.eraser) _onBrushUpdate(d);
                          else if (_toolMode == ToolMode.shape) _onShapeUpdate(d);
                        },
                        onPanEnd: (d) {
                          if (_toolMode == ToolMode.crop) _onCropPanEnd(d);
                          else if (_toolMode == ToolMode.brush || _toolMode == ToolMode.eraser) _onBrushEnd(d);
                          else if (_toolMode == ToolMode.shape) _onShapeEnd(d);
                        },
                        onTapDown: _toolMode == ToolMode.text
                            ? (d) => _onTextCanvasTap(d.localPosition)
                            : null,
                        child: Image.memory(_imageBytes!),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Crop overlay ──
            if (_toolMode == ToolMode.crop)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CropOverlayPainter(
                      selection: _selectionLayoutRect(),
                      imageSize: _displaySize ?? Size.zero,
                    ),
                  ),
                ),
              ),

            // ── Text crosshair ──
            if (_toolMode == ToolMode.text && _textX != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TextCrosshairPainter(position: _textLayoutPos()),
                  ),
                ),
              ),

            // ── Brush stroke preview ──
            if ((_toolMode == ToolMode.brush || _toolMode == ToolMode.eraser) && _currentStroke.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BrushPreviewPainter(
                      stroke: _currentStroke,
                      color: _toolMode == ToolMode.brush ? _brushColor : Colors.white,
                      size: _toolMode == ToolMode.brush ? _brushSize : _eraserSize,
                      imageInfo: _info,
                      displaySize: _displaySize ?? Size.zero,
                    ),
                  ),
                ),
              ),

            // ── Shape preview ──
            if (_toolMode == ToolMode.shape && _shapeStart != null && _shapeEnd != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShapePreviewPainter(
                      rect: _shapeLayoutRect(),
                      shapeType: _shapeType,
                      fillColor: _shapeFill ? _shapeFillColor : null,
                      strokeColor: _shapeStrokeColor,
                      strokeWidth: _shapeStrokeWidth,
                    ),
                  ),
                ),
              ),

            // ── Keyboard listener ──
            if (_toolMode == ToolMode.crop)
              Positioned.fill(
                child: KeyboardListener(
                  focusNode: FocusNode()..requestFocus(),
                  autofocus: true,
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.enter) {
                        _applyCrop();
                      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                        _exitToolMode();
                      }
                    }
                  },
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        );
      },
    );
  }

  // ════════════ RIGHT SIDEBAR ═══════════════════════

  Widget _buildRightSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFF16162A),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _sidebarContent(),
        ),
      ),
    );
  }

  List<Widget> _sidebarContent() {
    switch (_toolMode) {
      case ToolMode.none: return _sidebarInfo();
      case ToolMode.crop: return _sidebarCrop();
      case ToolMode.resize: return _sidebarResize();
      case ToolMode.rotate: return _sidebarRotate();
      case ToolMode.adjust: return _sidebarAdjust();
      case ToolMode.text: return _sidebarText();
      case ToolMode.brush: return _sidebarBrush();
      case ToolMode.eraser: return _sidebarEraser();
      case ToolMode.shape: return _sidebarShape();
    }
  }

  List<Widget> _sidebarInfo() {
    return [
      _sidebarTitle('Image Info'),
      _infoRow('Dimensions',
          '${_info?['width'] ?? '?'} × ${_info?['height'] ?? '?'}'),
      _infoRow('Format', '${_info?['format'] ?? ''}'),
      _infoRow('Mode', '${_info?['mode'] ?? ''}'),
      const SizedBox(height: 16),
      _sidebarTitle('Zoom'),
      _zoomControls(),
      if (_canUndo || _canRedo) ...[
        const SizedBox(height: 16),
        _sidebarTitle('History'),
        _infoRow('Steps', '${_canUndo ? 'Undo' : ''}${_canUndo && _canRedo ? ' / ' : ''}${_canRedo ? 'Redo' : ''}'),
      ],
    ];
  }

  List<Widget> _sidebarCrop() {
    return [
      _sidebarTitle('Crop'),
      const SizedBox(height: 8),
      _sideBtn('Apply Crop', _applyCrop),
      const SizedBox(height: 4),
      _sideBtn('Cancel', () { _exitToolMode(); setState(() {}); }),
      const SizedBox(height: 12),
      if (_selW != null && _selH != null)
        _infoRow('Selection', '${_selW!.round()} × ${_selH!.round()}'),
    ];
  }

  List<Widget> _sidebarResize() {
    final wC = TextEditingController(text: '${_info?['width'] ?? 800}');
    final hC = TextEditingController(text: '${_info?['height'] ?? 600}');
    return [
      _sidebarTitle('Resize'),
      const SizedBox(height: 8),
      _sideField('Width', wC),
      const SizedBox(height: 4),
      _sideField('Height', hC),
      const SizedBox(height: 8),
      _sideBtn('Apply', () {
        _callEdit('/api/v1/editor/resize', {
          'width': int.tryParse(wC.text) ?? 800,
          'height': int.tryParse(hC.text) ?? 600,
        });
        _exitToolMode();
      }),
      const SizedBox(height: 4),
      _sideBtn('Cancel', () { _exitToolMode(); setState(() {}); }),
    ];
  }

  List<Widget> _sidebarRotate() {
    return [
      _sidebarTitle('Rotate'),
      const SizedBox(height: 8),
      _sideBtn('↺ 90°', () => _callEdit('/api/v1/editor/rotate', {'angle': -90})),
      const SizedBox(height: 4),
      _sideBtn('↻ 90°', () => _callEdit('/api/v1/editor/rotate', {'angle': 90})),
      const SizedBox(height: 4),
      _sideBtn('↺ 180°', () => _callEdit('/api/v1/editor/rotate', {'angle': 180})),
      const SizedBox(height: 8),
      _sideBtn('Done', () { _exitToolMode(); setState(() {}); }),
    ];
  }

  List<Widget> _sidebarAdjust() {
    return [
      _sidebarTitle('Adjust'),
      const SizedBox(height: 8),
      _sideSlider('Brightness', _brightness, 0.0, 2.0, (v) {
        _brightness = v;
        _callEdit('/api/v1/editor/adjust',
            {'brightness': v, 'contrast': _contrast, 'saturation': _saturation});
      }),
      _sideSlider('Contrast', _contrast, 0.0, 2.0, (v) {
        _contrast = v;
        _callEdit('/api/v1/editor/adjust',
            {'brightness': _brightness, 'contrast': v, 'saturation': _saturation});
      }),
      _sideSlider('Saturation', _saturation, 0.0, 2.0, (v) {
        _saturation = v;
        _callEdit('/api/v1/editor/adjust',
            {'brightness': _brightness, 'contrast': _contrast, 'saturation': v});
      }),
      const SizedBox(height: 8),
      _sideBtn('Done', () { _exitToolMode(); setState(() {}); }),
    ];
  }

  List<Widget> _sidebarText() {
    return [
      _sidebarTitle('Text'),
      const SizedBox(height: 4),
      TextField(
        controller: _textCtrl,
        maxLines: 3, minLines: 1,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: InputDecoration(
          hintText: _textX == null ? 'Click image first' : 'Type text...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
          filled: true, fillColor: const Color(0xFF2A2A4E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      if (_textX != null) ...[
        const SizedBox(height: 4),
        _infoRow('Position', 'x:${_textX!.round()} y:${_textY!.round()}'),
      ],
      const SizedBox(height: 6),
      _sideLabel('Font Size'),
      _sideSliderNoVal(_textSize, 8, 120, (v) => setState(() => _textSize = v)),
      if (_fonts.isNotEmpty) ...[
        const SizedBox(height: 4),
        _sideLabel('Font'),
        DropdownButton<String>(
          value: _selectedFont?['name'] as String?,
          dropdownColor: const Color(0xFF16213E),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 10),
          underline: const SizedBox(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _selectedFont = _fonts.firstWhere(
                (f) => f['name'] == v, orElse: () => _fonts.first);
            });
          },
          items: _fonts.map((f) => DropdownMenuItem(
            value: f['name'] as String,
            child: Text(f['name'] as String, style: const TextStyle(fontSize: 10, color: Colors.white)),
          )).toList(),
        ),
      ],
      const SizedBox(height: 4),
      _sideLabel('Color'),
      _colorRow(_colorSwatches, _textColor, (c) => setState(() => _textColor = c)),
      const SizedBox(height: 4),
      _sideCheckbox('Stroke', _enableStroke, (v) => setState(() => _enableStroke = v ?? false)),
      if (_enableStroke) ...[
        _sideSliderNoVal(_strokeWidth, 1, 10, (v) => setState(() => _strokeWidth = v)),
        _colorRow(_colorSwatches.sublist(0, 4), _strokeColor, (c) => setState(() => _strokeColor = c)),
      ],
      _sideCheckbox('Shadow', _enableShadow, (v) => setState(() => _enableShadow = v ?? false)),
      if (_enableShadow) ...[
        _sideSliderNoVal(_shadowBlur, 1, 20, (v) => setState(() => _shadowBlur = v)),
        _colorRow(_colorSwatches.sublist(0, 4), _shadowColor, (c) => setState(() => _shadowColor = c)),
      ],
      const SizedBox(height: 8),
      _sideBtn('Apply Text', _applyText),
      const SizedBox(height: 4),
      _sideBtn('Cancel', () { _exitToolMode(); setState(() {}); }),
    ];
  }

  List<Widget> _sidebarBrush() {
    return [
      _sidebarTitle('Brush'),
      const SizedBox(height: 4),
      _sideLabel('Size: ${_brushSize.round()}'),
      _sideSliderNoVal(_brushSize, 1, 50, (v) => setState(() => _brushSize = v)),
      const SizedBox(height: 4),
      _sideLabel('Opacity: ${(_brushOpacity * 100).round()}%'),
      _sideSliderNoVal(_brushOpacity, 0.1, 1.0, (v) => setState(() => _brushOpacity = v)),
      const SizedBox(height: 4),
      _sideLabel('Color'),
      _colorRow(_colorSwatches, _brushColor, (c) => setState(() => _brushColor = c)),
      const SizedBox(height: 8),
      _infoRow('Tip', 'Drag on canvas to draw'),
      const SizedBox(height: 4),
      _sideBtn('Done', () { _exitToolMode(); setState(() {}); }),
    ];
  }

  List<Widget> _sidebarEraser() {
    return [
      _sidebarTitle('Eraser'),
      const SizedBox(height: 4),
      _sideLabel('Size: ${_eraserSize.round()}'),
      _sideSliderNoVal(_eraserSize, 5, 80, (v) => setState(() => _eraserSize = v)),
      const SizedBox(height: 8),
      _infoRow('Tip', 'Drag on canvas to erase'),
      const SizedBox(height: 4),
      _sideBtn('Done', () { _exitToolMode(); setState(() {}); }),
    ];
  }

  List<Widget> _sidebarShape() {
    return [
      _sidebarTitle('Shape'),
      const SizedBox(height: 4),
      _sideLabel('Type'),
      DropdownButton<String>(
        value: _shapeType,
        dropdownColor: const Color(0xFF16213E),
        isExpanded: true,
        style: const TextStyle(color: Colors.white, fontSize: 10),
        underline: const SizedBox(),
        onChanged: (v) => setState(() => _shapeType = v ?? 'rect'),
        items: ['rect', 'circle', 'line', 'arrow'].map((t) => DropdownMenuItem(
          value: t,
          child: Text(t[0].toUpperCase() + t.substring(1),
              style: const TextStyle(fontSize: 10, color: Colors.white)),
        )).toList(),
      ),
      const SizedBox(height: 4),
      _sideLabel('Stroke Width: ${_shapeStrokeWidth.round()}'),
      _sideSliderNoVal(_shapeStrokeWidth, 1, 10, (v) => setState(() => _shapeStrokeWidth = v)),
      const SizedBox(height: 4),
      _sideLabel('Stroke Color'),
      _colorRow(_colorSwatches.sublist(0, 4), _shapeStrokeColor, (c) => setState(() => _shapeStrokeColor = c)),
      const SizedBox(height: 4),
      _sideCheckbox('Fill', _shapeFill, (v) => setState(() => _shapeFill = v ?? false)),
      if (_shapeFill) ...[
        _sideLabel('Fill Color'),
        _colorRow(_colorSwatches, _shapeFillColor, (c) => setState(() => _shapeFillColor = c)),
      ],
      const SizedBox(height: 8),
      _infoRow('Tip', 'Drag on canvas to draw'),
      const SizedBox(height: 4),
      _sideBtn('Done', () { _exitToolMode(); setState(() {}); }),
    ];
  }

  // ════════════ STATUS BAR ═════════════════════════

  Widget _buildStatusBar() {
    final zoomPct = '${(_zoomLevel * 100).round()}%';
    final imgInfo = _info != null
        ? '${_info!['width']}×${_info!['height']} · ${_info!['format'] ?? ''}'
        : '';
    final historyLabel = _canUndo || _canRedo ? 'Undo/Redo avail' : '';
    String hint = '';
    if (_toolMode == ToolMode.text && _textX == null) hint = 'Click image to place text';
    else if (_toolMode == ToolMode.brush) hint = 'Drag to draw';
    else if (_toolMode == ToolMode.eraser) hint = 'Drag to erase';
    else if (_toolMode == ToolMode.shape) hint = 'Drag for shape';

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF12121E),
      child: Row(children: [
        // Zoom controls
        Text(zoomPct, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        const SizedBox(width: 4),
        _zoomBtn(Icons.add, () => setState(() => _zoomLevel = (_zoomLevel * 1.25).clamp(0.1, 5.0))),
        const SizedBox(width: 2),
        _zoomBtn(Icons.remove, () => setState(() => _zoomLevel = (_zoomLevel / 1.25).clamp(0.1, 5.0))),
        const SizedBox(width: 2),
        _zoomBtn(Icons.fit_screen, () => setState(() { _zoomLevel = 1.0; _panOffset = Offset.zero; })),
        const SizedBox(width: 12),
        // Image info
        Text(imgInfo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const Spacer(),
        // History hint
        if (historyLabel.isNotEmpty)
          Text(historyLabel, style: const TextStyle(fontSize: 10, color: const Color(0xFF6C63FF))),
        if (hint.isNotEmpty) ...[
          if (historyLabel.isNotEmpty) const SizedBox(width: 8),
          Text(hint, style: const TextStyle(fontSize: 10, color: Colors.orange)),
        ],
        if (_loading) ...[
          const SizedBox(width: 8),
          const SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
        ],
      ]),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A4E),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Icon(icon, size: 12, color: Colors.white70),
      ),
    );
  }

  // ════════════ SIDEBAR WIDGET HELPERS ═══════════

  Widget _sidebarTitle(String t) {
    return Text(t, style: const TextStyle(
        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600));
  }

  Widget _infoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ]),
    );
  }

  Widget _sideLabel(String t) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }

  Widget _sideBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white))),
      ),
    );
  }

  Widget _sideField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
        filled: true, fillColor: const Color(0xFF2A2A4E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _sideSlider(String label, double val, double min, double max,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        SizedBox(width: 70, child: Text('$label: ${val.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 10, color: Colors.white70))),
        Expanded(child: Slider(
          value: val, min: min, max: max, divisions: 40,
          activeColor: const Color(0xFF6C63FF),
          onChanged: onChanged,
        )),
      ]),
    );
  }

  Widget _sideSliderNoVal(double val, double min, double max,
      ValueChanged<double> onChanged) {
    return Slider(
      value: val, min: min, max: max,
      divisions: max == 1.0 ? 9 : null,
      activeColor: const Color(0xFF6C63FF),
      onChanged: onChanged,
    );
  }

  Widget _colorRow(List<Color> colors, Color selected, ValueChanged<Color> onTap) {
    return Wrap(
      spacing: 3, runSpacing: 3,
      children: colors.map((c) => GestureDetector(
        onTap: () => onTap(c),
        child: Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: c == selected ? const Color(0xFF6C63FF) : Colors.grey.shade600,
              width: c == selected ? 2 : 1,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _sideCheckbox(String label, bool val, ValueChanged<bool?> onChanged) {
    return Row(children: [
      SizedBox(
        width: 16, height: 16,
        child: Checkbox(
          value: val, onChanged: onChanged,
          activeColor: const Color(0xFF6C63FF),
          side: const BorderSide(color: Colors.grey, width: 1),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _zoomControls() {
    return Row(children: [
      _zoomBtn(Icons.remove, () => setState(() => _zoomLevel = (_zoomLevel / 1.25).clamp(0.1, 5.0))),
      const SizedBox(width: 4),
      Text('${(_zoomLevel * 100).round()}%',
          style: const TextStyle(fontSize: 11, color: Colors.white70)),
      const SizedBox(width: 4),
      _zoomBtn(Icons.add, () => setState(() => _zoomLevel = (_zoomLevel * 1.25).clamp(0.1, 5.0))),
      const SizedBox(width: 4),
      _zoomBtn(Icons.fit_screen, () => setState(() { _zoomLevel = 1.0; _panOffset = Offset.zero; })),
    ]);
  }

  // ── Top bar button ─────────────────────────────

  Widget _topBtn(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A4E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
// Crop overlay painter
// ═════════════════════════════════════════════════════

class _CropOverlayPainter extends CustomPainter {
  final Rect? selection;
  final Size imageSize;
  _CropOverlayPainter({required this.selection, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = const Color(0x88000000);
    if (selection != null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, imageSize.width, selection!.top), overlay);
      canvas.drawRect(Rect.fromLTWH(0, selection!.bottom, imageSize.width, imageSize.height - selection!.bottom), overlay);
      canvas.drawRect(Rect.fromLTWH(0, selection!.top, selection!.left, selection!.height), overlay);
      canvas.drawRect(Rect.fromLTWH(selection!.right, selection!.top, imageSize.width - selection!.right, selection!.height), overlay);
      final border = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(selection!, border);
      const hs = 6.0;
      final handle = Paint()..color = const Color(0xFF6C63FF);
      for (final corner in [
        selection!.topLeft, selection!.topRight,
        selection!.bottomLeft, selection!.bottomRight,
      ]) {
        canvas.drawRect(Rect.fromCenter(center: corner, width: hs * 2, height: hs * 2), handle);
      }
      final mid = selection!.center;
      for (final pt in [
        Offset(mid.dx, selection!.top), Offset(mid.dx, selection!.bottom),
        Offset(selection!.left, mid.dy), Offset(selection!.right, mid.dy),
      ]) {
        canvas.drawRect(Rect.fromCenter(center: pt, width: hs * 1.4, height: hs * 1.4), handle);
      }
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, imageSize.width, imageSize.height), overlay);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.selection != selection || old.imageSize != imageSize;
}

// ═════════════════════════════════════════════════════
// Text crosshair painter
// ═════════════════════════════════════════════════════

class _TextCrosshairPainter extends CustomPainter {
  final Offset? position;
  _TextCrosshairPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    if (position == null) return;
    final cross = Paint()..color = const Color(0xFF6C63FF)..strokeWidth = 1.5;
    const len = 12.0;
    final p = position!;
    canvas.drawLine(Offset(p.dx - len, p.dy), Offset(p.dx + len, p.dy), cross);
    canvas.drawLine(Offset(p.dx, p.dy - len), Offset(p.dx, p.dy + len), cross);
    canvas.drawCircle(p, 3, Paint()..color = const Color(0x806C63FF));
  }

  @override
  bool shouldRepaint(covariant _TextCrosshairPainter old) =>
      old.position != position;
}

// ═════════════════════════════════════════════════════
// Brush stroke preview painter
// ═════════════════════════════════════════════════════

class _BrushPreviewPainter extends CustomPainter {
  final List<Offset> stroke;
  final Color color;
  final double size;
  final Map<String, dynamic>? imageInfo;
  final Size displaySize;

  _BrushPreviewPainter({
    required this.stroke, required this.color, required this.size,
    required this.imageInfo, required this.displaySize,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (stroke.length < 1) return;
    final imgW = (imageInfo?['width'] as num?)?.toDouble() ?? 1;
    final imgH = (imageInfo?['height'] as num?)?.toDouble() ?? 1;
    final scale = (displaySize.width / imgW) < (displaySize.height / imgH)
        ? displaySize.width / imgW : displaySize.height / imgH;
    final ox = (displaySize.width - imgW * scale) / 2;
    final oy = (displaySize.height - imgH * scale) / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < stroke.length; i++) {
      final px = ox + stroke[i].dx * scale;
      final py = oy + stroke[i].dy * scale;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BrushPreviewPainter old) =>
      old.stroke != stroke || old.color != color || old.size != size;
}

// ═════════════════════════════════════════════════════
// Shape preview painter
// ═════════════════════════════════════════════════════

class _ShapePreviewPainter extends CustomPainter {
  final Rect? rect;
  final String shapeType;
  final Color? fillColor;
  final Color strokeColor;
  final double strokeWidth;

  _ShapePreviewPainter({
    required this.rect, required this.shapeType,
    required this.fillColor, required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rect == null) return;
    final stroke = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth * 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = fillColor ?? const Color(0x00000000)
      ..style = PaintingStyle.fill;

    switch (shapeType) {
      case 'rect':
        if (fillColor != null) canvas.drawRect(rect!, fill);
        canvas.drawRect(rect!, stroke);
        break;
      case 'circle':
        if (fillColor != null) canvas.drawOval(rect!, fill);
        canvas.drawOval(rect!, stroke);
        break;
      case 'line':
      case 'arrow':
        final start = Offset(rect!.left, rect!.top);
        final end = Offset(rect!.right, rect!.bottom);
        final line = Paint()
          ..color = strokeColor
          ..strokeWidth = strokeWidth * 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(start, end, line);
        // Arrowhead
        if (shapeType == 'arrow') {
          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          final aLen = strokeWidth * 6;
          final ax1 = Offset(
            end.dx - aLen * math.cos(angle - 0.4),
            end.dy - aLen * math.sin(angle - 0.4),
          );
          final ax2 = Offset(
            end.dx - aLen * math.cos(angle + 0.4),
            end.dy - aLen * math.sin(angle + 0.4),
          );
          final arrow = Paint()..color = strokeColor..style = PaintingStyle.fill;
          final path = Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(ax1.dx, ax1.dy)
            ..lineTo(ax2.dx, ax2.dy)
            ..close();
          canvas.drawPath(path, arrow);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePreviewPainter old) =>
      old.rect != rect || old.shapeType != shapeType;
}
