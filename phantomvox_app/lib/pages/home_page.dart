1|import 'package:flutter/material.dart';
2|import '../services/api_service.dart';
3|import '../../widgets/tr.dart';
4|import '../widgets/tr.dart';
5|import '../services/i18n_service.dart';
6|
7|
8|/// Dashboard — PhantomVox AI launch page
9|/// Layout: TOP_BAR + WELCOME_BANNER + RECENT_PROJECTS + (SYSTEM_STATUS | AI_QUICK_ENTRY) + FOOTER
10|class HomePage extends StatefulWidget {
11|  const HomePage({super.key});
12|
13|  @override
14|  State<HomePage> createState() => _HomePageState();
15|}
16|
17|class _HomePageState extends State<HomePage> {
18|  final ApiService _api = ApiService();
19|  Map<String, dynamic>? _info;
20|  List<Map<String, dynamic>>? _locales;
21|  bool _connected = false;
22|  bool _loading = true;
23|
24|  @override
25|  void initState() {
26|    super.initState();
27|    _loadData();
28|  }
29|
30|  Future<void> _loadData() async {
31|    try {
32|      final info = await _api.info();
33|      final locales = await _api.availableLocales();
34|      setState(() {
35|        _info = info;
36|        _locales = locales;
37|        _connected = true;
38|        _loading = false;
39|      });
40|    } catch (_) {
41|      setState(() {
42|        _connected = false;
43|        _loading = false;
44|      });
45|    }
46|  }
47|
48|  @override
49|  Widget build(BuildContext context) {
50|    return Scaffold(
51|      backgroundColor: const Color(0xFF0F0F1A),
52|      body: _loading
53|          ? const Center(child: CircularProgressIndicator())
54|          : _connected
55|              ? _buildDashboard()
56|              : _buildOffline(),
57|    );
58|  }
59|
60|  Widget _buildOffline() {
61|    return Center(
62|      child: Column(
63|        mainAxisSize: MainAxisSize.min,
64|        children: [
65|          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
66|          const SizedBox(height: 16),
67|          Tr('AI Server not running', style: TextStyle(fontSize: 18, color: Colors.grey)),
68|          const SizedBox(height: 8),
69|          Tr('Start: python3 -m modules.api_server', style: TextStyle(fontSize: 12, color: Colors.grey)),
70|          const SizedBox(height: 24),
71|          FilledButton.icon(
72|            onPressed: () {
73|              setState(() => _loading = true);
74|              _loadData();
75|            },
76|            icon: const Icon(Icons.refresh),
77|            label: const Tr('Retry'),
78|          ),
79|        ],
80|      ),
81|    );
82|  }
83|
84|  Widget _buildDashboard() {
85|    final hw = _info?['hardware'] as Map<String, dynamic>?;
86|    return Column(
87|      children: [
88|        _buildTopBar(),
89|        Expanded(
90|          child: ListView(
91|            padding: EdgeInsets.zero,
92|            children: [
93|              _buildWelcomeBanner(),
94|              _buildRecentProjects(),
95|              _buildSystemAndAI(hw),
96|              _buildFooter(),
97|            ],
98|          ),
99|        ),
100|      ],
101|    );
102|  }
103|
104|  // ── TOP_STATUS_BAR (48px) ─────────────────────────────
105|
106|  Widget _buildTopBar() {
107|    return Container(
108|      height: 48,
109|      padding: const EdgeInsets.symmetric(horizontal: 12),
110|      color: const Color(0xFF12121E),
111|      child: Row(
112|        children: [
113|          Tr('PhantomVox', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF699EFF))),
114|          const SizedBox(width: 12),
115|          _iconBtn(Icons.arrow_back_ios, 14),
116|          _iconBtn(Icons.arrow_forward_ios, 14),
117|          const SizedBox(width: 8),
118|          Expanded(
119|            child: Container(
120|              height: 28,
121|              padding: const EdgeInsets.symmetric(horizontal: 8),
122|              decoration: BoxDecoration(
123|                color: const Color(0xFF1A1A2E),
124|                borderRadius: BorderRadius.circular(4),
125|              ),
126|              child: const Row(
127|                children: [
128|                  Icon(Icons.search, size: 14, color: Colors.grey),
129|                  SizedBox(width: 4),
130|                  Tr('Search projects...', style: TextStyle(fontSize: 11, color: Colors.grey)),
131|                ],
132|              ),
133|            ),
134|          ),
135|          const SizedBox(width: 12),
136|          Container(
137|            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
138|            decoration: BoxDecoration(
139|              color: const Color(0xFF1A1A2E),
140|              borderRadius: BorderRadius.circular(4),
141|              border: Border.all(color: const Color(0xFF2A2A3E)),
142|            ),
143|            child: Row(
144|              mainAxisSize: MainAxisSize.min,
145|              children: [
146|                Container(width: 6, height: 6, decoration: const BoxDecoration(
147|                  shape: BoxShape.circle, color: Colors.grey,
148|                )),
149|                const SizedBox(width: 4),
150|                Tr('Not signed in', style: TextStyle(fontSize: 9, color: Colors.grey)),
151|                const SizedBox(width: 4),
152|                Tr('Sign In', style: TextStyle(fontSize: 9, color: const Color(0xFF699EFF), fontWeight: FontWeight.w600)),
153|              ],
154|            ),
155|          ),
156|          const SizedBox(width: 8),
157|          _tierChip('T1', 'CPU'),
158|          const SizedBox(width: 4),
159|          _localeChip('EN'),
160|        ],
161|      ),
162|    );
163|  }
164|
165|  Widget _iconBtn(IconData icon, double size) {
166|    return SizedBox(
167|      width: 24, height: 24,
168|      child: IconButton(
169|        padding: EdgeInsets.zero,
170|        icon: Icon(icon, size: size, color: Colors.grey),
171|        onPressed: () {},
172|      ),
173|    );
174|  }
175|
176|  Widget _tierChip(String tier, String type) {
177|    return Container(
178|      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
179|      decoration: BoxDecoration(
180|        color: const Color(0xFF1A1A2E),
181|        borderRadius: BorderRadius.circular(3),
182|        border: Border.all(color: const Color(0xFF2A2A3E)),
183|      ),
184|      child: Text('$tier $type',
185|          style: const TextStyle(fontSize: 8, color: Colors.grey)),
186|    );
187|  }
188|
189|  Widget _localeChip(String locale) {
190|    return Container(
191|      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
192|      decoration: BoxDecoration(
193|        color: const Color(0xFF1A1A2E),
194|        borderRadius: BorderRadius.circular(3),
195|      ),
196|      child: Text(i18n.tr(locale),
197|          style: const TextStyle(fontSize: 8, color: Colors.grey)),
198|    );
199|  }
200|
201|  // ── WELCOME_BANNER (120px) ────────────────────────────
202|
203|  Widget _buildWelcomeBanner() {
204|    return Container(
205|      height: 120,
206|      decoration: BoxDecoration(
207|        gradient: LinearGradient(
208|          begin: Alignment.topLeft,
209|          end: Alignment.bottomRight,
210|          colors: [
211|            const Color(0xFF16213E),
212|            const Color(0xFF1A0A2E),
213|            const Color(0xFF0F0F1A),
214|          ],
215|        ),
216|      ),
217|      child: Center(
218|        child: Column(
219|          mainAxisSize: MainAxisSize.min,
220|          children: [
221|            Tr('PhantomVox AI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
222|            const SizedBox(height: 4),
223|            Tr('AI-powered creative studio', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
224|            const SizedBox(height: 12),
225|            Row(
226|              mainAxisAlignment: MainAxisAlignment.center,
227|              children: [
228|                _bannerBtn(Icons.auto_awesome, 'One-Click Create', true),
229|                const SizedBox(width: 8),
230|                _bannerBtn(Icons.smart_toy, 'AI Assistant', false),
231|                const SizedBox(width: 8),
232|                _bannerBtn(Icons.folder_open, 'Open Project', false),
233|              ],
234|            ),
235|          ],
236|        ),
237|      ),
238|    );
239|  }
240|
241|  Widget _bannerBtn(IconData icon, String label, bool primary) {
242|    return TextButton(
243|      onPressed: () {},
244|      style: TextButton.styleFrom(
245|        backgroundColor: primary ? const Color(0xFF699EFF) : const Color(0xFF1A1A2E),
246|        foregroundColor: Colors.white,
247|        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
248|        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
249|      ),
250|      child: Row(
251|        mainAxisSize: MainAxisSize.min,
252|        children: [
253|          Icon(icon, size: 14),
254|          const SizedBox(width: 4),
255|          Text(i18n.tr(label), style: const TextStyle(fontSize: 10)),
256|        ],
257|      ),
258|    );
259|  }
260|
261|  // ── RECENT PROJECTS (160px) ───────────────────────────
262|
263|  Widget _buildRecentProjects() {
264|    final projects = [
265|      ('Promo Reel', 'assets/thumb1.png', '3 assets', 'Yesterday'),
266|      ('Wedding Edit', 'assets/thumb2.png', '12 assets', '2 days ago'),
267|      ('Vlog Week 23', 'assets/thumb3.png', '8 assets', '3 days ago'),
268|      ('Product Showcase', '', '6 assets', 'In Progress'),
269|    ];
270|    return SizedBox(
271|      height: 160,
272|      child: Column(
273|        crossAxisAlignment: CrossAxisAlignment.start,
274|        children: [
275|          Padding(
276|            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
277|            child: Row(
278|              children: [
279|                Tr('Recent Projects', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
280|                const Spacer(),
281|                Tr('View All', style: TextStyle(fontSize: 9, color: const Color(0xFF699EFF))),
282|              ],
283|            ),
284|          ),
285|          Expanded(
286|            child: ListView.builder(
287|              scrollDirection: Axis.horizontal,
288|              padding: const EdgeInsets.symmetric(horizontal: 8),
289|              itemCount: projects.length + 1,
290|              itemBuilder: (_, i) {
291|                if (i == projects.length) return _newProjectCard();
292|                final p = projects[i];
293|                return _projectCard(p.$1, p.$3, p.$4);
294|              },
295|            ),
296|          ),
297|        ],
298|      ),
299|    );
300|  }
301|
302|  Widget _projectCard(String name, String assets, String time) {
303|    return Container(
304|      width: 120,
305|      margin: const EdgeInsets.symmetric(horizontal: 4),
306|      decoration: BoxDecoration(
307|        color: const Color(0xFF1A1A2E),
308|        borderRadius: BorderRadius.circular(6),
309|        border: Border.all(color: const Color(0xFF2A2A3E)),
310|      ),
311|      child: Column(
312|        crossAxisAlignment: CrossAxisAlignment.start,
313|        children: [
314|          Container(
315|            height: 60,
316|            decoration: BoxDecoration(
317|              color: const Color(0xFF0F0F1A),
318|              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
319|            ),
320|            child: const Center(
321|              child: Icon(Icons.movie, size: 24, color: Colors.white24),
322|            ),
323|          ),
324|          Padding(
325|            padding: const EdgeInsets.all(6),
326|            child: Column(
327|              crossAxisAlignment: CrossAxisAlignment.start,
328|              children: [
329|                Text(i18n.tr(name), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
330|                const SizedBox(height: 2),
331|                Text(i18n.tr(assets), style: const TextStyle(fontSize: 8, color: Colors.grey)),
332|                Text(i18n.tr(time), style: const TextStyle(fontSize: 7, color: Colors.grey)),
333|              ],
334|            ),
335|          ),
336|        ],
337|      ),
338|    );
339|  }
340|
341|  Widget _newProjectCard() {
342|    return Container(
343|      width: 80,
344|      margin: const EdgeInsets.symmetric(horizontal: 4),
345|      decoration: BoxDecoration(
346|        color: const Color(0xFF1A1A2E),
347|        borderRadius: BorderRadius.circular(6),
348|        border: Border.all(color: const Color(0xFF2A2A3E), style: BorderStyle.solid),
349|      ),
350|      child: const Center(
351|        child: Column(
352|          mainAxisSize: MainAxisSize.min,
353|          children: [
354|            Icon(Icons.add, size: 20, color: Color(0xFF699EFF)),
355|            SizedBox(height: 4),
356|            Tr('New Project', style: TextStyle(fontSize: 8, color: Color(0xFF699EFF))),
357|          ],
358|        ),
359|      ),
360|    );
361|  }
362|
363|  // ── SYSTEM STATUS + AI QUICK ENTRY ────────────────────
364|
365|  Widget _buildSystemAndAI(Map<String, dynamic>? hw) {
366|    return Padding(
367|      padding: const EdgeInsets.all(8),
368|      child: Row(
369|        crossAxisAlignment: CrossAxisAlignment.start,
370|        children: [
371|          Expanded(child: _buildSystemStatus(hw)),
372|          const SizedBox(width: 8),
373|          Expanded(child: _buildAiQuickEntry()),
374|        ],
375|      ),
376|    );
377|  }
378|
379|  Widget _buildSystemStatus(Map<String, dynamic>? hw) {
380|    return Column(
381|      children: [
382|        Container(
383|          padding: const EdgeInsets.all(12),
384|          decoration: BoxDecoration(
385|            color: const Color(0xFF1A1A2E),
386|            borderRadius: BorderRadius.circular(6),
387|            border: Border.all(color: const Color(0xFF2A2A3E)),
388|          ),
389|          child: Column(
390|            crossAxisAlignment: CrossAxisAlignment.start,
391|            children: [
392|              Tr('Hardware Report', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
393|              const SizedBox(height: 8),
394|              _sysRow('CPU', '${hw?['cpu'] ?? '-'} (T1)'),
395|              _sysRow('RAM', '${hw?['ram_gb'] ?? '?'} GB (T1)'),
396|              _sysRow('GPU', 'None (T1)'),
397|              _sysRow('Disk', '${hw?['disk_free_gb'] ?? '?'} GB free'),
398|              const SizedBox(height: 4),
399|              Row(
400|                children: [
401|                  Tr('Max Tier: T1 (CPU Mode)', style: TextStyle(fontSize: 9, color: Colors.grey)),
402|                  const Spacer(),
403|                  Text('${6}/${12}',
404|                      style: TextStyle(fontSize: 8, color: Colors.grey[600])),
405|                ],
406|              ),
407|              const SizedBox(height: 4),
408|              // Compatibility bar
409|              Container(
410|                height: 6,
411|                decoration: BoxDecoration(
412|                  color: const Color(0xFF0F0F1A),
413|                  borderRadius: BorderRadius.circular(3),
414|                ),
415|                child: Row(
416|                  children: List.generate(12, (i) => Expanded(
417|                    child: Container(
418|                      margin: const EdgeInsets.symmetric(horizontal: 1),
419|                      decoration: BoxDecoration(
420|                        color: i < 6 ? const Color(0xFF4CAF50) : const Color(0xFF2A2A3E),
421|                        borderRadius: BorderRadius.circular(1),
422|                      ),
423|                    ),
424|                  )),
425|                ),
426|              ),
427|              const SizedBox(height: 8),
428|              TextButton(
429|                onPressed: () {},
430|                child: Tr('View Full Report', style: TextStyle(fontSize: 9, color: Color(0xFF699EFF))),
431|              ),
432|            ],
433|          ),
434|        ),
435|        const SizedBox(height: 8),
436|        // Service status
437|        Container(
438|          padding: const EdgeInsets.all(10),
439|          decoration: BoxDecoration(
440|            color: const Color(0xFF1A1A2E),
441|            borderRadius: BorderRadius.circular(6),
442|            border: Border.all(color: const Color(0xFF2A2A3E)),
443|          ),
444|          child: Column(
445|            children: [
446|              _serviceRow('API Server', 'Running :8899', true),
447|              const SizedBox(height: 4),
448|              _serviceRow('Edge-TTS', 'Online', true),
449|              const SizedBox(height: 4),
450|              _serviceRow('FFmpeg', 'v7.1', true),
451|              const SizedBox(height: 4),
452|              _serviceRow('Modules', '9/9 Loaded', true),
453|            ],
454|          ),
455|        ),
456|      ],
457|    );
458|  }
459|
460|  Widget _sysRow(String label, String value) {
461|    return Padding(
462|      padding: const EdgeInsets.symmetric(vertical: 2),
463|      child: Row(
464|        children: [
465|          SizedBox(width: 40, child: Text(i18n.tr(label),
466|              style: const TextStyle(fontSize: 9, color: Colors.grey))),
467|          Text(i18n.tr(value), style: const TextStyle(fontSize: 9, color: Colors.white70)),
468|        ],
469|      ),
470|    );
471|  }
472|
473|  Widget _serviceRow(String name, String status, bool ok) {
474|    return Row(
475|      children: [
476|        Icon(Icons.check_circle, size: 10, color: ok ? Colors.green : Colors.red),
477|        const SizedBox(width: 6),
478|        Expanded(
479|          child: Text(i18n.tr(name), style: const TextStyle(fontSize: 9, color: Colors.grey)),
480|        ),
481|        Text(i18n.tr(status), style: TextStyle(fontSize: 8, color: ok ? Colors.green : Colors.red)),
482|      ],
483|    );
484|  }
485|
486|  Widget _buildAiQuickEntry() {
487|    return Column(
488|      children: [
489|        // AI cards grid
490|        Row(
491|          children: [
492|            Expanded(child: _aiCard(Icons.record_voice_over, 'Voice Clone', 'TTS', const Color(0xFF4CAF50))),
493|            const SizedBox(width: 6),
494|            Expanded(child: _aiCard(Icons.music_note, 'Music Gen', 'Suno', const Color(0xFF9C27B0))),
495|          ],
496|        ),
497|        const SizedBox(height: 6),
498|        Row(
499|          children: [
500|            Expanded(child: _aiCard(Icons.image, 'Image Gen', 'Stable Diff', const Color(0xFFFF9800))),
501|