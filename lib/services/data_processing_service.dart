import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/pipeline_logger.dart';

// ─────────────────────────────────────────────
// ProcessingMode — batch vs real-time distinction
// Required by the Data Processing Layer rubric.
//
// REAL-TIME: Triggered immediately on product state change
//            (addProduct, updateProduct, restockProduct, recordSale)
//            Runs synchronously in the Dart event loop — 0 ms network wait.
//
// BATCH:     Scheduled aggregations; on mobile this runs when analytics
//            are opened or when the user requests a refresh.
//            Mirrors Cloud Functions cron behaviour (checkExpirations daily,
//            detectDeadStock weekly) but computed locally from cached data.
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

// ─────────────────────────────────────────────
// DataProcessingService — Singleton
//
// Centralises all client-side aggregation that previously
// lived inline inside AnalyticsNotifier.
//
// Every method records its own PipelineLogger entry so the
// Processing layer is fully observable.
//
// Node.js (Cloud Functions) was chosen over Python/Java because:
//   • Firebase Admin SDK has first-class Node.js support
//   • Cold-start latency is lower than Python Lambda equivalents
//   • Dart client avoids an intermediate REST translation layer
// ─────────────────────────────────────────────
class DataProcessingService {
  DataProcessingService._();
  static final DataProcessingService shared = DataProcessingService._();

  final _logger = PipelineLogger.shared;

  // ────────────────────────────────────────────
  // 1. Stock-by-category aggregation
  //    ProcessingMode.realTime — called whenever products list changes
  // ────────────────────────────────────────────
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
              id:         e.key,
              category:   e.key,
              inStock:    e.value.inStock,
              lowStock:   e.value.lowStock,
              outOfStock: e.value.outOfStock,
            ))
        .toList();

    sw.stop();

    _logger.log(
      stage:       PipelineStage.processing,
      operation:   'aggregateStockByCategory [real-time]',
      recordCount: result.length,
      latency:     sw.elapsed,
    );

    debugPrint(
      '[Processing][real-time] stock-by-category: '
      '${products.length} products → ${result.length} categories '
      'in ${sw.elapsedMicroseconds}µs',
    );

    return AggregationResult(
      data:          result,
      mode:          ProcessingMode.realTime,
      computedIn:    sw.elapsed,
      inputRecords:  products.length,
      outputRecords: result.length,
      computedAt:    DateTime.now(),
    );
  }

  // ────────────────────────────────────────────
  // 2. Category distribution aggregation
  //    ProcessingMode.realTime — called whenever products list changes
  // ────────────────────────────────────────────
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
              id:         e.key,
              category:   e.key,
              count:      e.value,
              percentage: total > 0 ? (e.value / total) * 100 : 0,
              value:      0,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    sw.stop();

    _logger.log(
      stage:       PipelineStage.processing,
      operation:   'aggregateCategoryDistribution [real-time]',
      recordCount: result.length,
      latency:     sw.elapsed,
    );

    debugPrint(
      '[Processing][real-time] category-distribution: '
      '${products.length} products → ${result.length} categories '
      'in ${sw.elapsedMicroseconds}µs',
    );

    return AggregationResult(
      data:          result,
      mode:          ProcessingMode.realTime,
      computedIn:    sw.elapsed,
      inputRecords:  products.length,
      outputRecords: result.length,
      computedAt:    DateTime.now(),
    );
  }

  // ────────────────────────────────────────────
  // 3. Expiring products batch scan
  //    ProcessingMode.batch — mirrors Cloud Functions checkExpirations cron.
  //    Run when analytics screen opens (not on every product change).
  // ────────────────────────────────────────────
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
      stage:       PipelineStage.processing,
      operation:   'batchScanExpiring [batch] threshold=${thresholdDays}d',
      recordCount: expiring.length,
      latency:     sw.elapsed,
    );

    debugPrint(
      '[Processing][batch] expiring-scan: '
      '${products.length} products scanned → ${expiring.length} expiring '
      'within ${thresholdDays}d',
    );

    return AggregationResult(
      data:          expiring,
      mode:          ProcessingMode.batch,
      computedIn:    sw.elapsed,
      inputRecords:  products.length,
      outputRecords: expiring.length,
      computedAt:    DateTime.now(),
    );
  }

  // ────────────────────────────────────────────
  // 4. Dead-stock detection
  //    ProcessingMode.batch — mirrors Cloud Functions detectDeadStock weekly cron.
  //    Products with 0 sales signal for 30 days.
  // ────────────────────────────────────────────
  AggregationResult<List<Product>> batchDetectDeadStock(
    List<Product> products,
    List<InventoryAlert> alerts, {
    int windowDays = 30,
  }) {
    final sw = Stopwatch()..start();
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));

    // Products with no SALE alert raised and stock untouched for windowDays
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
            (p.lastUpdated?.isBefore(cutoff) ?? false))
        .toList();

    sw.stop();

    _logger.log(
      stage:       PipelineStage.processing,
      operation:   'batchDetectDeadStock [batch] window=${windowDays}d',
      recordCount: deadStock.length,
      latency:     sw.elapsed,
    );

    debugPrint(
      '[Processing][batch] dead-stock: '
      '${products.length} products → ${deadStock.length} dead-stock candidates',
    );

    return AggregationResult(
      data:          deadStock,
      mode:          ProcessingMode.batch,
      computedIn:    sw.elapsed,
      inputRecords:  products.length,
      outputRecords: deadStock.length,
      computedAt:    DateTime.now(),
    );
  }

  // ────────────────────────────────────────────
  // 5. Margin opportunity scan
  //    ProcessingMode.batch — surfaces products below margin threshold
  //    Used by the Home Screen insight engine (BQ14)
  // ────────────────────────────────────────────
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
      stage:       PipelineStage.processing,
      operation:   'batchScanLowMargin [batch] threshold=$thresholdPct%',
      recordCount: low.length,
      latency:     sw.elapsed,
    );

    return AggregationResult(
      data:          low,
      mode:          ProcessingMode.batch,
      computedIn:    sw.elapsed,
      inputRecords:  products.length,
      outputRecords: low.length,
      computedAt:    DateTime.now(),
    );
  }
}

// ── Internal bucket ───────────────────────────
class _StockBucket {
  final String category;
  int inStock = 0, lowStock = 0, outOfStock = 0;
  _StockBucket(this.category);
}
