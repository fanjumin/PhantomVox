import 'package:flutter/material.dart';
import '../../widgets/tr.dart';
import '../services/i18n_service.dart';
import '../services/api_service.dart';

/// Flow Graph — Creative flow tree editor.
class FlowGraphPage extends StatefulWidget {
  const FlowGraphPage({super.key});

  @override
  State<FlowGraphPage> createState() => _FlowGraphPageState();
}

// ─── Data model ────────────────────────────────────────────

class _FlowNode {
  final String id;
  String label;
  String nodeType; // topic, scene, beat, missing
  String description;
  bool aiGenerated;
  String status;
  final List<_FlowNode> children;

  _FlowNode({
    required this.id,
    required this.label,
    this.nodeType = 'topic',
    this.description = '',
    this.aiGenerated = false,
    this.status = 'pending',
    List<_FlowNode>? children,
  }) : children = children ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label, 'node_type': nodeType,
    'description': description, 'ai_generated': aiGenerated,
    'status': status,
  };
}

// ─── State ──────────────────────────────────────────────────

class _FlowGraphPageState extends State<FlowGraphPage> {
  final ApiService _api = ApiService();

  // Tree data
  _FlowNode? _root;
  _FlowNode? _selectedNode;
  bool _loading = true;

  // Bottom panel
  bool _showBottomPanel = false;
  int _bottomTab = 0; // 0=Schedule, 1=Logs

