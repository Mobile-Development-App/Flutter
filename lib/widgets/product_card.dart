import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/extensions.dart';
import '../models/product.dart';
import 'badge_widget.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  Color get _categoryColor {
    switch (product.category) {
      case ProductCategory.beverages:   return AppColors.freshSky;
      case ProductCategory.dairy:       return AppColors.info;
      case ProductCategory.snacks:      return AppColors.warning;
      case ProductCategory.cleaning:    return AppColors.teaGreen;
      case ProductCategory.personalCare:return Colors.pinkAccent;
      case ProductCategory.grains:      return const Color(0xFFB8860B);
      case ProductCategory.fruits:      return AppColors.success;
      case ProductCategory.meat:        return AppColors.error;
      case ProductCategory.bakery:      return Colors.orange;
      case ProductCategory.frozen:      return AppColors.freshSky;
      case ProductCategory.condiments:  return const Color(0xFFD84315);
      case ProductCategory.other:       return AppColors.textSecondary;
    }
  }

  Color get _quantityColor {
    switch (product.stockStatus) {
      case StockStatus.inStock:   return AppColors.success;
      case StockStatus.lowStock:  return AppColors.warning;
      case StockStatus.outOfStock:return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(isDark: isDark),
        child: Row(
          children: [
            _ProductThumb(
              imageURL: product.imageURL,
              categoryIcon: product.category.icon,
              categoryColor: _categoryColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + price row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: AppTypography.headline.copyWith(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product.salePrice.currencyFormatted,
                        style: AppTypography.callout.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // SKU + category
                  Text(
                    '${product.sku} · ${product.category.label}',
                    style: AppTypography.caption2.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Badges row
                  Row(
                    children: [
                      StockBadge(status: product.stockStatus),
                      const SizedBox(width: 6),
                      _MiniInsightChip(
                        icon: product.marginHealth.icon,
                        label: product.marginHealth.label,
                        color: product.marginHealth.color,
                      ),
                      const SizedBox(width: 6),
                      _MiniInsightChip(
                        icon: product.stockTrend.icon,
                        label: product.stockTrend.label,
                        color: product.stockTrend.color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Quantity pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _quantityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _quantityColor.withValues(alpha: 0.25),
                        width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${product.quantity}',
                        style: AppTypography.headline.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _quantityColor,
                        ),
                      ),
                      Text(
                        'uds',
                        style: AppTypography.overline.copyWith(
                          color: _quantityColor.withValues(alpha: 0.8),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInsightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniInsightChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.overline.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductThumb
// ─────────────────────────────────────────────────────────────────────────────
class _ProductThumb extends StatefulWidget {
  final String? imageURL;
  final IconData categoryIcon;
  final Color categoryColor;

  const _ProductThumb({
    required this.imageURL,
    required this.categoryIcon,
    required this.categoryColor,
  });

  @override
  State<_ProductThumb> createState() => _ProductThumbState();
}

class _ProductThumbState extends State<_ProductThumb> {
  bool _imgFailed = false;

  @override
  void didUpdateWidget(_ProductThumb old) {
    super.didUpdateWidget(old);
    if (old.imageURL != widget.imageURL) _imgFailed = false;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryColor;
    final url = widget.imageURL;
    final hasImage = url != null && url.isNotEmpty && !_imgFailed;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: color),
                  ),
                );
              },
              errorBuilder: (_, __, ___) {
                if (!_imgFailed) {
                  Future.microtask(() {
                    if (mounted) setState(() => _imgFailed = true);
                  });
                }
                return _icon(color);
              },
            )
          : _icon(color),
    );
  }

  Widget _icon(Color color) => Center(
        child: Icon(widget.categoryIcon, color: color, size: 24),
      );
}
