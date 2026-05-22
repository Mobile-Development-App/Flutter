import 'package:flutter/foundation.dart' show compute, kIsWeb;

import '../models/location_walk.dart';
import '../models/product.dart';

Future<R> _safeCompute<M, R>(R Function(M) callback, M message) {
  if (kIsWeb) return Future.value(callback(message));
  return compute(callback, message);
}

Map<String, dynamic> _isolateGroupAisles(List<Map<String, dynamic>> rows) {
  final sw = Stopwatch()..start();
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final r in rows) {
    final key = r['locationKey'] as String;
    buckets.putIfAbsent(key, () => []).add(r);
  }
  final aisles = <Map<String, dynamic>>[];
  for (final entry in buckets.entries) {
    var low = 0;
    final items = <Map<String, dynamic>>[];
    for (final r in entry.value) {
      if (r['lowStock'] as bool) low++;
      items.add({
        'id': r['productId'],
        'name': r['productName'],
        'quantity': r['quantity'],
        'lowStock': r['lowStock'],
      });
    }
    items.sort((a, b) =>
        (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ));
    aisles.add({
      'key': entry.key,
      'label': entry.value.first['locationLabel'] as String,
      'productCount': entry.value.length,
      'lowStockCount': low,
      'products': items,
    });
  }
  aisles.sort((a, b) {
    final c = (b['productCount'] as int).compareTo(a['productCount'] as int);
    if (c != 0) return c;
    return (a['label'] as String).compareTo(b['label'] as String);
  });
  sw.stop();
  return {'aisles': aisles, 'elapsedMs': sw.elapsedMilliseconds};
}

Map<String, dynamic> _isolateCountLowStock(List<Map<String, dynamic>> rows) {
  final sw = Stopwatch()..start();
  var n = 0;
  for (final r in rows) {
    if (r['lowStock'] as bool) n++;
  }
  sw.stop();
  return {'count': n, 'elapsedMs': sw.elapsedMilliseconds};
}

Map<String, dynamic> _isolateProductsCovered(
    Map<String, dynamic> payload) {
  final sw = Stopwatch()..start();
  final rows = payload['rows'] as List<Map<String, dynamic>>;
  final checked = (payload['checked'] as List<dynamic>).map((e) => e.toString()).toSet();
  var covered = 0;
  for (final r in rows) {
    if (checked.contains(r['locationKey'] as String)) covered++;
  }
  sw.stop();
  return {'covered': covered, 'elapsedMs': sw.elapsedMilliseconds};
}

Map<String, dynamic> _isolateUncheckedLowStock(
    Map<String, dynamic> payload) {
  final sw = Stopwatch()..start();
  final rows = payload['rows'] as List<Map<String, dynamic>>;
  final checked = (payload['checked'] as List<dynamic>).map((e) => e.toString()).toSet();
  var n = 0;
  for (final r in rows) {
    if (checked.contains(r['locationKey'] as String)) continue;
    if (r['lowStock'] as bool) n++;
  }
  sw.stop();
  return {'count': n, 'elapsedMs': sw.elapsedMilliseconds};
}

class LocationWalkProcessingService {
  LocationWalkProcessingService._();
  static final LocationWalkProcessingService shared =
      LocationWalkProcessingService._();

  static String _locationKey(String location) {
    final t = location.trim();
    if (t.isEmpty) return '__sin_ubicacion__';
    return t.toLowerCase();
  }

  static String _locationLabel(String location) {
    final t = location.trim();
    if (t.isEmpty) return 'Sin ubicación asignada';
    return t;
  }

  static List<Map<String, dynamic>> wireFromProducts(List<Product> products) =>
      products
          .where((p) => p.isActive)
          .map((p) => {
                'locationKey': _locationKey(p.location),
                'locationLabel': _locationLabel(p.location),
                'productId': p.id,
                'productName': p.name,
                'quantity': p.quantity,
                'lowStock': p.stockStatus != StockStatus.inStock,
              })
          .toList();

  Future<({List<LocationAisle> aisles, LocationWalkSummary summary})>
      buildPlan(
    List<Product> products, {
    List<String> checkedKeys = const [],
  }) async {
    final wire = wireFromProducts(products);
    if (wire.isEmpty) {
      return (
        aisles: const <LocationAisle>[],
        summary: const LocationWalkSummary(
          aisleCount: 0,
          checkedAisles: 0,
          productCount: 0,
          productsCovered: 0,
          lowStockSpotted: 0,
          computedIn: Duration.zero,
        ),
      );
    }

    final wall = Stopwatch()..start();
    final results = await Future.wait([
      _safeCompute(_isolateGroupAisles, wire),
      _safeCompute(_isolateCountLowStock, wire),
      _safeCompute(_isolateProductsCovered, {
        'rows': wire,
        'checked': checkedKeys,
      }),
      _safeCompute(_isolateUncheckedLowStock, {
        'rows': wire,
        'checked': checkedKeys,
      }),
    ]);
    wall.stop();

    final grouped = results[0];
    final aisleMaps = (grouped['aisles'] as List<dynamic>)
        .map((e) => LocationAisle.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();

    final checkedSet = checkedKeys.toSet();
    final checkedAisles =
        aisleMaps.where((a) => checkedSet.contains(a.key)).length;

    final summary = LocationWalkSummary(
      aisleCount: aisleMaps.length,
      checkedAisles: checkedAisles,
      productCount: wire.length,
      productsCovered: results[2]['covered'] as int,
      lowStockSpotted: results[3]['count'] as int,
      computedIn: wall.elapsed,
    );

    return (aisles: aisleMaps, summary: summary);
  }
}
