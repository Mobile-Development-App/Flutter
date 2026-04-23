import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/pipeline_logger.dart';
import '../services/data_processing_service.dart';
import '../core/utils/extensions.dart';
import 'inventory_provider.dart';

// ─────────────────────────────────────────────
// TimeRange
// ─────────────────────────────────────────────
enum TimeRange {
  week('7d', '7 días', 7),
  month('30d', '30 días', 30),
  quarter('90d', '90 días', 90),
  year('1a', '1 año', 365);

  const TimeRange(this.value, this.label, this.days);
  final String value;
  final String label;
  final int days;
}

// ─────────────────────────────────────────────
// AnalyticsState
// ─────────────────────────────────────────────
class AnalyticsState {
  final TimeRange selectedTimeRange;
  final List<SalesDataPoint> salesData;
  final List<StockLevelData> stockLevelData;
  final List<CategoryDistribution> categoryDistribution;
  final bool isExporting;
  final bool exportSuccess;
  final bool isLoading;
  final Map<PipelineStage, PipelineStageSummary> pipelineMetrics;

  const AnalyticsState({
    this.selectedTimeRange    = TimeRange.week,
    this.salesData            = const [],
    this.stockLevelData       = const [],
    this.categoryDistribution = const [],
    this.isExporting          = false,
    this.exportSuccess        = false,
    this.isLoading            = false,
    this.pipelineMetrics      = const {},
  });

  double get totalSales =>
      salesData.fold<double>(0.0, (s, p) => s + p.sales);

  double get averageDailySales =>
      salesData.isEmpty ? 0.0 : totalSales / salesData.length;

  int get totalOrders =>
      salesData.fold(0, (s, p) => s + p.orders);

  double get salesTrend {
    if (salesData.length < 2) return 0;
    final mid        = salesData.length ~/ 2;
    final firstHalf  = salesData.sublist(0, mid).fold<double>(0.0, (s, p) => s + p.sales);
    final secondHalf = salesData.sublist(mid).fold<double>(0.0, (s, p) => s + p.sales);
    if (firstHalf == 0) return 0;
    return ((secondHalf - firstHalf) / firstHalf) * 100;
  }

  AnalyticsState copyWith({
    TimeRange? selectedTimeRange,
    List<SalesDataPoint>? salesData,
    List<StockLevelData>? stockLevelData,
    List<CategoryDistribution>? categoryDistribution,
    bool? isExporting,
    bool? exportSuccess,
    bool? isLoading,
    Map<PipelineStage, PipelineStageSummary>? pipelineMetrics,
  }) =>
      AnalyticsState(
        selectedTimeRange:    selectedTimeRange    ?? this.selectedTimeRange,
        salesData:            salesData            ?? this.salesData,
        stockLevelData:       stockLevelData       ?? this.stockLevelData,
        categoryDistribution: categoryDistribution ?? this.categoryDistribution,
        isExporting:          isExporting          ?? this.isExporting,
        exportSuccess:        exportSuccess        ?? this.exportSuccess,
        isLoading:            isLoading            ?? this.isLoading,
        pipelineMetrics:      pipelineMetrics      ?? this.pipelineMetrics,
      );
}

// ─────────────────────────────────────────────
// _FirestoreSaleRecord — parsed raw Firestore doc
// ─────────────────────────────────────────────
class _FirestoreSaleRecord {
  final DateTime createdAt;
  final double totalAmount;
  final int quantity;

  const _FirestoreSaleRecord({
    required this.createdAt,
    required this.totalAmount,
    required this.quantity,
  });

