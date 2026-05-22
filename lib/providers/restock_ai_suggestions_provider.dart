import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/openai_restock_service.dart';
import 'inventory_provider.dart';

class RestockAiSuggestionCard {
  final String title;
  final String body;
  final String? actionLabel;
  final String? actionRoute;
  final bool isCritical;

  const RestockAiSuggestionCard({
    required this.title,
    required this.body,
    this.actionLabel,
    this.actionRoute,
    this.isCritical = false,
  });
}

class RestockAiSuggestionsState {
  final bool isAi;
  final List<RestockAiSuggestionCard> cards;

  const RestockAiSuggestionsState({
    required this.isAi,
    required this.cards,
  });
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in ['cards', 'suggestions', 'data', 'items', 'results']) {
      final val = data[key];
      if (val is List) return val;
    }
  }
  return const [];
}

int _salesQtyLastDays(List<InventoryMovement> movements, int days) {
  if (movements.isEmpty) return 0;
  final cutoff = DateTime.now().subtract(Duration(days: days));
  return movements
      .where((m) => m.type == InventoryMovementType.sale && m.createdAt.isAfter(cutoff))
      .fold<int>(0, (s, m) => s + m.quantity.abs());
}

Future<List<InventoryMovement>> _fetchMovementsForProduct(
  ApiService api,
  String productId,
) async {
  final data = await api.get(
    kInventoryMovements,
    query: {'productId': productId},
  );

  List<dynamic> list;
  if (data is List) {
    list = data;
  } else if (data is Map<String, dynamic>) {
    list = (data['data'] as List?) ??
        (data['items'] as List?) ??
        (data['movements'] as List?) ??
        (data['results'] as List?) ??
        const [];
  } else {
    list = const [];
  }

  return list
      .whereType<Map>()
      .map((e) => InventoryMovement.fromBackendJson(e.cast<String, dynamic>()))
      .toList();
}

RestockAiSuggestionCard _buildReplacementCard({
  required Product neverSold,
  required List<Product> replacements,
  required int orderQtyForNeverSold,
}) {
  final replacementsText = replacements.take(2).map((p) => p.name).join(' y ');
  final critical = orderQtyForNeverSold > 0;

  return RestockAiSuggestionCard(
    isCritical: critical,
    title: 'Rotación para ${neverSold.name}',
    body: critical
        ? 'Este producto no registra ventas recientes. Propongo reemplazar parte del pedido por $replacementsText para mejorar ganancias.'
        : 'No registra ventas recientes. Si vas a pedir, considera reemplazar por $replacementsText.',
  );
}

List<RestockAiSuggestionCard> _buildLocalFallback({
  required List<Product> allProducts,
  required List<Product> restockNeeded,
  required int neverSoldDaysWindow,
  required Map<String, int> salesByProductId,
}) {
  final cards = <RestockAiSuggestionCard>[];

  // Only handle first few to keep the UI quick.
  final candidatesNeverSold = restockNeeded
      .where((p) => (salesByProductId[p.id] ?? 0) == 0)
      .toList()
    ..sort((a, b) => b.profitValue.compareTo(a.profitValue));

  for (final neverSold in candidatesNeverSold.take(3)) {
    final replacements = [...allProducts]
      ..retainWhere((p) =>
          p.isActive &&
          p.id != neverSold.id &&
          p.category == neverSold.category &&
          (salesByProductId[p.id] ?? 0) > 0)
      ..sort((a, b) => b.profitValue.compareTo(a.profitValue));

    final orderQty = (neverSold.minStock - neverSold.quantity).clamp(0, 999999);
    if (replacements.isEmpty) {
      cards.add(RestockAiSuggestionCard(
        isCritical: orderQty > 0,
        title: 'Revisar ${neverSold.name}',
        body: orderQty > 0
            ? 'No tiene ventas recientes. Antes de pedir, revisa precio/canal o reemplázalo por productos de la misma categoría con historial.'
            : 'No tiene ventas recientes. Podrías pausarlo o rotarlo por productos de la misma categoría con ventas.',
      ));
      continue;
    }

    cards.add(_buildReplacementCard(
      neverSold: neverSold,
      replacements: replacements.take(3).toList(),
      orderQtyForNeverSold: orderQty,
    ));
  }

  // If nothing is never-sold, give an optimization card.
  if (cards.isEmpty) {
    final top = [...restockNeeded]
      ..sort((a, b) => b.profitValue.compareTo(a.profitValue));
    if (top.isNotEmpty) {
      final p = top.first;
      final orderQty = (p.minStock - p.quantity).clamp(0, 999999);
      cards.add(RestockAiSuggestionCard(
        isCritical: orderQty > 0,
        title: 'Pedido inteligente',
        body: orderQty > 0
            ? 'Prioriza ${p.name}. Tiene alta ganancia potencial y está por debajo de su mínimo. Pedido sugerido: $orderQty uds.'
            : 'Tu inventario está razonablemente cubierto. Mantén el foco en productos con mejor ganancia por unidad.',
      ));
    }
  }

  return cards;
}

