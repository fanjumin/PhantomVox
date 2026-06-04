import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Singleton i18n service — fetches translations from backend API.
/// Cache translations in-memory to avoid per-widget API calls.
class I18nService extends ChangeNotifier {
  static final I18nService _instance = I18nService._();
  factory I18nService() => _instance;
  I18nService._();

  final ApiService _api = ApiService();
  String _locale = 'en';
  bool _ready = false;

  /// Cache: key -> translated string for current locale.
  final Map<String, String> _cache = {};

  String get locale => _locale;
  bool get ready => _ready;

  /// Initialize: load current locale from backend.
  Future<void> init() async {
    try {
      final r = await _api.currentLocale();
      _locale = r['locale'] as String? ?? 'en';
      _ready = true;
      notifyListeners();
    } catch (_) {
      _locale = 'en';
      _ready = true;
      notifyListeners();
    }
  }

  /// Translate a key (defaults to English text as key).
  /// Falls back to `key` if backend has no translation or request fails.
  String tr(String key, {Map<String, String>? params}) {
    if (_cache.containsKey(key)) {
      return _applyParams(_cache[key]!, params);
    }
    // Request from backend asynchronously; return key until cached.
    _fetchAndCache(key, params);
    return key;
  }

  /// Change locale and clear cache.
  Future<void> setLocale(String code) async {
    try {
      await _api.setLocale(code);
    } catch (_) {
      // ignore errors
    }
    _locale = code;
    _cache.clear();
    notifyListeners();
  }

  Future<void> _fetchAndCache(String key, Map<String, String>? params) async {
    try {
      final value = await _api.translate(key, params: params);
      _cache[key] = value;
      notifyListeners();
    } catch (_) {
      _cache[key] = key;
      notifyListeners();
    }
  }

  String _applyParams(String value, Map<String, String>? params) {
    if (params == null || params.isEmpty) return value;
    String result = value;
    params.forEach((k, v) {
      result = result.replaceAll('{$k}', v);
    });
    return result;
  }
}

/// Convenience shorthand.
I18nService get i18n => I18nService();
