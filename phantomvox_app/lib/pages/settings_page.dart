1|import 'package:flutter/material.dart';
2|import 'package:flutter/services.dart';
3|import '../services/api_service.dart';
4|import '../services/i18n_service.dart';
5|import '../widgets/tr.dart';
6|
7|/// PhantomVox Settings page — 4 tabs: General / Project / AI Models / About.
8|/// Launched as a full-page overlay from the menu bar.
9|class SettingsPage extends StatefulWidget {
10|  const SettingsPage({super.key});
11|
12|  @override
13|  State<SettingsPage> createState() => _SettingsPageState();
14|}
15|
16|class _SettingsPageState extends State<SettingsPage>
17|    with SingleTickerProviderStateMixin {
18|  late TabController _tabCtrl;
19|  Map<String, dynamic> _config = {};
20|  List<dynamic> _allModels = [];
21|  bool _loading = true;
22|  String? _error;
23|
24|  // Form fields
25|  String _language = 'zh_CN';
26|  String _theme = 'dark';
27|  String _autoSave = '5';
28|
29|  // Project defaults
30|  String _defaultRes = '1920×1080';
31|  String _defaultFps = '24';
32|  String _defaultSampleRate = '48000';
33|  String _defaultFormat = 'H.264';
34|
35|  // AI model selections per category
36|  final Map<String, String> _selectedModels = {};
37|  final Map<String, String> _apiKeys = {};
38|  double _temperature = 0.7;
39|
40|  // Persistent TextEditingControllers for API key fields
41|  final Map<String, TextEditingController> _keyControllers = {};
42|
43|  @override
44|  void initState() {
45|    super.initState();
46|    _tabCtrl = TabController(length: 4, vsync: this);
47|    _loadConfig();
48|  }
49|
50|  @override
51|  void dispose() {
52|    _tabCtrl.dispose();
53|    for (final c in _keyControllers.values) {
54|      c.dispose();
55|    }
56|    super.dispose();
57|  }
58|
59|  Future<void> _loadConfig() async {
60|    try {
61|      final api = ApiService();
62|      final config = await api.get('/api/v1/models/config');
63|      final modelsRes = await api.get('/api/v1/models?category=all');
64|      if (!mounted) return;
65|      setState(() {
66|        _config = config;
67|        _allModels = modelsRes['models'] ?? [];
68|        _loading = false;
69|
70|        // Populate form fields
71|        _language = _deepGet(config, 'locale') as String? ?? 'zh_CN';
72|        _temperature = (_deepGet(config, 'llm', 'temperature') as num?)?.toDouble() ?? 0.7;
73|        final keys = config['api_keys'] ?? {};
74|        if (keys is Map) {
75|          for (final e in keys.entries) {
76|            _apiKeys[e.key] = e.value?.toString() ?? '';
77|          }
78|        }
79|
80|        // Set selected models from config
81|        _selectedModels['llm'] = _deepGet(config, 'llm', 'model') as String? ?? '';
82|        _selectedModels['image'] = _deepGet(config, 'image', 'engine') as String? ?? '';
83|        _selectedModels['video'] = _deepGet(config, 'video', 'engine') as String? ?? '';
84|        _selectedModels['tts'] = _deepGet(config, 'audio', 'tts', 'engine') as String? ?? '';
85|        _selectedModels['music'] = _deepGet(config, 'audio', 'music', 'engine') as String? ?? '';
86|
87|        // Create persistent controllers for API key fields
88|        final keyProviders = ['openai', 'anthropic', 'deepseek', 'google', 'zhipu', 'alibaba', 'baidu'];
89|        for (final p in keyProviders) {
90|          _keyControllers.putIfAbsent(p, () => TextEditingController(text: _apiKeys[p] ?? ''));
91|        }
92|      });
93|    } catch (e) {
94|      if (!mounted) return;
95|      setState(() {
96|        _loading = false;
97|        _error = e.toString();
98|      });
99|    }
100|  }
101|
102|  dynamic _deepGet(Map m, String k1, [dynamic k2, dynamic k3]) {
103|    final v1 = m[k1];
104|    if (k2 == null) return v1;
105|    if (v1 is! Map) return null;
106|    final v2 = v1[k2];
107|    if (k3 == null) return v2;
108|    if (v2 is! Map) return null;
109|    return v2[k3];
110|  }
111|
112|  List<Map<String, dynamic>> _modelsByCategory(String cat) {
113|    return (_allModels)
114|        .where((m) => m['category'] == cat)
115|        .map((m) => Map<String, dynamic>.from(m as Map))
116|        .toList();
117|  }
118|
119|  @override
120|  Widget build(BuildContext context) {
121|    return Scaffold(
122|      backgroundColor: const Color(0xFF1A1A2E),
123|      appBar: AppBar(
124|        backgroundColor: const Color(0xFF0D0D1A),
125|        title: const Tr('Settings'),
126|        leading: IconButton(
127|          icon: const Icon(Icons.close),
128|          onPressed: () => Navigator.of(context).pop(),
129|        ),
130|        bottom: TabBar(
131|          controller: _tabCtrl,
132|          indicatorColor: const Color(0xFF6C63FF),
133|          labelColor: Colors.white,
134|          unselectedLabelColor: Colors.grey,
135|          tabs: [
136|            Tab(text: i18n.tr('General')),
137|            Tab(text: i18n.tr('Project')),
138|            Tab(text: i18n.tr('AI Models')),
139|            Tab(text: i18n.tr('About')),
140|          ],
141|        ),
142|      ),
143|      body: _loading
144|          ? const Center(child: CircularProgressIndicator())
145|          : _error != null
146|              ? Center(
147|                  child: Padding(
148|                    padding: const EdgeInsets.all(32),
149|                    child: Text('Unable to load settings:\n$_error',
150|                        style: const TextStyle(color: Colors.redAccent)),
151|                  ),
152|                )
153|              : TabBarView(
154|                  controller: _tabCtrl,
155|                  children: [
156|                    _buildGeneralTab(),
157|                    _buildProjectTab(),
158|                    _buildAiModelsTab(),
159|                    _buildAboutTab(),
160|                  ],
161|                ),
162|    );
163|  }
164|
165|  // ── General Tab ──────────────────────────────────────
166|
167|  Widget _buildGeneralTab() {
168|    return _tabContent([
169|      _section('General Settings', [
170|        _dropdown('Language', _language, ['zh_CN', 'zh_TW', 'en', 'ja', 'ko', 'fr', 'de', 'it', 'es', 'pt_BR', 'ru', 'ar', 'vi', 'th', 'id'],
171|            (v) {
172|              _language = v;
173|              i18n.setLocale(v);
174|            }),
175|        _row('Theme', [
176|          _radio('Dark', _theme == 'dark', () => _theme = 'dark'),
177|          const SizedBox(width: 16),
178|          _radio('Light', _theme == 'light', () => _theme = 'light'),
179|        ]),
180|        _dropdown('Auto-save interval', _autoSave,
181|            ['1', '5', '10', '15', '30'], (v) => _autoSave = v),
182|      ]),
183|      _section('Account', [
184|        const SizedBox(height: 8),
185|        Container(
186|          padding: const EdgeInsets.all(12),
187|          decoration: BoxDecoration(
188|            color: const Color(0xFF0D0D1A),
189|            borderRadius: BorderRadius.circular(6),
190|          ),
191|          child: Row(
192|            children: [
193|              const Icon(Icons.person_outline, size: 20, color: Colors.grey),
194|              const SizedBox(width: 12),
195|              Column(
196|                crossAxisAlignment: CrossAxisAlignment.start,
197|                children: [
198|                  Text(i18n.tr('Local Profile'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
199|                  Text(i18n.tr('No cloud account required. Preferences are stored locally.'),
200|                      style: TextStyle(color: Colors.grey, fontSize: 11)),
201|                ],
202|              ),
203|            ],
204|          ),
205|        ),
206|      ]),
207|      _buttonRow(),
208|    ]);
209|  }
210|
211|  // ── Project Tab ───────────────────────────────────────
212|
213|  Widget _buildProjectTab() {
214|    return _tabContent([
215|      _section('Default Project Settings', [
216|        _dropdown('Resolution', _defaultRes,
217|            ['3840×2160', '1920×1080', '1280×720', '640×360'],
218|            (v) => _defaultRes = v),
219|        _dropdown('Frame Rate', _defaultFps,
220|            ['23.976', '24', '25', '29.97', '30', '60'],
221|            (v) => _defaultFps = v),
222|        _dropdown('Audio Sample Rate', _defaultSampleRate,
223|            ['44100', '48000', '96000'],
224|            (v) => _defaultSampleRate = v),
225|        _dropdown('Render Format', _defaultFormat,
226|            ['H.264', 'H.265', 'ProRes', 'DNxHD', 'VP9', 'AV1'],
227|            (v) => _defaultFormat = v),
228|      ]),
229|      _buttonRow(),
230|    ]);
231|  }
232|
233|  // ── AI Models Tab ─────────────────────────────────────
234|
235|  Widget _buildAiModelsTab() {
236|    return _tabContent([
237|      _modelSection('LLM', 'llm', ['provider', 'temperature', 'max_tokens']),
238|      _modelSection('Image', 'image', ['provider', 'resolution']),
239|      _modelSection('Video', 'video', ['provider', 'max_duration', 'resolution']),
240|      _modelSection('TTS', 'tts', ['provider']),
241|      _modelSection('Music', 'music', ['provider']),
242|      _section('API Keys', [
243|        for (final provider in ['openai', 'anthropic', 'deepseek', 'google', 'zhipu', 'alibaba', 'baidu'])
244|          _apiKeyField(provider),
245|      ]),
246|      const SizedBox(height: 16),
247|      Center(
248|        child: Text(
249|          i18n.tr('Local models do not require API keys.'),
250|          style: TextStyle(color: Colors.grey[600], fontSize: 11),
251|        ),
252|      ),
253|      _buttonRow(),
254|    ]);
255|  }
256|
257|  Widget _modelSection(String label, String cat, List<String> extras) {
258|    final models = _modelsByCategory(cat);
259|    return _section(label, [
260|      _dropdown('Model', _selectedModels[cat] ?? '',
261|          models.map((m) => m['key'] as String).toList(),
262|          (v) => _selectedModels[cat] = v,
263|          displayName: (v) {
264|            final m = models.cast<Map<String, dynamic>?>().firstWhere(
265|                (x) => x?['key'] == v, orElse: () => null);
266|            if (m != null) {
267|              final tier = m['tier'];
268|              final local = m['local'] == true ? ' (local)' : '';
269|              return '${m['name']} — T$tier$local';
270|            }
271|            return v;
272|          },
273|          hint: 'Select $label model'),
274|      if (cat == 'llm') ...[
275|        const SizedBox(height: 8),
276|        Row(
277|          children: [
278|            const SizedBox(width: 16),
279|            Text(i18n.tr('Temperature:'), style: TextStyle(fontSize: 11, color: Colors.grey)),
280|            Expanded(
281|              child: Slider(
282|                value: _temperature,
283|                min: 0,
284|                max: 2,
285|                divisions: 20,
286|                activeColor: const Color(0xFF6C63FF),
287|                onChanged: (v) => _temperature = v,
288|              ),
289|            ),
290|            Text('${_temperature.toStringAsFixed(1)}',
291|                style: const TextStyle(fontSize: 11, color: Colors.grey)),
292|            const SizedBox(width: 16),
293|          ],
294|        ),
295|      ],
296|    ]);
297|  }
298|
299|  Widget _apiKeyField(String provider) {
300|    final icons = {
301|      'openai': Icons.flare,
302|      'anthropic': Icons.psychology,
303|      'deepseek': Icons.auto_awesome,
304|      'google': Icons.cloud,
305|      'zhipu': Icons.smart_toy,
306|      'alibaba': Icons.shopping_bag,
307|      'baidu': Icons.language,
308|    };
309|    return Padding(
310|      padding: const EdgeInsets.only(bottom: 8),
311|      child: Row(
312|        children: [
313|          Icon(icons[provider] ?? Icons.vpn_key, size: 16, color: Colors.grey),
314|          const SizedBox(width: 8),
315|          SizedBox(
316|            width: 100,
317|            child: Text(provider, style: const TextStyle(fontSize: 12)),
318|          ),
319|          Expanded(
320|            child: SizedBox(
321|              height: 32,
322|              child: TextField(
323|                obscureText: true,
324|                style: const TextStyle(fontSize: 11),
325|                decoration: InputDecoration(
326|                  hintText: i18n.tr('sk-...'),
327|                  hintStyle: TextStyle(color: Colors.grey[700]),
328|                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
329|                  border: OutlineInputBorder(
330|                    borderRadius: BorderRadius.circular(4),
331|                    borderSide: BorderSide(color: Colors.grey[800]!),
332|                  ),
333|                  enabledBorder: OutlineInputBorder(
334|                    borderRadius: BorderRadius.circular(4),
335|                    borderSide: BorderSide(color: Colors.grey[800]!),
336|                  ),
337|                  filled: true,
338|                  fillColor: const Color(0xFF0D0D1A),
339|                ),
340|                controller: _keyControllers[provider]!,
341|                onChanged: (v) => _apiKeys[provider] = v,
342|              ),
343|            ),
344|          ),
345|        ],
346|      ),
347|    );
348|  }
349|
350|  // ── About Tab ─────────────────────────────────────────
351|
352|  Widget _buildAboutTab() {
353|    return _tabContent([
354|      _section('PhantomVox AI', [
355|        const SizedBox(height: 16),
356|        Center(
357|          child: Column(
358|            children: [
359|              const Icon(Icons.movie_creation, size: 48, color: Color(0xFF6C63FF)),
360|              const SizedBox(height: 8),
361|              Text(i18n.tr('v0.3.77'),
362|                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
363|              const SizedBox(height: 4),
364|              Text(i18n.tr('Where AI Meets Creativity'),
365|                  style: TextStyle(color: Colors.grey, fontSize: 13)),
366|              const SizedBox(height: 24),
367|              _infoRow(i18n.tr('License'), i18n.tr('MIT')),
368|              _infoRow(i18n.tr('Platform'), i18n.tr('Linux, Windows, macOS')),
369|              _infoRow(i18n.tr('Flutter SDK'), i18n.tr('3.44.1')),
370|              _infoRow(i18n.tr('Python'), i18n.tr('3.12')),
371|              const SizedBox(height: 24),
372|              Wrap(
373|                spacing: 8,
374|                children: [
375|                  _actionChip(Icons.update, i18n.tr('Check Updates')),
376|                  _actionChip(Icons.computer, i18n.tr('System Info')),
377|                  _actionChip(Icons.description, i18n.tr('License')),
378|                ],
379|              ),
380|              const SizedBox(height: 32),
381|              Text(
382|                i18n.tr('Built with Flutter + Python AI Server.'),
383|                textAlign: TextAlign.center,
384|                style: TextStyle(color: Colors.grey[700], fontSize: 10),
385|              ),
386|            ],
387|          ),
388|        ),
389|      ]),
390|    ]);
391|  }
392|
393|  // ── Helpers ───────────────────────────────────────────
394|
395|  Widget _tabContent(List<Widget> children) {
396|    return SingleChildScrollView(
397|      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
398|      child: Column(
399|        crossAxisAlignment: CrossAxisAlignment.start,
400|        children: children,
401|      ),
402|    );
403|  }
404|
405|  Widget _section(String title, List<Widget> children) {
406|    return Padding(
407|      padding: const EdgeInsets.only(bottom: 24),
408|      child: Column(
409|        crossAxisAlignment: CrossAxisAlignment.start,
410|        children: [
411|          Text(title,
412|              style: const TextStyle(
413|                  fontSize: 13,
414|                  fontWeight: FontWeight.w600,
415|                  color: Color(0xFF6C63FF))),
416|          const SizedBox(height: 12),
417|          ...children,
418|        ],
419|      ),
420|    );
421|  }
422|
423|  Widget _dropdown(String label, String value, List<String> options,
424|      ValueChanged<String> onChanged,
425|      {String Function(String)? displayName, String? hint}) {
426|    return Padding(
427|      padding: const EdgeInsets.only(bottom: 8),
428|      child: Row(
429|        children: [
430|          SizedBox(
431|            width: 140,
432|            child: Text(i18n.tr(label), style: const TextStyle(fontSize: 12)),
433|          ),
434|          SizedBox(
435|            width: 280,
436|            height: 32,
437|            child: DropdownButtonFormField<String>(
438|              value: options.contains(value) ? value : null,
439|              isExpanded: true,
440|              decoration: _inputDeco(),
441|              style: const TextStyle(fontSize: 11, color: Colors.white),
442|              dropdownColor: const Color(0xFF1A1A2E),
443|              hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
444|              items: options.map((o) {
445|                final dn = displayName != null ? displayName(o) : o;
446|                return DropdownMenuItem(value: o, child: Text(dn));
447|              }).toList(),
448|              onChanged: (v) {
449|                if (v != null) onChanged(v);
450|              },
451|            ),
452|          ),
453|        ],
454|      ),
455|    );
456|  }
457|
458|  InputDecoration _inputDeco() {
459|    return InputDecoration(
460|      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
461|      border: OutlineInputBorder(
462|        borderRadius: BorderRadius.circular(4),
463|        borderSide: BorderSide(color: Colors.grey[800]!),
464|      ),
465|      enabledBorder: OutlineInputBorder(
466|        borderRadius: BorderRadius.circular(4),
467|        borderSide: BorderSide(color: Colors.grey[800]!),
468|      ),
469|      filled: true,
470|      fillColor: const Color(0xFF0D0D1A),
471|    );
472|  }
473|
474|  Widget _row(String label, List<Widget> children) {
475|    return Padding(
476|      padding: const EdgeInsets.only(bottom: 8),
477|      child: Row(
478|        children: [
479|          SizedBox(width: 140, child: Text(i18n.tr(label), style: const TextStyle(fontSize: 12))),
480|          ...children,
481|        ],
482|      ),
483|    );
484|  }
485|
486|  Widget _radio(String label, bool selected, VoidCallback onTap) {
487|    return GestureDetector(
488|      onTap: onTap,
489|      child: Row(
490|        mainAxisSize: MainAxisSize.min,
491|        children: [
492|          Icon(
493|            selected ? Icons.radio_button_checked : Icons.radio_button_off,
494|            size: 16,
495|            color: selected ? const Color(0xFF6C63FF) : Colors.grey,
496|          ),
497|          const SizedBox(width: 4),
498|          Text(i18n.tr(label), style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.grey)),
499|        ],
500|      ),
501|