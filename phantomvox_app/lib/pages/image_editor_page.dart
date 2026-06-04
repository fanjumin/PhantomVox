import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

/// Tool interaction modes
enum ToolMode { none, crop, adjust, rotate, text }

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

  // ── Tool mode & interactive state ──────────────────
  ToolMode _toolMode = ToolMode.none;
  // Crop selection (in image pixel coords, normalized to layout)
  double? _selX, _selY, _selW, _selH;
  double? _dragStartX, _dragStartY;
  String? _dragHandle; // corner/edge being dragged
  // Image display area info (layout coords)
  final GlobalKey _imgKey = GlobalKey();
  Size? _displaySize; // actual rendered size on screen
  final FocusNode _focusNode = FocusNode();

  // Adjust sliders
  double _brightness = 1.0, _contrast = 1.0, _saturation = 1.0;

  Map<String, dynamic> _caps = {};

  // ── Text tool state ──────────────────────────────
  double? _textX, _textY;           // click position (image coords)
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

  // ── Undo/Redo state ─────────────────────────────
  bool _canUndo = false;
  bool _canRedo = false;

  // Color swatches for text/stroke/shadow
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
    _focusNode.dispose();
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
    _toolMode = ToolMode.none;
    _selX = _selY = _selW = _selH = null;
    _dragHandle = null;
    _textX = _textY = null;
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

  // ── Text: click on canvas ───────────────────────
  void _onTextCanvasTap(DragStartDetails d) {
    if (_toolMode != ToolMode.text) return;
    final pos = _screenToImage(d.localPosition);
    if (pos == null) return;
    setState(() {
      _textX = pos.dx;
      _textY = pos.dy;
      _textCtrl.clear();
      _textSize = 32;
      _textColor = Colors.white;
      _enableStroke = false;
      _enableShadow = false;
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
    // Stay in text mode so user can add more text
    setState(() {
      _textX = _textY = null;
      _textCtrl.clear();
    });
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

  // ── Layout image coords for overlay drawing ─────

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

  /// Convert text click position to layout position (for crosshair indicator)
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

  // ── Quick actions ──────────────────────────────

  void _quickFilter(String f) => _callEdit('/api/v1/editor/filter', {'filter': f});

  // ══════════════ BUILD ═══════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Image Studio',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          // Undo / Redo
          if (_imageBytes != null) ...{
            _iconBtn(Icons.undo, 'Undo', _canUndo ? _undo : null),
            _iconBtn(Icons.redo, 'Redo', _canRedo ? _redo : null),
          },
          _btn('Open', Icons.folder_open, _openImage),
          _btn('Export', Icons.save_alt, _exportImage),
          if (_imageBytes != null) ...[
            _btn('Flip H', Icons.flip, () => _callEdit('/api/v1/editor/flip', {'direction': 'horizontal'})),
            _btn('Flip V', Icons.flip, () => _callEdit('/api/v1/editor/flip', {'direction': 'vertical'})),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          _buildStatusBar(),
          Expanded(child: _buildCanvas()),
          if (_toolMode != ToolMode.none) _buildActionPanel(),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: onTap != null ? const Color(0xFF2A2A4E) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(icon, size: 14,
              color: onTap != null ? Colors.white70 : Colors.grey.shade700),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: const Color(0xFF1A1A2E),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _toolBtn('Crop', Icons.crop, _enterCrop, active: _toolMode == ToolMode.crop),
          _toolBtn('Resize', Icons.photo_size_select_large, _resizeDialog),
          _toolBtn('Rotate', Icons.rotate_right, _enterRotate, active: _toolMode == ToolMode.rotate),
          _toolBtn('Adjust', Icons.tune, _enterAdjust, active: _toolMode == ToolMode.adjust),
          _toolBtn('Text', Icons.text_fields, _enterText, active: _toolMode == ToolMode.text),
          const SizedBox(width: 4),
          Container(width: 1, height: 20, color: const Color(0xFF3A3A5E)),
          const SizedBox(width: 4),
          _toolBtn('Gray', Icons.filter_b_and_w, () => _quickFilter('grayscale')),
          _toolBtn('Sepia', Icons.color_lens, () => _quickFilter('sepia')),
          _toolBtn('Blur', Icons.blur_on, () => _quickFilter('blur')),
          _toolBtn('Invert', Icons.invert_colors, () => _quickFilter('invert')),
          const SizedBox(width: 4),
          Container(width: 1, height: 20, color: const Color(0xFF3A3A5E)),
          const SizedBox(width: 4),
          _toolBtn('Denoise', Icons.noise_control_off, () => _callEdit('/api/v1/editor/denoise', {'strength': 3})),
          if (_caps['remove_bg'] == true)
            _toolBtn('Rm BG', Icons.image_not_supported, () => _callEdit('/api/v1/editor/remove-bg', {})),
        ]),
      ),
    );
  }

  Widget _buildStatusBar() {
    String hint = '';
    if (_toolMode == ToolMode.crop) {
      hint = '  ·  Drag to select region, Enter to apply';
    } else if (_toolMode == ToolMode.text) {
      if (_textX == null) {
        hint = '  ·  Click on image to place text';
      } else {
        hint = '  ·  Type text below, adjust properties, then Apply';
      }
    }
    String undoLabel = '';
    if (_canUndo) undoLabel = '  [Undo avail]';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: const Color(0xFF12121E),
      child: Row(children: [
        Text(_status, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (_loading) ...{
          const SizedBox(width: 8),
          const SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
        },
        Text(undoLabel, style: const TextStyle(fontSize: 10, color: Color(0xFF6C63FF))),
        if (hint.isNotEmpty)
          Text(hint, style: const TextStyle(fontSize: 10, color: Colors.orange)),
      ]),
    );
  }

  Widget _buildCanvas() {
    if (_imageBytes == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.image, size: 64, color: Color(0xFF3A3A5E)),
          const SizedBox(height: 12),
          Text('Click Open to load an image',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        _displaySize = constraints.biggest;
        return Stack(
          children: [
            // Image
            Positioned.fill(
              child: FittedBox(
                key: _imgKey,
                fit: BoxFit.contain,
                child: Image.memory(_imageBytes!),
              ),
            ),

            // ── Crop overlay ──
            if (_toolMode == ToolMode.crop)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: _onCropPanStart,
                  onPanUpdate: _onCropPanUpdate,
                  onPanEnd: _onCropPanEnd,
                  child: CustomPaint(
                    painter: _CropOverlayPainter(
                      selection: _selectionLayoutRect(),
                      imageSize: _displaySize ?? Size.zero,
                    ),
                  ),
                ),
              ),

            // ── Text crosshair indicator ──
            if (_toolMode == ToolMode.text && _textX != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TextCrosshairPainter(
                      position: _textLayoutPos(),
                    ),
                  ),
                ),
              ),

            // ── Text click handler ──
            if (_toolMode == ToolMode.text)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _onTextCanvasTap,
                  child: const SizedBox.expand(),
                ),
              ),

            // ── Keyboard listener (crop Enter/Esc) ──
            if (_toolMode == ToolMode.crop)
              Positioned.fill(
                child: KeyboardListener(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.enter) {
                        _applyCrop();
                      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                        _exitToolMode();
                        if (mounted) setState(() {});
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

  Widget _buildActionPanel() {
    switch (_toolMode) {
      case ToolMode.crop:
        return Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF1A1A2E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actBtn('Cancel', () { _exitToolMode(); setState(() {}); }),
              const SizedBox(width: 12),
              _actBtn('Apply Crop', _applyCrop),
            ],
          ),
        );
      case ToolMode.adjust:
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: const Color(0xFF1A1A2E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _slider('Brightness', _brightness, 0.0, 2.0, (v) {
                _brightness = v;
                _callEdit('/api/v1/editor/adjust',
                    {'brightness': v, 'contrast': _contrast, 'saturation': _saturation});
              }),
              _slider('Contrast', _contrast, 0.0, 2.0, (v) {
                _contrast = v;
                _callEdit('/api/v1/editor/adjust',
                    {'brightness': _brightness, 'contrast': v, 'saturation': _saturation});
              }),
              _slider('Saturation', _saturation, 0.0, 2.0, (v) {
                _saturation = v;
                _callEdit('/api/v1/editor/adjust',
                    {'brightness': _brightness, 'contrast': _contrast, 'saturation': v});
              }),
              const SizedBox(height: 4),
              _actBtn('Done', () { _exitToolMode(); setState(() {}); }),
            ],
          ),
        );
      case ToolMode.rotate:
        return Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF1A1A2E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actBtn('↺ 90°', () => _callEdit('/api/v1/editor/rotate', {'angle': -90})),
              const SizedBox(width: 8),
              _actBtn('↻ 90°', () => _callEdit('/api/v1/editor/rotate', {'angle': 90})),
              const SizedBox(width: 8),
              _actBtn('↺ 180°', () => _callEdit('/api/v1/editor/rotate', {'angle': 180})),
              const SizedBox(width: 12),
              _actBtn('Done', () { _exitToolMode(); setState(() {}); }),
            ],
          ),
        );
      case ToolMode.text:
        return _buildTextPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Text property panel ──────────────────────────

  Widget _buildTextPanel() {
    if (_textX == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      color: const Color(0xFF1A1A2E),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text input
            TextField(
              controller: _textCtrl,
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Type your text here...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF2A2A4E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 6),

            // Font size
            Row(children: [
              const SizedBox(width: 60, child: Text('Font Size', style: TextStyle(fontSize: 10, color: Colors.grey))),
              Expanded(child: Slider(
                value: _textSize, min: 8, max: 120, divisions: 112,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (v) => setState(() => _textSize = v),
                label: _textSize.round().toString(),
              )),
              SizedBox(width: 30, child: Text('${_textSize.round()}', style: const TextStyle(fontSize: 10, color: Colors.white70))),
            ]),

            // Font selector
            if (_fonts.isNotEmpty) ...{
              Row(children: [
                const SizedBox(width: 60, child: Text('Font', style: TextStyle(fontSize: 10, color: Colors.grey))),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedFont?['name'] as String?,
                    dropdownColor: const Color(0xFF16213E),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    underline: const SizedBox(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedFont = _fonts.firstWhere(
                          (f) => f['name'] == v,
                          orElse: () => _fonts.first,
                        );
                      });
                    },
                    items: _fonts.map((f) => DropdownMenuItem(
                      value: f['name'] as String,
                      child: Text(f['name'] as String, style: const TextStyle(fontSize: 11, color: Colors.white)),
                    )).toList(),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
            },

            // Color swatches
            Row(children: [
              const SizedBox(width: 60, child: Text('Color', style: TextStyle(fontSize: 10, color: Colors.grey))),
              ..._colorSwatches.map((c) => GestureDetector(
                onTap: () => setState(() => _textColor = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: c == _textColor ? const Color(0xFF6C63FF) : Colors.grey.shade600,
                      width: c == _textColor ? 2 : 1,
                    ),
                  ),
                ),
              )),
            ]),
            const SizedBox(height: 6),

            // Stroke toggle
            Row(children: [
              SizedBox(
                width: 18, height: 18,
                child: Checkbox(
                  value: _enableStroke,
                  onChanged: (v) => setState(() => _enableStroke = v ?? false),
                  activeColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Stroke', style: TextStyle(fontSize: 10, color: Colors.grey)),
              if (_enableStroke) ...{
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Slider(
                    value: _strokeWidth, min: 1, max: 10, divisions: 9,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                ),
                SizedBox(width: 20, child: Text('${_strokeWidth.round()}', style: const TextStyle(fontSize: 10, color: Colors.white70))),
                const SizedBox(width: 4),
                ..._colorSwatches.take(4).map((c) => GestureDetector(
                  onTap: () => setState(() => _strokeColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 3),
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: c == _strokeColor ? const Color(0xFF6C63FF) : Colors.grey.shade600,
                        width: c == _strokeColor ? 2 : 1,
                      ),
                    ),
                  ),
                )),
              },
            ]),
            const SizedBox(height: 4),

            // Shadow toggle
            Row(children: [
              SizedBox(
                width: 18, height: 18,
                child: Checkbox(
                  value: _enableShadow,
                  onChanged: (v) => setState(() => _enableShadow = v ?? false),
                  activeColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Shadow', style: TextStyle(fontSize: 10, color: Colors.grey)),
              if (_enableShadow) ...{
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Slider(
                    value: _shadowBlur, min: 1, max: 20, divisions: 19,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (v) => setState(() => _shadowBlur = v),
                  ),
                ),
                SizedBox(width: 20, child: Text('${_shadowBlur.round()}', style: const TextStyle(fontSize: 10, color: Colors.white70))),
                const SizedBox(width: 4),
                ..._colorSwatches.take(4).map((c) => GestureDetector(
                  onTap: () => setState(() => _shadowColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 3),
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: c == _shadowColor ? const Color(0xFF6C63FF) : Colors.grey.shade600,
                        width: c == _shadowColor ? 2 : 1,
                      ),
                    ),
                  ),
                )),
              },
            ]),
            const SizedBox(height: 6),

            // Apply + Cancel
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _actBtn('Cancel', () { _exitToolMode(); setState(() {}); }),
              const SizedBox(width: 12),
              _actBtn('Apply Text', _applyText),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Resize dialog ─────────────────────────────

  void _resizeDialog() {
    final wC = TextEditingController(text: '${_info?['width'] ?? 800}');
    final hC = TextEditingController(text: '${_info?['height'] ?? 600}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Resize', style: TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field('Width', wC), _field('Height', hC),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12))),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            _callEdit('/api/v1/editor/resize', {
              'width': int.tryParse(wC.text) ?? 800,
              'height': int.tryParse(hC.text) ?? 600,
            });
          }, child: const Text('Apply', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12))),
        ],
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────

  Widget _btn(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A4E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
          ]),
        ),
      ),
    );
  }

  Widget _toolBtn(String label, IconData icon, VoidCallback onTap, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF3A3A7E) : const Color(0xFF2A2A4E),
            borderRadius: BorderRadius.circular(4),
            border: active ? Border.all(color: const Color(0xFF6C63FF), width: 1) : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF6C63FF) : Colors.white70),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 8, color: active ? Colors.white : Colors.white70)),
          ]),
        ),
      ),
    );
  }

  Widget _actBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      ),
    );
  }

  Widget _slider(String label, double val, double min, double max, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 80, child: Text('$label: ${val.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 11, color: Colors.white70))),
      Expanded(
        child: Slider(
          value: val, min: min, max: max, divisions: 40,
          activeColor: const Color(0xFF6C63FF),
          onChanged: onChanged,
        ),
      ),
    ]);
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    final cross = Paint()
      ..color = const Color(0xFF6C63FF)
      ..strokeWidth = 1.5;
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
