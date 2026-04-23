import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// connectivity_provider.dart — Sprint 4 (Streams)
//
// Responsabilidad:
//   • Exponer ConnectivityService.onConnectivityChanged como StreamProvider
//     con ciclo de vida correcto (suscripción + cancelación).
//   • Drenar OfflineQueueService automáticamente al recuperar conexión.
//
// PATRÓN DE SUSCRIPCIÓN CORRECTO:
//   Se usa StreamProvider.autoDispose en lugar de un StreamProvider plano para
//   que Riverpod cancele la suscripción cuando no haya listeners activos.
//   El stream de ConnectivityService es broadcast, así que múltiples
//   providers pueden escucharlo sin interferencia.
//
// INTEGRACIÓN CON OFFLINE QUEUE:
//   offlineQueueWatcherProvider escucha el mismo stream con una suscripción
//   explícita manejada con ref.onDispose, garantizando que se cancele al
//   destruir el provider.  Cuando detecta reconexión, notifica a
//   InventoryNotifier para que drene la cola usando su executor real.
// ─────────────────────────────────────────────────────────────────────────────

/// Estado de conectividad en tiempo real.
///
/// Uso en widget:
/// ```dart
/// final isOnline = ref.watch(connectivityProvider).value ?? true;
/// ```
///
/// Se inicializa con el estado actual del dispositivo (yield síncrono) y luego
/// emite cada transición online/offline a través del Stream del servicio.
///
/// `.autoDispose` garantiza que Riverpod cancele la escucha al stream cuando
/// no haya widgets activos observando este provider.
final connectivityProvider = StreamProvider.autoDispose<bool>((ref) async* {
  // Asegurar inicialización del servicio (idempotente si ya fue llamado).
  await ConnectivityService.shared.init();

  // Emitir estado sincrónico actual antes de cualquier evento del stream.
  yield ConnectivityService.shared.isOnline;

  // Delegar al stream del servicio. Riverpod cancela la suscripción
  // automáticamente en dispose gracias a .autoDispose.
  yield* ConnectivityService.shared.onConnectivityChanged;
});

// ─────────────────────────────────────────────────────────────────────────────
// Watcher: drena OfflineQueue al recuperar conectividad
// ─────────────────────────────────────────────────────────────────────────────

/// Proveedor que escucha cambios de conectividad y drena la OfflineQueue
/// automáticamente al reconectarse.
///
/// CÓMO USARLO:
///   1. Montar en un widget raíz que viva toda la sesión (ej: MainTabView):
///        @override
///        void initState() {
///          super.initState();
///          ref.read(offlineQueueWatcherProvider); // activa el watcher
///        }
///
///   2. El watcher llama a [OfflineQueueService.shared.drainQueue] pasando
///      un executor.  Provee el executor real desde InventoryNotifier
///      o registra un callback con [registerExecutor] antes de montar.
///
/// CANCELACIÓN: ref.onDispose cancela la StreamSubscription explícita,
/// evitando leaks aunque el widget se desmonte inesperadamente.
final offlineQueueWatcherProvider = Provider.autoDispose<void>((ref) {
  StreamSubscription<bool>? sub;

  sub = ConnectivityService.shared.onConnectivityChanged.listen(
    (isOnline) async {
      if (!isOnline) return;

      final queue = OfflineQueueService.shared;
      if (queue.pendingCount == 0) return;

      debugPrint('[QueueWatcher] Conexión recuperada — '
          '${queue.pendingCount} ops pendientes en cola');

      // Obtener el executor registrado (si existe).
      final executor = OfflineQueueExecutorRegistry.executor;
      if (executor == null) {
        debugPrint('[QueueWatcher] ⚠️ No hay executor registrado; '
            'la cola se drenará cuando InventoryNotifier registre uno');
        return;
      }

      final count = await queue.drainQueue(executor);
      debugPrint('[QueueWatcher] ✅ Cola drenada — $count ops ejecutadas');
    },
    onError: (Object e) {
      debugPrint('[QueueWatcher] error en stream: $e');
    },
  );

  // ── Cancelación correcta ──────────────────────────────────────────────────
  ref.onDispose(() {
    sub?.cancel();
    debugPrint('[QueueWatcher] dispose — StreamSubscription cancelada');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// OfflineQueueExecutorRegistry
//
// Registro simple para desacoplar el watcher de InventoryNotifier.
// InventoryNotifier llama a register() en su constructor; el watcher
// obtiene el executor cuando detecta reconexión.
// ─────────────────────────────────────────────────────────────────────────────

typedef Executor = Future<void> Function(OfflineOperation op);

class OfflineQueueExecutorRegistry {
  OfflineQueueExecutorRegistry._();

  static Executor? _executor;

  static void register(Executor executor) {
    _executor = executor;
    debugPrint('[QueueExecutorRegistry] executor registrado');
  }

  static void unregister() {
    _executor = null;
    debugPrint('[QueueExecutorRegistry] executor removido');
  }

  static Executor? get executor => _executor;
}
