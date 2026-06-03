import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// AudioForge page — TTS, Music generation, Voice cloning
class AudioForgePage extends StatefulWidget {
  const AudioForgePage({super.key});

  @override
  State<AudioForgePage> createState() => _AudioForgePageState();
}

class _AudioForgePageState extends State<AudioForgePage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabCtrl;

  // ── TTS state ──
  final _ttsTextCtrl = TextEditingController(text: 'Hello, this is a test.');
  List<Map<String, dynamic>> _ttsVoices = [];
  String? _selectedVoice;
  String? _ttsResult;

  // ── Music state ──
  final _musicPromptCtrl = TextEditingController();
  List<Map<String, dynamic>> _musicStyles = [];
  String? _selectedStyle;
  double _musicDuration = 15;
  String? _musicResult;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadVoices();
    _loadStyles();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _ttsTextCtrl.dispose();
    _musicPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await _api.get('/api/v1/tts/voices');
      setState(() {
        _ttsVoices = List<Map<String, dynamic>>.from(voices);
        if (_ttsVoices.isNotEmpty) {
          _selectedVoice = _ttsVoices.first['id']?.toString() ??
              _ttsVoices.first['name']?.toString();
        }
      });
    } catch (_) {
      // Offline: use mock data
      _ttsVoices = [
        {'id': 'en-US-JennyNeural', 'name': 'Jenny (English)'},
        {'id': 'zh-CN-Xiaoxiao', 'name': 'Xiaoxiao (Chinese)'},
        {'id': 'ja-JP-Nanami', 'name': 'Nanami (Japanese)'},
        {'id': 'fr-FR-Denise', 'name': 'Denise (French)'},
        {'id': 'de-DE-Katja', 'name': 'Katja (German)'},
      ];
      _selectedVoice = _ttsVoices.first['id']?.toString();
    }
  }

  Future<void> _loadStyles() async {
    try {
      final resp = await _api.get('/api/v1/music/styles');
      setState(() {
        _musicStyles = List<Map<String, dynamic>>.from(resp);
        if (_musicStyles.isNotEmpty) {
          _selectedStyle = _musicStyles.first['name']?.toString() ?? 'default';
        }
      });
    } catch (_) {
      _musicStyles = [
        {'name': 'default'}, {'name': 'jazz'}, {'name': 'electronic'},
        {'name': 'classical'}, {'name': 'pop'}, {'name': 'cinematic'},
      ];
      _selectedStyle = 'default';
    }
  }

  Future<void> _doTts() async {
    setState(() { _loading = true; _error = null; _ttsResult = null; });
    try {
      final resp = await _api.post('/api/v1/tts', body: {
        'text': _ttsTextCtrl.text,
        'voice': _selectedVoice ?? 'en-US-JennyNeural',
      });
      setState(() {
        _ttsResult = resp['status'] == 'ok'
            ? 'TTS generated: ${resp['output_path'] ?? 'OK'}'
            : 'Result: ${resp['result'] ?? resp.toString()}';
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _doMusic() async {
    setState(() { _loading = true; _error = null; _musicResult = null; });
    try {
      final resp = await _api.post('/api/v1/music', body: {
        'prompt': _musicPromptCtrl.text,
        'style': _selectedStyle ?? 'default',
        'duration': _musicDuration.toInt(),
      });
      setState(() {
        _musicResult = resp['status'] == 'ok'
            ? 'Music generated: ${resp['output_path'] ?? 'OK'}'
            : 'Result: ${resp['result'] ?? resp.toString()}';
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          // Header
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                const Text('AudioForge',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          // Error banner
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.withOpacity(0.2),
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFEF9A9A))),
            ),
          // Tabs
          TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6C63FF),
            tabs: const [
              Tab(icon: Icon(Icons.record_voice_over, size: 18), text: 'TTS'),
              Tab(icon: Icon(Icons.music_note, size: 18), text: 'Music'),
              Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Voice Clone'),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTtsTab(),
                _buildMusicTab(),
                _buildVoiceCloneTab(),
              ],
            ),
          ),
          // AI Audio Workshop bottom panel
          _buildAudioWorkshop(),
        ],
      ),
    );
  }

  // ── TTS tab ──

  Widget _buildTtsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Text-to-Speech',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Voice selector
          DropdownButtonFormField<String>(
            value: _selectedVoice,
            decoration: _inputDeco('Voice'),
            dropdownColor: const Color(0xFF16213E),
            items: _ttsVoices.map((v) => DropdownMenuItem(
              value: v['id']?.toString() ?? v['name']?.toString(),
              child: Text(v['name']?.toString() ?? v['id']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedVoice = v),
          ),
          const SizedBox(height: 12),
          // Text input
          TextField(
            controller: _ttsTextCtrl,
            maxLines: 5,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('Enter text to synthesize...'),
          ),
          const SizedBox(height: 16),
          // Generate button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _doTts,
              icon: const Icon(Icons.volume_up, size: 18),
              label: Text(_loading ? 'Generating...' : 'Generate Speech'),
            ),
          ),
          // Result
          if (_ttsResult != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_ttsResult!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFA5D6A7))),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Music tab ──

  Widget _buildMusicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Music Generation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Style selector
          DropdownButtonFormField<String>(
            value: _selectedStyle,
            decoration: _inputDeco('Style'),
            dropdownColor: const Color(0xFF16213E),
            items: _musicStyles.map((s) => DropdownMenuItem(
              value: s['name']?.toString() ?? 'default',
              child: Text(s['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedStyle = v),
          ),
          const SizedBox(height: 12),
          // Duration slider
          Row(
            children: [
              const Text('Duration: ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _musicDuration,
                  min: 5, max: 60, divisions: 11,
                  label: '${_musicDuration.toInt()}s',
                  onChanged: (v) => setState(() => _musicDuration = v),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text('${_musicDuration.toInt()}s',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Prompt input
          TextField(
            controller: _musicPromptCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('Describe the music...'),
          ),
          const SizedBox(height: 16),
          // Generate button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _doMusic,
              icon: const Icon(Icons.music_note, size: 18),
              label: Text(_loading ? 'Generating...' : 'Generate Music'),
            ),
          ),
          // Result
          if (_musicResult != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_musicResult!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFA5D6A7))),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Voice Clone tab (placeholder) ──

  Widget _buildVoiceCloneTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_search, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('Voice Cloning',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Upload a 5-10 second voice sample, then enter text to synthesize with cloned voice.\n\n'
              'Requires: F5-TTS (T2 GPU) or GPT-SoVITS (T2~T3)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Upload Reference Audio'),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Audio Workshop ──

  bool _workshopExpanded = false;

  Widget _buildAudioWorkshop() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: Color(0xFF2A2A3E)),
        GestureDetector(
          onTap: () => setState(() => _workshopExpanded = !_workshopExpanded),
          child: Container(
            height: 24,
            color: const Color(0xFF12121E),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high, size: 12, color: Color(0xFF6C63FF)),
                const SizedBox(width: 4),
                const Text('AI Audio Workshop',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                Icon(
                  _workshopExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 14, color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_workshopExpanded)
          Container(
            height: 80,
            color: const Color(0xFF0F0F1A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _workshopTool(Icons.record_voice_over, 'Voice Clone', Colors.blue),
                _workshopTool(Icons.text_fields, 'TTS', Colors.teal),
                _workshopTool(Icons.music_note, 'Music Gen', Colors.purple),
                _workshopTool(Icons.noise_control_off, 'Denoise', Colors.green),
                _workshopTool(Icons.tune, 'Mix', Colors.orange),
              ],
            ),
          ),
      ],
    );
  }

  Widget _workshopTool(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
    );
  }
}
