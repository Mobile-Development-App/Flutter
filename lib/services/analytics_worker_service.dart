import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'data_processing_service.dart';
import 'pipeline_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsWorkerService — Isolate persistente (worker vivo)
//
// Esto complementa el uso existente de compute() (isolate efímero).
// El worker se queda vivo y puede procesar múltiples requests sin respawn.
// ─────────────────────────────────────────────────────────────────────────────

enum _WorkerOp {
  stockByCategory,
  categoryDistribution,
}

class _WorkerResponse {
  final int id;
  final Object? data;
  final String? error;
  const _WorkerResponse({required this.id, this.data, this.error});
}

class AnalyticsWorkerService {
  AnalyticsWorkerService._();
  static final AnalyticsWorkerService shared = AnalyticsWorkerService._();

  final _logger = PipelineLogger.shared;

  Isolate? _isolate;
  SendPort? _send;
  ReceivePort? _receive;

  int _nextId = 1;
  final Map<int, Completer<_WorkerResponse>> _pending = {};

  bool get isInitialized => _send != null;

  Future<void> init() async {
    if (_send != null) return;

    final ready = ReceivePort();
    final recv = ReceivePort();

    _isolate = await Isolate.spawn<_IsolateBoot>(
      _workerMain,
      _IsolateBoot(ready.sendPort, recv.sendPort),
      debugName: 'analytics_worker',
    );

    _receive = recv;
    _receive!.listen((msg) {
      if (msg is Map) {
        final map = msg.cast<String, Object?>();
        final id = map['id'];
        if (id is! int) return;
        final c = _pending.remove(id);
        if (c == null) return;
        c.complete(
          _WorkerResponse(
            id: id,
            data: map['data'],
            error: map['error'] as String?,
          ),
        );
      }
    });

    final port = await ready.first;
    if (port is! SendPort) {
      throw StateError('Worker did not provide SendPort');
    }
    _send = port;
    debugPrint('[AnalyticsWorker] ✅ initialized');
  }

  Future<void> dispose() async {
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete(const _WorkerResponse(id: -1, error: 'disposed'));
      }
    }
    _pending.clear();
    _receive?.close();
    _receive = null;
    _send = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  Future<AggregationResult<List<StockLevelData>>> aggregateStockByCategoryWorker(
    List<Product> products,
  ) async {
    final sw = Stopwatch()..start();
    await init();

    final rows = products.map(_productToWire).toList();
    final raw = await _request(_WorkerOp.stockByCategory, rows);

    sw.stop();
    if (raw.error != null) {
      throw StateError(raw.error!);
    }

    final list = (raw.data as List).whereType<Map>().map((m) => m.cast<String, Object?>()).toList();
    final result = list
        .map((m) => StockLevelData(
              id: m['category'] as String,
              category: m['category'] as String,
              inStock: (m['inStock'] as int?) ?? 0,
              lowStock: (m['lowStock'] as int?) ?? 0,
              outOfStock: (m['outOfStock'] as int?) ?? 0,
            ))
        .toList();

    _logger.log(
      stage: PipelineStage.processing,
      operation: 'aggregateStockByCategory [worker-isolate]',
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

  Future<AggregationResult<List<CategoryDistribution>>> aggregateCategoryDistributionWorker(
    List<Product> products,
  ) async {
    final sw = Stopwatch()..start();
    await init();

    final rows = products.map(_productToWire).toList();
    final raw = await _request(_WorkerOp.categoryDistribution, rows);

    sw.stop();
    if (raw.error != null) {
      throw StateError(raw.error!);
    }

    final list = (raw.data as List).whereType<Map>().map((m) => m.cast<String, Object?>()).toList();
    final result = list
        .map((m) => CategoryDistribution(
              id: m['category'] as String,
              category: m['category'] as String,
              count: (m['count'] as int?) ?? 0,
              percentage: ((m['percentage'] as num?) ?? 0).toDouble(),
              value: 0,
            ))
        .toList();

    _logger.log(
      stage: PipelineStage.processing,
      operation: 'aggregateCategoryDistribution [worker-isolate]',
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

  // ───────────────────────────────────────────

  Future<_WorkerResponse> _request(_WorkerOp op, Object payload) async {
    final send = _send;
    if (send == null) throw StateError('Worker not initialized');
    final id = _nextId++;
    final c = Completer<_WorkerResponse>();
    _pending[id] = c;

    // El worker responde por el ReceivePort local (_receive).
    // Mandamos: {id, op, payload}
    send.send(<String, Object?>{
      'id': id,
      'op': op.name,
      'payload': payload,
    });

    return c.future.timeout(const Duration(seconds: 15));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolate code (top-level)
// ─────────────────────────────────────────────────────────────────────────────

class _IsolateBoot {
  final SendPort readyPort;
  final SendPort replyPort;
  const _IsolateBoot(this.readyPort, this.replyPort);
}

void _workerMain(_IsolateBoot boot) {
  final inbox = ReceivePort();
  boot.readyPort.send(inbox.sendPort);

  inbox.listen((msg) {
    if (msg is! Map) return;
    final map = msg.cast<String, Object?>();
    final id = map['id'];
    final opName = map['op'];
    final payload = map['payload'];
    if (id is! int || opName is! String) return;

    try {
      final op = _WorkerOp.values.firstWhere((e) => e.name == opName);
      final data = switch (op) {
        _WorkerOp.stockByCategory => _stockByCategory(payload),
        _WorkerOp.categoryDistribution => _categoryDistribution(payload),
      };
      boot.replyPort.send(<String, Object?>{'id': id, 'data': data});
    } catch (e) {
      boot.replyPort.send(<String, Object?>{'id': id, 'error': e.toString()});
    }
  });
}

List<Map<String, Object?>> _stockByCategory(Object? payload) {
  final rows = (payload as List).whereType<Map>().map((m) => m.cast<String, Object?>()).toList();
  final buckets = <String, Map<String, int>>{};
  for (final p in rows) {
    final category = (p['category'] as String?) ?? '—';
    final status = (p['stockStatus'] as String?) ?? '';
    buckets.putIfAbsent(category, () => {'inStock': 0, 'lowStock': 0, 'outOfStock': 0});
    if (status == StockStatus.inStock.name) {
      buckets[category]!['inStock'] = buckets[category]!['inStock']! + 1;
    } else if (status == StockStatus.lowStock.name) {
      buckets[category]!['lowStock'] = buckets[category]!['lowStock']! + 1;
    } else if (status == StockStatus.outOfStock.name) {
      buckets[category]!['outOfStock'] = buckets[category]!['outOfStock']! + 1;
    }
  }
  return buckets.entries
      .map((e) => <String, Object?>{
            'category': e.key,
            'inStock': e.value['inStock'],
            'lowStock': e.value['lowStock'],
            'outOfStock': e.value['outOfStock'],
          })
      .toList();
}

List<Map<String, Object?>> _categoryDistribution(Object? payload) {
  final rows = (payload as List).whereType<Map>().map((m) => m.cast<String, Object?>()).toList();
  final counts = <String, int>{};
  for (final p in rows) {
    final category = (p['category'] as String?) ?? '—';
    counts[category] = (counts[category] ?? 0) + 1;
  }
  final total = rows.length;
  final result = counts.entries
      .where((e) => e.value > 0)
      .map((e) => <String, Object?>{
            'category': e.key,
            'count': e.value,
            'percentage': total > 0 ? (e.value / total) * 100.0 : 0.0,
          })
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return result;
}

Map<String, Object?> _productToWire(Product p) => <String, Object?>{
      'category': p.category.label,
      'stockStatus': p.stockStatus.name,
    };

