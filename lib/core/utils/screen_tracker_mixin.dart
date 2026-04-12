import 'package:flutter/widgets.dart';

import '../../services/usage_tracking_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScreenTrackerMixin
//
// Add to any ConsumerState / State to automatically record session time
// in SQLite for BQ5 analysis (peak business hour engagement).
//
// Usage:
//   class _HomeScreenState extends ConsumerState<HomeScreen>
//       with ScreenTrackerMixin {
//
//     @override
//     String get trackedScreenName => 'home';
//   }
//
// That's it — initState/dispose calls are handled by the mixin.
// ─────────────────────────────────────────────────────────────────────────────

mixin ScreenTrackerMixin<T extends StatefulWidget> on State<T> {
  /// Override to supply the canonical screen identifier.
  /// Use short lowercase keys: 'home', 'products', 'restock', 'analytics',
  /// 'scan', 'notifications', 'settings', 'sprint3Insights'.
  String get trackedScreenName;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  void _startTracking() {
    UsageTrackingService.shared.init().then((_) {
      UsageTrackingService.shared.trackScreenEnter(trackedScreenName);
    });
  }

  void _stopTracking() {
    // Fire-and-forget: dispose cannot be async, so we use unawaited
    UsageTrackingService.shared.trackScreenExit(trackedScreenName);
  }
}
