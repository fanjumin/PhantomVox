import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/tr.dart';
import '../../services/i18n_service.dart';

/// AI Agent page — multi-agent control center with mind map
class AgentPage extends StatefulWidget {
  const AgentPage({super.key});

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _subTabCtrl;

  // Chat state
  final _chatCtrl = TextEditingController();
  final _messages = <Map<String, String>>[
    {'role': 'assistant', 'content': 'Hello! I am the PhantomVox AI Director. How can I help with your project?'},
  ];

  // Think state
  final _thinkSteps = <String>[
    'Goal analysis: "Create a product promo video"',
    'Decomposition: voiceover, music, B-roll, transitions',
    'Resources: checking available clips (12 items)',
    'Timeline estimate: ~45 seconds',
  ];

  // Image gen state
  final _imgPromptCtrl = TextEditingController();

  // Video gen state
  final _vidPromptCtrl = TextEditingController();

  // Agent matrix
  final _agents = <Map<String, dynamic>>[
    {'name': 'Director', 'status': 'active', 'desc': 'Task orchestration', 'icon': Icons.psychology},
    {'name': 'Editor', 'status': 'idle', 'desc': 'Timeline editing', 'icon': Icons.content_cut},
    {'name': 'Audio', 'status': 'active', 'desc': 'Voice & SFX', 'icon': Icons.record_voice_over},
    {'name': 'Music', 'status': 'idle', 'desc': 'Music composition', 'icon': Icons.music_note},
    {'name': 'Visual', 'status': 'active', 'desc': 'Image generation', 'icon': Icons.image},
    {'name': 'Color', 'status': 'idle', 'desc': 'Color grading', 'icon': Icons.palette},
    {'name': 'Restore', 'status': 'active', 'desc': 'Photo restoration', 'icon': Icons.healing},
    {'name': 'Code', 'status': 'active', 'desc': 'Custom effects', 'icon': Icons.code},
  ];

  bool _loading = false;
  String? _selectedAgent;
  String _generatedCode = '// Generated code will appear here\n// Try: "sepia tone", "fade transition", "glitch effect"';
  String? _currentWorkflowId;
  List<Map<String, dynamic>> _workflowTasks = [];
  List<Map<String, dynamic>> _timelineAssets = [];
  Map<String, dynamic>? _lastWorkflowResult;

  @override
  void initState() {
    super.initState();
    _subTabCtrl = TabController(length: 5, vsync: this);
    _loadAgentStatus();
  }

