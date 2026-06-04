import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Static helpers for file operations triggered from the menu bar.
/// All methods operate on the Flutter context for dialogs & navigation.
class FileOperations {
  FileOperations._();

  /// New Project dialog — name, resolution, fps, duration, audio rate.
  static Future<Map<String, dynamic>?> showNewProjectDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'Untitled');
    String resolution = '1920×1080';
    String fps = '24';
    String sampleRate = '48000';

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('New Project'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Project Name'),
                  SizedBox(
                    height: 32,
                    child: TextField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'My Project Name',
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey[800]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey[800]!),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D0D1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label('Resolution'),
                  _dropdown(ctx, resolution,
                      ['3840×2160', '1920×1080', '1280×720', '640×360'],
                      (v) => setDState(() => resolution = v)),
                  const SizedBox(height: 8),
                  _label('Frame Rate'),
                  _dropdown(ctx, fps, ['23.976', '24', '25', '29.97', '30', '60'],
                      (v) => setDState(() => fps = v)),
                  const SizedBox(height: 8),
                  _label('Audio Sample Rate'),
                  _dropdown(ctx, sampleRate, ['44100', '48000', '96000'],
                      (v) => setDState(() => sampleRate = v)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop({
                  'name': nameCtrl.text,
                  'resolution': resolution,
                  'fps': fps,
                  'sample_rate': sampleRate,
                }),
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Open file dialog for .phantomvox project files.
  static Future<String?> showOpenProjectDialog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['phantomvox', 'json'],
      dialogTitle: 'Open Project',
    );
    return result?.files.single.path;
  }

  /// Save file dialog for .phantomvox project files.
  static Future<String?> showSaveDialog() async {
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['phantomvox'],
      dialogTitle: 'Save Project As',
      fileName: 'untitled.phantomvox',
    );
    return result;
  }

  /// Import media file picker — video, audio, images.
  static Future<List<String>?> showImportDialog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
      dialogTitle: 'Import Media',
    );
    return result?.files.map((f) => f.path ?? '').where((p) => p.isNotEmpty).toList();
  }

  /// Export dialog — format, resolution, quality.
  static Future<Map<String, dynamic>?> showExportDialog(BuildContext context) {
    String format = 'H.264';
    String resolution = '1920×1080';
    String quality = 'High';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('Export Video'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Format'),
                  _dropdown(ctx, format,
                      ['H.264', 'H.265', 'ProRes', 'VP9', 'AV1'],
                      (v) => setDState(() => format = v)),
                  const SizedBox(height: 8),
                  _label('Resolution'),
                  _dropdown(ctx, resolution,
                      ['7680×4320', '3840×2160', '1920×1080', '1280×720'],
                      (v) => setDState(() => resolution = v)),
                  const SizedBox(height: 8),
                  _label('Quality'),
                  _dropdown(ctx, quality,
                      ['Low', 'Medium', 'High', 'Lossless'],
                      (v) => setDState(() => quality = v)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  // After dialog, open save file dialog
                  final path = await FilePicker.platform.saveFile(
                    type: FileType.custom,
                    allowedExtensions: ['mp4', 'mov', 'mkv', 'webm'],
                    fileName: 'export.${_ext(format)}',
                  );
                  if (path != null && context.mounted) {
                    Navigator.of(ctx).pop({
                      'format': format,
                      'resolution': resolution,
                      'quality': quality,
                      'path': path,
                    });
                  }
                },
                child: const Text('Export'),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _ext(String format) {
    switch (format) {
      case 'H.264': return 'mp4';
      case 'H.265': return 'mp4';
      case 'ProRes': return 'mov';
      case 'VP9': return 'webm';
      case 'AV1': return 'mkv';
      default: return 'mp4';
    }
  }

  // ── UI helpers ───────────────────────────────────

  static Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }

  static Widget _dropdown(BuildContext ctx, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return SizedBox(
      height: 32,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          filled: true,
          fillColor: const Color(0xFF0D0D1A),
        ),
        style: const TextStyle(fontSize: 11, color: Colors.white),
        dropdownColor: const Color(0xFF1A1A2E),
        items: items.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
