import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Palette page — precision color grading workspace
/// Reference: DaVinci Resolve Color workspace
/// Layout: TOP_BAR + (LEFT_GALLERY + CENTRAL_VIEWER + RIGHT_NODE_GRAPH) + MIDDLE_CLIP_STRIP + BOTTOM_COLOR_PANEL
class PalettePage extends StatefulWidget {
  const PalettePage({super.key});

  @override
  State<PalettePage> createState() => _PalettePageState();
}

class _PalettePageState extends State<PalettePage> {
  double _lift = 0.0, _gamma = 0.0, _gain = 0.0;
  double _saturation = 0.0, _temp = 0.0, _tint = 0.0;
  double _exposure = 0.0, _contrast = 0.0;
  int _selectedClip = 25;
  String _colorTab = 'Wheels';
  final List<String> _colorTabs = ['Wheels', 'Warper', 'Picker', 'Scopes'];

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
                _buildLeftGallery(),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                Expanded(child: _buildViewer()),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                _buildNodeGraph(),
              ],
            ),
          ),
          _buildClipStrip(),
          _buildColorPanel(),
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
          _tbBtn(Icons.photo_library, 'Gallery'),
          const SizedBox(width: 4),
          _tbBtn(Icons.palette_outlined, 'LUTs'),
          const SizedBox(width: 4),
          _tbBtn(Icons.folder, 'Media Pool'),
          const SizedBox(width: 4),
          _tbDropdown('Clips'),
          const SizedBox(width: 16),
          Container(width: 1, height: 16, color: const Color(0xFF2A2A3E)),
          const SizedBox(width: 8),
          const Text('The Ranch - Short Story | Edited',
              style: TextStyle(fontSize: 10, color: Colors.white54)),
          const Spacer(),
          _tbLabel('Zoom: 78%'),
          const SizedBox(width: 8),
          _tbLabel('Timeline 1'),
          const SizedBox(width: 8),
          _tbLabel('17:28:12:11'),
          const SizedBox(width: 8),
          _tbLabel('Clip'),
          const SizedBox(width: 12),
          _tbBtn(Icons.file_download, 'Quick Export'),
          const SizedBox(width: 4),
          _tbBtn(Icons.timeline, 'Timeline'),
          const SizedBox(width: 4),
          _tbBtn(Icons.account_tree, 'Nodes'),
          const SizedBox(width: 4),
          _tbBtn(Icons.auto_fix_high, 'Effects'),
          const SizedBox(width: 4),
          _tbBtn(Icons.light, 'Lightbox'),
          const SizedBox(width: 4),
          _tbBtn(Icons.colorize, 'AI Match', accent: true),
        ],
      ),
    );
  }

  Widget _tbBtn(IconData icon, String label, {bool accent = false}) {
    final color = accent ? const Color(0xFF699EFF) : Colors.grey;
    return TextButton.icon(
      icon: Icon(icon, size: 12, color: color),
      label: Text(label, style: TextStyle(fontSize: 9, color: color)),
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _tbDropdown(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
      ],
    );
  }

  Widget _tbLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 9, color: Colors.grey));
  }

  // ── LEFT_GALLERY (180px) ──────────────────────────────

  Widget _buildLeftGallery() {
    return Container(
      width: 180,
      color: const Color(0xFF12121E),
      child: Column(
        children: [
          _sectionHeader('Gallery'),
          // Directory tree
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _treeItem('Stills - Master', Icons.folder, true),
                _treeItem('Stills - Landsc.', Icons.folder, false),
                _treeItem('Stills - Car', Icons.folder, false),
                _treeItem('PowerGrade 1', Icons.auto_awesome, false),
                _treeItem('Timelines', Icons.timeline, false),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          // Thumbnail grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(4),
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 16 / 9,
              children: List.generate(15, (i) {
                final selected = i == 0;
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A30),
                    borderRadius: BorderRadius.circular(3),
                    border: selected
                        ? Border.all(color: const Color(0xFF699EFF), width: 1.5)
                        : null,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text('#1.19.1',
                          style: TextStyle(fontSize: 7, color: selected ? const Color(0xFF699EFF) : Colors.grey.shade600)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeItem(String name, IconData icon, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: selected ? const Color(0xFF1A1A3E) : null,
      child: Row(
        children: [
          Icon(icon, size: 12, color: selected ? const Color(0xFF699EFF) : Colors.grey),
          const SizedBox(width: 5),
          Text(name, style: TextStyle(
            fontSize: 10, color: selected ? Colors.white : Colors.grey,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  // ── CENTRAL_VIEWER ────────────────────────────────────

  Widget _buildViewer() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF0A0A14),
            child: Center(
              child: Container(
                width: 480, height: 270,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _GradientPainter()),
                    ),
                    Positioned(
                      left: 8, bottom: 8,
                      child: Row(
                        children: [
                          _smallBtn(Icons.skip_previous),
                          _smallBtn(Icons.play_arrow),
                          _smallBtn(Icons.skip_next),
                          _smallBtn(Icons.loop),
                          const SizedBox(width: 8),
                          const Text('01:14:56:13',
                              style: TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text('HDR | Rec.709',
                            style: TextStyle(fontSize: 8, color: Colors.white70)),
                      ),
                    ),
                    Positioned(
                      right: 8, bottom: 8,
                      child: Row(
                        children: [
                          _scopeBar(Colors.red, 0.7),
                          const SizedBox(width: 2),
                          _scopeBar(Colors.green, 0.5),
                          const SizedBox(width: 2),
                          _scopeBar(Colors.blue, 0.3),
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

  Widget _scopeBar(Color color, double level) {
    return Container(
      width: 4, height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 24 * level,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  // ── RIGHT_NODE_GRAPH (220px) ──────────────────────────

  Widget _buildNodeGraph() {
    return Container(
      width: 220,
      color: const Color(0xFF0D0D18),
      child: Column(
        children: [
          _sectionHeader('Node Graph'),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          Expanded(
            child: Stack(
              children: [
                CustomPaint(size: Size.infinite, painter: _GridPainter()),
                // Group labels
                Positioned(left: 4, top: 4,
                    child: _groupLabel('Pre-Process', const Color(0xFF448AFF))),
                // IDT (19), NR (20), BEAUTY (21)
                Positioned(left: 4, top: 18, child: _nodeBtn('19 IDT', const Color(0xFF448AFF))),
                Positioned(left: 76, top: 18, child: _nodeBtn('20 NR', const Color(0xFF448AFF))),
                Positioned(left: 148, top: 18, child: _nodeBtn('21 BEAUTY', const Color(0xFF448AFF))),

                Positioned(left: 4, top: 52,
                    child: _groupLabel('Color', const Color(0xFF4CAF50))),
                // 01-05
                Positioned(left: 4, top: 66, child: _nodeBtn('01 EXP', const Color(0xFF4CAF50))),
                Positioned(left: 76, top: 66, child: _nodeBtn('02 CON', const Color(0xFF4CAF50))),
                Positioned(left: 148, top: 66, child: _nodeBtn('03 WB', const Color(0xFF4CAF50))),
                Positioned(left: 4, top: 92, child: _nodeBtn('04 SAT', const Color(0xFF4CAF50))),
                Positioned(left: 76, top: 92, child: _nodeBtn('05 HL/SKY', const Color(0xFF4CAF50))),

                Positioned(left: 4, top: 120,
                    child: _groupLabel('Region', const Color(0xFFFF9800))),
                // 06-10
                Positioned(left: 4, top: 134, child: _nodeBtn('06 FLG-L', const Color(0xFFFF9800), small: true)),
                Positioned(left: 76, top: 134, child: _nodeBtn('07 FLG-C', const Color(0xFFFF9800), small: true)),
                Positioned(left: 148, top: 134, child: _nodeBtn('08 FLG-R', const Color(0xFFFF9800), small: true)),
                Positioned(left: 4, top: 156, child: _nodeBtn('09 FLG-T', const Color(0xFFFF9800), small: true)),
                Positioned(left: 76, top: 156, child: _nodeBtn('10 FLG-B', const Color(0xFFFF9800), small: true)),

                Positioned(left: 4, top: 178,
                    child: _groupLabel('Mask', const Color(0xFF9C27B0))),
                // 11-15
                Positioned(left: 4, top: 192, child: _nodeBtn('11 CIRC-L', const Color(0xFF9C27B0), small: true)),
                Positioned(left: 76, top: 192, child: _nodeBtn('12 CIRC-C', const Color(0xFF9C27B0), small: true)),
                Positioned(left: 148, top: 192, child: _nodeBtn('13 CIRC-R', const Color(0xFF9C27B0), small: true)),
                Positioned(left: 4, top: 214, child: _nodeBtn('14 VGN-IN', const Color(0xFF9C27B0), small: true)),
                Positioned(left: 76, top: 214, child: _nodeBtn('15 VGN-OUT', const Color(0xFF9C27B0), small: true)),

                // Final Out
                Positioned(
                  right: 8, bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.red, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_forward, size: 10, color: Colors.red),
                        const SizedBox(width: 4),
                        const Text('Final Out',
                            style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupLabel(String text, Color color) {
    return Text(text, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600));
  }

  Widget _nodeBtn(String label, Color color, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label, style: TextStyle(
        fontSize: small ? 7 : 8, color: color,
        fontWeight: FontWeight.w500,
      )),
    );
  }

  // ── MIDDLE_CLIP_STRIP (40px) ─────────────────────────

  Widget _buildClipStrip() {
    return Container(
      height: 40,
      color: const Color(0xFF12121E),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('\u2190 All Clips',
                  style: TextStyle(fontSize: 8, color: Colors.grey)),
              Text('Blackmagic RAW',
                  style: TextStyle(fontSize: 7, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              itemBuilder: (_, i) {
                final idx = 18 + i;
                final selected = idx == _selectedClip;
                return GestureDetector(
                  onTap: () => setState(() => _selectedClip = idx),
                  child: Container(
                    width: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1A1A3E) : const Color(0xFF0F0F1A),
                      border: Border.all(
                        color: selected ? const Color(0xFF699EFF) : const Color(0xFF2A2A3E),
                        width: selected ? 1.5 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(
                      child: Text('$idx',
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? Colors.white : Colors.grey,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          )),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          const Text('25', style: TextStyle(fontSize: 10, color: Color(0xFF699EFF))),
        ],
      ),
    );
  }

  // ── BOTTOM_COLOR_PANEL (200px) ───────────────────────

  Widget _buildColorPanel() {
    return Container(
      height: 200,
      color: const Color(0xFF0F0F1A),
      child: Column(
        children: [
          // Tab bar
          Container(
            height: 28,
            color: const Color(0xFF0D0D1A),
            child: Row(
              children: _colorTabs.map((t) => GestureDetector(
                onTap: () => setState(() => _colorTab = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _colorTab == t ? const Color(0xFF699EFF) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(t, style: TextStyle(
                    fontSize: 10,
                    color: _colorTab == t ? Colors.white : Colors.grey,
                  )),
                ),
              )).toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          Expanded(child: _buildColorContent()),
        ],
      ),
    );
  }

  Widget _buildColorContent() {
    switch (_colorTab) {
      case 'Wheels':
        return _buildWheels();
      case 'Warper':
        return _buildWarper();
      case 'Picker':
        return _buildPicker();
      case 'Scopes':
        return _buildScopes();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWheels() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // 4 color wheels (simplified as circular controls)
          Expanded(child: _miniWheel('Shadows', const Color(0xFF448AFF), _lift)),
          Expanded(child: _miniWheel('Midtones', const Color(0xFF69F0AE), _gamma)),
          Expanded(child: _miniWheel('Highlights', const Color(0xFFFF5252), _gain)),
          Expanded(child: _miniWheel('Global', const Color(0xFFFF9800), _exposure)),
          Container(width: 1, height: 120, color: const Color(0xFF2A2A3E)),
          // Parameter list
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _paramSlider('Exposure', _exposure, -2, 2),
                  _paramSlider('Contrast', _contrast, -1, 1),
                  _paramSlider('Saturation', _saturation, -1, 1),
                  _paramSlider('Temp', _temp, -1, 1),
                  _paramSlider('Tint', _tint, -1, 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniWheel(String label, Color color, double value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A1A2E),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          ),
          child: Center(
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey)),
        Text(value.toStringAsFixed(2),
            style: TextStyle(fontSize: 8, color: color, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _paramSlider(String label, double value, double min, double max) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: (v) => setState(() => _updateParam(label, v))),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 9, color: Colors.white54, fontFamily: 'monospace')),
        ),
      ],
    );
  }

  void _updateParam(String label, double v) {
    switch (label) {
      case 'Exposure': _exposure = v;
      case 'Contrast': _contrast = v;
      case 'Saturation': _saturation = v;
      case 'Temp': _temp = v;
      case 'Tint': _tint = v;
    }
  }

  Widget _buildWarper() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 140, height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2A2A3E)),
            ),
            child: CustomPaint(
              painter: _HexGridPainter(),
              size: const Size(140, 100),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Color Warper \u00b7 HSP Mode',
              style: TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pickerChip('Auto Lock', false),
        const SizedBox(width: 6),
        _pickerChip('1-Point', false),
        const SizedBox(width: 6),
        _pickerChip('Hue', true),
        const SizedBox(width: 6),
        _pickerChip('Sat', false),
        const SizedBox(width: 6),
        _pickerChip('Luma', false),
        const SizedBox(width: 12),
        _smallBtn(Icons.colorize),
        const SizedBox(width: 8),
        _smallBtn(Icons.timeline),
      ],
    );
  }

  Widget _pickerChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF699EFF) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: active ? Colors.white : Colors.grey)),
    );
  }

  Widget _buildScopes() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 100,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                border: Border.all(color: const Color(0xFF2A2A3E)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RGB Parade', style: TextStyle(fontSize: 8, color: Colors.grey)),
                  const Spacer(),
                  Row(
                    children: [
                      _paradeBar(Colors.red, 0.8),
                      const SizedBox(width: 4),
                      _paradeBar(Colors.green, 0.6),
                      const SizedBox(width: 4),
                      _paradeBar(Colors.blue, 0.4),
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

  Widget _paradeBar(Color color, double level) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: 60 * level,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      height: 26,
      padding: const EdgeInsets.only(left: 8),
      color: const Color(0xFF0D0D1A),
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
    );
  }

  Widget _smallBtn(IconData icon) {
    return SizedBox(
      width: 24, height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 14, color: Colors.white70),
        onPressed: () {},
      ),
    );
  }
}

// ── Custom Painters ─────────────────────────────────────

class _GradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      colors: [
        const Color(0xFF1A1A3E).withValues(alpha: 0.3),
        const Color(0xFF2A1A3E).withValues(alpha: 0.3),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..strokeWidth = 0.5;
    final center = Offset(size.width / 2, size.height / 2);
    for (int ring = 0; ring < 3; ring++) {
      for (int i = 0; i < 6; i++) {
        final angle = (i / 6) * math.pi * 2 - 1.5708;
        final r = 20.0 + ring * 18.0;
        final p = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
        for (int j = 0; j < 6; j++) {
          final a2 = (j / 6) * math.pi * 2 - 1.5708;
          final p2 = Offset(center.dx + r * math.cos(a2), center.dy + r * math.sin(a2));
          canvas.drawLine(p, p2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
