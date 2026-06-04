import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../../widgets/tr.dart';


/// Dashboard — PhantomVox AI launch page
/// Layout: TOP_BAR + WELCOME_BANNER + RECENT_PROJECTS + (SYSTEM_STATUS | AI_QUICK_ENTRY) + FOOTER
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _info;
  List<Map<String, dynamic>>? _locales;
  bool _connected = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final info = await _api.info();
      final locales = await _api.availableLocales();
      setState(() {
        _info = info;
        _locales = locales;
        _connected = true;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _connected = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _connected
              ? _buildDashboard()
              : _buildOffline(),
    );
  }

  Widget _buildOffline() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('AI Server not running',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Start: python3 -m modules.api_server',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              setState(() => _loading = true);
              _loadData();
            },
            icon: const Icon(Icons.refresh),
            label: const Tr('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final hw = _info?['hardware'] as Map<String, dynamic>?;
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildWelcomeBanner(),
              _buildRecentProjects(),
              _buildSystemAndAI(hw),
              _buildFooter(),
            ],
          ),
        ),
      ],
    );
  }

  // ── TOP_STATUS_BAR (48px) ─────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF12121E),
      child: Row(
        children: [
          const Text('PhantomVox',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF699EFF))),
          const SizedBox(width: 12),
          _iconBtn(Icons.arrow_back_ios, 14),
          _iconBtn(Icons.arrow_forward_ios, 14),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Search projects...',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2A2A3E)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.grey,
                )),
                const SizedBox(width: 4),
                const Text('Not signed in',
                    style: TextStyle(fontSize: 9, color: Colors.grey)),
                const SizedBox(width: 4),
                Text('Sign In',
                    style: TextStyle(fontSize: 9, color: const Color(0xFF699EFF), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _tierChip('T1', 'CPU'),
          const SizedBox(width: 4),
          _localeChip('EN'),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, double size) {
    return SizedBox(
      width: 24, height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: size, color: Colors.grey),
        onPressed: () {},
      ),
    );
  }

  Widget _tierChip(String tier, String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Text('$tier $type',
          style: const TextStyle(fontSize: 8, color: Colors.grey)),
    );
  }

  Widget _localeChip(String locale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(locale,
          style: const TextStyle(fontSize: 8, color: Colors.grey)),
    );
  }

  // ── WELCOME_BANNER (120px) ────────────────────────────

  Widget _buildWelcomeBanner() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF16213E),
            const Color(0xFF1A0A2E),
            const Color(0xFF0F0F1A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PhantomVox AI',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('AI-powered creative studio',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _bannerBtn(Icons.auto_awesome, 'One-Click Create', true),
                const SizedBox(width: 8),
                _bannerBtn(Icons.smart_toy, 'AI Assistant', false),
                const SizedBox(width: 8),
                _bannerBtn(Icons.folder_open, 'Open Project', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerBtn(IconData icon, String label, bool primary) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        backgroundColor: primary ? const Color(0xFF699EFF) : const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  // ── RECENT PROJECTS (160px) ───────────────────────────

  Widget _buildRecentProjects() {
    final projects = [
      ('Promo Reel', 'assets/thumb1.png', '3 assets', 'Yesterday'),
      ('Wedding Edit', 'assets/thumb2.png', '12 assets', '2 days ago'),
      ('Vlog Week 23', 'assets/thumb3.png', '8 assets', '3 days ago'),
      ('Product Showcase', '', '6 assets', 'In Progress'),
    ];
    return SizedBox(
      height: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                const Text('Recent Projects',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('View All',
                    style: TextStyle(fontSize: 9, color: const Color(0xFF699EFF))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: projects.length + 1,
              itemBuilder: (_, i) {
                if (i == projects.length) return _newProjectCard();
                final p = projects[i];
                return _projectCard(p.$1, p.$3, p.$4);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectCard(String name, String assets, String time) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: const Center(
              child: Icon(Icons.movie, size: 24, color: Colors.white24),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(assets, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                Text(time, style: const TextStyle(fontSize: 7, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _newProjectCard() {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2A2A3E), style: BorderStyle.solid),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 20, color: Color(0xFF699EFF)),
            SizedBox(height: 4),
            Text('New Project',
                style: TextStyle(fontSize: 8, color: Color(0xFF699EFF))),
          ],
        ),
      ),
    );
  }

  // ── SYSTEM STATUS + AI QUICK ENTRY ────────────────────

  Widget _buildSystemAndAI(Map<String, dynamic>? hw) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildSystemStatus(hw)),
          const SizedBox(width: 8),
          Expanded(child: _buildAiQuickEntry()),
        ],
      ),
    );
  }

  Widget _buildSystemStatus(Map<String, dynamic>? hw) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hardware Report',
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _sysRow('CPU', '${hw?['cpu'] ?? '-'} (T1)'),
              _sysRow('RAM', '${hw?['ram_gb'] ?? '?'} GB (T1)'),
              _sysRow('GPU', 'None (T1)'),
              _sysRow('Disk', '${hw?['disk_free_gb'] ?? '?'} GB free'),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Max Tier: T1 (CPU Mode)',
                      style: TextStyle(fontSize: 9, color: Colors.grey)),
                  const Spacer(),
                  Text('${6}/${12}',
                      style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 4),
              // Compatibility bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1A),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: List.generate(12, (i) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: i < 6 ? const Color(0xFF4CAF50) : const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  )),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {},
                child: const Text('View Full Report',
                    style: TextStyle(fontSize: 9, color: Color(0xFF699EFF))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Service status
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Column(
            children: [
              _serviceRow('API Server', 'Running :8899', true),
              const SizedBox(height: 4),
              _serviceRow('Edge-TTS', 'Online', true),
              const SizedBox(height: 4),
              _serviceRow('FFmpeg', 'v7.1', true),
              const SizedBox(height: 4),
              _serviceRow('Modules', '9/9 Loaded', true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sysRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.grey))),
          Text(value, style: const TextStyle(fontSize: 9, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _serviceRow(String name, String status, bool ok) {
    return Row(
      children: [
        Icon(Icons.check_circle, size: 10, color: ok ? Colors.green : Colors.red),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ),
        Text(status, style: TextStyle(fontSize: 8, color: ok ? Colors.green : Colors.red)),
      ],
    );
  }

  Widget _buildAiQuickEntry() {
    return Column(
      children: [
        // AI cards grid
        Row(
          children: [
            Expanded(child: _aiCard(Icons.record_voice_over, 'Voice Clone', 'TTS', const Color(0xFF4CAF50))),
            const SizedBox(width: 6),
            Expanded(child: _aiCard(Icons.music_note, 'Music Gen', 'Suno', const Color(0xFF9C27B0))),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _aiCard(Icons.image, 'Image Gen', 'Stable Diff', const Color(0xFFFF9800))),
            const SizedBox(width: 6),
            Expanded(child: _aiCard(Icons.videocam, 'Video Gen', 'Runway', const Color(0xFF2196F3))),
          ],
        ),
        const SizedBox(height: 8),
        // Quick chat
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Text('What do you want to create...',
                              style: TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF699EFF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.send, size: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _chatHistory('Make a product promo', '30m ago'),
              _chatHistory('Color grade to vintage', '2h ago'),
              _chatHistory('Clone my voice', 'Yesterday'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aiCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(fontSize: 7, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _chatHistory(String text, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, size: 8, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text('\"$text\"',
                style: const TextStyle(fontSize: 8, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
          ),
          Text(time, style: TextStyle(fontSize: 7, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ── FOOTER (24px) ─────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF12121E),
      child: Row(
        children: [
          const Text('PhantomVox v0.2.5',
              style: TextStyle(fontSize: 8, color: Colors.grey)),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: const Color(0xFF2A2A3E)),
          const SizedBox(width: 8),
          const Text('FFmpeg 7.1',
              style: TextStyle(fontSize: 8, color: Colors.grey)),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: const Color(0xFF2A2A3E)),
          const SizedBox(width: 8),
          const Text('Python 3.12',
              style: TextStyle(fontSize: 8, color: Colors.grey)),
          const Spacer(),
          TextButton(
            onPressed: () {},
            child: const Text('Check Update',
                style: TextStyle(fontSize: 8, color: Color(0xFF699EFF))),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {},
            child: const Text('Help F1',
                style: TextStyle(fontSize: 8, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
