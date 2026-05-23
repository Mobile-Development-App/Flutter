import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../services/quick_scan_history_service.dart';
import '../../widgets/widgets.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';
import '../inventory/location_walk_screen.dart';
import '../inventory/stock_count_screen.dart';
// Sprint 3 — BQ5: screen session tracking
import '../../core/utils/screen_tracker_mixin.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() =>
      _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen>
    with ScreenTrackerMixin {

  @override
  String get trackedScreenName => 'products'; // BQ5
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(quickScanHistoryProvider);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final invState = ref.watch(inventoryProvider).value;
    final selectedFilter =
        invState?.selectedFilter ?? StockFilter.all;
    final scanHistoryAsync = ref.watch(quickScanHistoryProvider);
    final allProducts = invState?.products ?? <Product>[];
    final filterCounts = _buildFilterCounts(
      invState?.filterCounts ?? {},
      scanHistoryAsync.valueOrNull,
      allProducts,
    );
    final products = _resolveProductList(
      invState: invState,
      allProducts: allProducts,
      scanHistory: scanHistoryAsync.valueOrNull,
      selectedFilter: selectedFilter,
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Recorrido por ubicación',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocationWalkScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_rounded),
            tooltip: 'Conteo en góndola',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockCountScreen()),
            ),
          ),
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
              onChanged: (v) {
                ref
                    .read(inventoryProvider.notifier)
                    .setSearchText(v);
                // Cachear búsqueda si tiene contenido significativo
                if (v.trim().length >= 2) {
                  final notifier =
                      ProductSearchHistoryNotifier(ref);
                  notifier.addSearch(v.trim(),
                      resultCount:
                          (invState?.filteredProducts.length ??
                              0));
                }
              },
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
                      if (f == StockFilter.recentScans) {
                        ref.invalidate(quickScanHistoryProvider);
                      }
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
          if (selectedFilter == StockFilter.recentScans)
            _buildQuickScanChips(
              ref,
              context,
              scanHistoryAsync.valueOrNull ?? [],
              isDark,
            ),
          // Recent searches (only when search is empty)
          if ((invState?.searchText.isEmpty ?? true) &&
              selectedFilter != StockFilter.recentScans)
            _buildRecentSearches(ref, context),
          Expanded(
            child: selectedFilter == StockFilter.recentScans
                ? _buildRecentScansPanel(
                    context,
                    ref,
                    scanHistoryAsync,
                    allProducts,
                    isDark,
                  )
                : products.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No se encontraron productos',
                        description: (invState?.searchText.isEmpty ?? true)
                            ? 'No hay productos en esta categoría'
                            : 'No hay resultados para "${invState?.searchText}"',
                        actionTitle: 'Agregar Producto',
                        onAction: () => _showAddProduct(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: products.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ProductCardRestockDaysV2(
                            product: products[i],
                            onTap: () =>
                                _showDetail(context, products[i]),
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

  Map<StockFilter, int> _buildFilterCounts(
    Map<StockFilter, int> base,
    List<QuickScanEntry>? scans,
    List<Product> allProducts,
  ) {
    if (scans == null) {
      return {...base, StockFilter.recentScans: 0};
    }
    return {...base, StockFilter.recentScans: scans.length};
  }

  Widget _buildRecentScansPanel(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<QuickScanEntry>> scanHistoryAsync,
    List<Product> allProducts,
    bool isDark,
  ) {
    return scanHistoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (scans) {
        if (scans.isEmpty) {
          return EmptyState(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Sin escaneos recientes',
            description:
                'Ve a la pestaña Escanear (cámara en el centro), '
                'lee un código y vuelve aquí.',
            actionTitle: 'Ir a escanear',
            onAction: () {
              ref.read(inventoryProvider.notifier).setFilter(StockFilter.all);
              // El usuario usa el botón central de escaneo en la barra inferior.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Toca el ícono de cámara en la barra inferior'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(quickScanHistoryProvider);
            await ref.read(quickScanHistoryProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            itemCount: scans.length,
            itemBuilder: (_, i) {
              final scan = scans[i];
              final product = _productForScan(scan, allProducts);
              if (product != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ProductCardRestockDaysV2(
                    product: product,
                    onTap: () => _showDetail(context, product),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _UnlistedScanTile(
                  entry: scan,
                  isDark: isDark,
                  onTap: () => _openScanAddProduct(context, scan),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Product? _productForScan(QuickScanEntry scan, List<Product> allProducts) {
    if (scan.productId != null) {
      for (final p in allProducts) {
        if (p.id == scan.productId) return p;
      }
    }
    for (final p in allProducts) {
      if (p.barcode == scan.barcode) return p;
    }
    return null;
  }

  void _openScanAddProduct(BuildContext context, QuickScanEntry scan) {
    final prefilled = ScannedProductResult(
      name: scan.displayName,
      brand: '',
      category: ProductCategory.other,
      barcode: scan.barcode,
      suggestedPrice: 0,
      confidence: 50,
      isDuplicate: false,
      similarProducts: const [],
    );
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
          child: AddProductScreen(fromScan: prefilled),
        ),
      ),
    );
  }

  List<Product> _resolveProductList({
    required InventoryState? invState,
    required List<Product> allProducts,
    required List<QuickScanEntry>? scanHistory,
    required StockFilter selectedFilter,
  }) {
    if (invState == null) return [];
    if (selectedFilter != StockFilter.recentScans) {
      return invState.filteredProducts;
    }
    return _productsFromScans(
      scanHistory ?? [],
      allProducts,
      invState.searchText,
    );
  }

  List<Product> _productsFromScans(
    List<QuickScanEntry> scans,
    List<Product> allProducts,
    String? searchText,
  ) {
    final ordered = <Product>[];
    final seen = <String>{};
    for (final scan in scans) {
      Product? match;
      if (scan.productId != null) {
        for (final p in allProducts) {
          if (p.id == scan.productId) {
            match = p;
            break;
          }
        }
      }
      if (match == null) {
        for (final p in allProducts) {
          if (p.barcode == scan.barcode) {
            match = p;
            break;
          }
        }
      }
      if (match == null || seen.contains(match.id)) continue;
      seen.add(match.id);
      ordered.add(match);
    }
    if (searchText == null || searchText.isEmpty) return ordered;
    final q = searchText.toLowerCase();
    return ordered
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.barcode.contains(q))
        .toList();
  }

  Widget _buildQuickScanChips(
    WidgetRef ref,
    BuildContext context,
    List<QuickScanEntry> scans,
    bool isDark,
  ) {
    if (scans.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toca un escaneo para abrir el producto',
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: scans.length,
              itemBuilder: (_, i) {
                final s = scans[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      s.foundInInventory
                          ? Icons.check_circle_outline
                          : Icons.help_outline,
                      size: 16,
                      color: AppColors.freshSky,
                    ),
                    label: Text(
                      s.displayName,
                      style: AppTypography.caption2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      final inv = ref.read(inventoryProvider).value;
                      final product =
                          _productForScan(s, inv?.products ?? []);
                      if (product != null) {
                        _showDetail(context, product);
                      } else {
                        _openScanAddProduct(context, s);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(WidgetRef ref, BuildContext context) {
    final isDark = context.isDark;
    final searchHistoryAsync =
        ref.watch(productSearchHistoryProvider);

    return searchHistoryAsync.when(
      data: (searches) {
        if (searches.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Búsquedas recientes',
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final notifier =
                          ProductSearchHistoryNotifier(ref);
                      notifier.clearAll();
                    },
                    child: Text(
                      'Limpiar',
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.freshSky,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: searches.length,
                  itemBuilder: (_, i) {
                    final search = searches[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _searchCtrl.text = search.query;
                          ref
                              .read(inventoryProvider.notifier)
                              .setSearchText(search.query);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.freshSky
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 12,
                                color: AppColors.freshSky,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                search.query,
                                style:
                                    AppTypography.caption2
                                        .copyWith(
                                  color: isDark
                                      ? AppColors
                                          .darkTextPrimary
                                      : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _UnlistedScanTile extends StatelessWidget {
  final QuickScanEntry entry;
  final bool isDark;
  final VoidCallback onTap;

  const _UnlistedScanTile({
    required this.entry,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                color: AppColors.warning,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: AppTypography.callout.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'No está en inventario · ${entry.barcode}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Agregar',
                style: AppTypography.caption.copyWith(
                  color: AppColors.freshSky,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
