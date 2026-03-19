import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';

// ─────────────────────────────────────────────
// ApiException
// ─────────────────────────────────────────────
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  const ApiException(this.statusCode, this.message, {this.code});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ─────────────────────────────────────────────
// ApiService — singleton HTTP client
// Attaches Bearer token + X-Store-Id to every request
// ─────────────────────────────────────────────
class ApiService {
  ApiService._();
  static final ApiService shared = ApiService._();

  static const _kToken   = 'inventaria_jwt_token';
  static const _kStoreId = 'inventaria_store_id';

  String? _token;
  String? _storeId;

  // ── Auth state ────────────────────────────

  Future<void> setAuth(String token, String storeId) async {
    _token   = token;
    _storeId = storeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken,   token);
    await prefs.setString(_kStoreId, storeId);
  }

  Future<bool> restoreAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token   = prefs.getString(_kToken);
    _storeId = prefs.getString(_kStoreId);
    return _token != null && _storeId != null;
  }

  Future<void> clearAuth() async {
    _token   = null;
    _storeId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kStoreId);
  }

  bool get isAuthenticated => _token != null;
  String? get storeId => _storeId;

  // ── Headers ───────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        if (_token   != null) 'Authorization': 'Bearer $_token',
        if (_storeId != null) 'X-Store-Id':    _storeId!,
      };

  // ── HTTP verbs ────────────────────────────

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = _buildUri(path, query);
    debugPrint('[API] GET $uri');
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = _buildUri(path);
    debugPrint('[API] POST $uri');
    final res = await http.post(uri,
        headers: _headers, body: jsonEncode(body));
    return _handle(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final uri = _buildUri(path);
    debugPrint('[API] PATCH $uri');
    final res = await http.patch(uri,
        headers: _headers, body: jsonEncode(body));
    return _handle(res);
  }

  Future<dynamic> delete(String path) async {
    final uri = _buildUri(path);
    debugPrint('[API] DELETE $uri');
    final res = await http.delete(uri, headers: _headers);
    return _handle(res);
  }

  // ── Helpers ───────────────────────────────

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$kApiBaseUrl$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: query);
  }

  dynamic _handle(http.Response res) {
    debugPrint('[API] ${res.statusCode} ${res.request?.url}');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(res.body);
    }

    String message = 'Error del servidor';
    String? code;
    try {
      final body = jsonDecode(res.body);
      message = body['error']?['message'] ?? body['message'] ?? message;
      code    = body['error']?['code'];
    } catch (_) {}

    throw ApiException(res.statusCode, message, code: code);
  }

  // ── Date parser (handles ISO strings and Firestore maps) ─
  static DateTime? parseDate(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) {
      return DateTime.fromMillisecondsSinceEpoch(val);
    }
    if (val is Map) {
      final seconds = val['_seconds'] as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return null;
  }
}
