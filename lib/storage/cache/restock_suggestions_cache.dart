import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/lru_cache.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RestockSuggestionsCache — NUEVO requerimiento (GET /restock/suggestions)
//
// Estrategia: L1 LRU (10 tiendas/respuestas) + L2 SharedPreferences
// TTL: 6 horas (sugerencias AI/backend no necesitan refresco constante).
// ─────────────────────────────────────────────────────────────────────────────

class RestockSuggestionsCache {
  RestockSuggestionsCache._();
  static final RestockSuggestionsCache shared = RestockSuggestionsCache._();

  static const _prefix = 'inventaria_restock_suggestions_';
  static const _ttl = Duration(hours: 6);
  static const _l1Capacity = 10;

  final LRUCache<String, _Entry> _l1 = LRUCache(_l1Capacity);
  bool _ready = false;

  Future<void> init() async {
    _ready = true;
  }

  Future<List<Map<String, dynamic>>?> read(String storeKey) async {
    if (!_ready) return null;

    final l1 = _l1.get(storeKey);
    if (l1 != null && !l1.isExpired) {
      return l1.cards;
    }
    if (l1 != null) _l1.remove(storeKey);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$storeKey');
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expires = DateTime.parse(map['expiresAt'] as String);
      if (DateTime.now().isAfter(expires)) {
        await prefs.remove('$_prefix$storeKey');
        return null;
      }
      final list = (map['cards'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _l1.put(storeKey, _Entry(cards: list, expiresAt: expires));
      return list;
    } catch (_) {
      await prefs.remove('$_prefix$storeKey');
      return null;
    }
  }

  Future<void> save(String storeKey, List<Map<String, dynamic>> cards) async {
    if (!_ready) return;
    final expires = DateTime.now().add(_ttl);
    _l1.put(storeKey, _Entry(cards: cards, expiresAt: expires));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$storeKey',
      jsonEncode({'expiresAt': expires.toIso8601String(), 'cards': cards}),
    );
  }

  Future<void> invalidate(String storeKey) async {
    _l1.remove(storeKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$storeKey');
  }
}

class _Entry {
  final List<Map<String, dynamic>> cards;
  final DateTime expiresAt;

  _Entry({required this.cards, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
