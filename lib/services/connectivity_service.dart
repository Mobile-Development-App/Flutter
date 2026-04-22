import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService shared = ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<bool> get onStatusChanged => _controller.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final current = await _connectivity.checkConnectivity();
    _setOnline(_hasConnection(current));

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _setOnline(_hasConnection(results));
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void _setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    _controller.add(value);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
