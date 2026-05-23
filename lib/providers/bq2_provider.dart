import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/stability_telemetry_service.dart';

/// BQ2 — Which app screens generate the most frequent crashes during
/// inventory updates?
class BQ2Dashboard {
  final List<CrashScreenInsight> screens;
  final int totalCrashes;
  final int limitDays;

  const BQ2Dashboard({
    required this.screens,
    required this.totalCrashes,
    this.limitDays = 30,
  });
}

class BQ2Notifier extends AsyncNotifier<BQ2Dashboard> {
  @override
  Future<BQ2Dashboard> build() async {
    await StabilityTelemetryService.shared.init();
    return _load();
  }

  Future<BQ2Dashboard> _load() async {
    const days = 30;
    final screens = await StabilityTelemetryService.shared
        .getInventoryCrashInsights(limitDays: days);
    final total = screens.fold<int>(0, (s, i) => s + i.crashCount);
    return BQ2Dashboard(
      screens: screens,
      totalCrashes: total,
      limitDays: days,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  /// Datos de prueba para validar la BQ2 en la viva sin esperar un crash real.
  Future<void> seedDemoData() async {
    const demos = [
      'stock_count',
      'stock_count',
      'scan',
      'productDetail',
      'scan',
      'location_walk',
    ];
    for (final s in demos) {
      await StabilityTelemetryService.shared.recordDemoCrash(s);
    }
    await refresh();
  }
}

final bq2Provider =
    AsyncNotifierProvider<BQ2Notifier, BQ2Dashboard>(BQ2Notifier.new);
