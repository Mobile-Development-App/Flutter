import 'package:flutter/foundation.dart' show compute, kIsWeb;

import '../models/stock_count.dart';

Future<R> _safeCompute<M, R>(R Function(M) callback, M message) {
  if (kIsWeb) return Future.value(callback(message));
  return compute(callback, message);
}

Map<String, dynamic> _isolateMatchCount(List<Map<String, dynamic>> rows) {
  final sw = Stopwatch()..start();
  var n = 0;
  for (final r in rows) {
    if ((r['counted'] as int) == (r['system'] as int)) n++;
  }
  sw.stop();
  return {'count': n, 'elapsedMs': sw.elapsedMilliseconds};
}

Map<String, dynamic> _isolateOverCount(List<Map<String, dynamic>> rows) {
  final sw = Stopwatch()..start();
  var n = 0;
  for (final r in rows) {
    if ((r['counted'] as int) > (r['system'] as int)) n++;
  }
  sw.stop();
  return {'count': n, 'elapsedMs': sw.elapsedMilliseconds};
}

Map<String, dynamic> _isolateUnderCount(List<Map<String, dynamic>> rows) {
  final sw = Stopwatch()..start();
  var n = 0;
  for (final r in rows) {
    if ((r['counted'] as int) < (r['system'] as int)) n++;
  }
  sw.stop();
  return {'count': n, 'elapsedMs': sw.elapsedMilliseconds};
}

Map<String, dynamic> _isolateVarianceUnits(List<Map<String, dynamic>> rows) {
  final sw = Stopwatch()..start();
  var total = 0;
  for (final r in rows) {
    final d = (r['counted'] as int) - (r['system'] as int);
    total += d.abs();
  }
  sw.stop();
  return {'total': total, 'elapsedMs': sw.elapsedMilliseconds};
}

class StockCountProcessingService {
  StockCountProcessingService._();
  static final StockCountProcessingService shared =
      StockCountProcessingService._();

  static List<Map<String, dynamic>> wireFromLines(List<StockCountLine> lines) =>
      lines
          .map((l) => {
                'system': l.systemQuantity,
                'counted': l.countedQuantity,
              })
          .toList();

  Future<StockCountSummary> analyse(List<StockCountLine> lines) async {
    final wire = wireFromLines(lines);
    if (wire.isEmpty) {
      return const StockCountSummary(
        matchCount: 0,
        overCount: 0,
        underCount: 0,
        totalVarianceUnits: 0,
        computedIn: Duration.zero,
      );
    }

    final wall = Stopwatch()..start();
    final results = await Future.wait([
      _safeCompute(_isolateMatchCount, wire),
      _safeCompute(_isolateOverCount, wire),
      _safeCompute(_isolateUnderCount, wire),
      _safeCompute(_isolateVarianceUnits, wire),
    ]);
    wall.stop();

    return StockCountSummary(
      matchCount: results[0]['count'] as int,
      overCount: results[1]['count'] as int,
      underCount: results[2]['count'] as int,
      totalVarianceUnits: results[3]['total'] as int,
      computedIn: wall.elapsed,
    );
  }
}
