import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../services/cache_service.dart';

/// Modelo para reportar el estado de eventual connectivity de una funcionalidad
class FunctionalityConnectivityStatus {
  final String name; // ej: "Products", "Business Questions"
  final String description; // ej: "Create, Read, Update, Delete operations"
  final bool supportsOfflineRead; // ¿puedo leer datos offline?
  final bool supportsOfflineWrite; // ¿puedo escribir datos offline?
  final bool hasAutoSync; // ¿sincroniza automáticamente al reconectar?
  final String storageBackend; // ej: "SQLite", "Hive", "SharedPreferences"
  final String cacheStrategy; // ej: "LRU 2-layer", "JSON", "Native"
  final String syncMechanism; // ej: "OfflineQueueService", "Manual", "Automatic"
  final List<String> relatedProviders; // ej: ["inventoryProvider", "contextProvider"]
  final List<String> relatedServices; // ej: ["LocalDatabaseService", "APIService"]

  FunctionalityConnectivityStatus({
    required this.name,
    required this.description,
    required this.supportsOfflineRead,
    required this.supportsOfflineWrite,
    required this.hasAutoSync,
    required this.storageBackend,
    required this.cacheStrategy,
    required this.syncMechanism,
    required this.relatedProviders,
    required this.relatedServices,
  });
}

