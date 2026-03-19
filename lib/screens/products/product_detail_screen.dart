import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'add_product_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState
    extends ConsumerState<ProductDetailScreen> {

  Color get _categoryColor {
    switch (widget.product.category) {
      case ProductCategory.beverages:
        return AppColors.freshSky;
      case ProductCategory.dairy:
        return AppColors.info;
      case ProductCategory.snacks:
        return AppColors.warning;
      case ProductCategory.cleaning:
        return AppColors.teaGreen;
      case ProductCategory.personalCare:
        return Colors.pink;
      case ProductCategory.grains:
        return Colors.brown;
      default:
        return AppColors.deepSpaceBlue;
    }
  }

  Color get _quantityColor {
    switch (widget.product.stockStatus) {
      case StockStatus.inStock:
        return AppColors.success;
      case StockStatus.lowStock:
        return AppColors.warning;
      case StockStatus.outOfStock:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final p = widget.product;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle del Producto'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_horiz_rounded),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Editar'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_rounded,
                      size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Eliminar',
                      style:
                          TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
            onSelected: (v) {
              if (v == 'edit') _showEdit(context);
              if (v == 'delete') _confirmDelete(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hero
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _categoryColor.withValues(alpha: 0.15),
                    _categoryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(p.category.icon,
                      size: 72, color: _categoryColor),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: StockBadge(status: p.stockStatus),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Title + badges
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: AppTypography.title.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      BadgeWidget(text: p.category.label),
                      BadgeWidget(
                          text: p.supplier,
                          style: BadgeStyle.secondary),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Alert banner
            if (p.stockStatus != StockStatus.inStock)
              _alertBanner(p, isDark),
            const SizedBox(height: 16),
            // Pricing grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _pricingCard('Precio de Venta',
                    p.salePrice.currencyFormatted,
                    Icons.label_rounded,
                    AppColors.deepSpaceBlue, isDark),
                _pricingCard('Cantidad',
                    '${p.quantity} uds',
                    Icons.inventory_2_rounded,
                    _quantityColor, isDark),
                _pricingCard('Precio de Costo',
                    p.costPrice.currencyFormatted,
                    Icons.monetization_on_outlined,
                    AppColors.textSecondary, isDark),
                _pricingCard(
                    'Margen',
                    p.profitMargin.percentFormatted,
                    Icons.percent_rounded,
                    p.profitMargin >= 20
                        ? AppColors.success
                        : AppColors.warning,
                    isDark),
              ],
            ),
            const SizedBox(height: 16),
            // Details
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detalles del Producto',
                      style: AppTypography.headline),
                  const SizedBox(height: 14),
                  _detailRow(Icons.qr_code_rounded, 'SKU',
                      p.sku, isDark),
                  _detailRow(Icons.barcode_reader, 'Código',
                      p.barcode, isDark),
                  _detailRow(Icons.location_on_outlined,
                      'Ubicación', p.location, isDark),
                  _detailRow(Icons.arrow_downward_rounded,
                      'Stock Mínimo', '${p.minStock} uds', isDark),
                  if (p.expirationDate != null)
                    _detailRow(
                      Icons.calendar_today_rounded,
                      'Fecha Vencimiento',
                      p.expirationDate!.shortFormatted,
                      isDark,
                      valueColor: p.isExpiringSoon
                          ? AppColors.warning
                          : null,
                    ),
                  _detailRow(Icons.update_rounded,
                      'Última Actualización',
                      p.lastUpdated.relativeFormatted, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Financial summary
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resumen Financiero',
                      style: AppTypography.headline),
                  const SizedBox(height: 14),
                  _financialRow(
                      'Valor en Stock (Venta)',
                      p.stockValue.currencyFormatted,
                      AppColors.success, isDark),
                  const Divider(height: 20),
                  _financialRow(
                      'Valor en Stock (Costo)',
                      p.costValue.currencyFormatted,
                      null, isDark),
                  const Divider(height: 20),
                  _financialRow(
                      'Ganancia Potencial',
                      (p.stockValue - p.costValue)
                          .currencyFormatted,
                      AppColors.teaGreen, isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showEdit(context),
                style: primaryButtonStyle,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar Producto'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(
                      color: AppColors.error, width: 1.5),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.delete_rounded),
                label: const Text('Eliminar Producto'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _alertBanner(Product p, bool isDark) {
    final isOut = p.stockStatus == StockStatus.outOfStock;
    final color = isOut ? AppColors.error : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
              isOut
                  ? Icons.cancel_rounded
                  : Icons.warning_rounded,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isOut ? 'Producto Agotado' : 'Stock Bajo',
                    style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600)),
                Text(
                    isOut
                        ? 'Este producto necesita reabastecimiento urgente'
                        : 'Solo quedan ${p.quantity} uds (mín: ${p.minStock})',
                    style: AppTypography.caption2.copyWith(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingCard(String title, String value, IconData icon,
      Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: AppTypography.title3.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(title,
              style: AppTypography.caption2
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      bool isDark,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(label,
              style: AppTypography.callout
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: AppTypography.callout.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor ??
                      (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _financialRow(String label, String value,
      Color? valueColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTypography.callout
                .copyWith(color: AppColors.textSecondary)),
        Text(value,
            style: AppTypography.headline.copyWith(
                color: valueColor ??
                    (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary))),
      ],
    );
  }

  void _showEdit(BuildContext context) {
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
          child: AddProductScreen(
              editingProduct: widget.product),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text(
            '¿Estás seguro de que deseas eliminar ${widget.product.name}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(inventoryProvider.notifier)
                  .deleteProduct(widget.product);
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close detail
            },
            child: Text('Eliminar',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
