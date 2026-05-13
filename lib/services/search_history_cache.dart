import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SearchHistoryCacheService — Sprint 5 (Caching Strategy per Mobile)
//
// PROPÓSITO:
//   Caché de historial de búsquedas y categorías visitadas por el usuario.
//   Distinto de CacheService (API responses), CachedProductImage (images),
//   y BQCacheService (Claude responses).
//
// ESTRATEGIA:
//   - JSON serialization + SharedPreferences para persistencia
//   - Prefijo único: 'inventaria_search_history_'
//   - Capacidad limitada (últimas 20 búsquedas, últimas 10 categorías)
//   - TTL opcional: entries se marcan con timestamp para limpieza de sesiones antiguas
//
// PLATAFORMAS:
//   - Android: SharedPreferences nativo
//   - iOS: NSUserDefaults (abstracción de SharedPreferences)
//
// USO:
//   await SearchHistoryCacheService.shared.addProductSearch('iPhone 15');
//   final searches = await SearchHistoryCacheService.shared.getProductSearchHistory();
//   await SearchHistoryCacheService.shared.clearAll();
// ─────────────────────────────────────────────────────────────────────────────

class SearchEntry {
  final String query;
  final DateTime timestamp;
  final int resultCount; // cuántos resultados se encontraron

  SearchEntry({
    required this.query,
    required this.timestamp,
    required this.resultCount,
  });