  static _FirestoreSaleRecord? fromDoc(Map<String, dynamic> doc) {
    try {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) return null;

      // createdAt — Firestore timestampValue is ISO-8601 string
      DateTime createdAt = DateTime.now();
      final tsField = fields['createdAt'];
      if (tsField != null) {
        final tsVal = tsField['timestampValue'] as String?;
        if (tsVal != null) {
          createdAt = DateTime.tryParse(tsVal) ?? DateTime.now();
        } else {
          // epoch seconds stored as integerValue
          final intVal = tsField['integerValue'] ?? tsField['doubleValue'];
          if (intVal != null) {
            final secs = double.tryParse(intVal.toString()) ?? 0;
            createdAt = DateTime.fromMillisecondsSinceEpoch((secs * 1000).toInt());
          }
        }
      }

      // totalAmount
      double totalAmount = 0;
      final taField = fields['totalAmount'];
      if (taField != null) {
        final v = taField['integerValue'] ?? taField['doubleValue'] ?? taField['numberValue'];
        totalAmount = double.tryParse(v?.toString() ?? '0') ?? 0;
      }

      // quantity
      int quantity = 1;
      final qField = fields['quantity'];
      if (qField != null) {
        final v = qField['integerValue'] ?? qField['doubleValue'];
        quantity = (double.tryParse(v?.toString() ?? '1') ?? 1).toInt();
      }

      // fallback: unitPrice × quantity if totalAmount still 0
      if (totalAmount == 0) {
        final upField = fields['unitPrice'];
        if (upField != null) {
          final v = upField['integerValue'] ?? upField['doubleValue'];
          final unitPrice = double.tryParse(v?.toString() ?? '0') ?? 0;
          totalAmount = unitPrice * quantity;
        }
      }

      return _FirestoreSaleRecord(
        createdAt:   createdAt,
        totalAmount: totalAmount,
        quantity:    quantity,
      );
    } catch (e) {
      debugPrint('[FirestoreSaleRecord] parse error: $e');
      return null;
    }
  }
}

// ─────────────────────────────────────────────
// _Bucket — período acumulador
// ─────────────────────────────────────────────
class _Bucket {
  final String key;
  double totalAmount = 0;
  int count = 0;
  _Bucket(this.key);
}

