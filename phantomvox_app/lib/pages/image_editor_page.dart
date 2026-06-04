import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../widgets/tr.dart';
import '../../services/i18n_service.dart';

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
  Map<String, dynamic> _caps = {};

  @override
  void initState() {
    super.initState();
    _loadCaps();
  }

  Future<void> _loadCaps() async {
    try {
      final c = await _api.get('/api/v1/editor/capabilities');
      if (mounted) setState(() => _caps = c);
    } catch (_) {}
  }

  void _setImage(String b64) {
    setState(() {
      _imageBytes = base64Decode(b64);
      _status = '${_info?['width'] ?? '?'} × ${_info?['height'] ?? '?'} · ${_info?['format'] ?? ''}';
    });
  }

  Future<void> _callEdit(String endpoint, Map<String, dynamic> body) async {
    setState(() => _loading = true);
    try {
      final r = await _api.post(endpoint, body: body);
      if (r['status'] == 'ok') {
        _info = r['info'] as Map<String, dynamic>?;
        _setImage(r['base64'] as String);
      } else {
        if (mounted) _showMsg(r['error'] ?? 'Error');
      }
    } catch (e) {
      if (mounted) _showMsg('$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ── Dialogs ──────────────────────────────────────

  Future<void> _openDialog() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      setState(() => _loading = true);
      final r = await _api.post('/api/v1/editor/load', body: {'path': path});
      if (r['status'] == 'ok') {
        _info = r['info'] as Map<String, dynamic>?;
        _setImage(r['base64'] as String);
      } else {
        _showMsg(r['error'] ?? 'Load failed');
      }
    } catch (e) {
      _showMsg('$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _exportDialog() async {
    try {
      final result = await FilePicker.platform.saveFile(
        type: FileType.image,
        fileName: 'exported_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (result == null) return;
      final path = result;
      final r = await _api.post('/api/v1/editor/export', body: {'path': path});
      if (r['status'] == 'ok') {
        _showMsg('Exported to $path');
      } else {
        _showMsg(r['error'] ?? 'Export failed');
      }
    } catch (e) {
      _showMsg('$e');
    }
  }

  // ── Tool dialogs ─────────────────────────────────

  void _cropDialog() {
    final xCtrl = TextEditingController(text: '0');
    final yCtrl = TextEditingController(text: '0');
    final wCtrl = TextEditingController(text: '${_info?['width'] ?? 100}');
    final hCtrl = TextEditingController(text: '${_info?['height'] ?? 100}');
    showDialog(
      context: context,
      builder: (ctx) => _toolDialog('Crop', [
        _field('X', xCtrl), _field('Y', yCtrl),
        _field('Width', wCtrl), _field('Height', hCtrl),
      ], () {
        Navigator.pop(ctx);
        _callEdit('/api/v1/editor/crop', {
          'x': int.tryParse(xCtrl.text) ?? 0,
          'y': int.tryParse(yCtrl.text) ?? 0,
          'w': int.tryParse(wCtrl.text) ?? 100,
          'h': int.tryParse(hCtrl.text) ?? 100,
        });
      }),
    );
  }

  void _resizeDialog() {
    final wCtrl = TextEditingController(text: '${_info?['width'] ?? 800}');
    final hCtrl = TextEditingController(text: '${_info?['height'] ?? 600}');
    showDialog(
      context: context,
      builder: (ctx) => _toolDialog('Resize', [
        _field('Width', wCtrl), _field('Height', hCtrl),
      ], () {
        Navigator.pop(ctx);
        _callEdit('/api/v1/editor/resize', {
          'width': int.tryParse(wCtrl.text) ?? 800,
          'height': int.tryParse(hCtrl.text) ?? 600,
        });
      }),
    );
  }

  void _rotateDialog() {
    final ctrl = TextEditingController(text: '90');
    showDialog(
      context: context,
      builder: (ctx) => _toolDialog('Rotate', [
        _field('Angle (degrees)', ctrl),
      ], () {
        Navigator.pop(ctx);
        _callEdit('/api/v1/editor/rotate', {
          'angle': double.tryParse(ctrl.text) ?? 90,
        });
      }),
    );
  }

  void _adjustDialog() {
    final bCtrl = TextEditingController(text: '1.0');
    final cCtrl = TextEditingController(text: '1.0');
    final sCtrl = TextEditingController(text: '1.0');
    showDialog(
      context: context,
      builder: (ctx) => _toolDialog('Adjust', [
        _field('Brightness (0-2)', bCtrl),
        _field('Contrast (0-2)', cCtrl),
        _field('Saturation (0-2)', sCtrl),
      ], () {
        Navigator.pop(ctx);
        _callEdit('/api/v1/editor/adjust', {
          'brightness': double.tryParse(bCtrl.text) ?? 1.0,
          'contrast': double.tryParse(cCtrl.text) ?? 1.0,
          'saturation': double.tryParse(sCtrl.text) ?? 1.0,
        });
      }),
    );
  }

  void _showAddTextDialog() async {
    final tCtrl = TextEditingController();
    final xCtrl = TextEditingController(text: '10');
    final yCtrl = TextEditingController(text: '10');
    final sCtrl = TextEditingController(text: '24');
    showDialog(
      context: context,
      builder: (ctx) => _toolDialog('Add Text', [
        _field('Text', tCtrl),
        _field('X', xCtrl), _field('Y', yCtrl),
        _field('Font size', sCtrl),
      ], () {
        Navigator.pop(ctx);
        _callEdit('/api/v1/editor/text', {
          'text': tCtrl.text,
          'x': int.tryParse(xCtrl.text) ?? 10,
          'y': int.tryParse(yCtrl.text) ?? 10,
          'font_size': int.tryParse(sCtrl.text) ?? 24,
        });
      }),
    );
  }

  // ── Quick actions ────────────────────────────────

  void _quickFilter(String filter) =>
      _callEdit('/api/v1/editor/filter', {'filter': filter});

  // ── Build ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService();
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Image Studio',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        centerTitle: false,
        actions: [
          _btn('Open', Icons.folder_open, _openDialog),
          _btn('Export', Icons.save_alt, _exportDialog),
          if (_imageBytes != null) ...[
            _btn('Flip H', Icons.flip, () => _callEdit('/api/v1/editor/flip', {'direction': 'horizontal'})),
            _btn('Flip V', Icons.flip, () => _callEdit('/api/v1/editor/flip', {'direction': 'vertical'})),
          ],
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xFF1A1A2E),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _toolBtn('Crop', Icons.crop, _cropDialog),
                _toolBtn('Resize', Icons.photo_size_select_large, _resizeDialog),
                _toolBtn('Rotate', Icons.rotate_right, _rotateDialog),
                _toolBtn('Adjust', Icons.tune, _adjustDialog),
                _toolBtn('Text', Icons.text_fields, _showAddTextDialog),
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
          ),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            color: const Color(0xFF12121E),
            child: Row(
              children: [
                Text(_status, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                if (_loading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
                ],
              ],
            ),
          ),
          // Canvas
          Expanded(
            child: Center(
              child: _imageBytes != null
                  ? InteractiveViewer(
                      child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image, size: 64, color: Color(0xFF3A3A5E)),
                        const SizedBox(height: 12),
                        Text('Click Open to load an image',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolBtn(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A4E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 8, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
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

  Widget _toolDialog(String title, List<Widget> fields, VoidCallback onApply) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: fields),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12))),
        TextButton(
            onPressed: onApply,
            child: const Text('Apply', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12))),
      ],
    );
  }

  Future<String?> _textDialog(String title, String label, String hint) {
    final ctrl = TextEditingController(text: hint);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Open', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12))),
        ],
      ),
    );
  }
}
