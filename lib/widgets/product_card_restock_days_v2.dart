// ─────────────────────────────────────────────────────────────────────────────
// product_card_restock_days_v2.dart — Sprint 4 [cached_network_image]
//
// CAMBIO: _ProductThumb ahora usa CachedNetworkImage en lugar de Image.network.
//
// BENEFICIOS:
//   • Las imágenes de producto se almacenan en disco tras la primera carga.
//   • En reconexión o scroll rápido no se re-descarga la imagen.
//   • Funciona en modo offline si la imagen ya fue cacheada previamente.
//   • Elimina el StatefulWidget _ProductThumb — CachedNetworkImage maneja
//     su propio estado de error/loading internamente.
//
// DEPENDENCIA:  cached_network_image: ^3.x  (agregar a pubspec.yaml)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget público
// ─────────────────────────────────────────────────────────────────────────────

class ProductCardRestockDaysV2 extends ConsumerWidget {
  const ProductCardRestockDaysV2({
    super.key,
    required this.product,
    this.onTap,
  });

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final cat = product.category;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // ── Thumbnail con cache ──────────────────────────────────────────
            _ProductThumb(
              imageURL: product.imageURL,
              categoryIcon: cat.icon,
              categoryColor: cat.color,
            ),
            const SizedBox(width: 12),

            // ── Datos del producto ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.sku,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StockBadge(product: product, isDark: isDark),
                ],
              ),
            ),

            // ── Chevron ──────────────────────────────────────────────────────
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductThumb — CachedNetworkImage + fallback de ícono
//
// ANTES: StatefulWidget con Image.network + bool _imgFailed + setState.
// AHORA: StatelessWidget — CachedNetworkImage gestiona estado internamente
//        y cachea en disco automáticamente (flutter_cache_manager).
// ─────────────────────────────────────────────────────────────────────────────

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({
    required this.imageURL,
    required this.categoryIcon,
    required this.categoryColor,
  });

  final String? imageURL;
  final IconData categoryIcon;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor;
    final hasUrl = imageURL != null && imageURL!.isNotEmpty;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: imageURL!,
              fit: BoxFit.cover,

              // Placeholder: indicador de carga ligero, mismo color de categoría.
              placeholder: (context, url) => Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: color,
                  ),
                ),
              ),

              // Error: ícono de categoría como fallback (igual que antes).
              errorWidget: (context, url, error) => _iconFallback(color),

              // Fade suave al cargar la imagen desde cache o red.
              fadeInDuration: const Duration(milliseconds: 200),
              fadeOutDuration: const Duration(milliseconds: 100),
            )
          : _iconFallback(color),
    );
  }

  Widget _iconFallback(Color color) => Icon(
        categoryIcon,
        size: 24,
        color: color,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _StockBadge
// ─────────────────────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product, required this.isDark});

  final Product product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final stock = product.quantity;
    final minStock = product.minStock;
    final isLow = stock <= minStock;
    final isOut = stock == 0;

    final Color badgeColor;
    final String label;

    if (isOut) {
      badgeColor = AppColors.error;
      label = 'Sin stock';
    } else if (isLow) {
      badgeColor = AppColors.warning;
      label = 'Stock bajo · $stock';
    } else {
      badgeColor = AppColors.success;
      label = 'En stock · $stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.caption2.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
