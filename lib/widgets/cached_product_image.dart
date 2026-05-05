// lib/widgets/cached_product_image.dart
//
// Widget reutilizable que encapsula cached_network_image para productos.
// Úsalo en cualquier pantalla que muestre imágenes de productos.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/product.dart';

/// Widget de imagen de producto con caché automático.
///
/// Ventajas frente a Image.network():
/// - Guarda la imagen en disco (persiste entre sesiones)
/// - Muestra un placeholder mientras carga (mejor UX)
/// - Muestra el ícono de categoría si no hay URL o falla la carga
/// - Reutilizable: un solo widget para lista y detalle
class CachedProductImage extends StatelessWidget {
  final Product product;
  final double height;
  final double? width;
  final double iconSize;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedProductImage({
    super.key,
    required this.product,
    this.height = 140,
    this.width,
    this.iconSize = 60,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Si el producto no tiene URL, mostramos el ícono de categoría directamente
    final url = product.imageURL;
    if (url == null || url.isEmpty) {
      return _fallbackIcon();
    }

    // ClipRRect aplica el borderRadius sobre la imagen cacheada
    Widget imageWidget = CachedNetworkImage(
      imageUrl: url,

      // ─── Dimensiones ─────────────────────────────────────────────────────
      height: height,
      width: width ?? double.infinity,
      fit: fit,

      // ─── Placeholder ─────────────────────────────────────────────────────
      // Se muestra mientras la imagen se descarga por primera vez.
      // En recargas posteriores, la imagen viene del caché y este
      // placeholder casi nunca aparece.
      placeholder: (context, url) => SizedBox(
        height: height,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.freshSky,
          ),
        ),
      ),

      // ─── Error ───────────────────────────────────────────────────────────
      // Si la URL es inválida o hay error de red, mostramos el ícono
      // de categoría como fallback (nunca pantalla rota).
      errorWidget: (context, url, error) => _fallbackIcon(),

      // ─── Configuración del caché ──────────────────────────────────────────
      // maxWidthDiskCache: limita el tamaño de la imagen guardada en disco.
      // Ahorra espacio sin perder calidad visual en mobile.
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
    );

    // Aplicamos borderRadius si viene configurado
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }
    return imageWidget;
  }

  /// Fallback: ícono de categoría del producto.
  /// Se usa cuando no hay URL o falla la descarga.
  Widget _fallbackIcon() {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: Icon(
        product.category.icon,
        size: iconSize,
        color: AppColors.warning,
      ),
    );
  }
}

/// Variante circular — útil para avatares/thumbnails en listas.
class CachedProductThumbnail extends StatelessWidget {
  final Product product;
  final double size;

  const CachedProductThumbnail({
    super.key,
    required this.product,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    // BUG FIX: antes había un ClipRRect envolviendo a CachedProductImage que
    // YA aplica su propio ClipRRect cuando recibe borderRadius. El doble clip
    // es redundante e ineficiente. Se elimina el outer ClipRRect y se delega
    // el recorte directamente al parámetro borderRadius de CachedProductImage.
    return CachedProductImage(
      product: product,
      height: size,
      width: size,
      iconSize: size * 0.5,
      borderRadius: BorderRadius.circular(8),
    );
  }
}
