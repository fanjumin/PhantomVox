import 'dart:convert';
import 'dart:io';
import '../services/api_service.dart';

/// Manages the current PhantomVox project state and file I/O.
/// Single project at a time, stored in memory + synced to .phantomvox file.
class ProjectManager {
  static final ProjectManager _instance = ProjectManager._();
  factory ProjectManager() => _instance;
  ProjectManager._();

  String? _currentPath;
  String _name = 'Untitled';
  String _resolution = '1920x1080';
  String _fps = '24';
  String _sampleRate = '48000';
  String _createdAt = '';
  String _updatedAt = '';
  Map<String, dynamic> _timeline = {};

  bool get hasProject => _currentPath != null || _createdAt.isNotEmpty;
  String get name => _name;
  String? get currentPath => _currentPath;
  String get resolution => _resolution;
  String get fps => _fps;
  bool get isModified => true; // simplified: always dirty

  /// Create a new empty project with given metadata.
  void newProject(String name, String resolution, String fps, String sampleRate) {
    final now = DateTime.now().toIso8601String();
    _currentPath = null;
    _name = name;
    _resolution = resolution;
    _fps = fps;
    _sampleRate = sampleRate;
    _createdAt = now;
    _updatedAt = now;
    _timeline = {
      'id': '',
      'name': name,
      'tracks': [],
      'duration': 0.0,
      'fps': double.tryParse(fps) ?? 24,
    };
  }

  /// Load a project from a .phantomvox file.
  Future<String?> openProject(String path) async {
    try {
      final api = ApiService();
      final data = await api.get('/api/v1/project/load?path=${Uri.encodeComponent(path)}');
      if (data case {'error': final msg}) return 'Load failed: $msg';

      _currentPath = path;
      final meta = data['metadata'] as Map<String, dynamic>? ?? {};
      _name = meta['name'] as String? ?? data['timeline']?['name'] ?? 'Untitled';
      _resolution = meta['resolution'] as String? ?? '1920x1080';
      _fps = meta['fps'] as String? ?? '24';
      _sampleRate = meta['sample_rate'] as String? ?? '48000';
      _createdAt = meta['created_at'] as String? ?? '';
      _updatedAt = meta['updated_at'] as String? ?? '';
      _timeline = data['timeline'] as Map<String, dynamic>? ?? {};
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  /// Save current project to the given path (or current path).
  Future<String?> saveProject(String? toPath) async {
    final path = toPath ?? _currentPath;
    if (path == null) return 'No save path specified';

    try {
      final api = ApiService();
      final now = DateTime.now().toIso8601String();
      _updatedAt = now;

      final payload = {
        'path': path,
        'metadata': {
          'name': _name,
          'resolution': _resolution,
          'fps': _fps,
          'sample_rate': _sampleRate,
          'created_at': _createdAt,
          'updated_at': _updatedAt,
        },
        'timeline': _timeline,
      };

      final result = await api.post('/api/v1/project/save', body: payload);
      if (result case {'error': final msg}) return 'Save failed: $msg';

      _currentPath = path;
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  /// Serialize project info for display / logs.
  Map<String, dynamic> toInfo() => {
    'name': _name,
    'path': _currentPath,
    'resolution': _resolution,
    'fps': _fps,
    'sample_rate': _sampleRate,
    'created_at': _createdAt,
    'updated_at': _updatedAt,
  };
}
