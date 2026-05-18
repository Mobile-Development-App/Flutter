import '../services/api_service.dart';
import 'cache/open_food_facts_cache.dart';

/// Lookup Open Food Facts con caché Hive (lib/storage).
class OpenFoodFactsLookup {
  OpenFoodFactsLookup._();

  static Future<Map<String, dynamic>?> lookup(String barcode) async {
    final cached = await OpenFoodFactsCache.shared.get(barcode);
    if (cached != null) return cached;

    try {
      final url =
          'https://world.openfoodfacts.org/api/v0/product/$barcode.json';
      final res = await ApiService.shared.getExternal(url);
      if (res == null) return null;
      final status = res['status'] as int? ?? 0;
      if (status != 1) return null;
      final p = res['product'] as Map<String, dynamic>?;
      if (p == null) return null;

      final data = {
        'name': p['product_name'] as String? ??
            p['product_name_es'] as String? ??
            '',
        'brand': p['brands'] as String? ?? '',
        'imageUrl': p['image_url'] as String?,
      };

      await OpenFoodFactsCache.shared.put(barcode, data);
      return data;
    } catch (_) {
      return null;
    }
  }
}
