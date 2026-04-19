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

  void _generatePurchaseList(
      BuildContext context, List<Product> products, bool isDark) {
    final items = products.map((p) {
      final qty = int.tryParse(_ctrl(p).text) ?? 0;
      return _PurchaseItem(
        product: p,
        quantity: qty,
        estimatedCost: p.costPrice * qty,
      );
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,         // permite altura personalizada
      enableDrag: true,                  // swipe hacia abajo para cerrar
      isDismissible: true,               // tap en el scrim cierra el sheet
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseListSheet(items: items, isDark: isDark),
    );
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
                  _generatePurchaseList(context, restockNeeded, isDark),
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

}

// ─────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────
class _PurchaseItem {
  final Product product;
  final int quantity;
  final double estimatedCost;
  const _PurchaseItem({
    required this.product,
    required this.quantity,
    required this.estimatedCost,
  });
}

// ─────────────────────────────────────────────
// _PurchaseListSheet
// Modal bottom sheet standalone — stateless,
// se abre con showModalBottomSheet, se cierra
// con swipe o con el botón / Navigator.pop.
// ─────────────────────────────────────────────
class _PurchaseListSheet extends StatelessWidget {
  final List<_PurchaseItem> items;
  final bool isDark;

  const _PurchaseListSheet({
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total    = items.fold<double>(0.0, (s, i) => s + i.estimatedCost);
    final totalQty = items.fold<int>(0, (s, i) => s + i.quantity);
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      // Máximo 80 % de pantalla; se ajusta si hay pocos ítems
      constraints: BoxConstraints(maxHeight: screenH * 0.80),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.deepSpaceBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    size: 20,
                    color: AppColors.deepSpaceBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lista de Compra', style: AppTypography.headline),
                      Text(
                        '${items.length} productos · $totalQty unidades',
                        style: AppTypography.caption2
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Botón X para cerrar
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        AppColors.textTertiary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Total destacado ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.deepSpaceBlue, Color(0xFF0A4F84)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded,
                      color: AppColors.teaGreen, size: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Costo total estimado',
                        style: AppTypography.caption2
                            .copyWith(color: Colors.white60),
                      ),
                      Text(
                        total.currencyFormatted,
                        style: AppTypography.title3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // ── Lista scrollable ──────────────────────
          Flexible(
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No hay productos para mostrar.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _ItemRow(
                      item: items[i],
                      isDark: isDark,
                      isLast: i == items.length - 1,
                    ),
                  ),
          ),

          // ── Footer con botón cerrar ───────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Listo'),
                  style: primaryButtonStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _ItemRow — cada producto en la lista de compra
// ─────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final _PurchaseItem item;
  final bool isDark;
  final bool isLast;

  const _ItemRow({
    required this.item,
    required this.isDark,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = item.product.stockStatus == StockStatus.outOfStock
        ? AppColors.error
        : AppColors.warning;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: priorityColor.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            // Ícono de categoría
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.product.category.icon,
                size: 18,
                color: priorityColor,
              ),
            ),
            const SizedBox(width: 12),

            // Nombre y proveedor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: AppTypography.callout
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.product.supplier.isEmpty
                        ? item.product.sku
                        : item.product.supplier,
                    style: AppTypography.caption2
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Cantidad y costo
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.quantity} uds',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.estimatedCost.currencyFormatted,
                  style: AppTypography.caption2
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
