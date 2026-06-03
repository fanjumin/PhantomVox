import 'package:flutter/material.dart';

/// Palette page — color grading workspace
class PalettePage extends StatefulWidget {
  const PalettePage({super.key});

  @override
  State<PalettePage> createState() => _PalettePageState();
}

class _PalettePageState extends State<PalettePage>
    with SingleTickerProviderStateMixin {
  late TabController _toolTabCtrl;

  double _lift = 0.0, _gamma = 0.0, _gain = 0.0;
  double _saturation = 0.0, _temp = 0.0, _tint = 0.0;
  double _exposure = 0.0, _contrast = 0.0;

  @override
  void initState() {
    super.initState();
    _toolTabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _toolTabCtrl.dispose();
    super.dispose();
  }

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
                const Text('Palette',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                _headerBtn(Icons.auto_fix_high, 'AI Match'),
                const SizedBox(width: 8),
                _headerBtn(Icons.style, 'Presets'),
                const SizedBox(width: 8),
                _headerBtn(Icons.file_download, 'Export LUT'),
                const SizedBox(width: 8),
                _headerBtn(Icons.more_horiz, ''),
              ],
            ),
          ),
          // Main 3-panel body
          Expanded(
            child: Row(
              children: [
                // Left: Reference gallery
                _buildReferenceGallery(),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                // Center: Viewport + Color tools
                Expanded(flex: 3, child: _buildCenterPanel()),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                // Right: Node workspace
                _buildNodeWorkspace(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Left panel: Reference gallery ──

  Widget _buildReferenceGallery() {
    return SizedBox(
      width: 180,
      child: Column(
        children: [
          // Section header
          Container(
            height: 28,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF12121E),
            alignment: Alignment.centerLeft,
            child: const Text('Reference Gallery',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          // Style presets row
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: const Color(0xFF16162A),
            child: Row(
              children: [
                _chip('Stills', true),
                const SizedBox(width: 4),
                _chip('Presets', false),
                const SizedBox(width: 4),
                _chip('Grades', false),
              ],
            ),
          ),
          // Thumbnail grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(4),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 16 / 9,
              children: List.generate(12, (i) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A30),
                  borderRadius: BorderRadius.circular(4),
                  border: i == 0
                      ? Border.all(color: const Color(0xFF6C63FF), width: 2)
                      : null,
                ),
                child: Center(
                  child: Text('Ref ${i + 1}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  // ── Center panel: Viewport + Color tools ──

  Widget _buildCenterPanel() {
    return Column(
      children: [
        // Viewport
        Expanded(
          flex: 2,
          child: Container(
            color: const Color(0xFF0A0A14),
            child: Center(
              child: Container(
                width: 320,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Stack(
                  children: [
                    // Mock gradient image
                    Positioned.fill(
                      child: CustomPaint(painter: _GradientPainter()),
                    ),
                    // Overlay controls
                    Positioned(
                      left: 8, bottom: 8,
                      child: Row(
                        children: [
                          _smallBtn(Icons.skip_previous, 18),
                          _smallBtn(Icons.play_arrow, 18),
                          _smallBtn(Icons.skip_next, 18),
                          const SizedBox(width: 8),
                          const Text('01:14:56:13',
                              style: TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    // Info overlay
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text('HDR | Rec.709',
                            style: TextStyle(fontSize: 9, color: Colors.white70)),
                      ),
                    ),
                    // Scopes mini view
                    Positioned(
                      right: 8, bottom: 8,
                      child: Row(
                        children: [
                          _scopeDot(Colors.red),
                          const SizedBox(width: 2),
                          _scopeDot(Colors.green),
                          const SizedBox(width: 2),
                          _scopeDot(Colors.blue),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Color tools tab bar
        Container(
          height: 28,
          color: const Color(0xFF12121E),
          child: TabBar(
            controller: _toolTabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6C63FF),
            labelStyle: const TextStyle(fontSize: 10),
            tabs: const [
              Tab(text: 'Wheels'),
              Tab(text: 'Curves'),
              Tab(text: 'Scopes'),
            ],
          ),
        ),
        // Color tools content
        Expanded(
          flex: 2,
          child: TabBarView(
            controller: _toolTabCtrl,
            children: [
              _buildColorWheels(),
              _buildCurvesTab(),
              _buildScopesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorWheels() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Lift / Gamma / Gain wheels (simplified as sliders)
          _wheelSlider('Lift', _lift, Color(0xFF448AFF), (v) => _lift = v),
          const SizedBox(height: 8),
          _wheelSlider('Gamma', _gamma, Color(0xFF69F0AE), (v) => _gamma = v),
          const SizedBox(height: 8),
          _wheelSlider('Gain', _gain, Color(0xFFFF5252), (v) => _gain = v),
          const Divider(color: Color(0xFF2A2A3E), height: 16),
          // Global controls
          Row(
            children: [
              Expanded(child: _knobSlider('Exposure', _exposure, -2, 2, (v) => _exposure = v)),
              const SizedBox(width: 8),
              Expanded(child: _knobSlider('Contrast', _contrast, -1, 1, (v) => _contrast = v)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _knobSlider('Saturation', _saturation, -1, 1, (v) => _saturation = v)),
              const SizedBox(width: 8),
              Expanded(child: _knobSlider('Temp', _temp, -1, 1, (v) => _temp = v)),
              const SizedBox(width: 8),
              Expanded(child: _knobSlider('Tint', _tint, -1, 1, (v) => _tint = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurvesTab() {
    return Center(
      child: Container(
        width: 180, height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          border: Border.all(color: const Color(0xFF2A2A3E)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: CustomPaint(painter: _CurveGridPainter()),
      ),
    );
  }

  Widget _buildScopesTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                border: Border.all(color: const Color(0xFF2A2A3E)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text('Waveform',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                border: Border.all(color: const Color(0xFF2A2A3E)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text('Vectorscope',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right panel: Node workspace ──

  Widget _buildNodeWorkspace() {
    return SizedBox(
      width: 240,
      child: Column(
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF12121E),
            alignment: Alignment.centerLeft,
            child: const Text('Node Graph',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          // Node canvas
          Expanded(
            child: Container(
              color: const Color(0xFF0D0D18),
              child: Stack(
                children: [
                  // Grid background
                  CustomPaint(
                    size: Size.infinite,
                    painter: _GridPainter(),
                  ),
                  // Nodes
                  _node('Input', 16, 24, const Color(0xFF448AFF)),
                  _node('IDT', 80, 60, const Color(0xFF4CAF50)),
                  _node('NR', 80, 100, const Color(0xFF4CAF50)),
                  _node('Grade', 80, 140, const Color(0xFFFF9800)),
                  _node('Output', 140, 170, const Color(0xFFFF5252)),
                  // Connection lines drawn behind nodes
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _node(String label, double left, double top, Color color) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ),
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

  Widget _chip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6C63FF) : const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: active ? Colors.white : Colors.grey)),
    );
  }

  Widget _smallBtn(IconData icon, double size) {
    return SizedBox(
      width: 24, height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: size, color: Colors.white70),
        onPressed: () {},
      ),
    );
  }

  Widget _scopeDot(Color color) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: color.withOpacity(0.6),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _wheelSlider(String label, double value, Color color, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Container(
          width: 40,
          alignment: Alignment.centerLeft,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
            ),
            child: Slider(
              value: value,
              min: -1, max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _knobSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min, max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ── Custom painters ──

class _GradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF1A237E),
        const Color(0xFF4A148C),
        const Color(0xFF311B92),
        const Color(0xFF1A237E),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    // Color bars overlay
    final barH = size.height / 3;
    for (int i = 0; i < 3; i++) {
      final colors = [Colors.red, Colors.green, Colors.blue];
      canvas.drawRect(
        Rect.fromLTWH(0, barH * i, size.width * 0.6, barH),
        Paint()..color = colors[i].withOpacity(0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_GradientPainter old) => false;
}

class _CurveGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..strokeWidth = 0.5;
    // Grid lines
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // S-curve
    final curvePaint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(0, size.height);
    path.cubicTo(
      size.width * 0.25, size.height * 0.75,
      size.width * 0.75, size.height * 0.25,
      size.width, 0,
    );
    canvas.drawPath(path, curvePaint);
    // Diagonal reference
    final diagPaint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), diagPaint);
  }

  @override
  bool shouldRepaint(_CurveGridPainter old) => false;
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
  bool shouldRepaint(_GridPainter old) => false;
}
