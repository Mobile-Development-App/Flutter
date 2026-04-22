import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OfflineQueueService — Sprint 4 (Eventual Connectivity)
//
// RESPONSABILIDAD: Persistir operaciones CRUD que no pudieron enviarse al
// backend por falta de red y reintentarlas en orden FIFO cuando se recupere
// la conectividad.
//
// ALMACENAMIENTO: Hive box "pending_ops" (estrategia distinta a
// SharedPreferences ya usada en Sprint 2).  Cada entrada es un mapa JSON con:
//   id          — UUID v4, clave primaria en el box
//   type        — 'addProduct' | 'updateProduct' | 'deleteProduct' | 'recordSale'
//   payload     — JSON-encoded Map con los datos de la operación
//   enqueuedAt  — ISO-8601 timestamp
//   retryCount  — entero, incrementa en cada intento fallido
//
// POLÍTICA DE REINTENTOS: máximo 3 intentos por operación.  Si drainQueue()
// falla 3 veces en una op, la descarta y loggea un warning.
//
// USO:
//   await OfflineQueueService.shared.init();          // en main()
//   await OfflineQueueService.shared.enqueue(op);     // en InventoryNotifier
//   await OfflineQueueService.shared.drainQueue(fn);  // al reconectar
// ─────────────────────────────────────────────────────────────────────────────

/// Tipos de operación soportados por la cola.
enum OfflineOpType {
  addProduct,
  updateProduct,
  deleteProduct,
  recordSale,
}

/// Modelo de una operación pendiente.
class OfflineOperation {
  final String id;
  final OfflineOpType type;
  final Map<String, dynamic> payload;
  final DateTime enqueuedAt;
  final int retryCount;

  const OfflineOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.enqueuedAt,
    this.retryCount = 0,
  });

  // ── Serialización ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': jsonEncode(payload),
        'enqueuedAt': enqueuedAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory OfflineOperation.fromJson(Map<dynamic, dynamic> map) {
    return OfflineOperation(
      id: map['id'] as String,
      type: OfflineOpType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => OfflineOpType.addProduct,
      ),
      payload: Map<String, dynamic>.from(
          jsonDecode(map['payload'] as String) as Map),
      enqueuedAt: DateTime.parse(map['enqueuedAt'] as String),
      retryCount: (map['retryCount'] as int?) ?? 0,
    );
  }

  OfflineOperation withIncrementedRetry() => OfflineOperation(
        id: id,
        type: type,
        payload: payload,
        enqueuedAt: enqueuedAt,
        retryCount: retryCount + 1,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

/// Firma del ejecutor que InventoryNotifier debe proveer a drainQueue().
/// Recibe cada operación y debe lanzar excepción si falla.
typedef OpExecutor = Future<void> Function(OfflineOperation op);

class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService shared = OfflineQueueService._();

  static const _boxName = 'pending_ops';
  static const _maxRetries = 3;
  static const _uuid = Uuid();

  late Box<Map> _box;

  bool _initialized = false;

  /// Inicializa el box de Hive.  Llamar en main() tras Hive.initFlutter().
  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<Map>(_boxName);
    _initialized = true;
    debugPrint('[OfflineQueue] init — ${_box.length} ops pendientes');
  }

  // ── Escritura ──────────────────────────────────────────────────────────────

  /// Agrega una operación a la cola.
  Future<void> enqueue(OfflineOperation op) async {
    _assertInit();
    await _box.put(op.id, op.toJson());
    debugPrint('[OfflineQueue] enqueued ${op.type.name}  id=${op.id}  '
        'total=${_box.length}');
  }

  // ── Lectura ────────────────────────────────────────────────────────────────

  /// Lista de operaciones en orden de encolado (FIFO por enqueuedAt).
  List<OfflineOperation> get pendingOps {
    _assertInit();
    final ops = _box.values
        .map((m) => OfflineOperation.fromJson(m))
        .toList()
      ..sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    return ops;
  }

  int get pendingCount => _initialized ? _box.length : 0;

  // ── Drain ──────────────────────────────────────────────────────────────────

  /// Ejecuta las operaciones pendientes en orden FIFO usando [executor].
  ///
  /// - Si la operación se ejecuta con éxito → la elimina de la cola.
  /// - Si falla y retryCount < maxRetries → incrementa retryCount y persiste.
  /// - Si falla y retryCount >= maxRetries → descarta la operación.
  ///
  /// Retorna el número de operaciones procesadas exitosamente.
  Future<int> drainQueue(OpExecutor executor) async {
    _assertInit();
    final ops = pendingOps;
    if (ops.isEmpty) {
      debugPrint('[OfflineQueue] drainQueue — cola vacía, nada que procesar');
      return 0;
    }

    debugPrint('[OfflineQueue] drainQueue — procesando ${ops.length} ops');
    int successCount = 0;

    for (final op in ops) {
      try {
        await executor(op);
        await _box.delete(op.id);
        successCount++;
        debugPrint('[OfflineQueue] ✅ ${op.type.name} ejecutado  id=${op.id}');
      } catch (e) {
        final updated = op.withIncrementedRetry();
        if (updated.retryCount >= _maxRetries) {
          await _box.delete(op.id);
          debugPrint('[OfflineQueue] ❌ ${op.type.name} descartado tras '
              '$_maxRetries reintentos  id=${op.id}  error=$e');
        } else {
          await _box.put(op.id, updated.toJson());
          debugPrint('[OfflineQueue] ⚠️  ${op.type.name} reintento '
              '${updated.retryCount}/$_maxRetries  id=${op.id}  error=$e');
        }
      }
    }

    debugPrint('[OfflineQueue] drainQueue completado — '
        '$successCount/${ops.length} exitosos  '
        'pendientes restantes=${_box.length}');
    return successCount;
  }

  // ── Limpieza ───────────────────────────────────────────────────────────────

  /// Elimina todas las operaciones pendientes (útil al cerrar sesión).
  Future<void> clearAll() async {
    _assertInit();
    await _box.clear();
    debugPrint('[OfflineQueue] clearAll — cola vaciada');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _assertInit() {
    assert(_initialized, 'OfflineQueueService no inicializado — llama init()');
  }

  /// Crea un OfflineOperation con UUID auto-generado.
  static OfflineOperation createOp({
    required OfflineOpType type,
    required Map<String, dynamic> payload,
  }) {
    return OfflineOperation(
      id: _uuid.v4(),
      type: type,
      payload: payload,
      enqueuedAt: DateTime.now(),
    );
  }
}
