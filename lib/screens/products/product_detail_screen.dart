import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../providers/restock_latency_provider.dart';
import '../../widgets/app_card.dart';
import 'add_product_screen.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final analysis = product.smartAnalysis;
    final restockInfo = ref.watch(restockLatencyProvider(product.id));
    final restockDays = restockInfo.recommendedDays ??
        restockInfo.lastCycleDays ??
        restockInfo.averageDays;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle del Producto'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _heroSection(),
            const SizedBox(height: 16),
            _topMetrics(),
            const SizedBox(height: 16),

            /// 🔥 SMART FEATURE (NUEVO)
            _smartFeatureCard(analysis),

            if (product.stockStatus != StockStatus.inStock) ...[
              const SizedBox(height: 16),
              _restockBanner(product, restockDays, isDark),
            ],
            const SizedBox(height: 16),
            _detailsSection(),
            const SizedBox(height: 16),
            _financialSection(),
            const SizedBox(height: 20),
            _actions(context, ref),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HERO (imagen + nombre)
  // ─────────────────────────────────────────────
  Widget _heroSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 140,
            alignment: Alignment.center,
            child: Icon(
              product.category.icon,
              size: 60,
              color: AppColors.warning,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  product.name.toUpperCase(),
                  style: AppTypography.title,
                ),
                const SizedBox(height: 6),
                Text(
                  product.category.label,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MÉTRICAS PRINCIPALES (como tu imagen)
  // ─────────────────────────────────────────────
  Widget _topMetrics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Precio de Venta',
                product.salePrice.currencyFormatted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Cantidad',
                '${product.quantity} uds',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Precio de Costo',
                product.costPrice.currencyFormatted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Margen',
                product.profitMargin.percentFormatted,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, {Color? color}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTypography.title3.copyWith(
                color: color,
              )),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _smartFeatureCard(SmartProductAnalysis analysis) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Feature', style: AppTypography.headline),
          const SizedBox(height: 10),

          Text(
            analysis.headline,
            style: AppTypography.callout.copyWith(
              color: analysis.marginHealth.color,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            children: [
              _chip(
                product.marginHealth.label,
                product.marginHealth.icon,
                product.marginHealth.color,
              ),
              _chip(
                'Tendencia ${product.stockTrend.label}',
                product.stockTrend.icon,
                product.stockTrend.color,
              ),
              _chip(
                'Utilidad ${product.profitPerUnit.currencyFormatted}',
                Icons.attach_money,
                AppColors.success,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(analysis.message, style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _restockBanner(Product p, int? days, bool isDark) {
    final isOut = p.stockStatus == StockStatus.outOfStock;
    final color = isOut ? AppColors.error : AppColors.warning;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            isOut ? Icons.cancel_rounded : Icons.warning_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOut ? 'Producto Agotado' : 'Stock Bajo',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isOut
                      ? 'Este producto necesita reabastecimiento urgente'
                      : 'Solo quedan ${p.quantity} uds (mín: ${p.minStock})',
                  style: AppTypography.caption2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (days != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reabastecer en ~$days día${days == 1 ? '' : 's'}',
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalles del Producto', style: AppTypography.headline),
          const SizedBox(height: 10),
          _row('SKU', product.sku),
          _row('Código', product.barcode),
          _row('Ubicación', product.location),
          _row('Stock Mínimo', '${product.minStock} uds'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FINANCIERO
  // ─────────────────────────────────────────────
  Widget _financialSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen Financiero', style: AppTypography.headline),
          const SizedBox(height: 10),
          _row('Valor Venta', product.stockValue.currencyFormatted),
          _row('Valor Costo', product.costValue.currencyFormatted),
          _row('Ganancia', product.profitValue.currencyFormatted),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            final updated = await Navigator.push<Product>(
              context,
              MaterialPageRoute(
                builder: (_) => AddProductScreen(editingProduct: product),
              ),
            );

            if (updated != null) {
              ref.read(inventoryProvider.notifier).updateProduct(updated);
            }
          },
          child: const Text('Editar Producto'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () {
            ref.read(inventoryProvider.notifier).deleteProduct(product);
            Navigator.pop(context);
          },
          child: const Text('Eliminar Producto'),
        ),
      ],
    );
  }
}