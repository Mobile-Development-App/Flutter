import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../storage/open_food_facts_lookup.dart';
import '../../storage/persistence/scan_session_file_store.dart';
import '../products/add_product_screen.dart';
import '../products/product_detail_screen.dart';
import 'scan_screen_mobile.dart';
import 'scan_screen_web.dart';

// ─────────────────────────────────────────────
// Open Food Facts lookup (gratuita, sin key)
// ─────────────────────────────────────────────
class OpenFoodFactsService {
  static Future<Map<String, dynamic>?> lookup(String barcode) =>
      OpenFoodFactsLookup.lookup(barcode);
}

/// Registra el escaneo en archivo local (lib/storage).
Future<void> recordScanSession({
  required String barcode,
  required bool foundInInventory,
  String? productName,
  String? brand,
}) async {
  await ScanSessionFileStore.shared.append(
    ScanSessionEntry(
      barcode: barcode,
      productName: productName,
      brand: brand,
      scannedAt: DateTime.now(),
      foundInInventory: foundInInventory,
    ),
  );
}

// ─────────────────────────────────────────────
// ScanScreen — router: Web vs Mobile
// ─────────────────────────────────────────────
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      return const ScanScreenWeb();
    }
    return const ScanScreenMobile();
  }
}

// ─────────────────────────────────────────────
// Shared state enums & models
// ─────────────────────────────────────────────
enum ScanState {
  ready,
  initializing,
  analyzing,
  found,
  notFound,
  error,
}

class ScanResult {
  final String barcode;
  final Product? existingProduct;
  final Map<String, dynamic>? openFoodData;

  const ScanResult({
    required this.barcode,
    required this.existingProduct,
    required this.openFoodData,
  });
}

// ─────────────────────────────────────────────
// ScanUI — shared widgets for both platforms
// ─────────────────────────────────────────────
class ScanUI {
  static Widget glassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  static Widget glassCard({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }

  static Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: Colors.white54)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.callout.copyWith(
                  fontWeight: FontWeight.w500, color: Colors.white),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static Widget actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.callout.copyWith(
                    fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }

  static Widget badge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: AppTypography.caption.copyWith(color: color)),
      ]),
    );
  }

  // ── Result cards (shared by web & mobile) ──

  static Widget foundCard(
    BuildContext context,
    ScanResult result,
    VoidCallback onReset,
  ) {
    final product = result.existingProduct!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        badge(
          icon: Icons.check_circle_rounded,
          label: 'Producto encontrado en inventario',
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        glassCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            infoRow('Nombre', product.name),
            infoRow('SKU', product.sku),
            infoRow('Código', result.barcode),
            infoRow('Stock', '${product.quantity} uds'),
            infoRow('Precio', product.salePrice.currencyFormatted),
            infoRow('Estado', product.stockStatus.label),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: actionButton(
              label: 'Ver Detalle',
              icon: Icons.visibility_rounded,
              color: AppColors.teaGreen,
              textColor: AppColors.inkBlack,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductDetailScreen(product: product),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: actionButton(
              label: 'Nuevo escaneo',
              icon: Icons.replay_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              textColor: Colors.white,
              onTap: onReset,
            ),
          ),
        ]),
      ]),
    );
  }

  static Widget notFoundCard(
    BuildContext context,
    ScanResult result,
    VoidCallback onReset,
  ) {
    final food = result.openFoodData;
    final barcode = result.barcode;
    final name = food?['name'] as String? ?? '';
    final brand = food?['brand'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        badge(
          icon: Icons.add_circle_outline_rounded,
          label: 'Producto no está en tu inventario',
          color: AppColors.warning,
        ),
        const SizedBox(height: 16),
        glassCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            infoRow('Código', barcode),
            if (name.isNotEmpty) infoRow('Nombre', name),
            if (brand.isNotEmpty) infoRow('Marca', brand),
            if (name.isEmpty && brand.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin información adicional para este código',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: actionButton(
              label: 'Agregar al inventario',
              icon: Icons.add_rounded,
              color: AppColors.teaGreen,
              textColor: AppColors.inkBlack,
              onTap: () => _openAddProduct(context, barcode, name, brand),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: actionButton(
              label: 'Nuevo escaneo',
              icon: Icons.replay_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              textColor: Colors.white,
              onTap: onReset,
            ),
          ),
        ]),
      ]),
    );
  }

  static void _openAddProduct(
    BuildContext context,
    String barcode,
    String name,
    String brand,
  ) {
    final prefilled = ScannedProductResult(
      name: name.isNotEmpty ? name : 'Producto $barcode',
      brand: brand,
      category: ProductCategory.other,
      barcode: barcode,
      suggestedPrice: 0,
      confidence: name.isNotEmpty ? 90 : 50,
      isDuplicate: false,
      similarProducts: const [],
    );
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
          child: AddProductScreen(fromScan: prefilled),
        ),
      ),
    );
  }
}
