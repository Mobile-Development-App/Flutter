import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityService — Sprint 4 (Eventual Connectivity)
//
// RESPONSABILIDAD: Detectar transiciones online/offline y exponerlas a través
// de un Stream para que OfflineQueueService e InventoryNotifier reaccionen.
//
// DISEÑO:
//   • Singleton `shared` — instancia única durante todo el ciclo de vida.
//   • init() suscribe al stream nativo de connectivity_plus y evalúa el estado
//     inicial del dispositivo.
//   • isOnline: bool — snapshot sincrónico legible en cualquier momento.
//   • onConnectivityChanged: Stream<bool> — emite true al conectarse,
//     false al desconectarse.  Usa StreamController.broadcast() para que
//     múltiples listeners puedan suscribirse (provider + queue service).
//
// NOTA: connectivity_plus puede reportar "connected" aunque el host real no sea
// alcanzable (red sin internet). Para este MVP consideramos la presencia de una
// interfaz de red activa como indicador suficiente de conectividad.
// ─────────────────────────────────────────────────────────────────────────────

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService shared = ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Estado actual de conectividad (snapshot sincrónico).
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Stream de transiciones: `true` = online, `false` = offline.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Inicializa el servicio.  Debe llamarse en main() antes de runApp().
  Future<void> init() async {
    // Evaluar estado inicial antes de suscribirse al stream.
    final initial = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(initial);
    debugPrint('[Connectivity] init — isOnline=$_isOnline  ($initial)');

    // Suscribirse a cambios futuros.
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final online = _isConnected(results);
        if (online == _isOnline) return; // sin cambio real
        _isOnline = online;
        debugPrint('[Connectivity] change → isOnline=$_isOnline');
        _controller.add(_isOnline);
      },
      onError: (Object e) {
        debugPrint('[Connectivity] stream error: $e');
      },
    );
  }

  /// Libera recursos. Llamar al cerrar la app (opcional en móvil).
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi    ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }
}
