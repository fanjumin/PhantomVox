import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/timeline_canvas.dart';

/// ProEdit page — 4-panel layout: media pool, viewport, timeline, inspector
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
    } catch (e) {
      // Offline — use mock data for UI demo
      _tracks = [
        {'id': 'v1', 'type': 'video', 'name': 'Video 1', 'index': 0, 'clips': [
          {'id': 'c1', 'name': 'Intro.mp4', 'start': 0.0, 'duration': 5.0, 'asset_path': ''},
          {'id': 'c2', 'name': 'Main.mp4', 'start': 5.0, 'duration': 8.0, 'asset_path': ''},
        ]},
        {'id': 'v2', 'type': 'video', 'name': 'Video 2 (B-Roll)', 'index': 1, 'clips': [
          {'id': 'c3', 'name': 'B-Roll.mp4', 'start': 1.0, 'duration': 4.0, 'asset_path': ''},
        ]},
        {'id': 'a1', 'type': 'audio', 'name': 'Audio 1 (VO)', 'index': 2, 'clips': [
          {'id': 'c4', 'name': 'Voiceover.wav', 'start': 2.0, 'duration': 10.0, 'asset_path': ''},
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
          // Top bar
          _buildTopBar(),
          // Main editor area
          Expanded(
            child: Row(
              children: [
                // Left: Media Pool
                _buildMediaPool(),
                const VerticalDivider(width: 1),
                // Center: Viewport + Timeline
                Expanded(
                  child: Column(
                    children: [
                      // Viewport
                      Expanded(flex: 3, child: _buildViewport()),
                      const Divider(height: 1),
                      // Timeline
                      Expanded(
                        flex: 2,
                        child: _buildTimeline(),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                // Right: Inspector + Mixer
                _buildRightPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          const Text('ProEdit',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 16),
          _chip(Icons.content_cut, 'Split'),
          const SizedBox(width: 4),
          _chip(Icons.crop, 'Trim'),
          const SizedBox(width: 4),
          _chip(Icons.transit_enterexit, 'Transition'),
          const SizedBox(width: 4),
          _chip(Icons.speed, 'Speed'),
          const Spacer(),
          Text(_timeline?['name'] ?? 'Untitled',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 16),
          _chip(Icons.play_arrow, 'Render', onTap: _showRenderInfo),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, {VoidCallback? onTap}) {
    return ActionChip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildMediaPool() {
    return Container(
      width: 200,
      color: const Color(0xFF12121E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader('Media Pool', Icons.folder),
          const Divider(height: 1),
          const Expanded(
            child: Center(
              child: Text('Drop media here',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewport() {
    return Container(
      color: const Color(0xFF0A0A14),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 320,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF000008),
                border: Border.all(color: Colors.white12),
              ),
              child: const Center(
                child: Icon(Icons.movie_creation_outlined,
                    size: 48, color: Colors.white24),
              ),
            ),
          ),
          // Playback controls overlay
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _smallBtn(Icons.skip_previous),
                _smallBtn(_isPlaying ? Icons.pause : Icons.play_arrow,
                    onTap: _togglePlay),
                _smallBtn(Icons.skip_next),
                const SizedBox(width: 12),
                Text(_formatTime(_currentTime),
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace', color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      color: const Color(0xFF0F0F1A),
      child: TimelineCanvas(
        tracks: _tracks,
        duration: _duration,
        currentTime: _currentTime,
        onSeek: (t) => setState(() => _currentTime = t),
        onPlayPause: _togglePlay,
        isPlaying: _isPlaying,
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      width: 250,
      color: const Color(0xFF12121E),
      child: Column(
        children: [
          _panelHeader('Inspector', Icons.tune),
          const Divider(height: 1),
          // Advanced transform
          _propGroup('Transform', [
            _propRow('Zoom X', '1.000'),
            _propRow('Zoom Y', '1.000'),
            _propRow('Position X', '0.0'),
            _propRow('Position Y', '0.0'),
            _propRow('Rotation', '0.0'),
            _propRow('Anchor X', '0.5'),
            _propRow('Anchor Y', '0.5'),
            _propRow('Pitch', '0.0'),
            _propRow('Yaw', '0.0'),
            _propRow('Flip', 'Off'),
          ]),
          const Divider(height: 1),
          _propGroup('Tools', [
            _propRow('Smart Reframe', 'Auto'),
            _propRow('Cropping', 'Off'),
            _propRow('Dynamic Zoom', 'Off'),
            _propRow('Speed', '1.00x'),
            _propRow('Stabilization', 'Off'),
          ]),
          const Divider(height: 1),
          // Mixer (compact)
          _panelHeader('Mixer', Icons.equalizer),
          Expanded(
            child: ListView(
              children: _tracks
                  .where((t) => t['type'] == 'audio')
                  .map((t) => _mixerChannel(t))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _propGroup(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        ...rows,
      ],
    );
  }

  Widget _propRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(value,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mixerChannel(Map<String, dynamic> track) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(track['name'] ?? '',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          const Icon(Icons.equalizer, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Center(
              child: Icon(Icons.keyboard_arrow_up, size: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(IconData icon, {VoidCallback? onTap}) {
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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

  void _showRenderInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Render Timeline'),
        content: Text(
            'Timeline: ${_tracks.length} tracks\n'
            'Duration: ${_duration.toStringAsFixed(1)}s\n'
            'Clips: ${_tracks.fold<int>(0, (s, t) => s + ((t['clips'] as List<dynamic>?)?.length ?? 0))}\n\n'
            'Start python3 -m modules.api_server\n'
            'then POST /api/v1/timelines/{id}/render'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTime(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toStringAsFixed(1).padLeft(4, '0');
    return '$m:$s';
  }
}
