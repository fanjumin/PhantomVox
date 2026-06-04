import 'package:flutter/material.dart';
import '../../widgets/tr.dart';
import '../widgets/tr.dart';


/// Flow Graph — DAG workflow orchestration center.
class FlowGraphPage extends StatefulWidget {
  const FlowGraphPage({super.key});

  @override
  State<FlowGraphPage> createState() => _FlowGraphPageState();
}

// ─── Data models ────────────────────────────────────────────

class _FlowNode {
  final String id;
  String label;
  double progress;
  _FlowNodeType type;
  final List<_FlowNode> children;
  bool running;

  _FlowNode({
    required this.id,
    required this.label,
    this.progress = 0,
    this.type = _FlowNodeType.branch,
    List<_FlowNode>? children,
    this.running = false,
  }) : children = children ?? [];
}

enum _FlowNodeType { root, branch, leaf }

enum _TaskStatus { active, paused, failed }

class _ScheduledTask {
  final String name;
  final String schedule;
  _TaskStatus status;
  _ScheduledTask(this.name, this.schedule, this.status);
}

class _RunRecord {
  final String id;
  double progress;
  final String status; // 'running' | 'done' | 'failed'
  final String duration;
  _RunRecord(this.id, this.progress, this.status, this.duration);
}

// ─── State ──────────────────────────────────────────────────

class _FlowGraphPageState extends State<FlowGraphPage> {
  int _tabIndex = 0;

  static const _tabs = [
    _TabData('📋', 'Flow'),
    _TabData('⏰', 'Schedule'),
    _TabData('⚙', 'Settings'),
    _TabData('🔄', 'Logs'),
  ];

  // Flow graph data
  late _FlowNode _root;

  // Scheduled tasks
  final List<_ScheduledTask> _tasks = [
    _ScheduledTask('Daily Report', 'Every day 08:00', _TaskStatus.active),
    _ScheduledTask('Archive Backup', 'Every Monday', _TaskStatus.paused),
    _ScheduledTask('Video Transcode', 'Manual only', _TaskStatus.failed),
  ];

  // Workflow run log
  final List<_RunRecord> _runs = [
    _RunRecord('#1423', 0.68, 'running', '2m34s'),
    _RunRecord('#1422', 1.0, 'done', '1m12s'),
    _RunRecord('#1421', 0.45, 'failed', '3m01s'),
  ];

  @override
  void initState() {
    super.initState();
    _root = _FlowNode(
      id: 'root',
      label: 'Product Promo',
      type: _FlowNodeType.root,
      progress: 0.65,
      children: [
        _FlowNode(id: 'n1', label: 'Voice Clone', progress: 0.5, type: _FlowNodeType.branch,
            children: [_FlowNode(id: 'n1a', label: 'Narration', progress: 1.0, type: _FlowNodeType.leaf)]),
        _FlowNode(id: 'n2', label: 'Music Gen', progress: 0.3, type: _FlowNodeType.branch,
            children: [_FlowNode(id: 'n2a', label: 'Jazz Style', progress: 0.6, type: _FlowNodeType.leaf)]),
        _FlowNode(id: 'n3', label: 'Material Prep', progress: 0.8, type: _FlowNodeType.branch,
            children: [_FlowNode(id: 'n3a', label: 'AI BG', progress: 1.0, type: _FlowNodeType.leaf)]),
        _FlowNode(id: 'n4', label: 'Video Gen', progress: 0.0, type: _FlowNodeType.branch,
            children: [_FlowNode(id: 'n4a', label: 'Promo Clip', progress: 0.0, type: _FlowNodeType.leaf)]),
        _FlowNode(id: 'n5', label: 'Code Gen', progress: 0.0, type: _FlowNodeType.branch,
            children: [_FlowNode(id: 'n5a', label: 'Custom FX', progress: 0.0, type: _FlowNodeType.leaf)]),
      ],
    );
  }

