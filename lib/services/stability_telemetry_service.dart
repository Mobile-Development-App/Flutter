import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/inventory_workflow_screens.dart';

// Sprint 4 — BQ2: crashes durante actualizaciones de inventario.

class CrashScreenInsight {
  final String screenName;
  final int crashCount;
  final double sharePercent;

  const CrashScreenInsight({
    required this.screenName,
    required this.crashCount,
    required this.sharePercent,
  });
}

List<CrashScreenInsight> _aggregateInventoryCrashes(
    List<Map<String, dynamic>> rows) {
  final counts = <String, int>{};
  for (final row in rows) {
    final screen = row['screen_name'] as String? ?? 'unknown';
    if (row['inventory_update'] != true) continue;
    counts[screen] = (counts[screen] ?? 0) + 1;
  }
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) return [];

  return counts.entries
      .map((e) => CrashScreenInsight(
            screenName: e.key,
            crashCount: e.value,
            sharePercent: (e.value / total) * 100,
          ))
      .toList()
    ..sort((a, b) => b.crashCount.compareTo(a.crashCount));
}

class StabilityTelemetryService {
  StabilityTelemetryService._();
  static final StabilityTelemetryService shared = StabilityTelemetryService._();

  static const _boxName = 'stability_events_v1';

  bool _ready = false;
  String? _activeScreen;
  bool _handlersInstalled = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    await Hive.openBox<Map>(_boxName);
    _ready = true;
    debugPrint('[StabilityTelemetry] Hive listo');
  }

  Box<Map> get _box => Hive.box<Map>(_boxName);

  void setActiveScreen(String? screenName) {
    _activeScreen = screenName;
  }

  void installGlobalHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      recordEvent(
        errorType: 'flutter_error',
        message: details.exceptionAsString(),
        stackSnippet: details.stack?.toString(),
      );
      previousFlutter?.call(details);
    };

    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      recordEvent(
        errorType: 'unhandled_async',
        message: error.toString(),
        stackSnippet: stack.toString(),
      );
      return previousPlatform?.call(error, stack) ?? false;
    };
  }

  Future<void> recordEvent({
    required String errorType,
    required String message,
    String? stackSnippet,
    String? screenOverride,
    bool? inventoryUpdate,
  }) async {
    await init();
    final screen = screenOverride ?? _activeScreen ?? 'unknown';
    final duringInventory =
        inventoryUpdate ?? isInventoryUpdateScreen(screen);

    await _box.add({
      'screen_name': screen,
      'error_type': errorType,
      'message': message.length > 280 ? message.substring(0, 280) : message,
      'stack_snippet': stackSnippet != null && stackSnippet.length > 400
          ? stackSnippet.substring(0, 400)
          : stackSnippet,
      'inventory_update': duringInventory,
      'recorded_at': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint(
        '[StabilityTelemetry] $errorType @ $screen (inventory=$duringInventory)');
  }

  /// Registro de prueba para demo / viva (solo inventario).
  Future<void> recordDemoCrash(String screenName) async {
    await recordEvent(
      errorType: 'demo_crash',
      message: 'Simulación BQ2 — $screenName',
      screenOverride: screenName,
      inventoryUpdate: true,
    );
  }

  Future<List<CrashScreenInsight>> getInventoryCrashInsights({
    int limitDays = 30,
  }) async {
    await init();
    final cutoff = DateTime.now()
        .subtract(Duration(days: limitDays))
        .millisecondsSinceEpoch;
    final rows = _box.values
        .where((m) => (m['recorded_at'] as int) >= cutoff)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (kIsWeb) {
      return _aggregateInventoryCrashes(rows);
    }
    return compute(_aggregateInventoryCrashes, rows);
  }

  Future<int> getTotalInventoryCrashCount({int limitDays = 30}) async {
    final insights =
        await getInventoryCrashInsights(limitDays: limitDays);
    return insights.fold<int>(0, (s, i) => s + i.crashCount);
  }
}
