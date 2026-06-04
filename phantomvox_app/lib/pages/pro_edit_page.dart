import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/timeline_canvas.dart';
import '../widgets/tr.dart';
import '../../services/i18n_service.dart';
import '../services/i18n_service.dart';

/// ProEdit page — 4-panel precision editing layout
/// Reference: DaVinci Resolve Edit workspace
/// TOP_BAR + LEFT_SIDEBAR(media+toolbox) + CENTRAL_VIEWER + RIGHT_INSPECTOR + TIMELINE + MIXER
class ProEditPage extends StatefulWidget {
  const ProEditPage({super.key});

  @override
  State<ProEditPage> createState() => _ProEditPageState();
}

class _ProEditPageState extends State<ProEditPage> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _timeline;
  List<Map<String, dynamic>> _tracks = [];
  String? _selectedClipId;
  double _currentTime = 0.0;
  bool _isPlaying = false;
  String _inspectorTab = 'Video';
  bool _mixerVisible = true;
  final Map<String, bool> _foldGroups = {
    'Transform': true, 'Smart Reframe': false, 'Cropping': false,
    'Dynamic Zoom': false, 'Composite': false, 'Speed Change': false,
    'Stabilization': false, 'Lens Correction': false, 'AI Tuning': false,
  };

  @override
  void initState() {
    super.initState();
    _initTimeline();
  }

  Future<void> _initTimeline() async {
    try {
      final resp = await _api.createTimeline(name: 'My Edit');
      setState(() {
        _timeline = resp['timeline'];
        _tracks = List<Map<String, dynamic>>.from(
            (_timeline?['tracks'] as List<dynamic>?) ?? []);
      });
    } catch (_) {
      _tracks = [
        {'id': 'v1', 'type': 'video', 'name': 'V1 DYLAN', 'index': 0, 'color': '#3A7BD5', 'clips': [
          {'id': 'c1', 'name': 'A001_C001', 'start': 0.0, 'duration': 5.0, 'asset_path': ''},
          {'id': 'c2', 'name': 'A003_C010', 'start': 6.0, 'duration': 8.0, 'asset_path': ''},
          {'id': 'c5', 'name': 'A005_C020', 'start': 16.0, 'duration': 6.0, 'asset_path': ''},
        ]},
        {'id': 'v2', 'type': 'video', 'name': 'V2 B-ROLL', 'index': 1, 'color': '#7B68EE', 'clips': [
          {'id': 'c3', 'name': 'A002_C005', 'start': 1.0, 'duration': 4.0, 'asset_path': ''},
          {'id': 'c6', 'name': 'A004_C012', 'start': 12.0, 'duration': 5.0, 'asset_path': ''},
        ]},
        {'id': 'a1', 'type': 'audio', 'name': 'A1 VO', 'index': 2, 'color': '#2E8B57', 'clips': [
          {'id': 'c4', 'name': 'Voiceover_Narration', 'start': 2.0, 'duration': 12.0, 'asset_path': ''},
        ]},
        {'id': 'a2', 'type': 'audio', 'name': 'A2 SOUNDTRACK', 'index': 3, 'color': '#CD853F', 'clips': [
          {'id': 'c7', 'name': 'BGM_MainTheme', 'start': 0.0, 'duration': 20.0, 'asset_path': ''},
        ]},
        {'id': 'a3', 'type': 'audio', 'name': 'A3 SFX', 'index': 4, 'color': '#8FBC8F', 'clips': [
          {'id': 'c8', 'name': 'Ambient_Forest', 'start': 3.0, 'duration': 8.0, 'asset_path': ''},
        ]},
      ];
    }
  }

  double get _duration {
    double maxDur = 0;
    for (final t in _tracks) {
      for (final c in (t['clips'] as List<dynamic>)) {
        final end = ((c['start'] as num?)?.toDouble() ?? 0) +
            ((c['duration'] as num?)?.toDouble() ?? 0);
        if (end > maxDur) maxDur = end;
      }
    }
    return maxDur > 0 ? maxDur : 30.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                _buildLeftSidebar(),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(flex: 5, child: _buildViewport()),
                      const Divider(height: 1, color: Color(0xFF2A2A3E)),
                      Expanded(flex: 4, child: _buildTimelineArea()),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                _buildRightPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP_BAR (40px) ────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          _tbBtn('Media Pool', Icons.folder, true),
          _tbBtn('Effects', Icons.auto_fix_high, false),
          _tbBtn('Index', Icons.list_alt, false),
          _tbBtn('Sound', Icons.library_music, false),
          _tbBtn('Keyframes', Icons.keyboard, false),
          Container(width: 1, height: 20, color: const Color(0xFF2A2A3E)),
          const SizedBox(width: 8),
          _tbChip(Icons.content_cut, 'Split'),
          const SizedBox(width: 4),
          _tbChip(Icons.crop, 'Trim'),
          const SizedBox(width: 4),
          _tbChip(Icons.transit_enterexit, 'Transition'),
          const SizedBox(width: 4),
          _tbChip(Icons.speed, 'Speed'),
          const Spacer(),
          Text(_timeline?['name'] ?? 'The Ranch - Short Story',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(width: 16),
          _tbLabel('Zoom: 46%'),
          const SizedBox(width: 8),
          _tbLabel('TC: 00:04:53:10'),
          const SizedBox(width: 8),
          _tbLabel('24fps'),
          const SizedBox(width: 12),
          _tbBtn('AI', Icons.smart_toy, false, accent: true),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.tune, size: 16,
                color: _mixerVisible ? const Color(0xFF699EFF) : Colors.grey),
            onPressed: () => setState(() => _mixerVisible = !_mixerVisible),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Mixer',
          ),
          _tbBtn('Metadata', Icons.info_outline, false),
          _tbBtn('Inspector', Icons.tune, true),
          const SizedBox(width: 4),
          _tbChip(Icons.file_download, 'Quick Export'),
        ],
      ),
    );
  }

  Widget _tbBtn(String label, IconData icon, bool active, {bool accent = false}) {
    final color = accent ? const Color(0xFF699EFF) : (active ? Colors.white : Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: TextButton.icon(
        icon: Icon(icon, size: 14, color: color),
        label: Text(i18n.tr(label), style: TextStyle(fontSize: 10, color: color)),
        onPressed: () {},
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _tbChip(IconData icon, String label) {
    return ActionChip(
      avatar: Icon(icon, size: 13),
      label: Text(i18n.tr(label), style: const TextStyle(fontSize: 10)),
      onPressed: null,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _tbLabel(String text) {
    return Text(i18n.tr(text), style: const TextStyle(fontSize: 10, color: Colors.grey));
  }

  // ── LEFT_SIDEBAR (200px) ──────────────────────────────

  Widget _buildLeftSidebar() {
    return Container(
      width: 200,
      color: const Color(0xFF12121E),
      child: Column(
        children: [
          _panelHeader('Media Pool', Icons.folder),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          Expanded(flex: 3, child: _buildMediaTree()),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          _panelHeader('Toolbox', Icons.build),
          Expanded(flex: 4, child: _buildToolbox()),
        ],
      ),
    );
  }

  Widget _buildMediaTree() {
    final items = [
      ('FOLEY', Icons.folder, false),
      ('GFX', Icons.folder, false),
      ('RANCH', Icons.folder, false),
      ('A003_C001_2404', Icons.movie, true),
      ('A003_C010_2404', Icons.movie, false),
      ('A005_C020_2404', Icons.movie, false),
      ('Smart Bins', Icons.auto_awesome, false),
      ('Keywords', Icons.label, false),
      ('Collections', Icons.star, false),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: items.map((e) => _treeItem(e.$1, e.$2, e.$3)).toList(),
    );
  }

  Widget _treeItem(String name, IconData icon, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: selected ? const Color(0xFF1A1A3E) : null,
      child: Row(
        children: [
          Icon(icon, size: 13, color: selected ? const Color(0xFF699EFF) : Colors.grey),
          const SizedBox(width: 6),
          Text(i18n.tr(name), style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : Colors.grey,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  Widget _buildToolbox() {
    final folders = [
      ('Video Transitions', [('Dissolve', Icons.blur_on), ('Iris', Icons.blur_circular), ('Wipe', Icons.swipe)]),
      ('Audio Transitions', [('Crossfade', Icons.blur_on)]),
      ('Titles', [('Lower Third', Icons.text_fields), ('Full Screen', Icons.title)]),
      ('Generators', [('Solid Color', Icons.color_lens), ('Gradient', Icons.gradient)]),
      ('Open FX', [('FilmLook', Icons.movie_filter), ('Vintage', Icons.filter_vintage)]),
      ('Filters', [('Blur', Icons.blur_on), ('Sharpen', Icons.filter_hdr)]),
      ('Audio FX', [('Reverb', Icons.theater_comedy), ('Delay', Icons.timer)]),
      ('VST / AU', [('VST3', Icons.extension)]),
      ('Favorites', [('Color Grade', Icons.palette), ('Noise Gate', Icons.noise_aware)]),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: folders.map((f) => _toolFolder(f.$1, f.$2)).toList(),
    );
  }

  Widget _toolFolder(String name, List<(String, IconData)> items) {
    return ExpansionTile(
      title: Text(i18n.tr(name), style: const TextStyle(fontSize: 10, color: Colors.grey)),
      childrenPadding: EdgeInsets.zero,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      dense: true,
      children: items.map((e) => Container(
        padding: const EdgeInsets.only(left: 24, right: 8, top: 3, bottom: 3),
        child: Row(
          children: [
            Icon(e.$2, size: 12, color: Colors.white54),
            const SizedBox(width: 6),
            Text(e.$1, style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
      )).toList(),
    );
  }

  // ── VIEWPORT ──────────────────────────────────────────

  Widget _buildViewport() {
    return Container(
      color: const Color(0xFF0A0A14),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 480,
              height: 270,
              decoration: BoxDecoration(
                color: const Color(0xFF000008),
                border: Border.all(color: Colors.white12),
              ),
              child: Stack(
                children: [
                  // Frame counter
                  Positioned(
                    top: 6, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(2),
                      ),
                      child: Tr('DYLAN', style: TextStyle(fontSize: 9, color: Colors.white60)),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.movie_creation_outlined,
                        size: 48, color: Colors.white24),
                  ),
                  // Keyframe track bar
                  Positioned(
                    bottom: 28, left: 0, right: 0, height: 4,
                    child: Container(color: const Color(0xFF2A2A3E)),
                  ),
                  // Playback controls
                  Positioned(
                    bottom: 4, left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _smallBtn(Icons.skip_previous, onTap: () => setState(() => _currentTime = 0)),
                        _smallBtn(_isPlaying ? Icons.pause : Icons.play_arrow, onTap: _togglePlay),
                        _smallBtn(Icons.skip_next),
                        const SizedBox(width: 12),
                        Text(_formatTime(_currentTime),
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey)),
                        const SizedBox(width: 12),
                        _smallBtn(Icons.loop),
                        _smallBtn(Icons.bookmark_border),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TIMELINE AREA (flex) ──────────────────────────────

  Widget _buildTimelineArea() {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF0F0F1A),
            child: TimelineCanvas(
              tracks: _tracks,
              duration: _duration,
              currentTime: _currentTime,
              onSeek: (t) => setState(() => _currentTime = t),
              onPlayPause: _togglePlay,
              isPlaying: _isPlaying,
            ),
          ),
        ),
        if (_mixerVisible) ...[
          const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
          _buildMixerPanel(),
        ],
      ],
    );
  }

  // ── MIXER_PANEL (160px) ───────────────────────────────

  Widget _buildMixerPanel() {
    return Container(
      width: 160,
      color: const Color(0xFF12121E),
      child: Column(
        children: [
          _panelHeader('Mixer', Icons.equalizer),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          Expanded(
            child: Row(
              children: [
                _mixerChannel('A1', 'DYLAN', const Color(0xFF2E8B57), 0.65),
                _mixerChannel('A2', 'SOUNDTRACK', const Color(0xFFCD853F), 0.72),
                _mixerBus('Bus1'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mixerChannel(String id, String name, Color color, double level) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(i18n.tr(name), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white70)),
            ),
            // FX buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _fxDot('FX', false),
                const SizedBox(width: 4),
                _fxDot('EQ', true),
              ],
            ),
            const SizedBox(height: 4),
            // VU meter
            Expanded(
              child: Container(
                width: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: const Color(0xFF0F0F1A),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 80 * level,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [color, color.withValues(alpha: 0.3), const Color(0xFFCD5C5C)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Fader
            Container(
              height: 40, width: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 4, width: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(i18n.tr(id), style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mixerBus(String name) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF8B4513), width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(i18n.tr(name), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.orangeAccent)),
            ),
            _fxDot('FX', false),
            const SizedBox(height: 2),
            _fxDot('EQ', false),
            const Spacer(),
            Container(
              height: 50, width: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 6, width: 18,
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(i18n.tr(name), style: const TextStyle(fontSize: 9, color: Colors.orangeAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fxDot(String label, bool active) {
    return Container(
      width: 18, height: 12,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF699EFF) : const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Center(child: Text(i18n.tr(label), style: TextStyle(fontSize: 6, color: active ? Colors.white : Colors.grey))),
    );
  }

  // ── RIGHT_INSPECTOR (280px) ───────────────────────────

  Widget _buildRightPanel() {
    return Container(
      width: 280,
      color: const Color(0xFF12121E),
      child: Column(
        children: [
          _buildInspectorTabs(),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          Expanded(child: _buildInspectorContent()),
        ],
      ),
    );
  }

  Widget _buildInspectorTabs() {
    final tabs = ['Video', 'Audio', 'Effects', 'Transition', 'Image', 'File'];
    return Container(
      height: 28,
      color: const Color(0xFF0F0F1A),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: tabs.map((t) => GestureDetector(
          onTap: () => setState(() => _inspectorTab = t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _inspectorTab == t ? const Color(0xFF699EFF) : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(t, style: TextStyle(
              fontSize: 10,
              color: _inspectorTab == t ? Colors.white : Colors.grey,
              fontWeight: _inspectorTab == t ? FontWeight.w600 : FontWeight.normal,
            )),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInspectorContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _foldGroup('Transform', [
          _propRow('Zoom X', '1.000', numInput: true),
          _propRow('Zoom Y', '1.000', numInput: true),
          _propRow('Position X', '0.000', numInput: true),
          _propRow('Position Y', '0.000', numInput: true),
          _propRow('Rotation', '0.000', numInput: true),
          _propRow('Anchor X', '0.500', numInput: true),
          _propRow('Anchor Y', '0.500', numInput: true),
          _propRow('Pitch', '0.000', numInput: true),
          _propRow('Yaw', '0.000', numInput: true),
          _flipRow(),
        ]),
        _foldGroup('Smart Reframe', []),
        _foldGroup('Cropping', []),
        _foldGroup('Dynamic Zoom', []),
        _foldGroup('Composite', [
          _propRow('Mode', 'Normal', dropdown: true),
          _propRow('Opacity', '100.00', slider: true),
        ]),
        _foldGroup('Speed Change', []),
        _foldGroup('Stabilization', []),
        _foldGroup('Lens Correction', []),
        _foldGroup('AI Tuning', [
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: i18n.tr('Adjust color to warm cinematic...'),
                    hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                    filled: true, fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  maxLines: 2,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Tr('Apply', style: TextStyle(fontSize: 10, color: Color(0xFF699EFF))),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _foldGroup(String title, List<Widget> children) {
    final isOpen = _foldGroups[title] ?? true;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _foldGroups[title] = !isOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFF0F0F1A),
            child: Row(
              children: [
                Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(i18n.tr(title), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                const Spacer(),
                if (title == 'Transform')
                  Tr('✕', style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
        if (isOpen) ...children,
        const Divider(height: 1, color: Color(0xFF2A2A3E)),
      ],
    );
  }

  Widget _propRow(String label, String value, {bool numInput = false, bool dropdown = false, bool slider = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(i18n.tr(label), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          if (numInput)
            Expanded(
              child: Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: TextField(
                  controller: TextEditingController(text: value),
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
            )
          else if (dropdown)
            Expanded(
              child: Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isDense: true,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white),
                    items: [value].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (_) {},
                  ),
                ),
              ),
            )
          else if (slider)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: double.tryParse(value) ?? 100,
                      min: 0, max: 100,
                      onChanged: (_) {},
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Container(
                      height: 20, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(i18n.tr(value), style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white)),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(i18n.tr(value), style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _flipRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 80, child: Tr('Flip', style: TextStyle(fontSize: 10, color: Colors.grey))),
          _flipBtn(Icons.flip, 'H'),
          const SizedBox(width: 4),
          _flipBtn(Icons.flip_to_front, 'V'),
        ],
      ),
    );
  }

  Widget _flipBtn(IconData icon, String label) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 12),
      label: Text(i18n.tr(label), style: const TextStyle(fontSize: 10)),
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: Color(0xFF2A2A3E)),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _panelHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 6),
          Text(i18n.tr(title), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _smallBtn(IconData icon, {VoidCallback? onTap}) {
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
    );
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) _simulatePlayback();
  }

  void _simulatePlayback() async {
    while (_isPlaying && mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() {
        _currentTime += 0.05;
        if (_currentTime >= _duration) {
          _currentTime = 0;
          _isPlaying = false;
        }
      });
    }
  }

  String _formatTime(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toStringAsFixed(1).padLeft(4, '0');
    return '$m:$s';
  }
}
