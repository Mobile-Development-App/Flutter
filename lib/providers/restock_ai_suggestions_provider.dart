import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/openai_restock_suggestions_service.dart';
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
  final m = item.cast<String, dynamic>();

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

    // Local compute: identify products with 0 SALES in the window.
    const neverSoldDaysWindow = 30;
    final api = ApiService.shared;

    final allProducts = inv.products;
    final idsToCheck = <String>{};

    // Check restock-needed first, plus a small set of same-category high-profit candidates.
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
    // Fetch movements (sequential to avoid hammering the backend).
    for (final pid in idsToCheck) {
      try {
        final movements = await _fetchMovementsForProduct(api, pid);
        salesById[pid] = _salesQtyLastDays(movements, neverSoldDaysWindow);
      } catch (e) {
        debugPrint('[AI] movements fetch failed for $pid: $e');
        salesById[pid] = 0;
      }
    }

    final localCards = _buildLocalFallback(
      allProducts: allProducts,
      restockNeeded: restockNeeded,
      neverSoldDaysWindow: neverSoldDaysWindow,
      salesByProductId: salesById,
    );

    // OpenAI (ChatGPT) en el cliente — sin depender del backend.
    try {
      final payload = <String, dynamic>{
        'now': DateTime.now().toIso8601String(),
        'windowDays': neverSoldDaysWindow,
        'store': {'timezone': DateTime.now().timeZoneName},
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

      final rawMaps = await OpenAiRestockSuggestionsService.instance
          .fetchInsightCards(inventoryContext: payload);
      if (rawMaps.isNotEmpty) {
        final cards = rawMaps
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

    // Fallback: local heuristics.
    return RestockAiSuggestionsState(isAi: false, cards: localCards);
  } catch (e, st) {
    debugPrint('[AI] restock suggestions fatal: $e\n$st');
    return const RestockAiSuggestionsState(isAi: false, cards: []);
  }
});

