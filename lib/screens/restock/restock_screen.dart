import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
// Sprint 3 — BQ5: screen session tracking
import '../../core/utils/screen_tracker_mixin.dart';

class RestockScreen extends ConsumerStatefulWidget {
  const RestockScreen({super.key});

  @override
  ConsumerState<RestockScreen> createState() =>
      _RestockScreenState();
}

class _RestockScreenState extends ConsumerState<RestockScreen>
    with ScreenTrackerMixin {

  @override
  String get trackedScreenName => 'restock'; // BQ5

  final Map<String, TextEditingController> _qtyControllers = {};
  bool _showPurchaseList = false;
  List<_PurchaseItem> _purchaseItems = [];

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(Product product) {
    return _qtyControllers.putIfAbsent(
      product.id,
      () => TextEditingController(
        text:
            '${(product.minStock - product.quantity).clamp(0, 9999)}',
      ),
    );
  }

  void _generatePurchaseList(List<Product> products) {
    _purchaseItems = products.map((p) {
      final qty = int.tryParse(_ctrl(p).text) ?? 0;
      return _PurchaseItem(
        product: p,
        quantity: qty,
        estimatedCost: p.costPrice * qty,
      );
    }).toList();
    setState(() => _showPurchaseList = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final invState = ref.watch(inventoryProvider).value;
    final restockNeeded = invState?.restockNeeded ?? [];
    final expiring = invState?.expiringProducts ?? [];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Reabastecimiento'),
        actions: [
          if (restockNeeded.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.assignment_rounded),
              onPressed: () =>
                  _generatePurchaseList(restockNeeded),
            ),
        ],
      ),
      body: restockNeeded.isEmpty && expiring.isEmpty
          ? EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Todo en orden',
              description:
                  'No hay productos que necesiten reabastecimiento en este momento.',
            )
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                children: [
                  _summaryCard(invState),
                  const SizedBox(height: 16),
                  if (restockNeeded.isNotEmpty) ...[
                    _restockSection(
                        restockNeeded, isDark),
                    const SizedBox(height: 16),
                  ],
                  if (expiring.isNotEmpty)
                    _expiringSection(expiring, isDark),
                ],
              ),
            ),
      bottomSheet: _showPurchaseList
          ? _purchaseListSheet(context, isDark)
          : null,
    );
  }

  Widget _summaryCard(invState) {
    final stats = invState?.dashboardStats;
    final aiAsync = ref.watch(restockAiSuggestionsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.deepSpaceBlue, AppColors.inkBlack],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.teaGreen, size: 20),
              const SizedBox(width: 8),
              Text('Sugerencias IA',
                  style: AppTypography.headline
                      .copyWith(color: Colors.white)),
              const Spacer(),
              BadgeWidget(
                text:
                    '${invState?.restockNeeded.length ?? 0} productos',
                style: BadgeStyle.warning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Basado en niveles de stock mínimo y velocidad de venta, estos productos necesitan reabastecimiento.',
            style: AppTypography.caption
                .copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryMetric(
                '${invState?.restockNeeded.length ?? 0}',
                'Por reabastecer',
                Icons.warning_rounded,
                AppColors.warning,
              ),
              _summaryMetric(
                '${invState?.expiringProducts.length ?? 0}',
                'Por vencer',
                Icons.access_time_rounded,
                AppColors.error,
              ),
              _summaryMetric(
                '${stats?.outOfStockCount ?? 0}',
                'Agotados',
                Icons.cancel_rounded,
                AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          aiAsync.when(
            loading: () => Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Analizando mejores decisiones...',
                  style: AppTypography.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
            error: (_, __) => Text(
              'No se pudo conectar a la IA. Mostrando sugerencias básicas.',
              style: AppTypography.caption.copyWith(color: Colors.white70),
            ),
            data: (s) {
              if (s.cards.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.isAi ? 'Recomendaciones IA' : 'Sugerencias',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...s.cards.take(3).map(
                    (c) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: c.isCritical ? 0.10 : 0.07,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: c.isCritical ? 0.20 : 0.12,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.body,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption2.copyWith(
                              color: Colors.white70,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.headline
                  .copyWith(color: Colors.white)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: Colors.white60),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _restockSection(
      List<Product> products, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Productos para Reabastecer',
                style: AppTypography.headline),
            Text('Prioridad',
                style: AppTypography.caption2
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        ...products.asMap().entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _restockCard(
                  e.value, e.key + 1, isDark),
            )),
      ],
    );
  }

  Widget _restockCard(
      Product product, int priority, bool isDark) {
    final ctrl = _ctrl(product);
    final priorityColor = priority == 1
        ? AppColors.error
        : priority <= 3
            ? AppColors.warning
            : AppColors.freshSky;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      priorityColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$priority',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTypography.callout.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.sku} | ${product.supplier}',
                      style: AppTypography.caption2.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.quantity}/${product.minStock}',
                    style: AppTypography.callout.copyWith(
                      fontWeight: FontWeight.w600,
                      color: product.stockStatus ==
                              StockStatus.outOfStock
                          ? AppColors.error
                          : AppColors.warning,
                    ),
                  ),
                  Text(
                    'actual/mín',
                    style: AppTypography.caption2.copyWith(
                        color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Cantidad a pedir:',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Container(
                width: 64,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceSecondary
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: AppTypography.callout,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  final qty =
                      int.tryParse(ctrl.text) ?? 0;
                  if (qty > 0) {
                    ref
                        .read(inventoryProvider.notifier)
                        .restockProduct(
                            product.id, qty);
                    ctrl.clear();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.teaGreen,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded,
                          size: 14,
                          color: AppColors.inkBlack),
                      const SizedBox(width: 4),
                      Text('Reabastecer',
                          style: AppTypography.caption2
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkBlack,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expiringSection(
      List<Product> products, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 6),
              Text('Próximos a Vencer',
                  style: AppTypography.headline),
            ],
          ),
          const SizedBox(height: 12),
          ...products.map((product) {
            final daysLeft = product.expirationDate
                    ?.difference(DateTime.now())
                    .inDays ??
                0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.warning
                          .withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: Icon(product.category.icon,
                        size: 16,
                        color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: AppTypography.caption
                                .copyWith(
                                    fontWeight:
                                        FontWeight.w500)),
                        Text(
                          'Vence en $daysLeft días',
                          style: AppTypography.caption2
                              .copyWith(
                            color: daysLeft <= 7
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${product.quantity} uds',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _purchaseListSheet(
      BuildContext context, bool isDark) {
    final total = _purchaseItems.fold<double>(
        0.0, (s, i) => s + i.estimatedCost);
    final totalQty =
        _purchaseItems.fold<int>(0, (s, i) => s + i.quantity);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Lista de Compra',
                    style: AppTypography.title),
                const SizedBox(height: 4),
                Text(total.currencyFormatted,
                    style: AppTypography.headline.copyWith(
                        color: AppColors.freshSky)),
                Text(
                    '${_purchaseItems.length} productos | $totalQty unidades',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16),
              itemCount: _purchaseItems.length,
              itemBuilder: (_, i) {
                final item = _purchaseItems[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name,
                                  style: AppTypography
                                      .callout.copyWith(
                                          fontWeight:
                                              FontWeight.w500)),
                              Text(item.product.supplier,
                                  style:
                                      AppTypography.caption2
                                          .copyWith(
                                              color: AppColors
                                                  .textSecondary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text('${item.quantity} uds',
                                style: AppTypography.callout
                                    .copyWith(
                                        fontWeight:
                                            FontWeight.w600)),
                            Text(
                                item.estimatedCost
                                    .currencyFormatted,
                                style:
                                    AppTypography.caption2
                                        .copyWith(
                                            color: AppColors
                                                .textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _showPurchaseList = false),
                    style: secondaryButtonStyle,
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseItem {
  final Product product;
  final int quantity;
  final double estimatedCost;
  const _PurchaseItem(
      {required this.product,
      required this.quantity,
      required this.estimatedCost});
}
