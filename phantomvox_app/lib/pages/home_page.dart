import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
    } catch (e) {
      setState(() {
        _connected = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhantomVox AI'),
        centerTitle: true,
        backgroundColor: const Color(0xFF16213E),
      ),
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
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final hw = _info?['hardware'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── System Info Card ──
        _card(
          children: [
            _label('System Info'),
            _row('Name', _info?['name'] ?? '-'),
            _row('Tagline', _info?['tagline'] ?? '-'),
            _row('Locale', _info?['locale'] ?? '-'),
            _row('Tier', 'T${_info?['tier'] ?? '?'}'),
          ],
        ),
        const SizedBox(height: 12),

        // ── Hardware Card ──
        _card(
          children: [
            _label('Hardware'),
            _row('CPU', hw?['cpu'] ?? '-'),
            _row('Cores', '${hw?['cores'] ?? '?'}c / ${hw?['threads'] ?? '?'}t'),
            _row('RAM', '${hw?['ram_gb'] ?? '?'} GB'),
            _row('GPU', (hw?['gpu'] as List?)?.join(', ') ?? 'None'),
            _row('Disk', '${hw?['disk_free_gb'] ?? '?'} GB free'),
          ],
        ),
        const SizedBox(height: 12),

        // ── Locale Switcher ──
        _card(
          children: [
            _label('Language'),
            DropdownButtonFormField<String>(
              initialValue: _info?['locale'] as String?,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: const Color(0xFF16213E),
              items: (_locales ?? [])
                  .map((l) => DropdownMenuItem(
                        value: l['code'] as String,
                        child: Text('${l['flag']}  ${l['name']}'),
                      ))
                  .toList(),
              onChanged: (code) async {
                if (code == null) return;
                await _api.setLocale(code);
                _loadData();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Quick Actions ──
        _card(
          children: [
            _label('Quick Actions'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Full Report'),
                  onPressed: () async {
                    final hw = await _api.hardware();
                    if (!context.mounted) return;
                    _showHardwareSheet(context, hw);
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.language, size: 18),
                  label: const Text('Health Check'),
                  onPressed: () async {
                    final h = await _api.health();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Server: ${h['status']}')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _showHardwareSheet(BuildContext context, Map<String, dynamic> hw) {
    final models = hw['can_run_models'] as Map<String, dynamic>? ?? {};
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Model Compatibility',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            for (final entry in models.entries)
              ListTile(
                dense: true,
                leading: Icon(
                  entry.value['can_run'] == true
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: entry.value['can_run'] == true
                      ? Colors.green
                      : Colors.red,
                  size: 20,
                ),
                title: Text(entry.key),
                subtitle: Text(
                    'T${entry.value['required_tier']} [${entry.value['type']}]'),
              ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _card({required List<Widget> children}) {
    return Card(
      color: const Color(0xFF16213E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
