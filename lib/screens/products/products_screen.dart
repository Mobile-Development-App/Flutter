import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/widgets.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() =>
      _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final invState = ref.watch(inventoryProvider).value;
    final products = invState?.filteredProducts ?? [];
    final filterCounts = invState?.filterCounts ?? {};
    final selectedFilter =
        invState?.selectedFilter ?? StockFilter.all;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddProduct(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AppSearchBar(
              controller: _searchCtrl,
              onChanged: (v) => ref
                  .read(inventoryProvider.notifier)
                  .setSearchText(v),
            ),
          ),
          // Filter tabs
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              children: StockFilter.values.map((f) {
                final isSelected = selectedFilter == f;
                final count = filterCounts[f] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(inventoryProvider.notifier)
                          .setFilter(f);
                      HapticManager.selection();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.deepSpaceBlue
                            : (isDark
                                ? AppColors.darkSurface
                                : AppColors.surface),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AppColors.border
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            f.label,
                            style: AppTypography.caption.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                      .withValues(alpha: 0.2)
                                  : (isDark
                                      ? AppColors
                                          .darkSurfaceSecondary
                                      : AppColors
                                          .surfaceSecondary),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: AppTypography.caption2
                                  .copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Product list
          Expanded(
            child: products.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No se encontraron productos',
                    description: (invState?.searchText.isEmpty ??
                            true)
                        ? 'No hay productos en esta categoría'
                        : 'No hay resultados para "${invState?.searchText}"',
                    actionTitle: 'Agregar Producto',
                    onAction: () => _showAddProduct(context),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        16, 4, 16, 100),
                    itemCount: products.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ProductCardRestockDaysV2(
                        product: products[i],
                        onTap: () => _showDetail(
                            context, products[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddProduct(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        maxChildSize: 0.95,
        builder: (_, __) => ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          child: const AddProductScreen(),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        maxChildSize: 0.95,
        builder: (_, __) => ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          child: ProductDetailScreen(product: product),
        ),
      ),
    );
  }
}
