// lib/screens/products/cached_image_demo_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/cached_product_image.dart';

// ════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL — Lista de productos con thumbnails cacheados
// ════════════════════════════════════════════════════════════════════════════

class CachedImageDemoScreen extends ConsumerWidget {
  const CachedImageDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final products = ref.watch(inventoryProvider).value?.products ?? [];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Productos (con caché)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'Limpiar caché (demo)',
            onPressed: () async {
              // BUG FIX: evictFromCache('') solo eliminaba la entrada con URL
              // vacía (ninguna). Para limpiar TODO el caché de imágenes hay que
              // usar DefaultCacheManager().emptyCache().
              await DefaultCacheManager().emptyCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Caché limpiado — las imágenes se recargarán'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductListTile(product: product);
              },
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TILE CON THUMBNAIL CACHEADO
// ════════════════════════════════════════════════════════════════════════════

class _ProductListTile extends StatelessWidget {
  final Product product;
  const _ProductListTile({required this.product});

  @override
  Widget build(BuildContext context) {
    // AppCard no tiene onTap → GestureDetector como wrapper
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ProductDetailWithCache(product: product),
        ),
      ),
      child: AppCard(
        child: Row(
          children: [
            CachedProductThumbnail(product: product, size: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.category.label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (product.imageURL != null && product.imageURL!.isNotEmpty)
              Tooltip(
                message: 'Imagen cacheada',
                child: Icon(Icons.cached_rounded,
                    size: 16, color: AppColors.freshSky),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PANTALLA DE DETALLE CON IMAGEN HERO CACHEADA
// ════════════════════════════════════════════════════════════════════════════

class _ProductDetailWithCache extends StatelessWidget {
  final Product product;
  const _ProductDetailWithCache({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(product.name),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero: imagen cacheada ─────────────────────────────────────
            AppCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedProductImage(
                  product: product,
                  height: 220,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Info básica ───────────────────────────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title3 = SemiBold 18px (equivalente a headlineSmall)
                  Text(product.name, style: AppTypography.title3),
                  const SizedBox(height: 4),
                  Text(
                    product.category.label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.freshSky),
                  ),
                  const SizedBox(height: 12),
                  // salePrice = precio de venta (campo real del modelo)
                  _infoRow(
                      'Precio', '\$${product.salePrice.toStringAsFixed(2)}'),
                  // quantity = stock actual (campo real del modelo)
                  _infoRow('Stock', '${product.quantity} unidades'),
                  _infoRow('SKU', product.sku),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _CachingInfoCard(
                hasImage: product.imageURL?.isNotEmpty ?? false),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
          Text(value,
              style:
                  AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PANEL INFORMATIVO — Para mostrar en la presentación
// ════════════════════════════════════════════════════════════════════════════

class _CachingInfoCard extends StatelessWidget {
  final bool hasImage;
  const _CachingInfoCard({required this.hasImage});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: AppColors.freshSky, size: 20),
              const SizedBox(width: 8),
              Text('Estado del caché',
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow(
            icon: hasImage
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: hasImage ? AppColors.success : AppColors.warning,
            label: hasImage
                ? 'Imagen descargada y guardada en disco'
                : 'Sin URL de imagen — se usa ícono fallback',
          ),
          _statusRow(
            icon: Icons.offline_bolt_rounded,
            color: AppColors.freshSky,
            label: 'Disponible offline una vez cacheada',
          ),
          _statusRow(
            icon: Icons.data_saver_on_rounded,
            color: AppColors.success,
            label: 'Segunda carga: 0 bytes de red consumidos',
          ),
          _statusRow(
            icon: Icons.memory_rounded,
            color: AppColors.warning,
            label: 'Caché en RAM + persistente en disco',
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTypography.caption)),
        ],
      ),
    );
  }
}