  // Schedule + Logs (kept from old version for backward compat)
  static const _scheduleTasks = [
    {'name': 'Daily Report', 'schedule': 'Every day 08:00', 'status': '🟢'},
    {'name': 'Archive Backup', 'schedule': 'Every Monday', 'status': '⚪'},
    {'name': 'Video Transcode', 'schedule': 'Manual only', 'status': '🔴'},
  ];
  static const _runLogs = [
    {'id': '#1423', 'progress': 0.68, 'status': 'running', 'duration': '2m34s'},
    {'id': '#1422', 'progress': 1.0, 'status': 'done', 'duration': '1m12s'},
    {'id': '#1421', 'progress': 0.45, 'status': 'failed', 'duration': '3m01s'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFlowGraph();
  }

  Future<void> _loadFlowGraph() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/v1/flowgraph');
      _root = _parseNodes(data);
    } catch (_) {
      // Default demo data if server not reachable
      _root = _defaultDemo();
    }
    setState(() => _loading = false);
  }

  _FlowNode _parseNodes(Map<String, dynamic> data) {
    final nodes = data['nodes'] as Map<String, dynamic>? ?? {};
    final rootId = data['root'] as String? ?? '';
    if (rootId.isEmpty || nodes.isEmpty) return _defaultDemo();

    // Build map of id -> _FlowNode
    final map = <String, _FlowNode>{};
    for (final entry in nodes.entries) {
      final n = entry.value as Map<String, dynamic>;
      map[entry.key] = _FlowNode(
        id: n['id'] as String,
        label: n['label'] as String? ?? '',
        nodeType: n['node_type'] as String? ?? 'topic',
        description: n['description'] as String? ?? '',
        aiGenerated: n['ai_generated'] as bool? ?? false,
        status: n['status'] as String? ?? 'pending',
      );
    }

    // Link children
    for (final entry in nodes.entries) {
      final n = entry.value as Map<String, dynamic>;
      final node = map[entry.key];
      if (node == null) continue;
      for (final cid in (n['children'] as List? ?? [])) {
        final child = map[cid as String];
        if (child != null) node.children.add(child);
      }
    }

    return map[rootId] ?? _defaultDemo();
  }

  _FlowNode _defaultDemo() {
    return _FlowNode(
      id: 'root', label: 'Demo: Craft Heritage', nodeType: 'topic',
      children: [
        _FlowNode(id: 'n1', label: 'Opening: Master Teaching', nodeType: 'scene',
          description: 'Make close-up shots of leather crafting hands',
          children: [
            _FlowNode(id: 'n1a', label: 'Hand close-up (10s)', nodeType: 'beat'),
            _FlowNode(id: 'n1b', label: 'Student frown', nodeType: 'beat'),
          ]),
        _FlowNode(id: 'n2', label: 'Conflict: Student Frustrated', nodeType: 'scene',
          children: [
            _FlowNode(id: 'n2a', label: 'Drop tool audio', nodeType: 'beat'),
          ]),
        _FlowNode(id: 'n3', label: '[AI] Turning point', nodeType: 'missing',
          description: 'AI suggests: teacher repairs tool at night alone',
          aiGenerated: true),
        _FlowNode(id: 'n4', label: 'Resolution: Final product', nodeType: 'scene'),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────

  void _selectNode(_FlowNode node) {
    setState(() => _selectedNode = node);
  }

  Future<void> _addNode([String? parentId]) async {
    final parent = parentId != null ? _findNode(parentId) : _selectedNode ?? _root;
    if (parent == null) return;

    final labelCtrl = TextEditingController();
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Tr('Add Node', style: TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Node label...',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A2A4E))),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: 'scene',
              items: ['scene', 'beat', 'missing'].map((t) =>
                DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12))),
              ).toList(),
              onChanged: (v) {},
              dropdownColor: const Color(0xFF16213E),
              decoration: const InputDecoration(
                labelText: 'Type', labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Tr('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Tr('Add')),
        ],
      ),
    );

    if (type != 'ok' || labelCtrl.text.isEmpty) return;

    try {
      await _api.post('/api/v1/flowgraph/node', body: {
        'parent_id': parent.id,
        'label': labelCtrl.text,
        'node_type': 'scene',
      });
      await _loadFlowGraph();
    } catch (_) {
      // Fallback: add locally
      setState(() {
        parent.children.add(_FlowNode(
          id: 'n${DateTime.now().millisecondsSinceEpoch}',
          label: labelCtrl.text,
          nodeType: 'scene',
        ));
      });
    }
  }

  Future<void> _deleteNode(String nodeId) async {
    try {
      await _api.delete('/api/v1/flowgraph/node/$nodeId');
      await _loadFlowGraph();
    } catch (_) {
      // Fallback: remove locally
      _removeNode(_root, nodeId);
      setState(() {});
    }
  }

  bool _removeNode(_FlowNode? parent, String id) {
    if (parent == null) return false;
    parent.children.removeWhere((c) => c.id == id);
    for (final c in parent.children) {
      if (_removeNode(c, id)) return true;
    }
    return false;
  }

  Future<void> _aiExpand(String nodeId) async {
    try {
      final result = await _api.post('/api/v1/flowgraph/expand', body: {
        'node_id': nodeId,
      });
      if (result['status'] == 'ok') {
        await _loadFlowGraph();
      }
    } catch (_) {
      // Fallback: add a mock AI suggestion
      final node = _findNode(nodeId);
      if (node != null) {
        setState(() {
          node.children.add(_FlowNode(
            id: 'ai${DateTime.now().millisecondsSinceEpoch}',
            label: '[AI] Suggested scene',
            nodeType: 'missing',
            description: 'AI generated suggestion — review and adjust',
            aiGenerated: true,
          ));
        });
      }
    }
  }

  Future<void> _saveFlowGraph() async {
    try {
      await _api.post('/api/v1/flowgraph/root', body: {
        'label': _root?.label ?? 'Untitled',
      });
      if (_root != null) await _saveNodeRecursive(_root!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Tr('Saved'), duration: const Duration(seconds: 1)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Tr('Save failed — server not reachable'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _saveNodeRecursive(_FlowNode node) async {
    for (final child in node.children) {
      await _api.post('/api/v1/flowgraph/node', body: {
        'parent_id': node.id,
        'label': child.label,
        'node_type': child.nodeType,
        'description': child.description,
        'ai_generated': child.aiGenerated,
      });
      await _saveNodeRecursive(child);
    }
  }

  Future<void> _updateNodeLabel(String nodeId, String newLabel) async {
    try {
      await _api.patch('/api/v1/flowgraph/node/$nodeId', body: {'label': newLabel});
      final node = _findNode(nodeId);
      if (node != null) setState(() => node.label = newLabel);
    } catch (_) {
      final node = _findNode(nodeId);
      if (node != null) setState(() => node.label = newLabel);
    }
  }

  _FlowNode? _findNode(String id, [_FlowNode? parent]) {
    parent ??= _root;
    if (parent == null) return null;
    if (parent.id == id) return parent;
    for (final c in parent.children) {
      final found = _findNode(id, c);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _reorderNode(_FlowNode parent, int oldIdx, int newIdx) async {
    setState(() {
      if (oldIdx < newIdx) newIdx--;
      final node = parent.children.removeAt(oldIdx);
      parent.children.insert(newIdx, node);
    });
    // Sync to API
    try {
      final ids = parent.children.map((c) => c.id).toList();
      await _api.post('/api/v1/flowgraph/reorder', body: {
        'parent_id': parent.id,
        'child_ids': ids,
      });
    } catch (_) {}
  }

  Future<void> _changeNodeType(String nodeId, String newType) async {
    final node = _findNode(nodeId);
    if (node == null) return;
    try {
      await _api.patch('/api/v1/flowgraph/node/$nodeId', body: {'node_type': newType});
      setState(() => node.nodeType = newType);
    } catch (_) {
      setState(() => node.nodeType = newType);
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(
        children: [
          _buildTopBar(),
          const Divider(height: 1, color: Color(0xFF2A2A4E)),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final title = _root?.label ?? 'Flow Graph';
    return Container(
      height: 40,
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Tr('Flow Graph', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A4E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(i18n.tr(title), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A4E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(child: Tr('Draft', style: TextStyle(fontSize: 10, color: Colors.green))),
                ),
              ]),
            ),
          ),
          _topBtn(i18n.tr('Save'), Icons.save, () {
            // Re-think how saving works
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Tr('Flow graph is auto-synced via API — use Save to persist'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }),
          const SizedBox(width: 4),
          _topBtn(i18n.tr('+ Node'), Icons.add, () => _addNode()),
          const SizedBox(width: 4),
          _topBtn(i18n.tr('AI'), Icons.auto_awesome,
              () => _aiExpand(_selectedNode?.id ?? _root?.id ?? 'root')),
          const SizedBox(width: 4),
          _topBtn(_showBottomPanel ? '▾' : '▴', Icons.expand_less,
              () => setState(() => _showBottomPanel = !_showBottomPanel)),
        ],
      ),
    );
  }

  Widget _topBtn(String label, IconData icon, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A4E),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: label.length <= 3
              ? Text(label, style: const TextStyle(fontSize: 10, color: Colors.white))
              : Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────

  Widget _buildBody() {
    if (_root == null) return const Center(child: Tr('No flow graph data'));
    return Column(
      children: [
        Expanded(child: Row(
          children: [
            // Tree view (60%)
            Expanded(flex: 3, child: _buildTreeView()),
            Container(width: 1, color: const Color(0xFF2A2A4E)),
            // Node detail panel (40%)
            Expanded(flex: 2, child: _buildDetailPanel()),
          ],
        )),
        if (_showBottomPanel) ...[
          const Divider(height: 1, color: Color(0xFF2A2A4E)),
          SizedBox(height: 120, child: _buildBottomPanel()),
        ],
      ],
    );
  }

  // ══════════════ Tree view ═══════════════════════════════

  Widget _buildTreeView() {
    return Container(
      color: const Color(0xFF111122),
      child: _root == null ? const SizedBox.shrink() : _buildNodeTree(_root!, 0),
    );
  }

  Widget _buildNodeTree(_FlowNode node, int depth) {
    if (node.nodeType == 'beat' && node.children.isEmpty) {
      return _buildLeafTile(node, depth);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBranchTile(node, depth),
        if (node.children.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: node.children.length,
            onReorder: (oldIdx, newIdx) => _reorderNode(node, oldIdx, newIdx),
            proxyDecorator: (child, _, __) => Material(
              color: Colors.transparent,
              child: Opacity(opacity: 0.7, child: child),
            ),
            itemBuilder: (ctx, i) {
              final child = node.children[i];
              return _buildNodeTree(child, depth + 1);
            },
          ),
      ],
    );
  }

  Widget _buildBranchTile(_FlowNode node, int depth) {
    final isSelected = _selectedNode?.id == node.id;
    final icon = _nodeIcon(node.nodeType);
    final color = _nodeColor(node.nodeType);

    return GestureDetector(
      onTap: () => _selectNode(node),
      child: Container(
        key: ValueKey(node.id),
        padding: EdgeInsets.only(
          left: 12.0 + depth * 20.0,
          right: 8,
          top: 6,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A4E) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFF1A1A2E), width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            if (node.aiGenerated)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text('AI', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            Expanded(
              child: Text(
                i18n.tr(node.label),
                style: TextStyle(
                  fontSize: 12,
                  color: node.aiGenerated ? Colors.orange.shade200 : Colors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  decoration: node.nodeType == 'missing' ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (node.children.isNotEmpty)
              Text('${node.children.length}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            PopupMenuButton<String>(
              onSelected: (action) => _handleNodeAction(node, action),
              color: const Color(0xFF16213E),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'add', child: Tr('Add Child', style: TextStyle(color: Colors.white, fontSize: 11))),
                const PopupMenuItem(value: 'ai', child: Tr('AI Expand', style: TextStyle(color: Colors.white, fontSize: 11))),
                const PopupMenuItem(value: 'delete', child: Tr('Delete', style: TextStyle(color: Colors.red, fontSize: 11))),
              ],
              icon: const Icon(Icons.more_horiz, size: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeafTile(_FlowNode node, int depth) {
    final isSelected = _selectedNode?.id == node.id;
    final color = _nodeColor(node.nodeType);

    return GestureDetector(
      onTap: () => _selectNode(node),
      child: Container(
        key: ValueKey(node.id),
        padding: EdgeInsets.only(
          left: 12.0 + depth * 20.0,
          right: 8,
          top: 5,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A4E) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFF1A1A2E), width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              i18n.tr(node.label),
              style: TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            PopupMenuButton<String>(
              onSelected: (a) => _handleNodeAction(node, a),
              color: const Color(0xFF16213E),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'add', child: Tr('Add Child', style: TextStyle(color: Colors.white, fontSize: 11))),
                const PopupMenuItem(value: 'delete', child: Tr('Delete', style: TextStyle(color: Colors.red, fontSize: 11))),
              ],
              icon: const Icon(Icons.more_horiz, size: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNodeAction(_FlowNode node, String action) {
    switch (action) {
      case 'add': _addNode(node.id); break;
      case 'ai': _aiExpand(node.id); break;
      case 'delete': _deleteNode(node.id); break;
    }
  }

  // ══════════════ Detail panel ═══════════════════════════

  Widget _buildDetailPanel() {
    if (_selectedNode == null) {
      return Container(
        color: const Color(0xFF0D0D1A),
        child: Center(
          child: Tr('Select a node to edit', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ),
      );
    }

    final node = _selectedNode!;
    final labelCtrl = TextEditingController(text: node.label);
    final descCtrl = TextEditingController(text: node.description);

    return Container(
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_nodeIcon(node.nodeType), size: 16, color: _nodeColor(node.nodeType)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _nodeColor(node.nodeType).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(node.nodeType.toUpperCase(), style: TextStyle(fontSize: 9, color: _nodeColor(node.nodeType), fontWeight: FontWeight.bold)),
              ),
              if (node.aiGenerated) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text('AI', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: labelCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Label...',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A2A4E))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
              isDense: true,
            ),
            onSubmitted: (v) => _updateNodeLabel(node.id, v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            maxLines: 4,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            decoration: InputDecoration(
              hintText: i18n.tr('Description...'),
              hintStyle: const TextStyle(color: Colors.grey),
              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A2A4E))),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
              isDense: true,
              contentPadding: const EdgeInsets.all(8),
            ),
            onSubmitted: (v) {
              _changeDescription(node.id, v);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _detailBtn(i18n.tr('Add Child'), Icons.add, () => _addNode(node.id)),
              const SizedBox(width: 6),
              _detailBtn(i18n.tr('AI Expand'), Icons.auto_awesome, () => _aiExpand(node.id)),
              const SizedBox(width: 6),
              _detailBtn(i18n.tr('Delete'), Icons.delete, () => _deleteNode(node.id),
                  color: Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          // Type selector
          Tr('Type', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: node.nodeType,
            items: ['topic', 'scene', 'beat', 'missing'].map((t) =>
              DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.white))),
            ).toList(),
            onChanged: (v) {
              if (v != null) _changeNodeType(node.id, v);
            },
            dropdownColor: const Color(0xFF16213E),
            decoration: const InputDecoration(
              isDense: true,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A2A4E))),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _changeDescription(String nodeId, String desc) {
    final node = _findNode(nodeId);
    if (node != null) setState(() => node.description = desc);
  }

  Widget _detailBtn(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 12),
      label: Text(i18n.tr(label), style: const TextStyle(fontSize: 10)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? Colors.white,
        side: BorderSide(color: color?.withValues(alpha: 0.5) ?? const Color(0xFF2A2A4E)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ══════════════ Bottom panel ═══════════════════════════

  Widget _buildBottomPanel() {
    return Container(
      color: const Color(0xFF0D0D1A),
      child: Column(
        children: [
          Row(
            children: [
              _bottomTabBtn('Schedule', 0),
              _bottomTabBtn('Logs', 1),
              const Spacer(),
              _bottomTabBtn('×', -1),
            ],
          ),
          const Divider(height: 1, color: Color(0xFF2A2A4E)),
          Expanded(child: _bottomTab == 0 ? _buildScheduleView() : _buildLogsView()),
        ],
      ),
    );
  }

  Widget _bottomTabBtn(String label, int idx) {
    final active = idx == _bottomTab;
    return GestureDetector(
      onTap: () => setState(() {
        if (idx == -1) {
          _showBottomPanel = false;
        } else {
          _bottomTab = idx;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: active ? const Color(0xFF6C63FF) : Colors.transparent, width: 2,
          )),
        ),
        child: Text(
          idx == -1 ? '×' : i18n.tr(label),
          style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildScheduleView() {
    return ListView.builder(
      itemCount: _scheduleTasks.length,
      itemBuilder: (_, i) {
        final t = _scheduleTasks[i];
        return ListTile(
          dense: true,
          leading: Text(t['status']!, style: const TextStyle(fontSize: 12)),
          title: Text(t['name']!, style: const TextStyle(fontSize: 11, color: Colors.white)),
          subtitle: Text(t['schedule']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        );
      },
    );
  }

  Widget _buildLogsView() {
    return ListView.builder(
      itemCount: _runLogs.length,
      itemBuilder: (_, i) {
        final r = _runLogs[i];
        final icon = r['status'] == 'running' ? '🟢' : r['status'] == 'done' ? '✅' : '🔴';
        return ListTile(
          dense: true,
          leading: Text(icon, style: const TextStyle(fontSize: 12)),
          title: Text('${r['id']}  ${r['duration']}', style: const TextStyle(fontSize: 11, color: Colors.white)),
          subtitle: LinearProgressIndicator(
            value: r['progress'] as double,
            backgroundColor: const Color(0xFF2A2A4E),
            valueColor: AlwaysStoppedAnimation(r['status'] == 'failed' ? Colors.red : const Color(0xFF6C63FF)),
          ),
        );
      },
    );
  }

  // ─── Helpers ───────────────────────────────────────────

  IconData _nodeIcon(String type) {
    switch (type) {
      case 'topic': return Icons.circle;
      case 'scene': return Icons.crop_square;
      case 'beat': return Icons.play_arrow;
      case 'missing': return Icons.help_outline;
      default: return Icons.circle;
    }
  }

  Color _nodeColor(String type) {
    switch (type) {
      case 'topic': return const Color(0xFF9B6BFF); // Purple
      case 'scene': return const Color(0xFF6C63FF); // Blue
      case 'beat': return const Color(0xFF4CAF50);  // Green
      case 'missing': return const Color(0xFFFF9800); // Orange
      default: return Colors.grey;
    }
  }
}