  // ─── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(
        children: [
          _buildTopBar(),
          const Divider(height: 1, color: Color(0xFF2A2A4E)),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 32,
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Tr('Flow Graph', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i];
                final active = i == _tabIndex;
                return GestureDetector(
                  onTap: () => setState(() => _tabIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: active ? const Color(0xFF6C63FF) : Colors.transparent, width: 2,
                      )),
                    ),
                    child: Text(
                      '${t.icon} ${t.label}',
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? Colors.white : Colors.grey,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Status + action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A4E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Tr('Idle', style: TextStyle(fontSize: 10, color: Colors.green)),
                  ),
                ),
                const SizedBox(width: 6),
                _miniBtn('▶', 'Run All'),
                const SizedBox(width: 4),
                _miniBtn('⏸', 'Pause'),
                const SizedBox(width: 4),
                _miniBtn('💾', 'Save'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(String icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() {}),
        child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A4E),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 11)),
        ),
      ),
    );
  }

  // ─── Tab content ────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 0: return _buildFlowEditor();
      case 1: return _buildSchedulePanel();
      case 2: return _buildSettingsPanel();
      case 3: return _buildLogPanel();
      default: return const SizedBox.shrink();
    }
  }

  // ══════════════ TAB 0: Flow Graph DAG Editor ═══════════

  Widget _buildFlowEditor() {
    return Column(
      children: [
        // Canvas area
        Expanded(
          child: _FlowGraphCanvas(
            root: _root,
            onNodeTap: _onNodeTap,
            onNodeContext: _onNodeContext,
          ),
        ),
        const Divider(height: 1, color: Color(0xFF2A2A4E)),
        // Bottom bar: task schedule + workflow monitor
        SizedBox(
          height: 160,
          child: Row(
            children: [
              Expanded(child: _buildTaskPanel()),
              Container(width: 1, color: const Color(0xFF2A2A4E)),
              Expanded(child: _buildMonitorPanel()),
            ],
          ),
        ),
      ],
    );
  }

  void _onNodeTap(_FlowNode node) {
    setState(() {
      node.running = !node.running;
    });
  }

  void _onNodeContext(_FlowNode node, Offset globalPos) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      color: const Color(0xFF16213E),
      items: [
        const PopupMenuItem(value: 'run', child: Tr('▶ Run', style: TextStyle(color: Colors.white, fontSize: 12))),
        const PopupMenuItem(value: 'pause', child: Tr('⏸ Pause', style: TextStyle(color: Colors.white, fontSize: 12))),
        const PopupMenuItem(value: 'edit', child: Tr('✏ Edit', style: TextStyle(color: Colors.white, fontSize: 12))),
        const PopupMenuItem(value: 'backtrack', child: Tr('↩ Backtrack', style: TextStyle(color: Colors.white, fontSize: 12))),
        const PopupMenuItem(value: 'save', child: Tr('💾 Save as Template', style: TextStyle(color: Colors.white, fontSize: 12))),
      ],
    ).then((v) {
      if (v != null) {
        setState(() {
          if (v == 'run') node.running = true;
          if (v == 'pause') node.running = false;
        });
      }
    });
  }

  // ══════════════ TAB 1: Scheduled Tasks ═══════════════════

  Widget _buildSchedulePanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tr('Scheduled Tasks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              _actionChip('+ Add', Icons.add, () {}),
              const SizedBox(width: 8),
              _actionChip('Import/Export', Icons.import_export, () {}),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                _buildTaskHeader(),
                ..._tasks.map(_buildTaskRow),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A4E))),
      ),
      child: Row(
        children: const [
          SizedBox(width: 24),
          Expanded(child: Tr('Name', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Tr('Schedule', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
          SizedBox(width: 80, child: Tr('Status', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
          SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildTaskRow(_ScheduledTask task) {
    final icon = task.status == _TaskStatus.active ? '🟢' : task.status == _TaskStatus.paused ? '⚪' : '🔴';
    final st = task.status == _TaskStatus.active ? 'Active' : task.status == _TaskStatus.paused ? 'Paused' : 'Failed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A2E))),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(task.name, style: const TextStyle(fontSize: 12, color: Colors.white))),
          Expanded(child: Text(task.schedule, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          SizedBox(width: 80, child: Text(st, style: TextStyle(fontSize: 12, color: task.status == _TaskStatus.active ? Colors.green : Colors.grey))),
          SizedBox(
            width: 60,
            child: TextButton(
              onPressed: () {},
              child: Tr('Edit', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════ TAB 2: Settings ═════════════════════════

  Widget _buildSettingsPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr('Workflow Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          _settingRow('Execution Mode', 'Serial'),
          _settingRow('Parallel Branches', 'Enabled'),
          _settingRow('Conditional Branching', 'Enabled'),
          _settingRow('Merge Mode', 'Auto-merge'),
          _settingRow('Max Retries', '3'),
          _settingRow('Timeout per node', '5 min'),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save, size: 14),
            label: const Tr('Save Settings'),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ══════════════ TAB 3: Run Logs ═══════════════════════════

  Widget _buildLogPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tr('Run Logs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              _actionChip('Clear', Icons.delete_sweep, () => setState(() => _runs.clear())),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                _buildLogHeader(),
                ...List.generate(_runs.length, (i) => _buildLogRow(i)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A4E))),
      ),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Tr('Run ID', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Tr('Progress', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Tr('Status', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Tr('Duration', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
          SizedBox(width: 80, child: Tr('Action', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildLogRow(int i) {
    final r = _runs[i];
    final statusIcon = r.status == 'running' ? '🟢' : r.status == 'done' ? '✅' : '🔴';
    final statusLabel = r.status == 'running' ? 'Running' : r.status == 'done' ? 'Done' : 'Failed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A2E))),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(r.id, style: const TextStyle(fontSize: 12, color: Colors.white))),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: r.progress,
                      backgroundColor: const Color(0xFF2A2A4E),
                      valueColor: AlwaysStoppedAnimation(
                        r.status == 'failed' ? Colors.red : const Color(0xFF6C63FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${(r.progress * 100).toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(child: Text('$statusIcon $statusLabel', style: const TextStyle(fontSize: 12, color: Colors.white))),
          Expanded(child: Text(r.duration, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                if (r.status == 'running')
                  _tinyBtn('View')
                else if (r.status == 'done')
                  _tinyBtn('Log')
                else
                  _tinyBtn('Retry'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyBtn(String label) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6C63FF))),
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
      backgroundColor: const Color(0xFF2A2A4E),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // ══════════════ TAB 0: Task panel (bottom-left) ═══════════

  Widget _buildTaskPanel() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tr('Scheduled Tasks', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: Tr('+ Add', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              children: _tasks.map((t) {
                final icon = t.status == _TaskStatus.active ? '🟢' : t.status == _TaskStatus.paused ? '⚪' : '🔴';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(t.name, style: const TextStyle(fontSize: 10, color: Colors.white))),
                      Text(t.schedule, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════ TAB 0: Monitor panel (bottom-right) ═══════

  Widget _buildMonitorPanel() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tr('Workflow Monitor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              TextButton(onPressed: () {}, child: Tr('New', style: TextStyle(fontSize: 10))),
              TextButton(onPressed: () {}, child: Tr('Pause All', style: TextStyle(fontSize: 10))),
            ],
          ),
          Expanded(
            child: ListView(
              children: _runs.map((r) {
                final icon = r.status == 'running' ? '🟢' : r.status == 'done' ? '✅' : '🔴';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(r.id, style: const TextStyle(fontSize: 10, color: Colors.white)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: r.progress,
                            backgroundColor: const Color(0xFF2A2A4E),
                            valueColor: AlwaysStoppedAnimation(
                              r.status == 'failed' ? Colors.red : const Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('${(r.progress * 100).toInt()}%', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ─────────────────────────────────────────

class _TabData {
  final String icon;
  final String label;
  const _TabData(this.icon, this.label);
}

// ═══════════════════ Flow Graph Canvas ═══════════════════════

class _FlowGraphCanvas extends StatefulWidget {
  final _FlowNode root;
  final void Function(_FlowNode node) onNodeTap;
  final void Function(_FlowNode node, Offset globalPos) onNodeContext;

  const _FlowGraphCanvas({
    required this.root,
    required this.onNodeTap,
    required this.onNodeContext,
  });

  @override
  State<_FlowGraphCanvas> createState() => _FlowGraphCanvasState();
}

class _FlowGraphCanvasState extends State<_FlowGraphCanvas> {
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  Offset? _dragStart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (d) => _dragStart = d.focalPoint,
      onScaleUpdate: (d) {
        setState(() {
          if (d.pointerCount == 1 && _dragStart != null) {
            _offset += d.focalPoint - _dragStart!;
            _dragStart = d.focalPoint;
          } else {
            _scale = (_scale * d.scale).clamp(0.3, 3.0);
          }
        });
      },
      onScaleEnd: (_) => _dragStart = null,
      child: Container(
        color: const Color(0xFF111122),
        child: CustomPaint(
          painter: _ConnectorPainter(widget.root, _offset, _scale),
          child: Stack(
            children: _buildNodeWidgets(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNodeWidgets() {
    final widgets = <Widget>[];
    final basePositions = _computeNodePositions();
    for (final entry in basePositions.entries) {
      final node = entry.key;
      final pos = entry.value * _scale + _offset;
      widgets.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: _NodeWidget(
            node: node,
            onTap: () => widget.onNodeTap(node),
            onContext: (gp) => widget.onNodeContext(node, gp),
          ),
        ),
      );
    }
    return widgets;
  }

  Map<_FlowNode, Offset> _computeNodePositions() {
    final map = <_FlowNode, Offset>{};
    final root = widget.root;
    map[root] = const Offset(220, 10);
    const startX = 40.0;
    const stepX = 100.0;

    for (var i = 0; i < root.children.length; i++) {
      final branch = root.children[i];
      map[branch] = Offset(startX + i * stepX, 90);
      for (var j = 0; j < branch.children.length; j++) {
        map[branch.children[j]] = Offset(startX + i * stepX, 170);
      }
    }
    return map;
  }
}

// ─── Node connector painter ─────────────────────────────────

class _ConnectorPainter extends CustomPainter {
  final _FlowNode root;
  final Offset offset;
  final double scale;

  _ConnectorPainter(this.root, this.offset, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A3A6E)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final map = _computePositions();
    final rootPos = map[root]! * scale + offset;

    for (final branch in root.children) {
      if (!map.containsKey(branch)) continue;
      final branchPos = map[branch]! * scale + offset;
      _drawCurve(canvas, rootPos, branchPos, paint);

      for (final leaf in branch.children) {
        if (!map.containsKey(leaf)) continue;
        final leafPos = map[leaf]! * scale + offset;
        _drawCurve(canvas, branchPos, leafPos, paint);
      }
    }
  }

  void _drawCurve(Canvas canvas, Offset from, Offset to, Paint paint) {
    final midY = (from.dy + to.dy) / 2;
    final path = Path()
      ..moveTo(from.dx + 40, from.dy + 20)
      ..cubicTo(from.dx + 40, midY, to.dx + 40, midY, to.dx + 40, to.dy);
    canvas.drawPath(path, paint);
  }

  Map<_FlowNode, Offset> _computePositions() {
    final map = <_FlowNode, Offset>{};
    map[root] = const Offset(220, 10);
    const startX = 40.0, stepX = 100.0;
    for (var i = 0; i < root.children.length; i++) {
      final b = root.children[i];
      map[b] = Offset(startX + i * stepX, 90);
      for (var j = 0; j < b.children.length; j++) {
        map[b.children[j]] = Offset(startX + i * stepX, 170);
      }
    }
    return map;
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) => true;
}

// ─── Node widget ────────────────────────────────────────────

class _NodeWidget extends StatelessWidget {
  final _FlowNode node;
  final VoidCallback onTap;
  final void Function(Offset globalPos) onContext;

  const _NodeWidget({required this.node, required this.onTap, required this.onContext});

  @override
  Widget build(BuildContext context) {
    final isRoot = node.type == _FlowNodeType.root;
    final isLeaf = node.type == _FlowNodeType.leaf;
    Color bgColor;
    if (isRoot) {
      bgColor = const Color(0xFF4A2A6E);
    } else if (isLeaf) {
      bgColor = const Color(0xFF1A4A3E);
    } else {
      bgColor = const Color(0xFF2A3A6E);
    }

    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: () {
        final render = context.findRenderObject() as RenderBox?;
        if (render != null) {
          onContext(render.localToGlobal(Offset.zero));
        }
      },
      child: Container(
        width: isRoot ? 90 : 80,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: node.running ? const Color(0xFF6C63FF) : const Color(0xFF5A5A8E),
            width: node.running ? 2 : 1,
          ),
          boxShadow: node.running
              ? [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.3), blurRadius: 8)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              node.label,
              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Progress indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: node.progress,
                backgroundColor: Colors.black26,
                valueColor: AlwaysStoppedAnimation(isRoot ? const Color(0xFF9B6BFF) : const Color(0xFF6C63FF)),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${(node.progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 8, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
