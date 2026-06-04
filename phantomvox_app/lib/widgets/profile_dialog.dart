import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../../widgets/tr.dart';


/// Local profile dialog — no cloud account, just local display name + prefs.
/// Triggered from the menu bar account icon.
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  final _nameCtrl = TextEditingController();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ApiService();
      final profile = await api.get('/api/v1/profile');
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameCtrl.text = (profile['display_name'] as String?) ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    try {
      final api = ApiService();
      await api.post('/api/v1/profile', body: {
        'display_name': _nameCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: Row(
        children: [
          const Icon(Icons.person, size: 20, color: Color(0xFF6C63FF)),
          const SizedBox(width: 8),
          const Tr('Local Profile'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: _loading
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? Text('Error: $_error', style: const TextStyle(color: Colors.redAccent))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Display Name',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter your name',
                            hintStyle: TextStyle(color: Colors.grey[700]),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[800]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[800]!),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0D0D1A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D1A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow('Type', 'Local (no cloud)'),
                            _infoRow('Created',
                                _profile?['created_at']?.toString()?.split('T')[0] ?? '-'),
                            _infoRow('Data path', '~/.phantomvox/profile.json'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your profile is stored locally on this machine.\n'
                        'No data leaves your computer.',
                        style: TextStyle(color: Colors.grey[700], fontSize: 10),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Tr('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: const Tr('Save'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ),
          Text(value, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
