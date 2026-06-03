import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP client for PhantomVox Python AI Server (localhost:8899)
class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://127.0.0.1:8899'});

  // ── Health ──

  Future<Map<String, dynamic>> health() async {
    final r = await http.get(Uri.parse('$baseUrl/api/v1/health'));
    return jsonDecode(r.body);
  }

  // ── Info ──

  Future<Map<String, dynamic>> info() async {
    final r = await http.get(Uri.parse('$baseUrl/api/v1/info'));
    return jsonDecode(r.body);
  }

  // ── Hardware ──

  Future<Map<String, dynamic>> hardware() async {
    final r = await http.get(Uri.parse('$baseUrl/api/v1/hardware'));
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> hardwareCheck(String modelKey) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/v1/hardware/check/$modelKey'),
    );
    return jsonDecode(r.body);
  }

  // ── Locale ──

  Future<Map<String, dynamic>> currentLocale() async {
    final r = await http.get(Uri.parse('$baseUrl/api/v1/locale'));
    return jsonDecode(r.body);
  }

  Future<List<Map<String, dynamic>>> availableLocales() async {
    final r = await http.get(Uri.parse('$baseUrl/api/v1/locales'));
    return List<Map<String, dynamic>>.from(jsonDecode(r.body));
  }

  Future<Map<String, dynamic>> setLocale(String locale) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/v1/locale/set'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'locale': locale}),
    );
    return jsonDecode(r.body);
  }

  // ── Translate ──

  Future<String> translate(String key, {Map<String, String>? params}) async {
    final uri = Uri.parse('$baseUrl/api/v1/translate/$key')
        .replace(queryParameters: params);
    final r = await http.get(uri);
    final data = jsonDecode(r.body);
    return data['value'] as String;
  }

  // ── Generic helpers ──

  Future<dynamic> get(String path) async {
    final r = await http.get(Uri.parse('$baseUrl$path'));
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    return jsonDecode(r.body);
  }

  // ── Timeline ──

  Future<Map<String, dynamic>> createTimeline({
    String name = 'Untitled Project',
    double fps = 24.0,
    int width = 1920,
    int height = 1080,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/v1/timelines'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name, 'fps': fps, 'width': width, 'height': height,
      }),
    );
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> getTimeline(String tlId) async {
    final r = await http.get(Uri.parse('$baseUrl/api/v1/timelines/$tlId'));
    return jsonDecode(r.body);
  }

  Future<List<dynamic>> listTimelines() async {
    final r = await http.get(Uri.parse('$baseUrl/api/v1/timelines'));
    final data = jsonDecode(r.body);
    return data['timelines'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> addTrack(String tlId,
      {String type = 'video', String name = ''}) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/v1/timelines/$tlId/tracks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'type': type, 'name': name}),
    );
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> addClip(String tlId, String trackId,
      {required String assetPath, double start = 0.0, double duration = 10.0,
       String name = '', String clipType = 'video'}) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/v1/timelines/$tlId/tracks/$trackId/clips'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'asset_path': assetPath, 'start': start, 'duration': duration,
        'name': name, 'clip_type': clipType,
      }),
    );
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> addEffect(String tlId, String clipId,
      {required String type, String name = '', Map<String, dynamic> params = const {}}) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/v1/timelines/$tlId/clips/$clipId/effects'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'type': type, 'name': name, 'params': params}),
    );
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> renderCommand(String tlId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/v1/timelines/$tlId/render'),
    );
    return jsonDecode(r.body);
  }
}
