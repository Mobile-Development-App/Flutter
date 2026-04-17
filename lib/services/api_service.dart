import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import 'pipeline_logger.dart';

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
// Token = Firebase ID Token (JWT), NOT the uid
// Attaches:  Authorization: Bearer <idToken>
//            X-Store-Id: <storeId>
// ─────────────────────────────────────────────
class ApiService {
  ApiService._();
  static final ApiService shared = ApiService._();

  static const _kIdToken = 'inventaria_id_token';
  static const _kStoreId = 'inventaria_store_id';
  static const _kUid     = 'inventaria_uid';

  String? _idToken;
  String? _storeId;
  String? _uid;

  // ── Auth state ────────────────────────────

  /// Call after login/register with the Firebase ID Token (not uid)
  Future<void> setAuth(String idToken, String storeId, {String uid = ''}) async {
    _idToken  = idToken;
    _storeId  = storeId;
    _uid      = uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIdToken, idToken);
    await prefs.setString(_kStoreId, storeId);
    if (uid.isNotEmpty) await prefs.setString(_kUid, uid);
    debugPrint('[API] Auth set — storeId: $storeId uid: $uid '
        'token: ${idToken.length > 20 ? idToken.substring(0, 20) : idToken}...');
  }

  Future<bool> restoreAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _idToken  = prefs.getString(_kIdToken);
    _storeId  = prefs.getString(_kStoreId);
    _uid      = prefs.getString(_kUid);
    final ok  = _idToken != null && _storeId != null;
    debugPrint('[API] restoreAuth → ${ok ? "OK storeId=$_storeId" : "NO stored session"}');
    return ok;
  }

  Future<void> clearAuth() async {
    _idToken  = null;
    _storeId  = null;
    _uid      = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIdToken);
    await prefs.remove(_kStoreId);
    await prefs.remove(_kUid);
    debugPrint('[API] Auth cleared');
  }

  bool get isAuthenticated => _idToken != null && _storeId != null;
  String? get storeId      => _storeId;
  String? get uid          => _uid;

  // ── Headers ───────────────────────────────

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (_idToken != null && _idToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_idToken';
    }
    if (_storeId != null && _storeId!.isNotEmpty) {
      h['X-Store-Id'] = _storeId!;
    }
    if (kDebugMode) {
      debugPrint('[API] Headers — Auth: ${h.containsKey('Authorization') ? 'present' : 'MISSING'} '
          'X-Store-Id: ${h['X-Store-Id'] ?? 'MISSING'}');
    }
    return h;
  }

  // ── HTTP verbs ────────────────────────────

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = _buildUri(path, query);
    debugPrint('[API] GET $uri');
    final sw  = Stopwatch()..start();
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    sw.stop();
    // INGESTION layer: log every REST call
    PipelineLogger.shared.log(
      stage:       PipelineStage.ingestion,
      operation:   'GET $path',
      recordCount: 0,           // record count resolved by caller after parse
      latency:     sw.elapsed,
    );
    return _handle(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = _buildUri(path);
    debugPrint('[API] POST $uri');
    final sw  = Stopwatch()..start();
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    sw.stop();
    PipelineLogger.shared.log(
      stage:       PipelineStage.ingestion,
      operation:   'POST $path',
      recordCount: 0,
      latency:     sw.elapsed,
    );
    return _handle(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final uri = _buildUri(path);
    debugPrint('[API] PATCH $uri');
    final res = await http
        .patch(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _handle(res);
  }

  Future<dynamic> delete(String path) async {
    final uri = _buildUri(path);
    debugPrint('[API] DELETE $uri');
    final sw  = Stopwatch()..start();
    final res = await http
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    sw.stop();
    PipelineLogger.shared.log(
      stage:       PipelineStage.ingestion,
      operation:   'DELETE $path',
      recordCount: 0,
      latency:     sw.elapsed,
    );
    debugPrint('[API] DELETE completed — status ${res.statusCode} in ${sw.elapsedMilliseconds}ms');
    return _handle(res);
  }

  // ── External GET (no auth headers) ────────

  Future<dynamic> getExternal(String url) async {
    try {
      debugPrint('[API] GET (external) $url');
      final res = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (_) {
      return null;
    }
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

    debugPrint('[API] ERROR ${res.statusCode}: $message');
    throw ApiException(res.statusCode, message, code: code);
  }

  // ── Date parser ───────────────────────────

  static DateTime? parseDate(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is int)    return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is Map) {
      final seconds = val['_seconds'] as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return null;
  }
}
