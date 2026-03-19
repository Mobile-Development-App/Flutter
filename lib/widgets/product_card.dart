import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_theme.dart';
import '../models/product.dart';
import 'badge_widget.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  Color get _categoryColor {
    switch (product.category) {
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
      case ProductCategory.fruits:
        return AppColors.success;
      case ProductCategory.meat:
        return AppColors.error;
      case ProductCategory.bakery:
        return Colors.orange;
      case ProductCategory.frozen:
        return AppColors.freshSky;
      case ProductCategory.condiments:
        return Colors.red;
      case ProductCategory.other:
        return AppColors.textSecondary;
    }
  }

  Color get _quantityColor {
    switch (product.stockStatus) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(isDark: isDark),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(product.category.icon,
                  color: _categoryColor, size: 24),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTypography.headline.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        product.sku,
                        style: AppTypography.caption2.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: AppTypography.caption2.copyWith(
                            color: AppColors.textTertiary),
                      ),
                      Text(
                        product.category.label,
                        style: AppTypography.caption2.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${product.salePrice.toStringAsFixed(0)}',
                        style: AppTypography.callout.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      StockBadge(status: product.stockStatus),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Quantity
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.quantity}',
                  style: AppTypography.title3
                      .copyWith(color: _quantityColor),
                ),
                Text(
                  'uds',
                  style: AppTypography.caption2.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
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
