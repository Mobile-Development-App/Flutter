import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_store_service.dart';

class PinnedProductsNotifier extends AsyncNotifier<Set<String>> {
  static const _storageKey = 'pinned_products';

  @override
  Future<Set<String>> build() async {
    return _loadPinnedIds();
  }

  Future<Set<String>> _loadPinnedIds() async {
    await LocalStoreService.shared.init();
    final data = await LocalStoreService.shared.getJson(_storageKey);
    final rawIds = data?['pinnedIds'];
    if (rawIds is! List) return <String>{};
    return rawIds.whereType<String>().toSet();
  }

  Future<void> toggle(String productId) async {
    final current = state.valueOrNull ?? <String>{};
    final next = Set<String>.from(current);
    if (!next.add(productId)) {
      next.remove(productId);
    }
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> setPinned(String productId, bool pinned) async {
    final current = state.valueOrNull ?? <String>{};
    final next = Set<String>.from(current);
    if (pinned) {
      next.add(productId);
    } else {
      next.remove(productId);
    }
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> clear() async {
    state = const AsyncData(<String>{});
    await LocalStoreService.shared.remove(_storageKey);
  }

  Future<void> _persist(Set<String> ids) async {
    await LocalStoreService.shared.setJson(
      _storageKey,
      {
        'pinnedIds': ids.toList()..sort(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }
}

final pinnedProductsProvider =
    AsyncNotifierProvider<PinnedProductsNotifier, Set<String>>(
  PinnedProductsNotifier.new,
);
