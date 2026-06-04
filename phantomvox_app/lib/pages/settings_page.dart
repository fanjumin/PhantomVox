import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// PhantomVox Settings page — 4 tabs: General / Project / AI Models / About.
/// Launched as a full-page overlay from the menu bar.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic> _config = {};
  List<dynamic> _allModels = [];
  bool _loading = true;
  String? _error;

  // Form fields
  String _language = 'zh_CN';
  String _theme = 'dark';
  String _autoSave = '5';

  // Project defaults
  String _defaultRes = '1920×1080';
  String _defaultFps = '24';
  String _defaultSampleRate = '48000';
  String _defaultFormat = 'H.264';

  // AI model selections per category
  final Map<String, String> _selectedModels = {};
  final Map<String, String> _apiKeys = {};
  double _temperature = 0.7;

  // Persistent TextEditingControllers for API key fields
  final Map<String, TextEditingController> _keyControllers = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final api = ApiService();
      final config = await api.get('/api/v1/models/config');
      final modelsRes = await api.get('/api/v1/models?category=all');
      if (!mounted) return;
      setState(() {
        _config = config;
        _allModels = modelsRes['models'] ?? [];
        _loading = false;

        // Populate form fields
        _language = _deepGet(config, 'locale') as String? ?? 'zh_CN';
        _temperature = (_deepGet(config, 'llm', 'temperature') as num?)?.toDouble() ?? 0.7;
        final keys = config['api_keys'] ?? {};
        if (keys is Map) {
          for (final e in keys.entries) {
            _apiKeys[e.key] = e.value?.toString() ?? '';
          }
        }

        // Set selected models from config
        _selectedModels['llm'] = _deepGet(config, 'llm', 'model') as String? ?? '';
        _selectedModels['image'] = _deepGet(config, 'image', 'engine') as String? ?? '';
        _selectedModels['video'] = _deepGet(config, 'video', 'engine') as String? ?? '';
        _selectedModels['tts'] = _deepGet(config, 'audio', 'tts', 'engine') as String? ?? '';
        _selectedModels['music'] = _deepGet(config, 'audio', 'music', 'engine') as String? ?? '';

        // Create persistent controllers for API key fields
        final keyProviders = ['openai', 'anthropic', 'deepseek', 'google', 'zhipu', 'alibaba', 'baidu'];
        for (final p in keyProviders) {
          _keyControllers.putIfAbsent(p, () => TextEditingController(text: _apiKeys[p] ?? ''));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  dynamic _deepGet(Map m, String k1, [dynamic k2, dynamic k3]) {
    final v1 = m[k1];
    if (k2 == null) return v1;
    if (v1 is! Map) return null;
    final v2 = v1[k2];
    if (k3 == null) return v2;
    if (v2 is! Map) return null;
    return v2[k3];
  }

  List<Map<String, dynamic>> _modelsByCategory(String cat) {
    return (_allModels)
        .where((m) => m['category'] == cat)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Project'),
            Tab(text: 'AI Models'),
            Tab(text: 'About'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Unable to load settings:\n$_error',
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildGeneralTab(),
                    _buildProjectTab(),
                    _buildAiModelsTab(),
                    _buildAboutTab(),
                  ],
                ),
    );
  }

  // ── General Tab ──────────────────────────────────────

  Widget _buildGeneralTab() {
    return _tabContent([
      _section('General Settings', [
        _dropdown('Language', _language, ['zh_CN', 'zh_TW', 'en', 'ja', 'ko', 'fr', 'de', 'it', 'es', 'pt_BR', 'ru', 'ar', 'vi', 'th', 'id'],
            (v) => _language = v),
        _row('Theme', [
          _radio('Dark', _theme == 'dark', () => _theme = 'dark'),
          const SizedBox(width: 16),
          _radio('Light', _theme == 'light', () => _theme = 'light'),
        ]),
        _dropdown('Auto-save interval', _autoSave,
            ['1', '5', '10', '15', '30'], (v) => _autoSave = v),
      ]),
      _section('Account', [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1A),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Local Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('No cloud account required. Preferences are stored locally.',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ]),
      _buttonRow(),
    ]);
  }

  // ── Project Tab ───────────────────────────────────────

  Widget _buildProjectTab() {
    return _tabContent([
      _section('Default Project Settings', [
        _dropdown('Resolution', _defaultRes,
            ['3840×2160', '1920×1080', '1280×720', '640×360'],
            (v) => _defaultRes = v),
        _dropdown('Frame Rate', _defaultFps,
            ['23.976', '24', '25', '29.97', '30', '60'],
            (v) => _defaultFps = v),
        _dropdown('Audio Sample Rate', _defaultSampleRate,
            ['44100', '48000', '96000'],
            (v) => _defaultSampleRate = v),
        _dropdown('Render Format', _defaultFormat,
            ['H.264', 'H.265', 'ProRes', 'DNxHD', 'VP9', 'AV1'],
            (v) => _defaultFormat = v),
      ]),
      _buttonRow(),
    ]);
  }

  // ── AI Models Tab ─────────────────────────────────────

  Widget _buildAiModelsTab() {
    return _tabContent([
      _modelSection('LLM', 'llm', ['provider', 'temperature', 'max_tokens']),
      _modelSection('Image', 'image', ['provider', 'resolution']),
      _modelSection('Video', 'video', ['provider', 'max_duration', 'resolution']),
      _modelSection('TTS', 'tts', ['provider']),
      _modelSection('Music', 'music', ['provider']),
      _section('API Keys', [
        for (final provider in ['openai', 'anthropic', 'deepseek', 'google', 'zhipu', 'alibaba', 'baidu'])
          _apiKeyField(provider),
      ]),
      const SizedBox(height: 16),
      Center(
        child: Text(
          'Local models do not require API keys.',
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
      ),
      _buttonRow(),
    ]);
  }

  Widget _modelSection(String label, String cat, List<String> extras) {
    final models = _modelsByCategory(cat);
    return _section(label, [
      _dropdown('Model', _selectedModels[cat] ?? '',
          models.map((m) => m['key'] as String).toList(),
          (v) => _selectedModels[cat] = v,
          displayName: (v) {
            final m = models.cast<Map<String, dynamic>?>().firstWhere(
                (x) => x?['key'] == v, orElse: () => null);
            if (m != null) {
              final tier = m['tier'];
              final local = m['local'] == true ? ' (local)' : '';
              return '${m['name']} — T$tier$local';
            }
            return v;
          },
          hint: 'Select $label model'),
      if (cat == 'llm') ...[
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 16),
            const Text('Temperature:', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Expanded(
              child: Slider(
                value: _temperature,
                min: 0,
                max: 2,
                divisions: 20,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (v) => _temperature = v,
              ),
            ),
            Text('${_temperature.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 16),
          ],
        ),
      ],
    ]);
  }

  Widget _apiKeyField(String provider) {
    final icons = {
      'openai': Icons.flare,
      'anthropic': Icons.psychology,
      'deepseek': Icons.auto_awesome,
      'google': Icons.cloud,
      'zhipu': Icons.smart_toy,
      'alibaba': Icons.shopping_bag,
      'baidu': Icons.language,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icons[provider] ?? Icons.vpn_key, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(provider, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                obscureText: true,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'sk-...',
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
                controller: _keyControllers[provider]!,
                onChanged: (v) => _apiKeys[provider] = v,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── About Tab ─────────────────────────────────────────

  Widget _buildAboutTab() {
    return _tabContent([
      _section('PhantomVox AI', [
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              const Icon(Icons.movie_creation, size: 48, color: Color(0xFF6C63FF)),
              const SizedBox(height: 8),
              const Text('v0.2.5',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Where AI Meets Creativity',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              _infoRow('License', 'MIT'),
              _infoRow('Platform', 'Linux, Windows, macOS'),
              _infoRow('Flutter SDK', '3.44.1'),
              _infoRow('Python', '3.12'),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  _actionChip(Icons.update, 'Check Updates'),
                  _actionChip(Icons.computer, 'System Info'),
                  _actionChip(Icons.description, 'License'),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Built with Flutter + Python AI Server\n'
                '© 2026 PhantomVox AI',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 10),
              ),
            ],
          ),
        ),
      ]),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _tabContent(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C63FF))),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String> onChanged,
      {String Function(String)? displayName, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          SizedBox(
            width: 280,
            height: 32,
            child: DropdownButtonFormField<String>(
              value: options.contains(value) ? value : null,
              isExpanded: true,
              decoration: _inputDeco(),
              style: const TextStyle(fontSize: 11, color: Colors.white),
              dropdownColor: const Color(0xFF1A1A2E),
              hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
              items: options.map((o) {
                final dn = displayName != null ? displayName(o) : o;
                return DropdownMenuItem(value: o, child: Text(dn));
              }).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco() {
    return InputDecoration(
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
    );
  }

  Widget _row(String label, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12))),
          ...children,
        ],
      ),
    );
  }

  Widget _radio(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: selected ? const Color(0xFF6C63FF) : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.grey)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label) {
    return ActionChip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: const Color(0xFF0D0D1A),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label coming soon'), duration: const Duration(seconds: 1)),
        );
      },
    );
  }

  Widget _buttonRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      child: Row(
        children: [
          const Spacer(),
          OutlinedButton(
            onPressed: _loadConfig,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: BorderSide(color: Colors.grey[800]!),
            ),
            child: const Text('Reset', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _saveConfig,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfig() async {
    try {
      final api = ApiService();
      // Build config payload matching backend format:
      // {"llm": {"model": "...", "temperature": 0.7}, "audio": {"tts": {"engine": "..."}}}
      final configPayload = <String, dynamic>{};

      // LLM
      if ((_selectedModels['llm'] ?? '').isNotEmpty) {
        configPayload['llm'] = {
          'model': _selectedModels['llm'],
          'temperature': _temperature,
        };
      }
      // Image
      if ((_selectedModels['image'] ?? '').isNotEmpty) {
        configPayload['image'] = {'model': _selectedModels['image']};
      }
      // Video
      if ((_selectedModels['video'] ?? '').isNotEmpty) {
        configPayload['video'] = {'model': _selectedModels['video']};
      }
      // Audio (TTS + Music)
      final audioConfig = <String, dynamic>{};
      if ((_selectedModels['tts'] ?? '').isNotEmpty) {
        audioConfig['tts'] = {'engine': _selectedModels['tts']};
      }
      if ((_selectedModels['music'] ?? '').isNotEmpty) {
        audioConfig['music'] = {'engine': _selectedModels['music']};
      }
      if (audioConfig.isNotEmpty) {
        configPayload['audio'] = audioConfig;
      }

      if (configPayload.isNotEmpty) {
        await api.post('/api/v1/models/config', body: configPayload);
      }

      // Save API keys
      final apiKeysPayload = <String, String>{};
      for (final entry in _apiKeys.entries) {
        if (entry.value.isNotEmpty) {
          apiKeysPayload[entry.key] = entry.value;
        }
      }
      if (apiKeysPayload.isNotEmpty) {
        await api.post('/api/v1/models/api_keys', body: apiKeysPayload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings applied'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}
