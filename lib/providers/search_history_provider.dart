import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/search_history_cache.dart';

/// Provider para obtener el historial de búsquedas de productos
final productSearchHistoryProvider =
    FutureProvider<List<SearchEntry>>((ref) async {
  return SearchHistoryCacheService.shared.getProductSearchHistory();
});

/// Provider para obtener el historial de categorías visitadas
final categoryBrowseHistoryProvider =
    FutureProvider<List<CategoryBrowseEntry>>((ref) async {
  return SearchHistoryCacheService.shared.getCategoryBrowseHistory();
});

/// Notifier para agregar búsquedas al historial
class ProductSearchHistoryNotifier {
  final WidgetRef ref;

  ProductSearchHistoryNotifier(this.ref);

  Future<void> addSearch(String query, {int resultCount = 0}) async {
    await SearchHistoryCacheService.shared
        .addProductSearch(query, resultCount: resultCount);
    ref.invalidate(productSearchHistoryProvider);
  }

  Future<void> removeSearch(String query) async {
    await SearchHistoryCacheService.shared.removeProductSearch(query);
    ref.invalidate(productSearchHistoryProvider);
  }

  Future<void> clearAll() async {
    await SearchHistoryCacheService.shared.clearSearchHistory();
    ref.invalidate(productSearchHistoryProvider);
  }
}

/// Notifier para categorías
class CategoryBrowseHistoryNotifier {
  final WidgetRef ref;

  CategoryBrowseHistoryNotifier(this.ref);

  Future<void> addCategoryBrowse(
    String categoryId,
    String categoryName, {
    int itemsInCategory = 0,
  }) async {
    await SearchHistoryCacheService.shared.addCategoryBrowse(
      categoryId,
      categoryName,
      itemsInCategory: itemsInCategory,
    );
    ref.invalidate(categoryBrowseHistoryProvider);
  }

  Future<void> clearAll() async {
    await SearchHistoryCacheService.shared.clearCategoryHistory();
    ref.invalidate(categoryBrowseHistoryProvider);
  }
}
