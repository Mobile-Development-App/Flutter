import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/stock_count.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/stock_count_processing_service.dart';
import '../storage/cache/stock_count_summary_cache.dart';
import '../storage/persistence/inventory_sqlite_mirror.dart';
import '../storage/persistence/stock_count_local_store.dart';
import 'connectivity_provider.dart';
import 'inventory_provider.dart';

enum StockCountDataSource { live, cache, offlineStorage }

class StockCountState {
  final StockCountSession? activeSession;
  final StockCountSummary? lastSummary;
  final StockCountDataSource? summarySource;
  final bool isSyncing;
  final String? error;

  const StockCountState({
    this.activeSession,
    this.lastSummary,
    this.summarySource,
    this.isSyncing = false,
    this.error,
  });

  StockCountState copyWith({
    StockCountSession? activeSession,
    StockCountSummary? lastSummary,
    StockCountDataSource? summarySource,
    bool? isSyncing,
    String? error,
    bool clearError = false,
  }) =>
      StockCountState(
        activeSession: activeSession ?? this.activeSession,
        lastSummary: lastSummary ?? this.lastSummary,
        summarySource: summarySource ?? this.summarySource,
        isSyncing: isSyncing ?? this.isSyncing,
        error: clearError ? null : (error ?? this.error),
      );
}

class StockCountNotifier extends Notifier<StockCountState> {
  var _initialized = false;

  @override
  StockCountState build() {
    ref.watch(connectivityProvider);
    ref.listen(connectivityProvider, (prev, next) {
      final wasOffline = prev?.value == false;
      final isOnline = next.value == true;
      if (wasOffline && isOnline) {
        _drainPendingSync();
      }
    });
    if (!_initialized) {
      _initialized = true;
      Future.microtask(_bootstrap);
    }
    return const StockCountState();
  }

  Future<void> _bootstrap() async {
    await StockCountLocalStore.shared.init();
    await StockCountSummaryCache.shared.init();
    final storeKey = ApiService.shared.storeId ?? 'default';
    await StockCountLocalStore.shared.clearActive();
    StockCountSummary? summary;
    StockCountDataSource? source;

    if (ConnectivityService.shared.isOnline) {
      final completed = StockCountLocalStore.shared
          .completedSessions(storeKey, limit: 1);
      if (completed.isNotEmpty && completed.first.summary != null) {
        summary = completed.first.summary;
        source = StockCountDataSource.live;
      }
    }

    summary ??= await StockCountSummaryCache.shared.read(storeKey);
    source ??=
        summary != null ? StockCountDataSource.cache : null;

    state = StockCountState(
      lastSummary: summary,
      summarySource: source,
    );

    if (ConnectivityService.shared.isOnline) {
      await _drainPendingSync();
    }
  }

  Future<void> startSession() async {
    final storeKey = ApiService.shared.storeId ?? 'default';
    final session = StockCountSession(
      id: const Uuid().v4(),
      storeId: storeKey,
      startedAt: DateTime.now(),
    );
    state = StockCountState(activeSession: session);
  }

  Future<void> recordCount(Product product, int countedQuantity) async {
    var session = state.activeSession;
    if (session == null) {
      await startSession();
      session = state.activeSession;
    }
    if (session == null) return;

    final line = StockCountLine(
      productId: product.id,
      productName: product.name,
      sku: product.sku,
      systemQuantity: product.quantity,
      countedQuantity: countedQuantity,
      recordedAt: DateTime.now(),
    );

    final lines = [...session.lines];
    final idx = lines.indexWhere((l) => l.productId == product.id);
    if (idx >= 0) {
      lines[idx] = line;
    } else {
      lines.add(line);
    }

    final updated = session.copyWith(lines: lines);
    state = state.copyWith(activeSession: updated, clearError: true);
  }

  Future<StockCountSummary?> finalizeSession() async {
    final session = state.activeSession;
    if (session == null || session.lines.isEmpty) {
      state = state.copyWith(
          error: 'Cuenta al menos un producto antes de ver el informe.');
      return null;
    }

    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final summary =
          await StockCountProcessingService.shared.analyse(session.lines);
      final storeKey = session.storeId;
      final completed = session.copyWith(
        completedAt: DateTime.now(),
        summary: summary,
        syncPending: !ConnectivityService.shared.isOnline,
      );
      await StockCountLocalStore.shared.saveSession(completed);
      await StockCountLocalStore.shared.clearActive();
      await StockCountSummaryCache.shared.save(storeKey, summary);

      final source = ConnectivityService.shared.isOnline
          ? StockCountDataSource.live
          : StockCountDataSource.offlineStorage;

      state = StockCountState(
        lastSummary: summary,
        summarySource: source,
        isSyncing: false,
      );

      if (ConnectivityService.shared.isOnline) {
        await _applyAdjustments(completed);
        await StockCountLocalStore.shared.markSynced(completed.id);
      } else {
        await StockCountLocalStore.shared.enqueuePendingSync(completed.id);
      }
      return summary;
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
      return null;
    }
  }

  Future<void> _applyAdjustments(StockCountSession session) async {
    final inv = ref.read(inventoryProvider.notifier);
    final products = await _productsLookup();
    for (final line in session.lines) {
      if (line.variance == 0) continue;
      final product = products[line.productId];
      if (product == null) continue;
      await inv.updateProduct(
        product.copyWith(quantity: line.countedQuantity),
      );
    }
  }

  Future<Map<String, Product>> _productsLookup() async {
    final inv = ref.read(inventoryProvider).value;
    var list = inv?.products ?? <Product>[];
    if (list.isEmpty) {
      list = await InventorySqliteMirror.shared.readProductsOffline();
    }
    return {for (final p in list) p.id: p};
  }

  Future<void> _drainPendingSync() async {
    if (!ConnectivityService.shared.isOnline) return;
    final pending = StockCountLocalStore.shared.pendingSyncIds();
    if (pending.isEmpty) return;

    state = state.copyWith(isSyncing: true);
    for (final id in pending) {
      final session = StockCountLocalStore.shared.loadSession(id);
      if (session == null) continue;
      await _applyAdjustments(session);
      await StockCountLocalStore.shared.markSynced(id);
    }
    state = state.copyWith(isSyncing: false);
  }

  Future<void> abandonSession() async {
    final draftId = state.activeSession?.id;
    if (draftId != null) {
      await StockCountLocalStore.shared.discardDraftSession(draftId);
    }
    await StockCountLocalStore.shared.clearActive();
    state = const StockCountState();
  }
}

final stockCountProvider =
    NotifierProvider<StockCountNotifier, StockCountState>(
  StockCountNotifier.new,
);
