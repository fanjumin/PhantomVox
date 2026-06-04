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
  String nodeType;
  String description;
  bool aiGenerated;
  String status;
  String? parentId;
  final List<_FlowNode> children;

  _FlowNode({
    required this.id,
    required this.label,
    this.nodeType = 'topic',
    this.description = '',
    this.aiGenerated = false,
    this.status = 'pending',
    this.parentId,
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
  int _bottomTab = 0; // 0=Chat, 1=Versions

  // Chat state
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  bool _chatLoading = false;

  // Versions state
  List<Map<String, dynamic>> _versions = [];
  bool _versionsLoading = false;

  // Collapse state: node IDs whose children are hidden
  final Set<String> _collapsedIds = {};

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
    setState(() {
      _loading = false;
      _collapsedIds.clear(); // Reset collapse state on reload
    });
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
        parentId: n['parent_id'] as String?,
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

    // Add locally immediately, then sync to server in background
    final newNode = _FlowNode(
      id: 'n${DateTime.now().millisecondsSinceEpoch}',
      label: labelCtrl.text,
      nodeType: 'scene',
      parentId: parent.id,
    );
    setState(() {
      parent.children.add(newNode);
    });

    // Background sync to server (don't block UI)
    try {
      await _api.post('/api/v1/flowgraph/node', body: {
        'parent_id': parent.id,
        'label': labelCtrl.text,
        'node_type': 'scene',
      });
    } catch (_) {
      // Local add is enough
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
    final node = _findNode(nodeId);
    if (node == null) return;

    // Try server AI expand with full node info
    try {
      final result = await _api.post('/api/v1/flowgraph/expand', body: {
        'node_id': nodeId,
        'label': node.label,
        'node_type': node.nodeType,
        'description': node.description,
      });
      if (result['status'] == 'ok') {
        final suggestions = result['suggestions'] as List? ?? [];
        if (suggestions.isNotEmpty) {
          setState(() {
            for (final s in suggestions) {
              node.children.add(_FlowNode(
                id: s['id'] as String? ?? 'ai${DateTime.now().millisecondsSinceEpoch}',
                label: s['label'] as String? ?? '[AI] Suggestion',
                nodeType: s['node_type'] as String? ?? 'missing',
                aiGenerated: true,
              ));
            }
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback: local mock AI suggestion
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

  Future<void> _saveFlowGraph() async {
    if (_root == null) return;
    try {
      // Build the full tree dict from local data
      final treeData = _buildTreeDict(_root!);
      await _api.post('/api/v1/flowgraph/save', body: treeData);
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

  Map<String, dynamic> _buildTreeDict(_FlowNode node) {
    final nodes = <String, dynamic>{};
    void walk(_FlowNode n) {
      nodes[n.id] = {
        'id': n.id,
        'label': n.label,
        'node_type': n.nodeType,
        'description': n.description,
        'ai_generated': n.aiGenerated,
        'status': n.status,
        'parent_id': n.parentId,
        'children': n.children.map((c) => c.id).toList(),
        'progress': 0.0,
        'agent': '',
        'metadata': {},
      };
      for (final c in n.children) {
        walk(c);
      }
    }
    walk(node);
    return {'root': node.id, 'nodes': nodes};
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
          _topBtn(i18n.tr('Save'), Icons.save, () => _saveFlowGraph()),
          const SizedBox(width: 4),
          _topBtn(i18n.tr('Import'), Icons.file_open, () => _importFlowGraph()),
          const SizedBox(width: 4),
          _topBtn(i18n.tr('Export'), Icons.save_alt, () => _exportFlowGraph()),
          const SizedBox(width: 4),
          _topBtn(i18n.tr('Delete'), Icons.delete, () => _deleteFlowGraph()),
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

  // ── Flat tree view — single ReorderableListView ────────

  /// Flatten tree to a list of (node, depth) pairs (pre-order).
  /// Skips children of collapsed nodes.
  List<MapEntry<_FlowNode, int>> _flattenTree(_FlowNode node, int depth) {
    final result = <MapEntry<_FlowNode, int>>[];
    result.add(MapEntry(node, depth));
    if (!_collapsedIds.contains(node.id)) {
      for (final child in node.children) {
        result.addAll(_flattenTree(child, depth + 1));
      }
    }
    return result;
  }

  Widget _buildTreeView() {
    if (_root == null) {
      return const Center(child: Tr('No flow graph data'));
    }

    final flatList = _flattenTree(_root!, 0);

    return Container(
      color: const Color(0xFF111122),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: flatList.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF2A2A4E)),
        itemBuilder: (ctx, i) {
          final entry = flatList[i];
          final node = entry.key;
          final depth = entry.value;
          final isSelected = _selectedNode?.id == node.id;
          final color = _nodeColor(node.nodeType);

          return GestureDetector(
            onTap: () => _selectNode(node),
            child: Container(
              key: ValueKey('${node.id}_$i'),
              padding: EdgeInsets.only(
                left: 12.0 + depth * 20.0,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2A2A4E) : Colors.transparent,
              ),
              child: Row(
                children: [
                  // Collapse / expand toggle
                  SizedBox(
                    width: 16,
                    child: node.children.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_collapsedIds.contains(node.id)) {
                                  _collapsedIds.remove(node.id);
                                } else {
                                  _collapsedIds.add(node.id);
                                }
                              });
                            },
                            child: Icon(
                              _collapsedIds.contains(node.id) ? Icons.arrow_right : Icons.arrow_drop_down,
                              size: 16, color: Colors.grey,
                            ),
                          )
                        : const SizedBox(width: 16),
                  ),
                  Icon(_nodeIcon(node.nodeType), size: 14, color: color),
                  const SizedBox(width: 8),
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
                      node.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: node.aiGenerated ? Colors.orange.shade200 : Colors.white,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Child count
                  if (node.children.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${node.children.length}',
                          style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ),
                  // Menu
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
        },
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
              _bottomTabBtn('Chat', 0),
              _bottomTabBtn('Versions', 1),
              const Spacer(),
              _bottomTabBtn('×', -1),
            ],
          ),
          const Divider(height: 1, color: Color(0xFF2A2A4E)),
          Expanded(
            child: _bottomTab == 0 ? _buildChatView() : _buildVersionsView(),
          ),
        ],
      ),
    );
  }

  Widget _bottomTabBtn(String label, int idx) {
    final active = idx == _bottomTab;
    return GestureDetector(
      onTap: () {
        if (idx == -1) {
          setState(() => _showBottomPanel = false);
        } else {
          setState(() => _bottomTab = idx);
          if (idx == 1) _loadVersions();
        }
      },
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

  // ── Chat tab ──────────────────────────────────────────

  Widget _buildChatView() {
    return Column(
      children: [
        // Messages
        Expanded(
          child: _chatMessages.isEmpty
            ? Center(
                child: Text('Describe what you want to create.\ne.g. "都市办公室爱情短剧"',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _chatMessages.length,
                itemBuilder: (_, i) {
                  final msg = _chatMessages[i];
                  final isUser = msg['role'] == 'user';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isUser ? const Color(0xFF6C63FF) : const Color(0xFF2A2A4E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(msg['content'] ?? '',
                                style: const TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
        if (_chatLoading)
          const Padding(
            padding: EdgeInsets.all(4),
            child: SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
          ),
        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF2A2A4E))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Describe your project...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              GestureDetector(
                onTap: _chatLoading ? null : _sendChatMessage,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _chatLoading ? Colors.grey : const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.send, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendChatMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _chatLoading) return;
    _chatCtrl.clear();

    setState(() {
      _chatMessages.add({'role': 'user', 'content': text});
      _chatLoading = true;
    });

    try {
      // Auto-save version before generating
      try { await _api.post('/api/v1/flowgraph/versions/save'); } catch (_) {}

      final result = await _api.post('/api/v1/flowgraph/generate',
          body: {'prompt': text});

      if (result['status'] == 'ok' && result['flowgraph'] != null) {
        final fg = result['flowgraph'] as Map<String, dynamic>;
        final nodes = fg['nodes'] as Map<String, dynamic>? ?? {};
        final count = nodes.length;
        final rootLabel = (nodes[fg['root']] as Map<String, dynamic>?)?['label'] ?? '';

        // Reload tree from server
        await _loadFlowGraph();
        setState(() {
          _chatMessages.add({'role': 'assistant',
              'content': '✅ Generated "$rootLabel" — $count nodes created.'});
          _chatLoading = false;
        });
      } else {
        setState(() {
          _chatMessages.add({'role': 'assistant',
              'content': '❌ ${result['error'] ?? 'Generation failed'}'});
          _chatLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({'role': 'assistant', 'content': '❌ Error: $e'});
        _chatLoading = false;
      });
    }
  }

  // ── Versions tab ──────────────────────────────────────

  Future<void> _loadVersions() async {
    setState(() => _versionsLoading = true);
    try {
      final result = await _api.get('/api/v1/flowgraph/versions');
      _versions = (result['versions'] as List? ?? [])
          .cast<Map<String, dynamic>>();
    } catch (_) {
      _versions = [];
    }
    if (mounted) setState(() => _versionsLoading = false);
  }

  Widget _buildVersionsView() {
    if (_versionsLoading) {
      return const Center(
        child: SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
      );
    }
    if (_versions.isEmpty) {
      return const Center(
        child: Text('No saved versions yet. Chat generates auto-snapshots.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _versions.length,
      itemBuilder: (_, i) {
        final v = _versions[i];
        final time = DateTime.fromMillisecondsSinceEpoch(
            ((v['time'] as num) * 1000).toInt());
        final timeStr = '${time.month.toString().padLeft(2, '0')}-'
            '${time.day.toString().padLeft(2, '0')} '
            '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}';
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v['title'] ?? 'Untitled',
                        style: const TextStyle(fontSize: 11, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('$timeStr · ${v['node_count']} nodes',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _restoreVersion(v['file'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('Restore',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _restoreVersion(String file) async {
    try {
      await _api.post('/api/v1/flowgraph/versions/restore', body: {'file': file});
      await _loadFlowGraph();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Version restored'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), duration: Duration(seconds: 3)),
        );
      }
    }
  }

  // ── Delete ─────────────────────────────────────────────

  Future<void> _deleteFlowGraph() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Flow Graph?',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        content: const Text('This will clear all nodes. Are you sure?',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.post('/api/v1/flowgraph/delete');
      await _loadFlowGraph();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flow graph cleared'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), duration: Duration(seconds: 3)),
        );
      }
    }
  }

  // ── Import ──────────────────────────────────────────────

  Future<void> _importFlowGraph() async {
    final dataDir = '/home/guxiao/projects/video_ai_agent/data';
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '$dataDir/');
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Import Flow Graph',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter path to JSON file:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: ctrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: '/path/to/flowgraph.json',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey, fontSize: 12))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Import',
                    style:
                        TextStyle(color: Color(0xFF6C63FF), fontSize: 12))),
          ],
        );
      },
    );

    if (picked == null || picked.isEmpty) return;

    try {
      await _api.post('/api/v1/flowgraph/import', body: {'path': picked});
      await _loadFlowGraph();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Imported successfully'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import failed: $e'),
              duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  // ── Export ───────────────────────────────────────────────

  Future<void> _exportFlowGraph() async {
    final dataDir = '/home/guxiao/projects/video_ai_agent/data';
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '$dataDir/');
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Export Flow Graph',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Save to path:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: ctrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: '/path/to/export.json',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey, fontSize: 12))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Export',
                    style:
                        TextStyle(color: Color(0xFF6C63FF), fontSize: 12))),
          ],
        );
      },
    );

    if (picked == null || picked.isEmpty) return;

    try {
      await _api.post('/api/v1/flowgraph/export', body: {'path': picked});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Exported successfully'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              duration: const Duration(seconds: 3)),
        );
      }
    }
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