// ─────────────────────────────────────────────
// AnalyticsNotifier
// ─────────────────────────────────────────────
class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  final _api        = ApiService.shared;
  final _processing = DataProcessingService.shared;
  final _pipeline   = PipelineLogger.shared;

  static const _kProjectId    = 'inventaria-app-ae5ce';
  static const _kFirestoreBase =
      'https://firestore.googleapis.com/v1/projects/$_kProjectId/databases/(default)/documents';

  @override
  Future<AnalyticsState> build() async {
    final sw = Stopwatch()..start();
    final invState     = ref.watch(inventoryProvider).value;
    final products     = invState?.products ?? [];
    final currentRange = state.valueOrNull?.selectedTimeRange ?? TimeRange.week;

    final sales       = await _fetchSalesFromFirestore(currentRange);
    final stockResult = _processing.aggregateStockByCategory(products);
    final catResult   = _processing.aggregateCategoryDistribution(products);

    debugPrint('[Analytics] build() — sales=${sales.length} '
        'stock=${stockResult.data.length} cat=${catResult.data.length}');

    final result = AnalyticsState(
      selectedTimeRange:    currentRange,
      salesData:            sales,
      stockLevelData:       stockResult.data,
      categoryDistribution: catResult.data,
      pipelineMetrics:      _pipeline.summary,
    );

    sw.stop();
    _pipeline.log(
      stage: PipelineStage.computation,
      operation: 'AnalyticsNotifier.build',
      recordCount: result.salesData.length + result.stockLevelData.length + result.categoryDistribution.length,
      latency: sw.elapsed,
    );

    return result;
  }

  // ─────────────────────────────────────────────
  // INGESTION: Firestore REST → saleRecords
  // Path: stores/{storeId}/saleRecords
  // Auth: Bearer {idToken}
  // ─────────────────────────────────────────────
  Future<List<SalesDataPoint>> _fetchSalesFromFirestore(TimeRange range) async {
    final storeId = _api.storeId;
    final idToken = _api.idToken;

    if (storeId == null || storeId.isEmpty) {
      debugPrint('[Analytics] ⚠️  storeId no disponible — sin ventas');
      return [];
    }

    debugPrint('[Analytics] Consultando Firestore '
        'stores/$storeId/saleRecords range=${range.value}');

    try {
      final records = await _fetchAllPages(storeId, idToken);
      debugPrint('[Analytics] Total saleRecords: ${records.length}');
      if (records.isEmpty) return [];

      // Filtrar por rango de fechas
      final now      = DateTime.now();
      final dateFrom = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: range.days));

      final filtered = records.where((r) => r.createdAt.isAfter(dateFrom)).toList();
      debugPrint('[Analytics] En rango ${range.value}: ${filtered.length} registros');

      return _aggregateByPeriod(filtered, range, now);
    } catch (e, st) {
      debugPrint('[Analytics] ❌ _fetchSalesFromFirestore: $e\n$st');
      return [];
    }
  }

  /// Obtiene todos los documentos con paginación (máx 300 por página)
  Future<List<_FirestoreSaleRecord>> _fetchAllPages(
      String storeId, String? idToken) async {
    final all     = <_FirestoreSaleRecord>[];
    String? token;
    const pageSize = 300;

    final headers = <String, String>{
      'Accept': 'application/json',
      if (idToken != null && idToken.isNotEmpty)
        'Authorization': 'Bearer $idToken',
    };

    do {
      final params = <String, String>{'pageSize': '$pageSize'};
      if (token != null) params['pageToken'] = token;

      final uri = Uri.parse('$_kFirestoreBase/stores/$storeId/saleRecords')
          .replace(queryParameters: params);

      debugPrint('[Analytics] Firestore GET $uri');
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('[Analytics] Firestore status: ${resp.statusCode}');

      if (resp.statusCode != 200) {
        debugPrint('[Analytics] Firestore error: '
            '${resp.body.substring(0, resp.body.length.clamp(0, 400))}');
        break;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final docs  = body['documents'] as List<dynamic>? ?? [];

      for (final doc in docs) {
        final r = _FirestoreSaleRecord.fromDoc(doc as Map<String, dynamic>);
        if (r != null) all.add(r);
      }

      token = body['nextPageToken'] as String?;
      debugPrint('[Analytics] Página: ${docs.length} docs '
          'nextPage=${token != null ? "sí" : "no"}');
    } while (token != null);

    return all;
  }

  // ─────────────────────────────────────────────
  // Agrupación por período → SalesDataPoint
  // ─────────────────────────────────────────────
  List<SalesDataPoint> _aggregateByPeriod(
    List<_FirestoreSaleRecord> records,
    TimeRange range,
    DateTime now,
  ) {
    final byDay   = range.days <= 30;
    final byWeek  = range.days <= 90 && !byDay;

    final buckets = <String, _Bucket>{};

    for (final r in records) {
      final String key;
      if (byDay) {
        key = '${r.createdAt.year}-'
            '${r.createdAt.month.toString().padLeft(2, '0')}-'
            '${r.createdAt.day.toString().padLeft(2, '0')}';
      } else if (byWeek) {
        final w = _isoWeek(r.createdAt);
        key = '${r.createdAt.year}-W${w.toString().padLeft(2, '0')}';
      } else {
        key = '${r.createdAt.year}-'
            '${r.createdAt.month.toString().padLeft(2, '0')}';
      }
      final b = buckets[key] ?? _Bucket(key);
      b.totalAmount += r.totalAmount;
      b.count       += 1;
      buckets[key]   = b;
    }

    // Si sólo hay 1 punto, fabricar uno anterior en 0 para que el gráfico se vea
    if (buckets.length == 1) {
      final existing = buckets.values.first;
      final existDate = _parsePeriodKey(existing.key, byDay, byWeek) ?? now;
      final prevDate  = byDay
          ? existDate.subtract(const Duration(days: 1))
          : byWeek
              ? existDate.subtract(const Duration(days: 7))
              : DateTime(existDate.year, existDate.month - 1, 1);
      final prevKey = _dateToKey(prevDate, byDay, byWeek);
      buckets.putIfAbsent(prevKey, () => _Bucket(prevKey));
    }

    final sorted = buckets.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted.map((b) {
      final date = _parsePeriodKey(b.key, byDay, byWeek) ?? now;
      return SalesDataPoint(
        id:     b.key,
        date:   date,
        sales:  b.totalAmount,
        orders: b.count,
      );
    }).toList();
  }

  String _dateToKey(DateTime d, bool byDay, bool byWeek) {
    if (byDay) {
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }
    if (byWeek) {
      return '${d.year}-W${_isoWeek(d).toString().padLeft(2,'0')}';
    }
    return '${d.year}-${d.month.toString().padLeft(2,'0')}';
  }

  int _isoWeek(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return ((d.difference(start).inDays + start.weekday - 1) / 7).ceil();
  }

  DateTime? _parsePeriodKey(String key, bool byDay, bool byWeek) {
    if (byDay) return DateTime.tryParse(key);
    if (byWeek) {
      final parts = key.split('-W');
      if (parts.length != 2) return null;
      final year = int.tryParse(parts[0]);
      final week = int.tryParse(parts[1]);
      if (year == null || week == null) return null;
      return DateTime(year, 1, 1).add(Duration(days: (week - 1) * 7));
    }
    // month: YYYY-MM
    return DateTime.tryParse('$key-01');
  }

  // ── Actions ───────────────────────────────

  Future<void> loadData(TimeRange range) async {
    final sw = Stopwatch()..start();
    _update((s) => s.copyWith(isLoading: true, selectedTimeRange: range));
    final invState = ref.read(inventoryProvider).value;
    final products = invState?.products ?? [];

    final sales       = await _fetchSalesFromFirestore(range);
    final stockResult = _processing.aggregateStockByCategory(products);
    final catResult   = _processing.aggregateCategoryDistribution(products);

    _update((s) => s.copyWith(
      isLoading:            false,
      selectedTimeRange:    range,
      salesData:            sales,
      stockLevelData:       stockResult.data,
      categoryDistribution: catResult.data,
      pipelineMetrics:      _pipeline.summary,
    ));
    sw.stop();
    _pipeline.log(
      stage: PipelineStage.computation,
      operation: 'AnalyticsNotifier.loadData',
      recordCount: sales.length + stockResult.data.length + catResult.data.length,
      latency: sw.elapsed,
    );
  }

  Future<void> refreshAll() async {
    final sw = Stopwatch()..start();
    debugPrint('[Analytics] Manual refresh');
    final range = state.valueOrNull?.selectedTimeRange ?? TimeRange.week;
    state = const AsyncLoading();
    final invState = ref.read(inventoryProvider).value;
    final products = invState?.products ?? [];
    final sales       = await _fetchSalesFromFirestore(range);
    final stockResult = _processing.aggregateStockByCategory(products);
    final catResult   = _processing.aggregateCategoryDistribution(products);
    debugPrint('[Analytics] refreshAll → sales=${sales.length}');
    state = AsyncData(AnalyticsState(
      selectedTimeRange:    range,
      salesData:            sales,
      stockLevelData:       stockResult.data,
      categoryDistribution: catResult.data,
      pipelineMetrics:      _pipeline.summary,
    ));
    sw.stop();
    _pipeline.log(
      stage: PipelineStage.computation,
      operation: 'AnalyticsNotifier.refreshAll',
      recordCount: sales.length + stockResult.data.length + catResult.data.length,
      latency: sw.elapsed,
    );
  }

  Future<void> exportReport() async {
    _update((s) => s.copyWith(isExporting: true));
    try {
      await _api.post('/exports', {
        'format': 'PDF',
        'dateRange': {
          'from': DateTime.now()
              .subtract(Duration(days: state.value?.selectedTimeRange.days ?? 7))
              .toIso8601String(),
          'to': DateTime.now().toIso8601String(),
        },
      });
      debugPrint('[Analytics] ✅ Export sent');
    } catch (e) {
      debugPrint('[Analytics] ⚠️  exportReport failed: $e');
    }
    await HapticManager.success();
    _update((s) => s.copyWith(isExporting: false, exportSuccess: true));
    await Future<void>.delayed(const Duration(seconds: 2));
    _update((s) => s.copyWith(exportSuccess: false));
  }

  void _update(AnalyticsState Function(AnalyticsState) fn) {
    final current = state.value;
    if (current != null) state = AsyncData(fn(current));
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
        AnalyticsNotifier.new);
