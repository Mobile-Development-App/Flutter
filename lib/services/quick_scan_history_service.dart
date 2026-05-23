import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Sprint 4 — Últimos 10 escaneos rápidos (local storage / Hive).

class QuickScanEntry {
  final String barcode;
  final String? productId;
  final String displayName;
  final DateTime scannedAt;
  final bool foundInInventory;

  const QuickScanEntry({
    required this.barcode,
    this.productId,
    required this.displayName,
    required this.scannedAt,
    required this.foundInInventory,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'product_id': productId,
        'display_name': displayName,
        'scanned_at': scannedAt.millisecondsSinceEpoch,
        'found_in_inventory': foundInInventory,
      };

  factory QuickScanEntry.fromJson(Map<String, dynamic> m) => QuickScanEntry(
        barcode: m['barcode'] as String? ?? '',
        productId: m['product_id'] as String?,
        displayName: m['display_name'] as String? ?? '',
        scannedAt: DateTime.fromMillisecondsSinceEpoch(
          m['scanned_at'] as int? ?? 0,
        ),
        foundInInventory: m['found_in_inventory'] as bool? ?? false,
      );
}

class QuickScanHistoryService {
  QuickScanHistoryService._();
  static final QuickScanHistoryService shared = QuickScanHistoryService._();

  static const _boxName = 'quick_scan_history_v1';
  static const _maxEntries = 10;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    await Hive.openBox<Map>(_boxName);
    _ready = true;
    debugPrint('[QuickScanHistory] Hive listo');
  }

  Box<Map> get _box => Hive.box<Map>(_boxName);

  Future<void> record({
    required String barcode,
    String? productId,
    required String displayName,
    required bool foundInInventory,
  }) async {
    await init();
    await _box.add({
      'barcode': barcode,
      'product_id': productId,
      'display_name': displayName,
      'scanned_at': DateTime.now().millisecondsSinceEpoch,
      'found_in_inventory': foundInInventory,
    });
    while (_box.length > _maxEntries) {
      await _box.deleteAt(0);
    }
  }

  Future<List<QuickScanEntry>> getRecent() async {
    await init();
    final entries = _box.values
        .map((m) => QuickScanEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    entries.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return entries.take(_maxEntries).toList();
  }

  Future<void> clear() async {
    await init();
    await _box.clear();
  }
}
