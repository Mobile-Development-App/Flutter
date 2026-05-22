import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/location_walk.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/location_walk_processing_service.dart';
import '../storage/cache/location_walk_snapshot_cache.dart';
import '../storage/persistence/location_walk_local_store.dart';
import 'connectivity_provider.dart';
import 'inventory_provider.dart';

enum LocationWalkDataSource { live, cache, offlineStorage }

class LocationWalkState {
  final LocationWalkSession? activeSession;
  final LocationWalkSummary? lastSummary;
  final LocationWalkDataSource? summarySource;
  final bool isComputing;

  const LocationWalkState({
    this.activeSession,
    this.lastSummary,
    this.summarySource,
    this.isComputing = false,
  });

  LocationWalkState copyWith({
    LocationWalkSession? activeSession,
    LocationWalkSummary? lastSummary,
    LocationWalkDataSource? summarySource,
    bool? isComputing,
    bool clearSession = false,
  }) =>
      LocationWalkState(
        activeSession:
            clearSession ? null : (activeSession ?? this.activeSession),
        lastSummary: lastSummary ?? this.lastSummary,
        summarySource: summarySource ?? this.summarySource,
        isComputing: isComputing ?? this.isComputing,
      );
}

class LocationWalkNotifier extends Notifier<LocationWalkState> {
  var _initialized = false;

  @override
  LocationWalkState build() {
    ref.watch(connectivityProvider);
    if (!_initialized) {
      _initialized = true;
      Future.microtask(_bootstrap);
    }
    return const LocationWalkState();
  }

  Future<void> _bootstrap() async {
    await LocationWalkLocalStore.shared.init();
    await LocationWalkSnapshotCache.shared.init();
    final storeKey = ApiService.shared.storeId ?? 'default';

    LocationWalkSummary? summary;
    LocationWalkDataSource? source;

    final completed =
        LocationWalkLocalStore.shared.latestCompleted(storeKey);
    if (completed?.summary != null) {
      summary = completed!.summary;
      source = LocationWalkDataSource.offlineStorage;
    }

    summary ??= await LocationWalkSnapshotCache.shared.read(storeKey);
    source ??=
        summary != null ? LocationWalkDataSource.cache : null;

    var active = LocationWalkLocalStore.shared.activeSession();
    if (active != null) {
      final products = _products();
      if (products.isNotEmpty) {
        final plan = await LocationWalkProcessingService.shared.buildPlan(
          products,
          checkedKeys: active.checkedAisleKeys,
        );
        active = active.copyWith(
          aisles: plan.aisles,
          summary: plan.summary,
        );
        await LocationWalkLocalStore.shared.saveActive(active);
      }
    }
    state = LocationWalkState(
      activeSession: active,
      lastSummary: summary,
      summarySource: source,
    );
  }

  List<Product> _products() =>
      ref.read(inventoryProvider).value?.products ?? const [];

  Future<void> startWalk() async {
    final storeKey = ApiService.shared.storeId ?? 'default';
    state = state.copyWith(isComputing: true);
    final plan = await LocationWalkProcessingService.shared
        .buildPlan(_products());
    final session = LocationWalkSession(
      id: const Uuid().v4(),
      storeId: storeKey,
      startedAt: DateTime.now(),
      aisles: plan.aisles,
    );
    await LocationWalkLocalStore.shared.saveActive(session);
    state = LocationWalkState(
      activeSession: session,
      lastSummary: plan.summary,
      isComputing: false,
    );
  }

  Future<void> toggleAisle(String aisleKey) async {
    var session = state.activeSession;
    if (session == null) return;

    final keys = List<String>.from(session.checkedAisleKeys);
    if (keys.contains(aisleKey)) {
      keys.remove(aisleKey);
    } else {
      keys.add(aisleKey);
    }

    state = state.copyWith(isComputing: true);
    final plan = await LocationWalkProcessingService.shared.buildPlan(
      _products(),
      checkedKeys: keys,
    );

    session = session.copyWith(
      checkedAisleKeys: keys,
      aisles: plan.aisles,
      summary: plan.summary,
    );
    await LocationWalkLocalStore.shared.saveActive(session);
    state = LocationWalkState(
      activeSession: session,
      lastSummary: plan.summary,
      isComputing: false,
    );
  }

  Future<LocationWalkSummary?> finalizeWalk() async {
    final session = state.activeSession;
    if (session == null) return null;

    state = state.copyWith(isComputing: true);
    final plan = await LocationWalkProcessingService.shared.buildPlan(
      _products(),
      checkedKeys: session.checkedAisleKeys,
    );

    final completed = session.copyWith(
      aisles: plan.aisles,
      summary: plan.summary,
      completedAt: DateTime.now(),
    );

    await LocationWalkLocalStore.shared.saveCompleted(completed);
    final storeKey = session.storeId;
    await LocationWalkSnapshotCache.shared.save(storeKey, plan.summary);

    final source = ConnectivityService.shared.isOnline
        ? LocationWalkDataSource.live
        : LocationWalkDataSource.offlineStorage;

    state = LocationWalkState(
      lastSummary: plan.summary,
      summarySource: source,
      isComputing: false,
    );
    return plan.summary;
  }

  Future<void> abandonWalk() async {
    final session = state.activeSession;
    if (session != null) {
      await LocationWalkLocalStore.shared.discardDraft(session.id);
    }
    await LocationWalkLocalStore.shared.clearActive();
    state = LocationWalkState(
      lastSummary: state.lastSummary,
      summarySource: state.summarySource,
    );
  }
}

final locationWalkProvider =
    NotifierProvider<LocationWalkNotifier, LocationWalkState>(
  LocationWalkNotifier.new,
);