/// Provider que reporta el estado de eventual connectivity para CADA funcionalidad
final eventualConnectivityStatusProvider =
    FutureProvider<List<FunctionalityConnectivityStatus>>((ref) async {
  return [
    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Products (Productos)
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Products (CRUD)',
      description:
          'Create, Read, Update, Delete productos. Core inventory functionality.',
      supportsOfflineRead: true,
      supportsOfflineWrite: true,
      hasAutoSync: true,
      storageBackend: 'SQLite (LocalDatabaseService)',
      cacheStrategy: 'Local Database + LRU in-memory',
      syncMechanism: 'OfflineQueueService → drainQueue on reconnect',
      relatedProviders: [
        'inventoryProvider',
        'connectivityProvider',
        'offlineQueueWatcherProvider',
      ],
      relatedServices: [
        'LocalDatabaseService',
        'OfflineQueueService',
        'ConnectivityService',
        'APIService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Inventory Movements (Movimientos)
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Inventory Movements (Sales)',
      description: 'Record sales and inventory adjustments. Enqueues recordSale ops.',
      supportsOfflineRead: true,
      supportsOfflineWrite: true,
      hasAutoSync: true,
      storageBackend: 'SQLite (LocalDatabaseService)',
      cacheStrategy: 'Local Database + offline queue persistence',
      syncMechanism: 'OfflineQueueService.OfflineOpType.recordSale',
      relatedProviders: [
        'inventoryProvider',
        'connectivityProvider',
      ],
      relatedServices: [
        'LocalDatabaseService',
        'OfflineQueueService',
        'APIService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Search History (Historial de búsquedas)
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Search History Cache',
      description: 'Caches product search queries and category browsing.',
      supportsOfflineRead: true,
      supportsOfflineWrite: true,
      hasAutoSync: false, // no requiere sync (es local)
      storageBackend: 'SharedPreferences',
      cacheStrategy: 'JSON serialization with TTL (30 days)',
      syncMechanism: 'None (local only)',
      relatedProviders: [
        'productSearchHistoryProvider',
        'categoryBrowseHistoryProvider',
      ],
      relatedServices: [
        'SearchHistoryCacheService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Pinned Products (Productos fijados)
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Pinned Products',
      description: 'User preferences for favorite/pinned products.',
      supportsOfflineRead: true,
      supportsOfflineWrite: true,
      hasAutoSync: false, // no requiere sync (es local)
      storageBackend: 'SharedPreferences',
      cacheStrategy: 'JSON serialization',
      syncMechanism: 'None (local only)',
      relatedProviders: [
        'pinnedProductsProvider',
      ],
      relatedServices: [
        'LocalStoreService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Business Questions (Preguntas con IA)
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Business Questions (AI)',
      description:
          'Queries to Claude API for business insights. Cached with 12h TTL.',
      supportsOfflineRead: true,
      supportsOfflineWrite: false,
      hasAutoSync: false, // reads cached only
      storageBackend: 'SharedPreferences + LRU in-memory (L1+L2)',
      cacheStrategy: 'BQCacheService 2-layer cache with 12h TTL',
      syncMechanism: 'Manual retry on reconnect (show "Retry" button)',
      relatedProviders: [
        'businessQuestionsProvider',
        'connectivityProvider',
      ],
      relatedServices: [
        'BQCacheService',
        'ConnectivityService',
      ],
    ),

    FunctionalityConnectivityStatus(
      name: 'Conteo físico de inventario',
      description:
          'Sesiones de conteo en góndola; ajustes de stock al reconectar.',
      supportsOfflineRead: true,
      supportsOfflineWrite: true,
      hasAutoSync: true,
      storageBackend: 'Hive (sesiones + cola sync)',
      cacheStrategy: 'StockCountSummaryCache L1 LRU + L2 Hive (6 h)',
      syncMechanism:
          'Cola pending_sync + inventoryProvider.updateProduct al reconectar',
      relatedProviders: [
        'stockCountProvider',
        'inventoryProvider',
        'connectivityProvider',
      ],
      relatedServices: [
        'StockCountLocalStore',
        'StockCountProcessingService',
        'StockCountSummaryCache',
        'ConnectivityService',
      ],
    ),

    FunctionalityConnectivityStatus(
      name: 'Inventory Health Score',
      description:
          'Computed from local product data and cached reports. No API dependency.',
      supportsOfflineRead: true,
      supportsOfflineWrite: false,
      hasAutoSync: true,
      storageBackend: 'In-memory computed + cached reports (Hive)',
      cacheStrategy: 'Reactive computation from inventory data',
      syncMechanism: 'Automatic via inventoryProvider watch chain',
      relatedProviders: [
        'inventoryHealthProvider',
        'contextProvider',
      ],
      relatedServices: [
        'InventoryHealthService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Stores (Tiendas/Locales)
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Stores (Locales)',
      description:
          'Store list and details. Cached locally from initial sync.',
      supportsOfflineRead: true,
      supportsOfflineWrite: false,
      hasAutoSync: true,
      storageBackend: 'SQLite (LocalDatabaseService)',
      cacheStrategy: 'Local database (initial load on first session)',
      syncMechanism: 'Periodic background sync',
      relatedProviders: [
        'storeProvider',
        'connectivityProvider',
      ],
      relatedServices: [
        'LocalDatabaseService',
        'APIService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Restock Suggestions
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Restock Suggestions',
      description:
          'Computed from local product data and sales history. No API dependency.',
      supportsOfflineRead: true,
      supportsOfflineWrite: false,
      hasAutoSync: false,
      storageBackend: 'Computed from SQLite + in-memory',
      cacheStrategy: 'LRU cache of computed suggestions',
      syncMechanism: 'None (computed locally)',
      relatedProviders: [
        'restock_ai_suggestions_provider',
      ],
      relatedServices: [
        'LocalDatabaseService',
        'CacheService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Notifications
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Local Notifications',
      description:
          'Local push notifications. No API dependency, persisted in Hive.',
      supportsOfflineRead: true,
      supportsOfflineWrite: true,
      hasAutoSync: false,
      storageBackend: 'Hive box "notification_events"',
      cacheStrategy: 'Event-based persistence',
      syncMechanism: 'None (local only)',
      relatedProviders: [],
      relatedServices: [
        'NotificationService',
        'UsageTrackingService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Connectivity Monitoring
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Connectivity Monitoring',
      description:
          'Detects online/offline transitions and triggers sync automatically.',
      supportsOfflineRead: true,
      supportsOfflineWrite: false,
      hasAutoSync: true,
      storageBackend: 'connectivity_plus package (native)',
      cacheStrategy: 'Stream-based state management',
      syncMechanism: 'ConnectivityService → offlineQueueWatcher',
      relatedProviders: [
        'connectivityProvider',
        'offlineQueueWatcherProvider',
      ],
      relatedServices: [
        'ConnectivityService',
        'OfflineQueueService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: Offline Queue Management
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'Offline Queue Management',
      description:
          'Persists and retries failed operations. 3-retry policy per operation.',
      supportsOfflineRead: true,
      supportsOfflineWrite: true,
      hasAutoSync: true,
      storageBackend: 'Hive box "pending_ops"',
      cacheStrategy: 'FIFO queue with retry count tracking',
      syncMechanism:
          'OfflineQueueService.drainQueue() triggered by connectivityProvider',
      relatedProviders: [
        'offlineQueueWatcherProvider',
        'connectivityProvider',
      ],
      relatedServices: [
        'OfflineQueueService',
        'ConnectivityService',
      ],
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FUNCIONALIDAD: API Response Caching
    // ─────────────────────────────────────────────────────────────────────────
    FunctionalityConnectivityStatus(
      name: 'API Response Caching',
      description:
          'Multi-layer caching for generic API responses. L1 (LRU in-memory) + L2 (Hive persistent).',
      supportsOfflineRead: true,
      supportsOfflineWrite: false,
      hasAutoSync: false,
      storageBackend: 'LRU (memory) + Hive box "api_cache"',
      cacheStrategy: 'CacheService 2-layer with TTL per endpoint',
      syncMechanism: 'Automatic on API call (serve stale if offline)',
      relatedProviders: [],
      relatedServices: [
        'CacheService',
        'APIService',
      ],
    ),
  ];
});

/// Provider que devuelve un sumario del estado de eventual connectivity
final eventualConnectivitySummaryProvider =
    FutureProvider<EventualConnectivitySummary>((ref) async {
  final statuses =
      await ref.watch(eventualConnectivityStatusProvider.future);
  final connectivity = ConnectivityService.shared;
  final offline = OfflineQueueService.shared;
  final cache = CacheService.shared;

  final totalFunctionalities = statuses.length;
  final withOfflineRead = statuses.where((s) => s.supportsOfflineRead).length;
  final withOfflineWrite = statuses.where((s) => s.supportsOfflineWrite).length;
  final withAutoSync = statuses.where((s) => s.hasAutoSync).length;

  return EventualConnectivitySummary(
    isOnline: connectivity.isOnline,
    totalFunctionalities: totalFunctionalities,
    functionalitiesWithOfflineRead: withOfflineRead,
    functionalitiesWithOfflineWrite: withOfflineWrite,
    functionalitiesWithAutoSync: withAutoSync,
    pendingOperations: offline.pendingCount,
    storageLayers: [
      'SQLite (stores, products, movements)',
      'Hive (pending_ops, api_cache, notifications, events, etc.)',
      'SharedPreferences (BQ cache, search history, preferences)',
      'LRUCache in-memory (L1 for API responses and BQ queries)',
    ],
    allFunctionalitiesImplementedConnectivity: withOfflineRead == totalFunctionalities,
  );
});

/// Sumario de eventual connectivity para toda la app
class EventualConnectivitySummary {
  final bool isOnline;
  final int totalFunctionalities;
  final int functionalitiesWithOfflineRead;
  final int functionalitiesWithOfflineWrite;
  final int functionalitiesWithAutoSync;
  final int pendingOperations;
  final List<String> storageLayers;
  final bool allFunctionalitiesImplementedConnectivity;

  EventualConnectivitySummary({
    required this.isOnline,
    required this.totalFunctionalities,
    required this.functionalitiesWithOfflineRead,
    required this.functionalitiesWithOfflineWrite,
    required this.functionalitiesWithAutoSync,
    required this.pendingOperations,
    required this.storageLayers,
    required this.allFunctionalitiesImplementedConnectivity,
  });

  /// Porcentaje de funcionalidades con offlineRead implementado
  int get offlineReadCoverage =>
      ((functionalitiesWithOfflineRead / totalFunctionalities) * 100).toInt();

  /// Porcentaje de funcionalidades con offlineWrite implementado
  int get offlineWriteCoverage =>
      ((functionalitiesWithOfflineWrite / totalFunctionalities) * 100).toInt();

  /// Porcentaje de funcionalidades con autoSync implementado
  int get autoSyncCoverage =>
      ((functionalitiesWithAutoSync / totalFunctionalities) * 100).toInt();
}
