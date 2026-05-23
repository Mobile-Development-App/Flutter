import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class FeatureRequestRecord {
  final String id;
  final String title;
  final String normalizedTitle;
  final String accountId;
  final String accountLabel;
  final int submittedAtMs;

  const FeatureRequestRecord({
    required this.id,
    required this.title,
    required this.normalizedTitle,
    required this.accountId,
    required this.accountLabel,
    required this.submittedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'normalizedTitle': normalizedTitle,
        'accountId': accountId,
        'accountLabel': accountLabel,
        'submittedAtMs': submittedAtMs,
      };

  factory FeatureRequestRecord.fromJson(Map<String, dynamic> m) =>
      FeatureRequestRecord(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        normalizedTitle: m['normalizedTitle'] as String? ?? '',
        accountId: m['accountId'] as String? ?? '',
        accountLabel: m['accountLabel'] as String? ?? '',
        submittedAtMs: (m['submittedAtMs'] as num?)?.toInt() ?? 0,
      );
}

class FeatureRequestLocalStore {
  FeatureRequestLocalStore._();
  static final FeatureRequestLocalStore shared = FeatureRequestLocalStore._();

  static const _boxName = 'feature_requests_v1';
  static const _seedFlag = '__bq10_seeded__';
  static const _uuid = Uuid();

  late Box<String> _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox<String>(_boxName);
    _ready = true;
    await _seedCommunitySampleIfNeeded();
  }

  Future<void> insert(FeatureRequestRecord record) async {
    _assertReady();
    await _box.put(record.id, jsonEncode(record.toJson()));
  }

  List<FeatureRequestRecord> all() {
    _assertReady();
    final list = <FeatureRequestRecord>[];
    for (final key in _box.keys) {
      if (key == _seedFlag) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        list.add(FeatureRequestRecord.fromJson(
            jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return list;
  }

  Future<void> _seedCommunitySampleIfNeeded() async {
    if (_box.get(_seedFlag) == '1') return;
    final now = DateTime.now();
    final samples = <({String title, String accountId, String label, int daysAgo})>[
      (title: 'Exportar inventario a Excel', accountId: 'acct-norte-01', label: 'Minimarket Norte', daysAgo: 4),
      (title: 'Exportar inventario a Excel', accountId: 'acct-centro-02', label: 'Tienda Centro', daysAgo: 9),
      (title: 'Exportar inventario a Excel', accountId: 'acct-sur-03', label: 'Autoservicio Sur', daysAgo: 18),
      (title: 'Alertas por WhatsApp', accountId: 'acct-norte-01', label: 'Minimarket Norte', daysAgo: 6),
      (title: 'Alertas por WhatsApp', accountId: 'acct-oriente-04', label: 'Bodega Oriente', daysAgo: 11),
      (title: 'Alertas por WhatsApp', accountId: 'acct-centro-02', label: 'Tienda Centro', daysAgo: 22),
      (title: 'Modo oscuro en reportes', accountId: 'acct-sur-03', label: 'Autoservicio Sur', daysAgo: 3),
      (title: 'Modo oscuro en reportes', accountId: 'acct-oriente-04', label: 'Bodega Oriente', daysAgo: 14),
      (title: 'Escaneo masivo de varios productos', accountId: 'acct-norte-01', label: 'Minimarket Norte', daysAgo: 8),
      (title: 'Escaneo masivo de varios productos', accountId: 'acct-centro-02', label: 'Tienda Centro', daysAgo: 15),
      (title: 'Escaneo masivo de varios productos', accountId: 'acct-sur-03', label: 'Autoservicio Sur', daysAgo: 25),
      (title: 'Etiquetas con precio para impresora', accountId: 'acct-oriente-04', label: 'Bodega Oriente', daysAgo: 7),
      (title: 'Etiquetas con precio para impresora', accountId: 'acct-centro-02', label: 'Tienda Centro', daysAgo: 20),
      (title: 'Historial de cambios por empleado', accountId: 'acct-norte-01', label: 'Minimarket Norte', daysAgo: 12),
      (title: 'Sincronizar inventario entre sucursales', accountId: 'acct-sur-03', label: 'Autoservicio Sur', daysAgo: 5),
      (title: 'Sincronizar inventario entre sucursales', accountId: 'acct-oriente-04', label: 'Bodega Oriente', daysAgo: 17),
    ];

    for (final s in samples) {
      final normalized = _normalize(s.title);
      final record = FeatureRequestRecord(
        id: _uuid.v4(),
        title: s.title,
        normalizedTitle: normalized,
        accountId: s.accountId,
        accountLabel: s.label,
        submittedAtMs: now.subtract(Duration(days: s.daysAgo)).millisecondsSinceEpoch,
      );
      await _box.put(record.id, jsonEncode(record.toJson()));
    }
    await _box.put(_seedFlag, '1');
  }

  static String normalizeTitle(String raw) => _normalize(raw);

  static String _normalize(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void _assertReady() {
    assert(_ready, 'FeatureRequestLocalStore no inicializado');
  }
}
