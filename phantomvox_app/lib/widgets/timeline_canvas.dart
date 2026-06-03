import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Timeline canvas — draws tracks, clips, playhead
class TimelineCanvas extends StatefulWidget {
  final List<Map<String, dynamic>> tracks;
  final double duration;
  final double currentTime;
  final ValueChanged<double> onSeek;
  final VoidCallback onPlayPause;
  final bool isPlaying;

  const TimelineCanvas({
    super.key,
    required this.tracks,
    required this.duration,
    required this.currentTime,
    required this.onSeek,
    required this.onPlayPause,
    this.isPlaying = false,
  });

  @override
  State<TimelineCanvas> createState() => _TimelineCanvasState();
}

class _TimelineCanvasState extends State<TimelineCanvas> {
  final ScrollController _hScroll = ScrollController();
  double _pixelsPerSecond = 80.0;
  static const double _trackHeight = 48.0;
  static const double _rulerHeight = 28.0;
  static const double _labelWidth = 80.0;

  @override
  Widget build(BuildContext context) {
    final totalWidth = math.max(widget.duration * _pixelsPerSecond, 800.0);
    final totalHeight = _rulerHeight + widget.tracks.length * _trackHeight + 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar
        _buildToolbar(),
        // Timeline scroll area
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _hScroll,
            child: SizedBox(
              width: totalWidth + _labelWidth,
              height: totalHeight,
              child: GestureDetector(
                onTapDown: (details) {
                  final x = details.localPosition.dx - _labelWidth;
                  if (x >= 0) {
                    widget.onSeek(x / _pixelsPerSecond);
                  }
                },
                child: CustomPaint(
                  size: Size(totalWidth + _labelWidth, totalHeight),
                  painter: _TimelinePainter(
                    tracks: widget.tracks,
                    duration: widget.duration,
                    currentTime: widget.currentTime,
                    pixelsPerSec: _pixelsPerSecond,
                    trackHeight: _trackHeight,
                    rulerHeight: _rulerHeight,
                    labelWidth: _labelWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          IconButton(
            icon: Icon(widget.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 18),
            onPressed: widget.onPlayPause,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(widget.currentTime),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const Spacer(),
          Text('${widget.duration.toStringAsFixed(1)}s',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

class _TimelinePainter extends CustomPainter {
  final List<Map<String, dynamic>> tracks;
  final double duration;
  final double currentTime;
  final double pixelsPerSec;
  final double trackHeight;
  final double rulerHeight;
  final double labelWidth;

  _TimelinePainter({
    required this.tracks,
    required this.duration,
    required this.currentTime,
    required this.pixelsPerSec,
    required this.trackHeight,
    required this.rulerHeight,
    required this.labelWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawRuler(canvas);
    _drawTracks(canvas);
    _drawPlayhead(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0F0F1A);
    canvas.drawRect(const Offset(0, 0) & size, bg);
  }

  void _drawRuler(Canvas canvas) {
    final bg = Paint()..color = const Color(0xFF1A1A2E);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, labelWidth, rulerHeight), bg);

    // Time markers
    final markerPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.5;
    final textStyle = TextStyle(color: Colors.grey[600], fontSize: 9, fontFamily: 'monospace');

    for (double t = 0; t <= duration; t += 1.0) {
      final x = labelWidth + t * pixelsPerSec;
      canvas.drawLine(Offset(x, rulerHeight - 6), Offset(x, rulerHeight), markerPaint);
      if (t % 5 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: _formatTime(t), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 3, 4));
      }
    }
  }

  void _drawTracks(Canvas canvas) {
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final y = rulerHeight + i * trackHeight;

      // Track background
      final bg = Paint()
        ..color = (i % 2 == 0) ? const Color(0xFF141424) : const Color(0xFF181830);
      canvas.drawRect(
          Rect.fromLTWH(0, y, labelWidth + duration * pixelsPerSec, trackHeight), bg);

      // Track label
      final labelPaint = Paint()..color = const Color(0xFF1E1E3A);
      canvas.drawRect(Rect.fromLTWH(0, y, labelWidth, trackHeight), labelPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '${track['name'] ?? track['type']}',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth - 8);
      tp.paint(canvas, Offset(4, y + trackHeight / 2 - tp.height / 2));

      // Clips
      final clips = track['clips'] as List<dynamic>? ?? [];
      for (final clip in clips) {
        final c = clip as Map<String, dynamic>;
        final start = (c['start'] as num?)?.toDouble() ?? 0;
        final dur = (c['duration'] as num?)?.toDouble() ?? 5;
        final cx = labelWidth + start * pixelsPerSec;
        final cw = dur * pixelsPerSec;

        final clipColor = track['type'] == 'audio'
            ? const Color(0xFF2E7D32).withOpacity(0.7)
            : const Color(0xFF1565C0).withOpacity(0.8);

        final clipPaint = Paint()..color = clipColor;
        final clipRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx, y + 4, cw, trackHeight - 8),
          const Radius.circular(3),
        );
        canvas.drawRRect(clipRect, clipPaint);

        // Clip label
        final label = c['name'] ?? 'Clip';
        final ct = TextPainter(
          text: TextSpan(
            text: '$label',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '..',
        )..layout(maxWidth: cw - 8);
        ct.paint(canvas, Offset(cx + 4, y + trackHeight / 2 - ct.height / 2));
      }
    }
  }

  void _drawPlayhead(Canvas canvas) {
    final x = labelWidth + currentTime * pixelsPerSec;
    final headPaint = Paint()
      ..color = const Color(0xFFFF4444)
      ..strokeWidth = 2.0;
    final totalH = rulerHeight + tracks.length * trackHeight;
    canvas.drawLine(Offset(x, 0), Offset(x, totalH), headPaint);

    // Playhead triangle
    final path = Path()
      ..moveTo(x - 5, rulerHeight)
      ..lineTo(x + 5, rulerHeight)
      ..lineTo(x, rulerHeight - 8)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFF4444));
  }

  String _formatTime(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => true;
}