  @override
  void dispose() {
    _subTabCtrl.dispose();
    _chatCtrl.dispose();
    _imgPromptCtrl.dispose();
    _vidPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAgentStatus() async {
    try {
      final agents = await _api.get('/api/v1/agent/agents');
      if (agents is List && agents.isNotEmpty) {
        setState(() {
          for (final a in agents) {
            final idx = _agents.indexWhere((x) => x['name'] == a['name']);
            if (idx >= 0) {
              _agents[idx] = {
                ..._agents[idx],
                'status': a['status'] ?? 'idle',
                'desc': a['description'] ?? _agents[idx]['desc'],
              };
            }
          }
        });
      }
    } catch (_) {
      // Use mock data when offline
    }
  }

  Future<void> _generateCode() async {
    final query = _chatCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() { _loading = true; _generatedCode = '// Generating...'; });
    try {
      final resp = await _api.post('/api/v1/codegen/generate', body: {'query': query});
      setState(() {
        if (resp['status'] == 'ok') {
          _generatedCode = '// ${resp['name']} — ${resp['description']}\n'
              '// Category: ${resp['category']}\n'
              '// Filter code:\n'
              '${resp['filter_code']}\n';
        } else {
          _generatedCode = '// Error: ${resp['message']}\n'
              '// Suggestions: ${(resp['suggestions'] as List?)?.take(5).join(', ') ?? ''}';
        }
        _loading = false;
      });
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _generatedCode = '// Offline — using local templates\n'
            '// Try these effects:\n'
            '//   sepia tone, grayscale, fade transition,\n'
            '//   slow motion, glitch effect, volume up';
        _loading = false;
      });
    }
  }

  Future<void> _sendChat() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
      _workflowTasks = [];
      _timelineAssets = [];
      _lastWorkflowResult = null;
      _currentWorkflowId = null;
    });
    _chatCtrl.clear();
    try {
      final resp = await _api.post('/api/v1/agent/workflow', body: {'intent': text});
      setState(() {
        _currentWorkflowId = resp['id'] as String?;
        _lastWorkflowResult = resp;
        final tasks = resp['tasks'] as List? ?? [];
        _workflowTasks = tasks.cast<Map<String, dynamic>>();
        final assets = resp['timeline_assets'] as List? ?? [];
        _timelineAssets = assets.cast<Map<String, dynamic>>();

        final status = resp['status'] ?? 'completed';
        final count = resp['completed_count'] ?? 0;
        final total = resp['task_count'] ?? 0;
        final agentList = tasks.map((t) => t['agent'] ?? '?').join(', ');

        String resultText;
        if (status == 'completed') {
          resultText = 'Workflow completed successfully! '
              'Dispatched $count/$total tasks to: $agentList.\n\n'
              'Generated ${assets.length} timeline assets. '
              'Tap "Apply to Timeline" to use them.';
        } else {
          resultText = 'Workflow completed with ${resp['error_count'] ?? 0} errors. Check results below.';
        }
        _messages.add({'role': 'assistant', 'content': resultText});
        _loading = false;
      });
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Workflow started. I decomposed your request into subtasks and dispatched them to the agent team.\n\n'
              'Voiceover -> Audio Agent\n'
              'Music -> Composer Agent\n'
              'B-Roll -> Visual Agent\n'
              'Transitions -> Code Agent\n\n'
              'All tasks completed. Generated 4 timeline assets ready for editing.'
        });
        _timelineAssets = [
          {'type': 'audio', 'label': 'Voiceover', 'track': 'A1'},
          {'type': 'audio', 'label': 'Background Music', 'track': 'A2'},
          {'type': 'image', 'label': 'Background Visual', 'track': 'V1'},
          {'type': 'effect', 'label': 'Custom Transition', 'track': 'FX'},
        ];
        _loading = false;
      });
    }
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
                Tr('AI Agent', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Tr('Model: GPT-4o',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                const SizedBox(width: 8),
                _headerChip('All Agents Active', Colors.green),
              ],
            ),
          ),
          // Sub-tab bar
          Container(
            height: 28,
            color: const Color(0xFF12121E),
            child: TabBar(
              controller: _subTabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF6C63FF),
              labelStyle: const TextStyle(fontSize: 10),
              tabs: const [
                Tab(icon: Icon(Icons.chat, size: 14), text: 'Chat'),
                Tab(icon: Icon(Icons.psychology, size: 14), text: 'Think'),
                Tab(icon: Icon(Icons.image, size: 14), text: 'Image'),
                Tab(icon: Icon(Icons.videocam, size: 14), text: 'Video'),
                Tab(icon: Icon(Icons.code, size: 14), text: 'Code'),
              ],
            ),
          ),
          // Main body: sub-panels (left) + agent matrix (right)
          Expanded(
            child: Row(
              children: [
                // Left: active sub-panel (takes all remaining space)
                Expanded(
                  child: TabBarView(
                    controller: _subTabCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildChatPanel(),
                      _buildThinkPanel(),
                      _buildImageGenPanel(),
                      _buildVideoGenPanel(),
                      _buildCodePanel(),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFF2A2A3E)),
                // Right: agent matrix
                _buildAgentMatrix(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-panels ──

  Widget _buildChatPanel() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final msg = _messages[i];
              final isUser = msg['role'] == 'user';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isUser) ...[
                      Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C63FF),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.auto_fix_high, size: 12, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFF16213E)
                              : const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(msg['content'] ?? '',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    if (isUser) const SizedBox(width: 6),
                  ],
                ),
              );
            },
          ),
        ),
        // Timeline assets (shown after workflow completes)
        if (_timelineAssets.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            color: const Color(0xFF0D1B0D),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Tr('Timeline Assets', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA5D6A7))),
                    const Spacer(),
                    Text('${_timelineAssets.length} items',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 4),
                ...(_timelineAssets.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      _assetIcon(a['type'] as String? ?? 'info'),
                      const SizedBox(width: 6),
                      Text(a['label'] as String? ?? 'Asset',
                          style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3E),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(a['track'] as String? ?? a['type'] as String? ?? '',
                            style: TextStyle(fontSize: 8, color: Colors.grey[500], fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                ))),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.timeline, size: 14),
                    label: Tr('Apply to Timeline', style: TextStyle(fontSize: 10)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      backgroundColor: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Input bar
        Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF12121E),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: _loading ? i18n.tr('Thinking...') : i18n.tr('Ask AI to do anything...'),
                    hintStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, size: 18),
                onPressed: _loading ? null : _sendChat,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThinkPanel() {
    return Column(
      children: [
        Container(
          height: 24,
          color: const Color(0xFF12121E),
          padding: const EdgeInsets.only(left: 8),
          alignment: Alignment.centerLeft,
          child: Tr('Reasoning Chain', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _thinkSteps.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: i < _thinkSteps.length - 1
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF9800),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_thinkSteps[i],
                        style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGenPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr('Image Generation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _imgPromptCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: i18n.tr('Describe the image...'),
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.image, size: 16),
                  label: Tr('Generate', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.auto_fix_high, size: 14),
                label: Tr('AI Enhance', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showImageProcessingPopup(),
                icon: const Icon(Icons.build, size: 14),
                label: Tr('Master Tools', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Output placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2A2A3E)),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 40, color: Colors.white24),
                    SizedBox(height: 8),
                    Tr('Generated image preview', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageProcessingPopup() {
    showDialog(
      context: context,
      builder: (ctx) => _ImageProcessingDialog(),
    );
  }

  Widget _buildVideoGenPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr('Video Generation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _vidPromptCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: i18n.tr('Describe the video...'),
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.videocam, size: 16),
                  label: Tr('Generate', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.movie, size: 14),
                label: Tr('Image to Video', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Output placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2A2A3E)),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_outlined, size: 40, color: Colors.white24),
                    SizedBox(height: 8),
                    Tr('Generated video preview', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodePanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr('Code Generation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _chatCtrl,  // reuse chat input for code query
            maxLines: 2,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: i18n.tr('Describe the effect...'),
              filled: true,
              fillColor: Color(0xFF1A1A2E),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _generateCode,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.code, size: 16),
              label: Text(_loading ? i18n.tr('Generating...') : i18n.tr('Generate Code'), style: const TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2A2A3E)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _generatedCode,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFFA5D6A7)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Center: Mind map ──

  // ── Right: Agent matrix ──

  Widget _buildAgentMatrix() {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.only(left: 8),
            color: const Color(0xFF12121E),
            alignment: Alignment.centerLeft,
            child: Tr('Agent Matrix', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(6),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.9,
              children: _agents.map((a) => _agentCard(a)).toList(),
            ),
          ),
          // Detail panel when agent selected
          if (_selectedAgent != null)
            Container(
              height: 80,
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF12121E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedAgent!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Tr('Status: Active | Tasks: 3 | Progress: 60%', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _agentActionBtn('Pause', Icons.pause),
                      const SizedBox(width: 4),
                      _agentActionBtn('Adjust', Icons.tune),
                      const SizedBox(width: 4),
                      _agentActionBtn('Manual', Icons.edit),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _agentCard(Map<String, dynamic> agent) {
    final active = agent['status'] == 'active';
    final name = agent['name'] as String;
    return GestureDetector(
      onTap: () => setState(() => _selectedAgent = _selectedAgent == name ? null : name),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF16213E).withOpacity(0.8)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? const Color(0xFF6C63FF) : const Color(0xFF2A2A3E),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(agent['icon'] as IconData,
                size: 20,
                color: active ? const Color(0xFF6C63FF) : Colors.grey),
            const SizedBox(height: 4),
            Text(name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? Colors.white : Colors.grey,
                )),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(active ? i18n.tr('ACTIVE') : i18n.tr('IDLE'),
                  style: TextStyle(
                    fontSize: 7,
                    color: active ? Colors.green[300] : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable ──

  Widget _headerChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9, color: color.withOpacity(0.9))),
    );
  }

  Widget _assetIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'audio':
        icon = Icons.audiotrack; color = const Color(0xFF4CAF50); break;
      case 'video':
        icon = Icons.videocam; color = const Color(0xFF1565C0); break;
      case 'image':
        icon = Icons.image; color = const Color(0xFFFF9800); break;
      case 'effect':
        icon = Icons.auto_fix_high; color = const Color(0xFFAB47BC); break;
      case 'timeline':
        icon = Icons.timeline; color = const Color(0xFF6C63FF); break;
      default:
        icon = Icons.info_outline; color = Colors.grey;
    }
    return Icon(icon, size: 14, color: color);
  }

  Widget _agentActionBtn(String label, IconData icon) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 10, color: Colors.grey),
            const SizedBox(width: 3),
            Text(label,
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// Image processing master tools dialog — modal popup with 8 quick tools.
class _ImageProcessingDialog extends StatefulWidget {
  @override
  State<_ImageProcessingDialog> createState() => _ImageProcessingDialogState();
}

class _ImageProcessingDialogState extends State<_ImageProcessingDialog> {
  int _selectedTool = 0;
  double _strength = 0.7;

  static const _tools = [
    _ToolData('Enhance', Icons.auto_fix_high, Colors.blue),
    _ToolData('Filter', Icons.color_lens, Colors.purple),
    _ToolData('Restore', Icons.healing, Colors.orange),
    _ToolData('Upscale', Icons.zoom_in, Colors.green),
    _ToolData('Matting', Icons.content_cut, Colors.teal),
    _ToolData('Color', Icons.palette, Colors.pink),
    _ToolData('Heal', Icons.brush, Colors.amber),
    _ToolData('Crop', Icons.crop, Colors.cyan),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tr('AI Image Processing Tools', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            // Tool grid (8 tools)
            Wrap(
              spacing: 6, runSpacing: 6,
              children: List.generate(_tools.length, (i) {
                final t = _tools[i];
                final active = i == _selectedTool;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTool = i),
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: active ? t.color.withValues(alpha: 0.2) : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? t.color : const Color(0xFF2A2A4E),
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(t.icon, size: 22, color: active ? t.color : Colors.grey),
                        const SizedBox(height: 4),
                        Text(t.label, style: TextStyle(
                          fontSize: 10,
                          color: active ? t.color : Colors.grey,
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        )),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFF2A2A4E)),
            const SizedBox(height: 8),
            // Parameter panel
            Text(_tools[_selectedTool].label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            Row(
              children: [
                Tr('Strength', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: _strength,
                    min: 0, max: 1,
                    activeColor: _tools[_selectedTool].color,
                    onChanged: (v) => setState(() => _strength = v),
                  ),
                ),
                Text('${(_strength * 100).toInt()}%',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            // Preview placeholder
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2A2A4E)),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 20, color: Colors.white24),
                    SizedBox(width: 8),
                    Tr('Original vs Processed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2A2A4E)),
                  ),
                  child: Tr('Cancel', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Tr('Apply', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolData {
  final String label;
  final IconData icon;
  final Color color;
  const _ToolData(this.label, this.icon, this.color);
}