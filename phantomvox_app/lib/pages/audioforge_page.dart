import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/tr.dart';
import '../services/i18n_service.dart';

/// AudioForge page — professional audio mixing workspace + AI audio workshop
/// Reference: DaVinci Resolve Fairlight workspace
/// TOP_METER_BAR + PLAY_BAR + (TRACK_LIST + WAVE_TIMELINE + MIXER) + AI_WORKSHOP
class AudioForgePage extends StatefulWidget {
  const AudioForgePage({super.key});

  @override
  State<AudioForgePage> createState() => _AudioForgePageState();
}

class _AudioForgePageState extends State<AudioForgePage> {
  final ApiService _api = ApiService();
  final TextEditingController _ttsCtrl = TextEditingController(text: 'Hello, this is a test.');
  final TextEditingController _musicPromptCtrl = TextEditingController();
  List<Map<String, dynamic>> _ttsVoices = [];
  List<Map<String, dynamic>> _musicStyles = [];
  String? _selectedVoice;
  String? _selectedStyle;
  double _musicDuration = 15;
  String? _ttsResult;
  String? _musicResult;
  bool _loading = false;
  String? _error;
  double _playhead = 0.0;
  double _duration = 30.0;
  bool _aiPanelExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
    _loadStyles();
  }

  @override
  void dispose() {
    _ttsCtrl.dispose();
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
      _ttsVoices = [
        {'id': 'en-US-JennyNeural', 'name': 'Jenny (English)'},
        {'id': 'zh-CN-Xiaoxiao', 'name': 'Xiaoxiao (Chinese)'},
        {'id': 'ja-JP-Nanami', 'name': 'Nanami (Japanese)'},
      ];
      _selectedVoice = 'en-US-JennyNeural';
    }
  }

  Future<void> _loadStyles() async {
    try {
      final resp = await _api.get('/api/v1/music/styles');
      setState(() {
        _musicStyles = List<Map<String, dynamic>>.from(resp);
        if (_musicStyles.isNotEmpty) _selectedStyle = _musicStyles.first['name']?.toString();
      });
    } catch (_) {
      _musicStyles = [
        {'name': 'default'}, {'name': 'jazz'}, {'name': 'cinematic'},
      ];
      _selectedStyle = 'default';
    }
  }

  Future<void> _doTts() async {
    setState(() { _loading = true; _error = null; _ttsResult = null; });
    try {
      final resp = await _api.post('/api/v1/tts', body: {
        'text': _ttsCtrl.text,
        'voice': _selectedVoice ?? 'en-US-JennyNeural',
      });
      setState(() {
        _ttsResult = resp['status'] == 'ok'
            ? 'TTS generated: ${resp['output_path'] ?? 'OK'}'
            : 'Result: ${resp.toString()}';
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
            : 'Result: ${resp.toString()}';
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
          _buildMeterBar(),
          _buildPlayBar(),
          Expanded(
            child: Row(
              children: [
                _buildTrackList(),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                Expanded(child: _buildWaveTimeline()),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                _buildMixerPanel(),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(6),
              color: Colors.red.withValues(alpha: 0.2),
              child: Text(_error!, style: const TextStyle(fontSize: 10, color: Color(0xFFEF9A9A))),
            ),
          _buildAiWorkshop(),
        ],
      ),
    );
  }

  // ── TOP_GLOBAL_METER_BAR (48px) ──────────────────────

  Widget _buildMeterBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFF0D0D1A),
      child: Row(
        children: [
          // Left: buttons
          _meterBtn(Icons.folder, 'Media Pool'),
          _meterBtn(Icons.auto_fix_high, 'Effects'),
          _meterBtn(Icons.list_alt, 'Index'),
          _meterBtn(Icons.group_work, 'Groups'),
          _meterBtn(Icons.library_music, 'Sound Lib'),
          _meterBtn(Icons.mic, 'ADR'),
          Container(width: 1, height: 24, color: const Color(0xFF2A2A3E)),

          // Project name
          const SizedBox(width: 6),
          Tr('Land of Ice and Fire - Iceland', style: TextStyle(fontSize: 9, color: Colors.white54)),
          const Spacer(),

          // Meter: Bus + CR
          _miniVu(Colors.cyan, 0.7),
          Tr('Bus1', style: TextStyle(fontSize: 7, color: Colors.grey)),
          const SizedBox(width: 4),
          _miniVu(Colors.cyan, 0.5),
          Tr('CR', style: TextStyle(fontSize: 7, color: Colors.grey)),
          const SizedBox(width: 8),

          // Loudness readings
          _loudLabel('TP', '+5.1'),
          _loudLabel('M', '+19.7'),
          _loudLabel('Short', '+10.3'),
          _loudLabel('S.Max', '+15.2'),
          _loudLabel('Rng', '6.3'),
          _loudLabel('Int', '+13.3'),

          const SizedBox(width: 4),
          _miniBtn('Pause'),
          _miniBtn('Reset'),
          const SizedBox(width: 4),
          _miniBtn('DIM', active: true),
          const SizedBox(width: 8),

          // Buttons (right side)
          _meterBtn(Icons.tune, 'Mixer'),
          _meterBtn(Icons.equalizer, 'Meters'),
          _meterBtn(Icons.info_outline, 'Metadata'),
          _meterBtn(Icons.tune, 'Inspector'),
        ],
      ),
    );
  }

  Widget _meterBtn(IconData icon, String label) {
    return TextButton.icon(
      icon: Icon(icon, size: 11, color: Colors.grey),
      label: Text(i18n.tr(label), style: const TextStyle(fontSize: 8, color: Colors.grey)),
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _miniVu(Color color, double level) {
    return Container(
      width: 6, height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 28 * level,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loudLabel(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(i18n.tr(key), style: const TextStyle(fontSize: 6, color: Colors.grey)),
          Text(i18n.tr(value), style: const TextStyle(fontSize: 7, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF699EFF) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(i18n.tr(label), style: TextStyle(fontSize: 7, color: active ? Colors.white : Colors.grey)),
    );
  }

  // ── PLAY_CONTROL_BAR (32px) ──────────────────────────

  Widget _buildPlayBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF12121E),
      child: Row(
        children: [
          Tr('01:01:57:00', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
          const SizedBox(width: 8),
          _playBtn(Icons.skip_previous),
          _playBtn(Icons.play_arrow, color: const Color(0xFF4CAF50)),
          _playBtn(Icons.skip_next),
          _playBtn(Icons.loop),
          const SizedBox(width: 4),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(child: Tr('REC', style: TextStyle(fontSize: 7, color: Colors.red))),
          ),
          const SizedBox(width: 4),
          _playBtn(Icons.settings),
          const Spacer(),
          // Time ruler area
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  // Ruler ticks
                  CustomPaint(size: Size.infinite, painter: _RulerPainter()),
                  // Playhead
                  Positioned(
                    left: (_playhead / _duration) * 200,
                    top: 0, bottom: 0,
                    child: Container(width: 1, color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playBtn(IconData icon, {Color? color}) {
    return SizedBox(
      width: 24, height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 14, color: color ?? Colors.white70),
        onPressed: () {},
      ),
    );
  }

  // ── LEFT_TRACK (120px) ───────────────────────────────

  Widget _buildTrackList() {
    final tracks = [
      {'id': 'A1', 'name': 'Audio1', 'fx': '2.0', 'plugin': 'None', 'clips': 4},
      {'id': 'A2', 'name': 'Audio2', 'fx': '2.0', 'plugin': 'None', 'clips': 2},
      {'id': 'A3', 'name': 'Audio3', 'fx': '2.0', 'plugin': 'None', 'clips': 1},
      {'id': 'A4', 'name': 'Audio4', 'fx': '2.0', 'plugin': 'None', 'clips': 1},
      {'id': 'A5', 'name': 'Audio5', 'fx': '2.0', 'plugin': 'None', 'clips': 1},
    ];
    return Container(
      width: 120,
      color: const Color(0xFF12121E),
      child: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (_, i) {
          final t = tracks[i];
          return Container(
            height: 60,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: const Color(0xFF2A2A3E).withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(t['name'] as String, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const Spacer(),
                    Text('fx:${t['fx']}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                  ],
                ),
                Text(t['plugin'] as String, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                Text('${t['clips']} Clips', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _rsmBtn('R', Colors.red),
                    const SizedBox(width: 2),
                    _rsmBtn('S', Colors.orange),
                    const SizedBox(width: 2),
                    _rsmBtn('M', Colors.grey),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rsmBtn(String label, Color activeColor) {
    return Container(
      width: 18, height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Center(child: Text(i18n.tr(label), style: TextStyle(fontSize: 7, color: activeColor.withValues(alpha: 0.5)))),
    );
  }

  // ── CENTRAL_WAVE_TIMELINE ────────────────────────────

  Widget _buildWaveTimeline() {
    final waves = [
      {'name': 'Open Seas.wav', 'color': const Color(0xFF4CAF50), 'segments': 2},
      {'name': 'Open Seas + Wind', 'color': const Color(0xFFFF5252), 'segments': 1},
      {'name': 'Driving Beach.wav', 'color': const Color(0xFF2196F3), 'segments': 1},
      {'name': 'Desert Wind.wav', 'color': const Color(0xFFFF9800), 'segments': 1},
    ];
    return Container(
      color: const Color(0xFF0A0A14),
      child: ListView.builder(
        itemCount: waves.length,
        itemBuilder: (_, i) {
          return Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: const Color(0xFF2A2A3E).withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Text(waves[i]['name'] as String, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomPaint(
                    painter: _WavePainter(waves[i]['color'] as Color, waves[i]['segments'] as int),
                    size: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── RIGHT_MIXER (220px) ──────────────────────────────

  Widget _buildMixerPanel() {
    return Container(
      width: 220,
      color: const Color(0xFF12121E),
      child: Column(
        children: [
          _sectionHeader('Mixer'),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          Expanded(
            child: Row(
              children: [
                _mixerChannel('A1', 'Voice Isl', const Color(0xFF4CAF50)),
                _mixerChannel('A2', 'Voice Isl', const Color(0xFF2196F3)),
                _mixerChannel('A3', 'Dial Lev', const Color(0xFFFF9800)),
                _mixerChannel('A4', 'Dial Lev', const Color(0xFF9C27B0)),
                _mixerBus('Bus1'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mixerChannel(String id, String plugin, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          children: [
            Text(i18n.tr(id), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white70)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(i18n.tr(plugin), style: const TextStyle(fontSize: 6, color: Colors.grey)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _slotDot('DYN', false),
                const SizedBox(width: 2),
                _slotDot('EQ', true),
              ],
            ),
            const Spacer(),
            Container(
              width: 10, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [color, color.withValues(alpha: 0.3), const Color(0xFFCD5C5C)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Fader
            Container(
              height: 30, width: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 2, width: 10, color: color),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _rsmDot('R', Colors.red),
                _rsmDot('S', Colors.orange),
                _rsmDot('M', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mixerBus(String name) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF8B4513).withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(i18n.tr(name), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.orangeAccent)),
            _slotDot('FX', false),
            _slotDot('EQ', false),
            const Spacer(),
            Container(
              height: 50, width: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 4, width: 12, color: Colors.orangeAccent),
                ],
              ),
            ),
            Text(i18n.tr(name), style: const TextStyle(fontSize: 7, color: Colors.orangeAccent)),
          ],
        ),
      ),
    );
  }

  Widget _slotDot(String label, bool active) {
    return Container(
      width: 14, height: 10,
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF699EFF) : const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(1),
      ),
      child: Center(child: Text(i18n.tr(label), style: TextStyle(fontSize: 5, color: active ? Colors.white : Colors.grey))),
    );
  }

  Widget _rsmDot(String label, Color color) {
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(1),
      ),
      child: Center(child: Text(i18n.tr(label), style: TextStyle(fontSize: 5, color: color.withValues(alpha: 0.5)))),
    );
  }

  // ── AI AUDIO WORKSHOP (bottom panel, 120px) ──────────

  Widget _buildAiWorkshop() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: Color(0xFF2A2A3E)),
        GestureDetector(
          onTap: () => setState(() => _aiPanelExpanded = !_aiPanelExpanded),
          child: Container(
            height: 24,
            color: const Color(0xFF0D0D1A),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high, size: 12, color: Color(0xFF699EFF)),
                const SizedBox(width: 4),
                Tr('AI Audio Workshop', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                if (_loading)
                  const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                Icon(_aiPanelExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (_aiPanelExpanded)
          SizedBox(
            height: 120,
            child: Container(
              color: const Color(0xFF0F0F1A),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // TTS row
                    Row(
                      children: [
                        const SizedBox(width: 40, child: Tr('TTS', style: TextStyle(fontSize: 9, color: Color(0xFF699EFF)))),
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: TextField(
                              controller: _ttsCtrl,
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                              decoration: _aiInput('Text to synthesize...'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 60, height: 24,
                          child: DropdownButtonFormField<String>(
                            value: _selectedVoice,
                            isDense: true,
                            decoration: _aiInput('Voice'),
                            dropdownColor: const Color(0xFF16213E),
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                            items: _ttsVoices.map((v) => DropdownMenuItem(
                              value: v['id']?.toString(),
                              child: Text(v['name']?.toString() ?? '', style: const TextStyle(fontSize: 9)),
                            )).toList(),
                            onChanged: (v) => setState(() => _selectedVoice = v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 24,
                          child: FilledButton(
                            onPressed: _loading ? null : _doTts,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                            ),
                            child: Tr('Generate', style: TextStyle(fontSize: 9)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Music row
                    Row(
                      children: [
                        const SizedBox(width: 40, child: Tr('Music', style: TextStyle(fontSize: 9, color: Color(0xFF9C27B0)))),
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: TextField(
                              controller: _musicPromptCtrl,
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                              decoration: _aiInput('Describe the music...'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 50, height: 24,
                          child: DropdownButtonFormField<String>(
                            value: _selectedStyle,
                            isDense: true,
                            decoration: _aiInput('Style'),
                            dropdownColor: const Color(0xFF16213E),
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                            items: _musicStyles.map((s) => DropdownMenuItem(
                              value: s['name']?.toString(),
                              child: Text(s['name']?.toString() ?? '', style: const TextStyle(fontSize: 9)),
                            )).toList(),
                            onChanged: (v) => setState(() => _selectedStyle = v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 24,
                          child: FilledButton(
                            onPressed: _loading ? null : _doMusic,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                            ),
                            child: Tr('Generate', style: TextStyle(fontSize: 9)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Quick action chips
                    Row(
                      children: [
                        const SizedBox(width: 40),
                        _workshopChip(Icons.person_outline, 'Voice Clone'),
                        const SizedBox(width: 4),
                        _workshopChip(Icons.noise_control_off, 'Denoise'),
                        const SizedBox(width: 4),
                        _workshopChip(Icons.tune, 'Auto Mix'),
                        const SizedBox(width: 4),
                        _workshopChip(Icons.record_voice_over, 'Dialogue Match'),
                        const SizedBox(width: 4),
                        _workshopChip(Icons.equalizer, 'Level Match'),
                        const SizedBox(width: 4),
                        // Results
                        if (_ttsResult != null)
                          Tr('TTS: OK', style: TextStyle(fontSize: 8, color: Colors.green)),
                        if (_musicResult != null)
                          Tr('Music: OK', style: TextStyle(fontSize: 8, color: Colors.purple)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _workshopChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey),
          const SizedBox(width: 3),
          Text(i18n.tr(label), style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  InputDecoration _aiInput(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 9, color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      isDense: true,
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity, height: 22,
      padding: const EdgeInsets.only(left: 6),
      color: const Color(0xFF0D0D1A),
      alignment: Alignment.centerLeft,
      child: Text(i18n.tr(title), style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Custom Painters ──

class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  final Color color;
  final int segments;

  _WavePainter(this.color, this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    final path = Path();
    path.moveTo(0, size.height / 2);
    for (double x = 0; x < size.width; x += 2) {
      final y = size.height / 2 + math.sin(x / 20) * 8;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
