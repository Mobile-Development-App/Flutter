import 'package:flutter/foundation.dart';

import '../../services/local_file_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScanSessionFileStore — NUEVO requerimiento (archivos locales)
//
// Historial de escaneos en scan_history.json (dart:io + path_provider vía
// LocalFileService). Máximo 100 entradas.
// ─────────────────────────────────────────────────────────────────────────────

class ScanSessionEntry {
  final String barcode;
  final String? productName;
  final String? brand;
  final DateTime scannedAt;
  final bool foundInInventory;

  const ScanSessionEntry({
    required this.barcode,
    this.productName,
    this.brand,
    required this.scannedAt,
    required this.foundInInventory,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        if (productName != null) 'productName': productName,
        if (brand != null) 'brand': brand,
        'scannedAt': scannedAt.toIso8601String(),
        'foundInInventory': foundInInventory,
      };

  factory ScanSessionEntry.fromJson(Map<String, dynamic> json) =>
      ScanSessionEntry(
        barcode: json['barcode'] as String,
        productName: json['productName'] as String?,
        brand: json['brand'] as String?,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        foundInInventory: json['foundInInventory'] as bool? ?? false,
      );
}

class ScanSessionFileStore {
  ScanSessionFileStore._();
  static final ScanSessionFileStore shared = ScanSessionFileStore._();

  static const _fileName = 'scan_history.json';
  static const _maxEntries = 100;

  final _fs = LocalFileService.shared;

  Future<void> init() async {}

  Future<void> append(ScanSessionEntry entry) async {
    try {
      final raw = await _fs.readList(_fileName);
      final entries = raw.map(ScanSessionEntry.fromJson).toList()
        ..add(entry);
      final trimmed = entries.length > _maxEntries
          ? entries.sublist(entries.length - _maxEntries)
          : entries;
      await _fs.writeList(
        _fileName,
        trimmed.map((e) => e.toJson()).toList(),
      );
      debugPrint('[ScanFileStore] append ${entry.barcode}');
    } catch (e) {
      debugPrint('[ScanFileStore] append: $e');
    }
  }

  Future<List<ScanSessionEntry>> loadRecent({int limit = 20}) async {
    try {
      final raw = await _fs.readList(_fileName);
      final entries = raw.map(ScanSessionEntry.fromJson).toList();
      if (entries.length <= limit) return entries.reversed.toList();
      return entries.sublist(entries.length - limit).reversed.toList();
    } catch (e) {
      return [];
    }
  }
}
