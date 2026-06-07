import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Safe HTTP client with timeout, status checking, error wrapping
// ---------------------------------------------------------------------------
class ImageStudioApi {
  static const base = 'http://127.0.0.1:8899';
  static const Duration _timeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .post(Uri.parse('$base$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(_timeout);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw ApiException('HTTP ${r.statusCode}: ${r.body}');
      }
      final decoded = jsonDecode(r.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Unexpected response: ${decoded.runtimeType}');
      }
      if (decoded.containsKey('error')) {
        throw ApiException('${decoded['error']}');
      }
      return decoded;
    } on TimeoutException {
      throw ApiException('Request timed out (${_timeout.inSeconds}s): POST $path');
    } on http.ClientException catch (e) {
      throw ApiException('Connection failed: $e');
    } on FormatException catch (e) {
      throw ApiException('Invalid response: $e');
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final r = await http.get(Uri.parse('$base$path')).timeout(_timeout);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw ApiException('HTTP ${r.statusCode}: ${r.body}');
      }
      final decoded = jsonDecode(r.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Unexpected response: ${decoded.runtimeType}');
      }
      if (decoded.containsKey('error')) {
        throw ApiException('${decoded['error']}');
      }
      return decoded;
    } on TimeoutException {
      throw ApiException('Request timed out: GET $path');
    } on http.ClientException catch (e) {
      throw ApiException('Connection failed: GET $path');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Canvas token for dispose-safe async
// ---------------------------------------------------------------------------
class CanvasCancelToken {
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;
}

// Add helper methods to ImageStudioApi
extension ImageStudioApiExt on ImageStudioApi {
  Future<Map<String, dynamic>> getInfo() => get('/api/v1/editor/info');
  Future<Map<String, dynamic>> getLayers() => get('/api/v1/layer/info');
  Future<Map<String, dynamic>> addLayer() => post('/api/v1/editor/add-layer', {});
  Future<Map<String, dynamic>> deleteLayer() => post('/api/v1/editor/delete-layer', {});
}
