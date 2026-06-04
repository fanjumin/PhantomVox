import 'dart:math' as math;
import 'package:flutter/material.dart';

/// EffectLab page — visual effects compositing workspace (Fusion-style)
/// Reference: DaVinci Resolve Fusion workspace
/// Layout: TOP_BAR + (LEFT_PREVIEW + OUTPUT_VIEWPORT + RIGHT_INSPECTOR) + BOTTOM_FRAME_TIMELINE + BOTTOM_NODE_CANVAS
class EffectLabPage extends StatefulWidget {
  const EffectLabPage({super.key});

  @override
  State<EffectLabPage> createState() => _EffectLabPageState();
}

class _EffectLabPageState extends State<EffectLabPage> {
  int _selectedNode = 3;
  String _inspectorTab = 'Tools';
  final List<String> _tabOptions = ['Tools', 'Modifiers'];
  String _rendererSubtab = 'Controls';

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
                _buildLeftPreview(),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                Expanded(flex: 2, child: _buildOutputViewport()),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                _buildInspector(),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF2A2A3E)),
          _buildFrameTimeline(),
          Container(height: 1, color: const Color(0xFF2A2A3E)),
          Expanded(child: _buildNodeCanvas()),
        ],
      ),
    );
  }

  // ── TOP_BAR (32px) ────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF0D0D1A),
      child: Row(
        children: [
          _tbBtn(Icons.folder, 'Media Pool'),
          const SizedBox(width: 4),
          _tbBtn(Icons.auto_fix_high, 'Effects'),
          const SizedBox(width: 4),
          _tbBtn(Icons.movie, 'Clips'),
          const SizedBox(width: 4),
          _tbBtn(Icons.account_tree, 'Nodes'),
          const SizedBox(width: 12),
          Container(width: 1, height: 16, color: const Color(0xFF2A2A3E)),
          const SizedBox(width: 8),
          const Text('The Investigator - Car VFX | Edited',
              style: TextStyle(fontSize: 9, color: Colors.white54)),
          const Spacer(),
          _tbLabel('Zoom: 400%'),
          const SizedBox(width: 6),
          _tbLabel('uMerge1'),
          const SizedBox(width: 6),
          _tbLabel('MediaOut'),
          const SizedBox(width: 6),
          _tbLabel('Preset: Default'),
          const SizedBox(width: 6),
          _tbLabel('2048x1080 float32'),
          const SizedBox(width: 8),
          _tbBtn(Icons.show_chart, 'Spline'),
          _tbBtn(Icons.keyboard, 'Keyframes'),
          _tbBtn(Icons.info_outline, 'Metadata'),
          _tbBtn(Icons.tune, 'Inspector'),
          _tbBtn(Icons.auto_awesome, 'AI Generate', accent: true),
        ],
      ),
    );
  }

  Widget _tbBtn(IconData icon, String label, {bool accent = false}) {
    final color = accent ? const Color(0xFF699EFF) : Colors.grey;
    return TextButton.icon(
      icon: Icon(icon, size: 11, color: color),
      label: Text(label, style: TextStyle(fontSize: 8, color: color)),
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _tbLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 8, color: Colors.grey));
  }

  // ── LEFT_PREVIEW (180px) ──────────────────────────────

  Widget _buildLeftPreview() {
    return Container(
      width: 180,
      color: const Color(0xFF12121E),
      child: Column(
        children: [
          Container(
            height: 22,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF0D0D1A),
            alignment: Alignment.centerLeft,
            child: const Text('uMerge1',
                style: TextStyle(fontSize: 9, color: Color(0xFF699EFF), fontWeight: FontWeight.w600)),
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
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: const Center(
                    child: Text('Explosion FX',
                        style: TextStyle(fontSize: 8, color: Colors.white38)),
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 18,
            color: const Color(0xFF12121E),
            padding: const EdgeInsets.only(left: 8),
            alignment: Alignment.centerLeft,
            child: const Text('X: 320 | Y: 240 | Z: 0',
                style: TextStyle(fontSize: 8, color: Colors.grey, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  // ── OUTPUT_VIEWPORT ───────────────────────────────────

  Widget _buildOutputViewport() {
    return Column(
      children: [
        Container(
          height: 22,
          padding: const EdgeInsets.only(left: 8),
          color: const Color(0xFF12121E),
          alignment: Alignment.centerLeft,
          child: const Text('Output | MediaOut',
              style: TextStyle(fontSize: 9, color: Colors.grey)),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF0A0A14),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 400, height: 225,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF2A2A3E)),
                    ),
                    child: Stack(
                      children: [
                        CustomPaint(painter: _EffectGradientPainter()),
                        Positioned(
                          left: 8, bottom: 8,
                          child: Row(
                            children: [
                              _smallBtn(Icons.skip_previous),
                              _smallBtn(Icons.play_arrow),
                              _smallBtn(Icons.skip_next),
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
                Positioned(
                  right: 12, bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text('2048x1080 float32',
                        style: TextStyle(fontSize: 7, color: Colors.white60)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── RIGHT_INSPECTOR (260px) ───────────────────────────

  Widget _buildInspector() {
    return Container(
      width: 260,
      color: const Color(0xFF12121E),
      child: Column(
        children: [
          // Tab bar
          Container(
            height: 22,
            color: const Color(0xFF0D0D1A),
            child: Row(
              children: _tabOptions.map((t) => GestureDetector(
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
                    fontSize: 9, color: _inspectorTab == t ? Colors.white : Colors.grey,
                  )),
                ),
              )).toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          // Inspector content
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Renderer3D1 header
                Container(
                  padding: const EdgeInsets.all(6),
                  color: const Color(0xFF1A1A3E),
                  child: Row(
                    children: [
                      const Icon(Icons.view_in_ar, size: 12, color: Color(0xFF699EFF)),
                      const SizedBox(width: 4),
                      const Text('Renderer3D1', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      _insLabel('In'), _insInput('0'),
                      _insLabel('Out'), _insInput('155'),
                      _insLabel('Now'), _insInput('154'),
                    ],
                  ),
                ),
                // Subtabs
                Container(
                  height: 20,
                  color: const Color(0xFF0F0F1A),
                  child: Row(
                    children: ['Controls', 'Image', 'Settings'].map((t) => GestureDetector(
                      onTap: () => setState(() => _rendererSubtab = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _rendererSubtab == t ? const Color(0xFF699EFF) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Text(t, style: TextStyle(fontSize: 8, color: _rendererSubtab == t ? Colors.white : Colors.grey)),
                      ),
                    )).toList(),
                  ),
                ),
                // Controls content
                ..._buildControlsContent(),
                // Fold groups
                _foldGroup('Anti-Aliasing', []),
                _foldGroup('Accumulation Effects', []),
                _foldGroup('Lighting', [
                  _checkRow('Enable Lighting', true),
                  _checkRow('Shadows', false),
                  _paramRow('Shading Model', 'Smooth', dropdown: true),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Texture Depth', style: TextStyle(fontSize: 8, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _radioChip('int8', true),
                            const SizedBox(width: 4),
                            _radioChip('int16', false),
                            const SizedBox(width: 4),
                            _radioChip('float16', false),
                            const SizedBox(width: 4),
                            _radioChip('float32', false),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _paramRow('Transparency', 'Z Buffer', dropdown: true),
                  _checkRow('Wireframe', false),
                  _checkRow('Wire Antialias', true),
                ]),
                // AI Generate (original)
                _foldGroup('AI Effect Generation', [
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        TextField(
                          style: const TextStyle(fontSize: 9, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Describe the effect...',
                            hintStyle: const TextStyle(fontSize: 9, color: Colors.grey),
                            filled: true, fillColor: const Color(0xFF1A1A2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(3),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text('Generate', style: TextStyle(fontSize: 9, color: Color(0xFF699EFF))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildControlsContent() {
    return [
      // Camera & Eye
      _paramRow('Camera', 'Default', dropdown: true),
      _paramRow('Eye', 'Mono', dropdown: true),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text('Hardware Renderer',
                  style: TextStyle(fontSize: 8, color: Colors.grey)),
            ),
            const SizedBox(height: 4),
            _checkRow('Image', true, radio: true),
            _checkRow('Deep Image', false, radio: true),
            const Divider(height: 6, color: Color(0xFF2A2A3E)),
            const Text('Output Channels', style: TextStyle(fontSize: 8, color: Colors.grey)),
            const SizedBox(height: 2),
            _checkRow('RGBA', true),
            _checkRow('Z', false),
            _checkRow('Normal', false),
            _checkRow('Vector', true),
            _checkRow('Back Vector', false),
            _checkRow('Texture Coord', false),
            _checkRow('Object ID', false),
            _checkRow('Material ID', false),
            _checkRow('World Position', false),
          ],
        ),
      ),
    ];
  }

  Widget _paramRow(String label, String value, {bool dropdown = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey))),
          Expanded(
            child: Container(
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  if (dropdown) const Icon(Icons.arrow_drop_down, size: 12, color: Colors.grey),
                  Text(value, style: const TextStyle(fontSize: 8, color: Colors.white, fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkRow(String label, bool checked, {bool radio = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        children: [
          Icon(
            radio ? (checked ? Icons.radio_button_checked : Icons.radio_button_unchecked)
                 : (checked ? Icons.check_box : Icons.check_box_outline_blank),
            size: 12, color: checked ? const Color(0xFF699EFF) : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _radioChip(String label, bool selected) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF699EFF) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label, style: TextStyle(fontSize: 7, color: selected ? Colors.white : Colors.grey)),
      ),
    );
  }

  Widget _foldGroup(String title, List<Widget> children) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: const Color(0xFF0F0F1A),
          child: Row(
            children: [
              const Icon(Icons.expand_less, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w600)),
              const Spacer(),
            ],
          ),
        ),
        ...children,
        const Divider(height: 1, color: Color(0xFF2A2A3E)),
      ],
    );
  }

  Widget _insLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(text, style: const TextStyle(fontSize: 7, color: Colors.grey)),
    );
  }

  Widget _insInput(String value) {
    return Container(
      width: 24, height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(value, style: const TextStyle(fontSize: 7, color: Colors.white70, fontFamily: 'monospace')),
    );
  }

  // ── BOTTOM_FRAME_TIMELINE (32px) ──────────────────────

  Widget _buildFrameTimeline() {
    return Container(
      height: 32,
      color: const Color(0xFF12121E),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('Frame: 32', style: TextStyle(fontSize: 9, color: Colors.grey)),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  // Tick marks
                  CustomPaint(size: Size.infinite, painter: _FrameRulerPainter()),
                  // Playhead
                  Positioned(
                    left: 0.43 * 200, top: 0, bottom: 0,
                    child: Container(
                      width: 1,
                      color: Colors.red,
                      child: const Center(
                        child: Text('43.0', style: TextStyle(fontSize: 6, color: Colors.red)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Text('78', style: TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text('In:13.0', style: TextStyle(fontSize: 8, color: Colors.grey, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text('Out:58.0', style: TextStyle(fontSize: 8, color: Colors.grey, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          _smallBtn(Icons.skip_previous),
          _smallBtn(Icons.play_arrow),
          _smallBtn(Icons.skip_next),
          _smallBtn(Icons.loop),
        ],
      ),
    );
  }

  // ── BOTTOM_NODE_CANVAS (180px) ────────────────────────

  Widget _buildNodeCanvas() {
    return Container(
      color: const Color(0xFF0D0D18),
      child: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: _NodeGridPainter()),
          // Connection lines
          CustomPaint(size: Size.infinite, painter: _ConnectionPainter()),
          // Nodes
          _node('MediaIn1', 16, 20, const Color(0xFF448AFF)),
          _node('MediaIn2', 16, 64, const Color(0xFF448AFF)),
          _node('Merge', 86, 38, const Color(0xFF4CAF50)),
          _node('Glow', 152, 48, const Color(0xFFFF9800), selected: true),
          _node('Transform', 218, 38, const Color(0xFF9C27B0)),
          _node('MediaOut', 284, 20, const Color(0xFFFF5252)),
          // Context menu hint
          Positioned(
            right: 12, bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.mouse, size: 8, color: Colors.grey),
                  SizedBox(width: 3),
                  Text('right-click: AI | Edit | Replace | Delete',
                      style: TextStyle(fontSize: 6, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _node(String label, double left, double top, Color color, {bool selected = false}) {
    return Positioned(
      left: left, top: top,
      child: GestureDetector(
        onTap: () => setState(() => _selectedNode = 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.3 : 0.15),
            border: Border.all(
              color: selected ? Colors.white : color,
              width: selected ? 1.5 : 0.5,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lens, size: 6, color: color),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(
                fontSize: 8,
                color: selected ? Colors.white : color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _smallBtn(IconData icon) {
    return SizedBox(
      width: 20, height: 20,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 12, color: Colors.white70),
        onPressed: () {},
      ),
    );
  }
}

// ── Custom Painters ──

class _EffectGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0D0D18));
    final center = Offset(size.width / 2, size.height / 2);
    final gradient = RadialGradient(
      colors: [
        const Color(0xFFFF9800).withValues(alpha: 0.15),
        const Color(0xFFFF5252).withValues(alpha: 0.05),
        Colors.transparent,
      ],
    );
    canvas.drawCircle(center, size.width / 3, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrameRulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 15) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NodeGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = 0.3;
    for (double x = 0; x < size.width; x += 15) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 15) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConnectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..strokeWidth = 1.0;
    // MediaIn1 → Merge
    canvas.drawLine(const Offset(58, 28), const Offset(84, 46), paint);
    // MediaIn2 → Merge
    canvas.drawLine(const Offset(58, 72), const Offset(84, 46), paint);
    // Merge → Glow
    canvas.drawLine(const Offset(128, 46), const Offset(150, 56), paint);
    // Glow → Transform
    canvas.drawLine(const Offset(194, 56), const Offset(216, 46), paint);
    // Transform → MediaOut
    canvas.drawLine(const Offset(260, 46), const Offset(282, 28), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
