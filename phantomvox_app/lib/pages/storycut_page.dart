import 'package:flutter/material.dart';
import '../widgets/tr.dart';
import '../../services/i18n_service.dart';
import '../services/i18n_service.dart';

/// StoryCut page — quick story editing workspace
class StoryCutPage extends StatefulWidget {
  const StoryCutPage({super.key});

  @override
  State<StoryCutPage> createState() => _StoryCutPageState();
}

class _StoryCutPageState extends State<StoryCutPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          // Header toolbar
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF0D0D1A),
            child: Row(
              children: [
                _toolbarBtn('Media Pool'),
                const SizedBox(width: 2),
                _toolbarBtn('Sync Bin'),
                const SizedBox(width: 2),
                _toolbarBtn('Transitions'),
                const SizedBox(width: 2),
                _toolbarBtn('Titles'),
                const SizedBox(width: 2),
                _toolbarBtn('Effects'),
                const Spacer(),
                Tr('00:04:18:12', style: TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                Container(
                  width: 2, height: 16,
                  color: const Color(0xFF2A2A3E),
                ),
                const SizedBox(width: 8),
                _iconBtn(Icons.file_download, 'Quick Export'),
                const SizedBox(width: 4),
                _iconBtn(Icons.fullscreen, ''),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    border: Border.all(color: const Color(0xFF6C63FF)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_fix_high, size: 12, color: Color(0xFF6C63FF)),
                      SizedBox(width: 4),
                      Tr('AI Cut', style: TextStyle(fontSize: 10, color: Color(0xFF6C63FF))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Info bar
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF12121E),
            child: Row(
              children: [
                Tr('Clips: 3 Minute Edit 1', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                Tr('Source TC: 00:04:18:12', style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
                const SizedBox(width: 16),
                // VU level bar
                _vuBar(),
              ],
            ),
          ),
          // Main body
          Expanded(
            child: Row(
              children: [
                // Left: material browser
                _buildMaterialBrowser(),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                // Center: viewport
                Expanded(flex: 2, child: _buildViewport()),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                // Right: level indicator
                _buildLevelIndicator(),
              ],
            ),
          ),
          // AI QuickBar (collapsible)
          _buildAIQuickBar(),
          // Bottom: story timeline
          Container(
            height: 120,
            color: const Color(0xFF0A0A14),
            child: Row(
              children: [
                // Track controls
                SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      _trackLabel('V1', const Color(0xFF1565C0)),
                      _trackLabel('A1', const Color(0xFF2E7D32)),
                      _trackLabel('A2', const Color(0xFF2E7D32)),
                    ],
                  ),
                ),
                // Story timeline content
                Expanded(
                  child: Stack(
                    children: [
                      // Timeline background
                      CustomPaint(
                        size: Size.infinite,
                        painter: _StoryTimelinePainter(),
                      ),
                      // Ruler
                      Positioned(
                        top: 0, left: 0, right: 0, height: 20,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _RulerPainter(),
                        ),
                      ),
                      // Clips
                      Positioned(
                        top: 22, left: 40, width: 80, height: 28,
                        child: _clipTile('Scene 1', const Color(0xFF1565C0)),
                      ),
                      Positioned(
                        top: 22, left: 140, width: 140, height: 28,
                        child: _clipTile('Scene 2', const Color(0xFF1565C0)),
                      ),
                      Positioned(
                        top: 52, left: 20, width: 120, height: 24,
                        child: _clipTile('Voiceover', const Color(0xFF2E7D32)),
                      ),
                      Positioned(
                        top: 52, left: 160, width: 60, height: 24,
                        child: _clipTile('Music', const Color(0xFF2E7D32)),
                      ),
                      Positioned(
                        top: 80, left: 60, width: 100, height: 24,
                        child: _clipTile('SFX', const Color(0xFF2E7D32)),
                      ),
                      // Playhead
                      Positioned(
                        top: 0, left: 200, width: 2, bottom: 0,
                        child: Container(color: const Color(0xFFFF5252)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Left: material browser ──

  Widget _buildMaterialBrowser() {
    return SizedBox(
      width: 220,
      child: Column(
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF12121E),
            alignment: Alignment.centerLeft,
            child: Tr('Material Browser', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          // Search bar
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: const Color(0xFF16162A),
            child: TextField(
              style: const TextStyle(fontSize: 11, color: Colors.white),
              decoration: InputDecoration(
                hintText: i18n.tr('Search clips...'),
                hintStyle: TextStyle(fontSize: 10, color: Colors.grey[600]),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, size: 14, color: Colors.grey[600]),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          // Thumbnail grid (5 columns)
          Expanded(
            child: GridView.count(
              crossAxisCount: 5,
              padding: const EdgeInsets.all(4),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 16 / 9,
              children: List.generate(18, (i) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A30),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Icon(Icons.movie, size: 20, color: Colors.grey[700]),
                      ),
                    ),
                    Container(
                      height: 16,
                      color: const Color(0xFF12121E),
                      alignment: Alignment.center,
                      child: Text('Clip ${i + 1}',
                          style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                    ),
                  ],
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  // ── Center: viewport ──

  Widget _buildViewport() {
    return Column(
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.only(left: 8),
          color: const Color(0xFF12121E),
          alignment: Alignment.centerLeft,
          child: Tr('Viewport', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF0A0A14),
            child: Center(
              child: Container(
                width: 360, height: 240,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Stack(
                  children: [
                    // Scene content
                    CustomPaint(painter: _SceneGradientPainter()),
                    // Playback controls
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ctrlBtn(Icons.skip_previous, 16),
                            _ctrlBtn(Icons.play_arrow, 20),
                            _ctrlBtn(Icons.stop, 16),
                            _ctrlBtn(Icons.skip_next, 16),
                            _ctrlBtn(Icons.replay, 16),
                            const SizedBox(width: 12),
                            Tr('01:02:58:07', style: TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ),
                    // AI QuickCut badge
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_fix_high, size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Tr('AI Scene', style: TextStyle(fontSize: 8, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Scene markers bar
        Container(
          height: 24,
          color: const Color(0xFF12121E),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _markerChip('Scene 1', true),
              const SizedBox(width: 4),
              _markerChip('Scene 2', false),
              const SizedBox(width: 4),
              _markerChip('Scene 3', false),
              const Spacer(),
              _markerChip('+ Add Marker', false),
            ],
          ),
        ),
      ],
    );
  }

  // ── Right: level indicator ──

  Widget _buildLevelIndicator() {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF12121E),
            alignment: Alignment.centerLeft,
            child: Tr('Levels', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF0F0F1A),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _levelMeter('L', -6),
                  _levelMeter('R', -8),
                  const SizedBox(height: 8),
                  Tr('Mix', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  _levelMeter('M', -12),
                  const Divider(color: Color(0xFF2A2A3E), height: 8),
                  Tr('Bus 1', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  _levelMeter('B', -18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI QuickBar ──

  bool _aiBarExpanded = true;

  Widget _buildAIQuickBar() {
    return Container(
      height: _aiBarExpanded ? 40 : 20,
      color: const Color(0xFF12121E),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _aiBarExpanded = !_aiBarExpanded),
            child: Container(
              width: 24, height: 40,
              alignment: Alignment.center,
              child: Icon(
                _aiBarExpanded ? Icons.expand_less : Icons.expand_more,
                size: 14, color: Colors.grey,
              ),
            ),
          ),
          if (_aiBarExpanded) ...[
            Container(width: 1, height: 20, color: const Color(0xFF2A2A3E)),
            const SizedBox(width: 8),
            _aiQuickBtn(Icons.auto_fix_high, 'Quick Cut', const Color(0xFF6C63FF)),
            const SizedBox(width: 8),
            _aiQuickBtn(Icons.transcribe, 'Transcript', const Color(0xFF448AFF)),
            const SizedBox(width: 8),
            _aiQuickBtn(Icons.video_label, 'Scene Detect', const Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            _aiQuickBtn(Icons.voice_over_off, 'Denoise', const Color(0xFFFF9800)),
          ],
          const Spacer(),
          if (_aiBarExpanded)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Tr('AI QuickBar', style: TextStyle(fontSize: 9, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _aiQuickBtn(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(i18n.tr(label),
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Reusable widgets ──

  Widget _toolbarBtn(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(i18n.tr(label),
          style: const TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }

  Widget _iconBtn(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(i18n.tr(label), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, double size) {
    return SizedBox(
      width: 28, height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: size, color: Colors.white70),
        onPressed: () {},
      ),
    );
  }

  Widget _trackLabel(String label, Color color) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFF1A1A2E), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 3, height: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(i18n.tr(label),
              style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _clipTile(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      alignment: Alignment.center,
      child: Text(i18n.tr(label),
          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }

  Widget _markerChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6C63FF) : const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(i18n.tr(label),
          style: TextStyle(fontSize: 9, color: active ? Colors.white : Colors.grey)),
    );
  }

  Widget _vuBar() {
    return SizedBox(
      width: 80, height: 10,
      child: Row(
        children: List.generate(12, (i) {
          final level = i / 12;
          Color c;
          if (level < 0.6) c = Colors.green;
          else if (level < 0.85) c = Colors.yellow;
          else c = Colors.red;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: i < 8 ? c.withOpacity(0.8) : c.withOpacity(0.15),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _levelMeter(String label, double dB) {
    final normalized = (dB + 50) / 55;
    return Column(
      children: [
        Row(
          children: [
            Text(i18n.tr(label),
                style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace')),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: normalized.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: dB > -3 ? Colors.red : dB > -10 ? Colors.yellow : Colors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Custom painters ──

class _SceneGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Dark gradient with scene image simulation
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0D0D18));
    // Mountain-like shape
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.lineTo(size.width * 0.2, size.height * 0.3);
    path.lineTo(size.width * 0.35, size.height * 0.45);
    path.lineTo(size.width * 0.5, size.height * 0.15);
    path.lineTo(size.width * 0.65, size.height * 0.35);
    path.lineTo(size.width * 0.8, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF1A237E).withOpacity(0.6));

    // Second layer
    final path2 = Path();
    path2.moveTo(0, size.height * 0.8);
    path2.lineTo(size.width * 0.15, size.height * 0.5);
    path2.lineTo(size.width * 0.3, size.height * 0.65);
    path2.lineTo(size.width * 0.45, size.height * 0.4);
    path2.lineTo(size.width * 0.6, size.height * 0.55);
    path2.lineTo(size.width * 0.75, size.height * 0.35);
    path2.lineTo(size.width, size.height * 0.55);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, Paint()..color = const Color(0xFF0D47A1).withOpacity(0.4));
  }

  @override
  bool shouldRepaint(_SceneGradientPainter old) => false;
}

class _StoryTimelinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark background
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0A0A14));
    // Track row backgrounds
    final paints = [const Color(0xFF141424), const Color(0xFF181830), const Color(0xFF141424)];
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * 30.0 + 20.0, size.width, 28.0),
        Paint()..color = paints[i].withOpacity(0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_StoryTimelinePainter old) => false;
}

class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1A1A2E));
    final paint = Paint()
      ..color = const Color(0xFF3A3A5E)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => false;
}