  factory SearchEntry.fromJson(Map<String, dynamic> json) {
    return SearchEntry(
      query: json['query'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      resultCount: json['resultCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'query': query,
        'timestamp': timestamp.toIso8601String(),
        'resultCount': resultCount,
      };
}

class CategoryBrowseEntry {
  final String categoryId;
  final String categoryName;
  final DateTime timestamp;
  final int itemsInCategory;

  CategoryBrowseEntry({
    required this.categoryId,
    required this.categoryName,
    required this.timestamp,
    required this.itemsInCategory,
  });

  factory CategoryBrowseEntry.fromJson(Map<String, dynamic> json) {
    return CategoryBrowseEntry(
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      itemsInCategory: json['itemsInCategory'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'categoryName': categoryName,
        'timestamp': timestamp.toIso8601String(),
        'itemsInCategory': itemsInCategory,
      };
}

class SearchHistoryCacheService {
  SearchHistoryCacheService._();
  static final SearchHistoryCacheService shared =
      SearchHistoryCacheService._();

  static const String _searchPrefix = 'inventaria_search_history_searches_';
  static const String _categoryPrefix =
      'inventaria_search_history_categories_';
  static const String _storageKey = 'search_history';
  static const String _categoryStorageKey = 'category_browse_history';
  static const int _maxSearchHistory = 20;
  static const int _maxCategoryHistory = 10;

  // ── Inicialización ─────────────────────────────────────────────────────────

  Future<void> init() async {
    // Inicializar estructura de almacenamiento si no existe
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_searchPrefix + _storageKey)) {
      await prefs.setString(_searchPrefix + _storageKey, jsonEncode([]));
    }
    if (!prefs.containsKey(_categoryPrefix + _categoryStorageKey)) {
      await prefs.setString(_categoryPrefix + _categoryStorageKey, jsonEncode([]));
    }
  }

  // ── Búsquedas de Productos ─────────────────────────────────────────────────

  /// Agregar una búsqueda al historial
  Future<void> addProductSearch(
    String query, {
    int resultCount = 0,
  }) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _searchPrefix + _storageKey;

    // Leer historial actual
    final json = prefs.getString(key) ?? '[]';
    final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
    final entries = decoded
        .map((e) => SearchEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    // Remover duplicados (la búsqueda más reciente va primero)
    entries.removeWhere((e) => e.query.toLowerCase() == query.toLowerCase());

    // Agregar nueva búsqueda al inicio
    entries.insert(
      0,
      SearchEntry(
        query: query,
        timestamp: DateTime.now(),
        resultCount: resultCount,
      ),
    );

    // Mantener límite de historiales
    if (entries.length > _maxSearchHistory) {
      entries.removeRange(_maxSearchHistory, entries.length);
    }

    // Guardar
    final updated = entries.map((e) => e.toJson()).toList();
    await prefs.setString(key, jsonEncode(updated));
  }

  /// Obtener historial de búsquedas
  Future<List<SearchEntry>> getProductSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _searchPrefix + _storageKey;
    final json = prefs.getString(key) ?? '[]';

    try {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((e) => SearchEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error decoding search history: $e');
      return [];
    }
  }

  /// Remover una búsqueda específica
  Future<void> removeProductSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _searchPrefix + _storageKey;

    final json = prefs.getString(key) ?? '[]';
    final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
    final entries = decoded
        .map((e) => SearchEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    entries.removeWhere((e) => e.query.toLowerCase() == query.toLowerCase());

    final updated = entries.map((e) => e.toJson()).toList();
    await prefs.setString(key, jsonEncode(updated));
  }

  /// Limpiar historial de búsquedas
  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _searchPrefix + _storageKey;
    await prefs.setString(key, jsonEncode([]));
  }

  // ── Categorías Visitadas ───────────────────────────────────────────────────

  /// Agregar categoría al historial de visitas
  Future<void> addCategoryBrowse(
    String categoryId,
    String categoryName, {
    int itemsInCategory = 0,
  }) async {
    if (categoryId.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _categoryPrefix + _categoryStorageKey;

    // Leer historial actual
    final json = prefs.getString(key) ?? '[]';
    final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
    final entries = decoded
        .map((e) => CategoryBrowseEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    // Remover duplicados
    entries.removeWhere((e) => e.categoryId == categoryId);

    // Agregar nueva al inicio
    entries.insert(
      0,
      CategoryBrowseEntry(
        categoryId: categoryId,
        categoryName: categoryName,
        timestamp: DateTime.now(),
        itemsInCategory: itemsInCategory,
      ),
    );

    // Mantener límite
    if (entries.length > _maxCategoryHistory) {
      entries.removeRange(_maxCategoryHistory, entries.length);
    }

    // Guardar
    final updated = entries.map((e) => e.toJson()).toList();
    await prefs.setString(key, jsonEncode(updated));
  }

  /// Obtener historial de categorías visitadas
  Future<List<CategoryBrowseEntry>> getCategoryBrowseHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _categoryPrefix + _categoryStorageKey;
    final json = prefs.getString(key) ?? '[]';

    try {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((e) => CategoryBrowseEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error decoding category history: $e');
      return [];
    }
  }

  /// Limpiar historial de categorías
  Future<void> clearCategoryHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _categoryPrefix + _categoryStorageKey;
    await prefs.setString(key, jsonEncode([]));
  }

  // ── Limpieza general ───────────────────────────────────────────────────────

  /// Limpiar todo el historial (búsquedas y categorías)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchPrefix + _storageKey);
    await prefs.remove(_categoryPrefix + _categoryStorageKey);
  }

  /// Remover entries más antiguas que el TTL especificado
  Future<void> clearExpired({Duration ttl = const Duration(days: 30)}) async {
    final cutoffTime = DateTime.now().subtract(ttl);

    final prefs = await SharedPreferences.getInstance();

    // Limpiar búsquedas expiradas
    final searchKey = _searchPrefix + _storageKey;
    final searchJson = prefs.getString(searchKey) ?? '[]';
    final List<dynamic> searchDecoded = jsonDecode(searchJson) as List<dynamic>;
    final searches = searchDecoded
        .map((e) => SearchEntry.fromJson(e as Map<String, dynamic>))
        .where((e) => e.timestamp.isAfter(cutoffTime))
        .toList();
    await prefs.setString(searchKey, jsonEncode(searches.map((e) => e.toJson())));

    // Limpiar categorías expiradas
    final categoryKey = _categoryPrefix + _categoryStorageKey;
    final categoryJson = prefs.getString(categoryKey) ?? '[]';
    final List<dynamic> categoryDecoded = jsonDecode(categoryJson) as List<dynamic>;
    final categories = categoryDecoded
        .map((e) => CategoryBrowseEntry.fromJson(e as Map<String, dynamic>))
        .where((e) => e.timestamp.isAfter(cutoffTime))
        .toList();
    await prefs.setString(
      categoryKey,
      jsonEncode(categories.map((e) => e.toJson())),
    );
  }
}
