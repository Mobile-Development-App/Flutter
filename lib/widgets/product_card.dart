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
      case ProductCategory.beverages:    return AppColors.freshSky;
      case ProductCategory.dairy:        return AppColors.info;
      case ProductCategory.snacks:       return AppColors.warning;
      case ProductCategory.cleaning:     return AppColors.teaGreen;
      case ProductCategory.personalCare: return Colors.pink;
      case ProductCategory.grains:       return Colors.brown;
      case ProductCategory.fruits:       return AppColors.success;
      case ProductCategory.meat:         return AppColors.error;
      case ProductCategory.bakery:       return Colors.orange;
      case ProductCategory.frozen:       return AppColors.freshSky;
      case ProductCategory.condiments:   return Colors.red;
      case ProductCategory.other:        return AppColors.textSecondary;
    }
  }

  Color get _quantityColor {
    switch (product.stockStatus) {
      case StockStatus.inStock:    return AppColors.success;
      case StockStatus.lowStock:   return AppColors.warning;
      case StockStatus.outOfStock: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(isDark: isDark),
        child: Row(children: [
          // ── Product image or icon ──
          _ProductThumb(
            imageURL:      product.imageURL,
            categoryIcon:  product.category.icon,
            categoryColor: _categoryColor,
          ),
          const SizedBox(width: 12),
          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                const SizedBox(height: 2),
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
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.salePrice.currencyFormatted,
                      style: AppTypography.callout.copyWith(
                        fontSize: 13,
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
          const SizedBox(width: 10),
          // ── Quantity ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.quantity}',
                style: AppTypography.title3
                    .copyWith(fontSize: 18, color: _quantityColor),
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
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _ProductThumb — shows real image or category icon fallback
// ─────────────────────────────────────────────
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
    // Reset error flag if URL changes
    if (old.imageURL != widget.imageURL) {
      _imgFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color    = widget.categoryColor;
    final url      = widget.imageURL;
    final hasImage = url != null && url.isNotEmpty && !_imgFailed;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              url,
              fit: BoxFit.cover,
              // Show loading spinner while image loads
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
              // On error, mark as failed and show icon — no postFrameCallback needed
              errorBuilder: (_, __, ___) {
                if (!_imgFailed) {
                  // Use Future.microtask to avoid calling setState during build
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