RestockAiSuggestionCard? _parseCardFromBackend(dynamic item) {
  if (item is! Map) return null;
  final m = Map<String, dynamic>.from(item);

  final title = (m['title'] ?? m['headline'] ?? m['name'])?.toString();
  final body = (m['body'] ?? m['description'] ?? m['message'])?.toString();

  if (title == null || title.isEmpty || body == null || body.isEmpty) {
    return null;
  }

  final isCritical = (m['isCritical'] ?? m['critical']) == true;
  return RestockAiSuggestionCard(
    title: title,
    body: body,
    actionLabel: (m['actionLabel'] ?? m['action'])?.toString(),
    actionRoute: (m['actionRoute'] ?? m['route'])?.toString(),
    isCritical: isCritical,
  );
}

/// Respuesta del backend `GET /restock/suggestions` (`restockAIService.ts`).
RestockAiSuggestionCard? _cardFromRestockApiRow(dynamic item) {
  if (item is! Map) return null;
  final m = Map<String, dynamic>.from(item);
  final name = m['productName']?.toString();
  if (name == null || name.isEmpty) return null;

  final qty = (m['suggestedQty'] is num)
      ? (m['suggestedQty'] as num).toInt()
      : int.tryParse('${m['suggestedQty']}') ?? 0;
  final current = (m['currentStock'] is num)
      ? (m['currentStock'] as num).toInt()
      : int.tryParse('${m['currentStock']}') ?? 0;
  final min = (m['minStock'] is num)
      ? (m['minStock'] as num).toInt()
      : int.tryParse('${m['minStock']}') ?? 0;
  final priority = (m['priority'] ?? '').toString().toUpperCase();
  final days = m['daysUntilStockout'];
  final daysStr = days == null
      ? 'sin proyección clara de agotamiento'
      : '~$days días con la venta actual';

  final cost = (m['estimatedCost'] is num)
      ? (m['estimatedCost'] as num).toDouble()
      : double.tryParse('${m['estimatedCost']}') ?? 0.0;

  final isCritical = priority == 'HIGH' ||
      current == 0 ||
      (days is num && days <= 3);

  final title = priority == 'HIGH'
      ? 'Prioridad alta: $name'
      : priority == 'MEDIUM'
          ? 'Reabastecer: $name'
          : 'Sugerencia: $name';

  final body = StringBuffer()
    ..write('Pedido sugerido: $qty uds. Stock $current / mínimo $min. ')
    ..write('Proyección: $daysStr.')
    ..write(cost > 0 ? ' Costo estimado aprox.: ${cost.toStringAsFixed(0)}.' : '');

  return RestockAiSuggestionCard(
    title: title,
    body: body.toString(),
    isCritical: isCritical,
  );
}

List<RestockAiSuggestionCard> _mergeBackendAndLocal(
  List<RestockAiSuggestionCard> backend,
  List<RestockAiSuggestionCard> local,
) {
  final out = <RestockAiSuggestionCard>[...backend.take(4)];
  for (final c in local) {
    if (out.length >= 6) break;
    if (!out.any((x) => x.title == c.title)) out.add(c);
  }
  return out;
}

Future<void> _fillSalesByProductId(
  ApiService api,
  Iterable<String> ids,
  int windowDays,
  Map<String, int> salesById,
) async {
  const concurrency = 4;
  final list = ids.toList();
  for (var i = 0; i < list.length; i += concurrency) {
    final chunk = list.skip(i).take(concurrency);
    await Future.wait(chunk.map((pid) async {
      try {
        final movements = await _fetchMovementsForProduct(api, pid);
        salesById[pid] = _salesQtyLastDays(movements, windowDays);
      } catch (e) {
        debugPrint('[AI] movements fetch failed for $pid: $e');
        salesById[pid] = 0;
      }
    }));
  }
}

Map<String, dynamic> _restockAiPayload({
  required int neverSoldDaysWindow,
  required List<Product> restockNeeded,
  required Map<String, int> salesById,
}) {
  return {
    'now': DateTime.now().toIso8601String(),
    'windowDays': neverSoldDaysWindow,
    'store': {
      'timezone': DateTime.now().timeZoneName,
    },
    'restockNeeded': restockNeeded.take(12).map((p) => {
          'id': p.id,
          'name': p.name,
          'sku': p.sku,
          'category': p.category.label,
          'quantity': p.quantity,
          'minStock': p.minStock,
          'profitMargin': p.profitMargin,
          'profitValue': p.profitValue,
        }).toList(),
    'salesByProductId': salesById,
  };
}

