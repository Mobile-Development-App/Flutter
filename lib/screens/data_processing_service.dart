import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/pipeline_logger.dart';

// ─────────────────────────────────────────────
// ProcessingMode — batch vs real-time distinction
// ─────────────────────────────────────────────
enum ProcessingMode { realTime, batch }

// ─────────────────────────────────────────────
// AggregationResult<T>
// ─────────────────────────────────────────────
class AggregationResult<T> {
  final T data;
  final ProcessingMode mode;
  final Duration computedIn;
  final int inputRecords;
  final int outputRecords;
  final DateTime computedAt;

  const AggregationResult({
    required this.data,
    required this.mode,
    required this.computedIn,
    required this.inputRecords,
    required this.outputRecords,
    required this.computedAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DTOs de transferencia para Isolates
//
// compute() serializa los argumentos mediante SendPort (paso por copia).
// Los modelos de dominio (Product, InventoryAlert) son demasiado ricos para
// mandarse directamente sin riesgo de errores de serialización. Se usan mapas
// planos como "wire format" entre el hilo UI y el Isolate.
// ─────────────────────────────────────────────────────────────────────────────

/// Wire-format para Product, incluye sólo los campos usados en agregaciones.
Map<String, dynamic> _productToMap(Product p) => {
      'id': p.id,
      'category': p.category.label,
      'stockStatus': p.stockStatus.name,
      'expirationDate': p.expirationDate?.toIso8601String(),
      'lastUpdated': p.lastUpdated.toIso8601String(),
      'isActive': p.isActive,
      'quantity': p.quantity,
      'profitMargin': p.profitMargin,
    };

/// Wire-format para InventoryAlert.
Map<String, dynamic> _alertToMap(InventoryAlert a) => {
      'productId': a.productId,
      'type': a.type.name,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Funciones top-level para compute()
//
// DEBEN ser top-level (o static). No pueden capturar estado del closure porque
// compute() las envía a un Isolate limpio sin acceso al heap del hilo principal.
// ─────────────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _isolateStockByCategory(
    List<Map<String, dynamic>> rows) {
  final buckets = <String, Map<String, int>>{};
  for (final p in rows) {
    final key = p['category'] as String;
    buckets.putIfAbsent(key, () => {'inStock': 0, 'lowStock': 0, 'outOfStock': 0});
    final status = p['stockStatus'] as String;
    if (status == StockStatus.inStock.name) {
      buckets[key]!['inStock'] = buckets[key]!['inStock']! + 1;
    } else if (status == StockStatus.lowStock.name) {
      buckets[key]!['lowStock'] = buckets[key]!['lowStock']! + 1;
    } else if (status == StockStatus.outOfStock.name) {
      buckets[key]!['outOfStock'] = buckets[key]!['outOfStock']! + 1;
    }
  }
  return buckets.entries
      .map((e) => {
            'category': e.key,
            'inStock': e.value['inStock'],
            'lowStock': e.value['lowStock'],
            'outOfStock': e.value['outOfStock'],
          })
      .toList();
}

List<Map<String, dynamic>> _isolateCategoryDistribution(
    List<Map<String, dynamic>> rows) {
  final counts = <String, int>{};
  for (final p in rows) {
    final key = p['category'] as String;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final total = rows.length;
  final result = counts.entries
      .where((e) => e.value > 0)
      .map((e) => {
            'category': e.key,
            'count': e.value,
            'percentage': total > 0 ? (e.value / total) * 100.0 : 0.0,
          })
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return result;
}

/// Payload tipado para batchScanExpiring (compute sólo acepta 1 argumento).
class _ExpiringPayload {
  final List<Map<String, dynamic>> rows;
  final int thresholdDays;
  const _ExpiringPayload(this.rows, this.thresholdDays);
}

List<Map<String, dynamic>> _isolateScanExpiring(_ExpiringPayload payload) {
  final cutoff = DateTime.now().add(Duration(days: payload.thresholdDays));
  final now = DateTime.now();
  return payload.rows
      .where((p) {
        final expStr = p['expirationDate'] as String?;
        if (expStr == null) return false;
        final exp = DateTime.parse(expStr);
        return exp.isAfter(now) && exp.isBefore(cutoff);
      })
      .toList()
    ..sort((a, b) {
      final da = DateTime.parse(a['expirationDate'] as String);
      final db = DateTime.parse(b['expirationDate'] as String);
      return da.compareTo(db);
    });
}

/// Payload tipado para batchDetectDeadStock.
class _DeadStockPayload {
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> alerts;
  final int windowDays;
  const _DeadStockPayload(this.products, this.alerts, this.windowDays);
}

List<Map<String, dynamic>> _isolateDetectDeadStock(_DeadStockPayload payload) {
  final cutoff = DateTime.now().subtract(Duration(days: payload.windowDays));
  final recentlyAlerted = payload.alerts
      .where((a) =>
          a['type'] == AlertType.lowStock.name ||
          a['type'] == AlertType.outOfStock.name)
      .map((a) => a['productId'] as String)
      .toSet();

  return payload.products.where((p) {
    final lastUpdStr = p['lastUpdated'] as String?;
    if (lastUpdStr == null) return false;
    final lastUpd = DateTime.parse(lastUpdStr);
    return (p['isActive'] as bool) &&
        (p['quantity'] as int) > 0 &&
        !recentlyAlerted.contains(p['id'] as String) &&
        lastUpd.isBefore(cutoff);
  }).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// DataProcessingService — Singleton
//
// Mantiene los métodos síncronos originales (usos internos ligeros) y agrega
// versiones *Async que delegan a un Isolate vía compute().
//
// REGLA DE USO:
//   • Listas pequeñas (<200 items) o contexto síncrono → método síncrono.
//   • Desde un provider/notifier con await o catálogos grandes → método *Async.
// ─────────────────────────────────────────────────────────────────────────────
class DataProcessingService {
  DataProcessingService._();
  static final DataProcessingService shared = DataProcessingService._();

  final _logger = PipelineLogger.shared;

  // ── 1. Stock-by-category ────────────────────────────────────────────────────

  AggregationResult<List<StockLevelData>> aggregateStockByCategory(
    List<Product> products,
  ) {
    final sw = Stopwatch()..start();
    final Map<String, _StockBucket> buckets = {};
    for (final p in products) {
      final key = p.category.label;
      buckets.putIfAbsent(key, () => _StockBucket(key));
      switch (p.stockStatus) {
        case StockStatus.inStock:
          buckets[key]!.inStock++;
        case StockStatus.lowStock:
          buckets[key]!.lowStock++;
        case StockStatus.outOfStock:
          buckets[key]!.outOfStock++;
      }
    }
    final result = buckets.entries
        .map((e) => StockLevelData(
              id: e.key,
              category: e.key,
              inStock: e.value.inStock,
              lowStock: e.value.lowStock,
              outOfStock: e.value.outOfStock,
            ))
        .toList();
    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'aggregateStockByCategory [real-time]',
      recordCount: result.length,
      latency: sw.elapsed,
    );
    return AggregationResult(
      data: result,
      mode: ProcessingMode.realTime,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: result.length,
      computedAt: DateTime.now(),
    );
  }

  /// Versión async — corre en Isolate separado vía compute().
  /// Usar en AnalyticsNotifier.loadData / refreshAll.
  Future<AggregationResult<List<StockLevelData>>> aggregateStockByCategoryAsync(
    List<Product> products,
  ) async {
    final sw = Stopwatch()..start();
    final rows = products.map(_productToMap).toList();

    final rawResult = await compute(_isolateStockByCategory, rows);

    final result = rawResult
        .map((m) => StockLevelData(
              id: m['category'] as String,
              category: m['category'] as String,
              inStock: m['inStock'] as int,
              lowStock: m['lowStock'] as int,
              outOfStock: m['outOfStock'] as int,
            ))
        .toList();

    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'aggregateStockByCategory [isolate]',
      recordCount: result.length,
      latency: sw.elapsed,
    );
    debugPrint(
      '[Processing][isolate] stock-by-category: '
      '${products.length} products → ${result.length} categories '
      'in ${sw.elapsedMilliseconds}ms',
    );
    return AggregationResult(
      data: result,
      mode: ProcessingMode.realTime,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: result.length,
      computedAt: DateTime.now(),
    );
  }

  // ── 2. Category distribution ────────────────────────────────────────────────

  AggregationResult<List<CategoryDistribution>> aggregateCategoryDistribution(
    List<Product> products,
  ) {
    final sw = Stopwatch()..start();
    final Map<String, int> counts = {};
    for (final p in products) {
      final key = p.category.label;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final total = products.length;
    final result = counts.entries
        .where((e) => e.value > 0)
        .map((e) => CategoryDistribution(
              id: e.key,
              category: e.key,
              count: e.value,
              percentage: total > 0 ? (e.value / total) * 100 : 0,
              value: 0,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'aggregateCategoryDistribution [real-time]',
      recordCount: result.length,
      latency: sw.elapsed,
    );
    return AggregationResult(
      data: result,
      mode: ProcessingMode.realTime,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: result.length,
      computedAt: DateTime.now(),
    );
  }

  /// Versión async — corre en Isolate separado vía compute().
  Future<AggregationResult<List<CategoryDistribution>>>
      aggregateCategoryDistributionAsync(
    List<Product> products,
  ) async {
    final sw = Stopwatch()..start();
    final rows = products.map(_productToMap).toList();

    final rawResult = await compute(_isolateCategoryDistribution, rows);

    final result = rawResult
        .map((m) => CategoryDistribution(
              id: m['category'] as String,
              category: m['category'] as String,
              count: m['count'] as int,
              percentage: (m['percentage'] as num).toDouble(),
              value: 0,
            ))
        .toList();

    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'aggregateCategoryDistribution [isolate]',
      recordCount: result.length,
      latency: sw.elapsed,
    );
    debugPrint(
      '[Processing][isolate] category-distribution: '
      '${products.length} products → ${result.length} categories '
      'in ${sw.elapsedMilliseconds}ms',
    );
    return AggregationResult(
      data: result,
      mode: ProcessingMode.realTime,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: result.length,
      computedAt: DateTime.now(),
    );
  }

  // ── 3. Expiring products batch scan ────────────────────────────────────────

  AggregationResult<List<Product>> batchScanExpiring(
    List<Product> products, {
    int thresholdDays = 30,
  }) {
    final sw = Stopwatch()..start();
    final cutoff = DateTime.now().add(Duration(days: thresholdDays));
    final expiring = products
        .where((p) =>
            p.expirationDate != null &&
            p.expirationDate!.isAfter(DateTime.now()) &&
            p.expirationDate!.isBefore(cutoff))
        .toList()
      ..sort((a, b) =>
          (a.expirationDate ?? DateTime(9999))
              .compareTo(b.expirationDate ?? DateTime(9999)));
    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'batchScanExpiring [batch] threshold=${thresholdDays}d',
      recordCount: expiring.length,
      latency: sw.elapsed,
    );
    return AggregationResult(
      data: expiring,
      mode: ProcessingMode.batch,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: expiring.length,
      computedAt: DateTime.now(),
    );
  }

  /// Versión async — corre en Isolate separado vía compute().
  Future<AggregationResult<List<Product>>> batchScanExpiringAsync(
    List<Product> products, {
    int thresholdDays = 30,
  }) async {
    final sw = Stopwatch()..start();
    final rows = products.map(_productToMap).toList();
    final payload = _ExpiringPayload(rows, thresholdDays);

    final rawResult = await compute(_isolateScanExpiring, payload);

    // Reconstruir objetos Product desde los IDs retornados
    final idSet = rawResult.map((m) => m['id'] as String).toSet();
    final result = products.where((p) => idSet.contains(p.id)).toList()
      ..sort((a, b) =>
          (a.expirationDate ?? DateTime(9999))
              .compareTo(b.expirationDate ?? DateTime(9999)));

    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'batchScanExpiring [isolate] threshold=${thresholdDays}d',
      recordCount: result.length,
      latency: sw.elapsed,
    );
    debugPrint(
      '[Processing][isolate] expiring-scan: '
      '${products.length} products → ${result.length} expiring '
      'in ${sw.elapsedMilliseconds}ms',
    );
    return AggregationResult(
      data: result,
      mode: ProcessingMode.batch,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: result.length,
      computedAt: DateTime.now(),
    );
  }

  // ── 4. Dead-stock detection ─────────────────────────────────────────────────

  AggregationResult<List<Product>> batchDetectDeadStock(
    List<Product> products,
    List<InventoryAlert> alerts, {
    int windowDays = 30,
  }) {
    final sw = Stopwatch()..start();
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    final recentlyAlerted = alerts
        .where((a) =>
            a.type == AlertType.lowStock || a.type == AlertType.outOfStock)
        .map((a) => a.productId)
        .toSet();
    final deadStock = products
        .where((p) =>
            p.isActive &&
            p.quantity > 0 &&
            !recentlyAlerted.contains(p.id) &&
            p.lastUpdated.isBefore(cutoff))
        .toList();
    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'batchDetectDeadStock [batch] window=${windowDays}d',
      recordCount: deadStock.length,
      latency: sw.elapsed,
    );
    return AggregationResult(
      data: deadStock,
      mode: ProcessingMode.batch,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: deadStock.length,
      computedAt: DateTime.now(),
    );
  }

  /// Versión async — corre en Isolate separado vía compute().
  Future<AggregationResult<List<Product>>> batchDetectDeadStockAsync(
    List<Product> products,
    List<InventoryAlert> alerts, {
    int windowDays = 30,
  }) async {
    final sw = Stopwatch()..start();
    final payload = _DeadStockPayload(
      products.map(_productToMap).toList(),
      alerts.map(_alertToMap).toList(),
      windowDays,
    );

    final rawResult = await compute(_isolateDetectDeadStock, payload);

    final idSet = rawResult.map((m) => m['id'] as String).toSet();
    final result = products.where((p) => idSet.contains(p.id)).toList();

    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'batchDetectDeadStock [isolate] window=${windowDays}d',
      recordCount: result.length,
      latency: sw.elapsed,
    );
    debugPrint(
      '[Processing][isolate] dead-stock: '
      '${products.length} products → ${result.length} dead-stock candidates '
      'in ${sw.elapsedMilliseconds}ms',
    );
    return AggregationResult(
      data: result,
      mode: ProcessingMode.batch,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: result.length,
      computedAt: DateTime.now(),
    );
  }

  // ── 5. Margin opportunity scan (sin cambios — ya es rápida) ─────────────────

  AggregationResult<List<Product>> batchScanLowMargin(
    List<Product> products, {
    double thresholdPct = 10.0,
  }) {
    final sw = Stopwatch()..start();
    final low = products
        .where((p) => p.isActive && p.profitMargin < thresholdPct)
        .toList()
      ..sort((a, b) => a.profitMargin.compareTo(b.profitMargin));
    sw.stop();
    _logger.log(
      stage: PipelineStage.processing,
      operation: 'batchScanLowMargin [batch] threshold=$thresholdPct%',
      recordCount: low.length,
      latency: sw.elapsed,
    );
    return AggregationResult(
      data: low,
      mode: ProcessingMode.batch,
      computedIn: sw.elapsed,
      inputRecords: products.length,
      outputRecords: low.length,
      computedAt: DateTime.now(),
    );
  }
}

// ── Internal bucket ───────────────────────────
class _StockBucket {
  final String category;
  int inStock = 0, lowStock = 0, outOfStock = 0;
  _StockBucket(this.category);
}
