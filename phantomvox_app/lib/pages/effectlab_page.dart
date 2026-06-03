import 'package:flutter/material.dart';

/// EffectLab page — visual effects compositing workspace
class EffectLabPage extends StatefulWidget {
  const EffectLabPage({super.key});

  @override
  State<EffectLabPage> createState() => _EffectLabPageState();
}

class _EffectLabPageState extends State<EffectLabPage> {
  int _selectedNode = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          // Header
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF0D0D1A),
            child: Row(
              children: [
                const Text('EffectLab',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                _headerBtn(Icons.auto_fix_high, 'AI Generate'),
                const SizedBox(width: 8),
                _headerBtn(Icons.playlist_add, 'Effects'),
                const SizedBox(width: 8),
                _headerBtn(Icons.splitscreen, 'Split View'),
                const SizedBox(width: 8),
                _headerBtn(Icons.more_horiz, ''),
              ],
            ),
          ),
          // Main body
          Expanded(
            child: Column(
              children: [
                // Top: preview area
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      // Left: isolated element preview
                      _buildLeftPreview(),
                      const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                      // Center: output viewport
                      Expanded(flex: 2, child: _buildOutputViewport()),
                      const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                      // Right: inspector
                      _buildInspector(),
                    ],
                  ),
                ),
                // Divider
                Container(height: 1, color: const Color(0xFF2A2A3E)),
                // Bottom: node workspace + frame timeline
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _buildNodeWorkspace()),
                      const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                      _buildFrameTimeline(),
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

  // ── Left: isolated element preview ──

  Widget _buildLeftPreview() {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF12121E),
            alignment: Alignment.centerLeft,
            child: const Text('Element Preview',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF0A0A14),
              child: Center(
                child: Container(
                  width: 120, height: 68,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: const Color(0xFF2A2A3E), width: 0.5),
                  ),
                  child: const Center(
                    child: Text('Effect Only',
                        style: TextStyle(fontSize: 9, color: Colors.white38)),
                  ),
                ),
              ),
            ),
          ),
          // Coordinates label
          Container(
            height: 20,
            color: const Color(0xFF12121E),
            padding: const EdgeInsets.only(left: 8),
            alignment: Alignment.centerLeft,
            child: const Text('X: 320 | Y: 240 | Z: 0',
                style: TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  // ── Center: output viewport ──

  Widget _buildOutputViewport() {
    return Column(
      children: [
        Container(
          height: 24,
          padding: const EdgeInsets.only(left: 8),
          color: const Color(0xFF12121E),
          alignment: Alignment.centerLeft,
          child: const Text('Output',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF0A0A14),
            child: Center(
              child: Container(
                width: 320, height: 180,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Stack(
                  children: [
                    // Mock composite content
                    CustomPaint(painter: _EffectGradientPainter()),
                    // Overlay controls
                    Positioned(
                      left: 8, bottom: 8,
                      child: Row(
                        children: [
                          _smallBtn(Icons.skip_previous, 16),
                          _smallBtn(Icons.play_arrow, 16),
                          _smallBtn(Icons.skip_next, 16),
                          const SizedBox(width: 8),
                          const Text('Frame 43',
                              style: TextStyle(fontSize: 9, color: Colors.white70, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Right: inspector ──

  Widget _buildInspector() {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF12121E),
            alignment: Alignment.centerLeft,
            child: const Text('Inspector',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _sectionTitle('Transform'),
                _paramRow('Position X', '320'),
                _paramRow('Position Y', '240'),
                _paramRow('Scale', '1.0'),
                _paramRow('Rotation', '0°'),
                const SizedBox(height: 8),
                _sectionTitle('Renderer'),
                _paramRow('Blend Mode', 'Normal'),
                _paramRow('Opacity', '100%'),
                _paramRow('Camera', 'Default'),
                _paramRow('Eye', 'Mono'),
                const SizedBox(height: 8),
                _sectionTitle('Tools / Modifiers'),
                _toolBtn('Corner Pin'),
                _toolBtn('Corner Blur'),
                _toolBtn('Bump Map'),
                _toolBtn('Defocus'),
                _toolBtn('Glow'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Node workspace ──

  Widget _buildNodeWorkspace() {
    return Column(
      children: [
        Container(
          height: 24,
          padding: const EdgeInsets.only(left: 8),
          color: const Color(0xFF12121E),
          alignment: Alignment.centerLeft,
          child: const Text('Node Graph',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF0D0D18),
            child: Stack(
              children: [
                // Grid background
                CustomPaint(
                  size: Size.infinite,
                  painter: _GridPainter2(),
                ),
                // Nodes arranged in a merge chain
                _node('MediaIn1', 16, 20, const Color(0xFF448AFF), false),
                _node('MediaIn2', 16, 60, const Color(0xFF448AFF), false),
                _node('Merge', 80, 38, const Color(0xFF4CAF50), false),
                _node('Glow', 140, 50, const Color(0xFFFF9800), true),
                _node('Transform', 200, 38, const Color(0xFFAB47BC), false),
                _node('MediaOut', 260, 20, const Color(0xFFFF5252), false),
                // Inline arrows connecting nodes
                Positioned(
                  left: 52, top: 42,
                  child: Text('→', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
                Positioned(
                  left: 116, top: 54,
                  child: Text('→', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
                Positioned(
                  left: 176, top: 42,
                  child: Text('→', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
                Positioned(
                  left: 236, top: 22,
                  child: Text('→', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
                // Right-click context hint
                Positioned(
                  right: 8, bottom: 8,
                  child: Text('[right-click for AI]',
                      style: TextStyle(fontSize: 8, color: Colors.grey[700])),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Frame timeline ──

  Widget _buildFrameTimeline() {
    return SizedBox(
      width: 180,
      child: Column(
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF12121E),
            alignment: Alignment.centerLeft,
            child: const Text('Frame Timeline',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF0F0F1A),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // Frame info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Text('In: 13.0', style: TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace')),
                        SizedBox(width: 8),
                        Text('Out: 58.0', style: TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace')),
                        SizedBox(width: 8),
                        Text('Cur: 43.0', style: TextStyle(fontSize: 9, color: Color(0xFFFF5252), fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mini frame strip
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2A2A3E)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Column(
                        children: [
                          // Keyframe markers row
                          Expanded(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _KeyframePainter(),
                            ),
                          ),
                          // Frame counter
                          Container(
                            height: 16,
                            color: const Color(0xFF12121E),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: List.generate(10, (i) => Expanded(
                                child: Text('${i * 10}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 7, color: Colors.grey[700])),
                              )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Play controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _smallBtn(Icons.first_page, 14),
                      _smallBtn(Icons.skip_previous, 16),
                      _smallBtn(Icons.play_arrow, 16),
                      _smallBtn(Icons.skip_next, 16),
                      _smallBtn(Icons.last_page, 14),
                      const SizedBox(width: 8),
                      _smallBtn(Icons.add, 14),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ──

  Widget _headerBtn(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 28,
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _smallBtn(IconData icon, double size) {
    return SizedBox(
      width: 22, height: 22,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: size, color: Colors.white70),
        onPressed: () {},
      ),
    );
  }

  Widget _node(String label, double left, double top, Color color, bool selected) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => setState(() {}),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(selected ? 0.3 : 0.15),
            border: Border.all(
              color: selected ? Colors.white : color,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 9,
                color: selected ? Colors.white : color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
    );
  }

  Widget _paramRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(value,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        onTap: () {},
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ),
      ),
    );
  }
}

// ── Custom painters ──

class _EffectGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Dark base
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0D0D18));
    // Glow effect simulation
    final center = Offset(size.width / 2, size.height / 2);
    final glow = RadialGradient(
      colors: [
        const Color(0xFFFF6B35).withOpacity(0.4),
        const Color(0xFF0D0D18).withOpacity(0),
      ],
    );
    canvas.drawCircle(center, size.width * 0.4, Paint()..shader = glow.createShader(rect));
    // Particle-like dots
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.3);
    final seeds = [13, 27, 41, 55, 69, 83, 97];
    for (int i = 0; i < seeds.length; i++) {
      final x = (seeds[i] * 7.3) % size.width;
      final y = (seeds[i] * 11.7) % size.height;
      final r = (seeds[i] % 3) + 1.0;
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_EffectGradientPainter old) => false;
}

class _GridPainter2 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.height, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter2 old) => false;
}

class _KeyframePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2A2A3E);
    // Keyframe diamonds
    final keyframes = [0.1, 0.25, 0.5, 0.75, 0.9];
    for (final kf in keyframes) {
      final x = size.width * kf;
      final y = size.height / 2;
      final diamond = Path()
        ..moveTo(x, y - 4)
        ..lineTo(x + 3, y)
        ..lineTo(x, y + 4)
        ..lineTo(x - 3, y)
        ..close();
      canvas.drawPath(diamond, Paint()..color = const Color(0xFFFFD600));
    }
    // Playhead line
    canvas.drawLine(
      Offset(size.width * 0.43, 0),
      Offset(size.width * 0.43, size.height),
      Paint()
        ..color = const Color(0xFFFF5252)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_KeyframePainter old) => false;
}