final restockAiSuggestionsProvider =
    FutureProvider.autoDispose<RestockAiSuggestionsState>((ref) async {
  try {
    final invAsync = ref.watch(inventoryProvider);
    final inv = invAsync.value;
    if (inv == null) {
      return const RestockAiSuggestionsState(isAi: false, cards: []);
    }

    final restockNeeded = inv.restockNeeded;
    if (restockNeeded.isEmpty) {
      return const RestockAiSuggestionsState(isAi: false, cards: []);
    }

    const neverSoldDaysWindow = 30;
    final api = ApiService.shared;
    final isOnline = ConnectivityService.shared.isOnline;

    final allProducts = inv.products;
    final idsToCheck = <String>{};

    for (final p in restockNeeded.take(6)) {
      idsToCheck.add(p.id);
      final candidates = allProducts
          .where((x) => x.isActive && x.category == p.category && x.id != p.id)
          .toList()
        ..sort((a, b) => b.profitValue.compareTo(a.profitValue));
      for (final c in candidates.take(6)) {
        idsToCheck.add(c.id);
      }
    }

    final salesById = <String, int>{};
    if (isOnline) {
      await _fillSalesByProductId(api, idsToCheck, neverSoldDaysWindow, salesById);
    }

    final localCards = _buildLocalFallback(
      allProducts: allProducts,
      restockNeeded: restockNeeded,
      neverSoldDaysWindow: neverSoldDaysWindow,
      salesByProductId: salesById,
    );

    if (!isOnline) {
      return RestockAiSuggestionsState(isAi: false, cards: localCards);
    }

    final payload = _restockAiPayload(
      neverSoldDaysWindow: neverSoldDaysWindow,
      restockNeeded: restockNeeded,
      salesById: salesById,
    );

    if (OpenAiRestockService.isConfigured) {
      try {
        final maps =
            await OpenAiRestockService.fetchSuggestionMaps(contextPayload: payload);
        if (maps != null && maps.isNotEmpty) {
          final cards = maps
              .map(_parseCardFromBackend)
              .whereType<RestockAiSuggestionCard>()
              .toList();
          if (cards.isNotEmpty) {
            return RestockAiSuggestionsState(isAi: true, cards: cards);
          }
        }
      } catch (e) {
        debugPrint('[AI] OpenAI suggestions failed: $e');
      }
    }

    try {
      // Backend: GET /restock/suggestions → { data: RestockSuggestion[] }
      final res = await api.get(kRestockSuggestions);
      final rawList = _extractList(res);

      final fromApiRows = rawList
          .map(_cardFromRestockApiRow)
          .whereType<RestockAiSuggestionCard>()
          .toList();

      final fromLegacyCards = rawList
          .map(_parseCardFromBackend)
          .whereType<RestockAiSuggestionCard>()
          .toList();

      if (fromApiRows.isNotEmpty) {
        final merged = _mergeBackendAndLocal(fromApiRows, localCards);
        return RestockAiSuggestionsState(isAi: true, cards: merged);
      }

      if (fromLegacyCards.isNotEmpty) {
        final merged = _mergeBackendAndLocal(fromLegacyCards, localCards);
        return RestockAiSuggestionsState(isAi: true, cards: merged);
      }

      if (res is Map) {
        final nested = _extractList(res['cards'] ?? res['suggestions']);
        final cards = nested
            .map(_parseCardFromBackend)
            .whereType<RestockAiSuggestionCard>()
            .toList();
        if (cards.isNotEmpty) {
          return RestockAiSuggestionsState(
            isAi: true,
            cards: _mergeBackendAndLocal(cards, localCards),
          );
        }
      }
    } catch (e) {
      debugPrint('[AI] backend restock suggestions failed: $e');
    }

    return RestockAiSuggestionsState(isAi: false, cards: localCards);
  } catch (e, st) {
    debugPrint('[AI] restock provider fatal: $e\n$st');
    final inv = ref.read(inventoryProvider).value;
    if (inv == null) {
      return const RestockAiSuggestionsState(isAi: false, cards: []);
    }
    final fallback = _buildLocalFallback(
      allProducts: inv.products,
      restockNeeded: inv.restockNeeded,
      neverSoldDaysWindow: 30,
      salesByProductId: const {},
    );
    return RestockAiSuggestionsState(isAi: false, cards: fallback);
  }
});

