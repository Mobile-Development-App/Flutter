import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../providers/restock_latency_provider.dart';
import '../../widgets/app_card.dart';
import 'add_product_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _saleLoading = false;

  Product get _current {
    final inv = ref.read(inventoryProvider).value;
    if (inv == null) return widget.product;
    return inv.products.firstWhere(
      (p) => p.id == widget.product.id,
      orElse: () => widget.product,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final inv = ref.watch(inventoryProvider).value;
    final product = inv?.products.firstWhere(
          (p) => p.id == widget.product.id,
          orElse: () => widget.product,
        ) ??
        widget.product;

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
            _heroSection(product),
            const SizedBox(height: 16),
            _topMetrics(product),
            const SizedBox(height: 16),
            _smartFeatureCard(product, analysis),
            if (product.stockStatus != StockStatus.inStock) ...[
              const SizedBox(height: 16),
              _restockBanner(product, restockDays, isDark),
            ],
            const SizedBox(height: 16),
            _detailsSection(product),
            const SizedBox(height: 16),
            _financialSection(product),
            const SizedBox(height: 20),
            _actions(context, product),
          ],
        ),
      ),
    );
  }

  Widget _heroSection(Product product) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 140,
            alignment: Alignment.center,
            child: Icon(product.category.icon, size: 60, color: AppColors.warning),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(product.name.toUpperCase(), style: AppTypography.title),
                const SizedBox(height: 6),
                Text(product.category.label, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topMetrics(Product product) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _metricCard('Precio de Venta', product.salePrice.currencyFormatted)),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Cantidad',
                '${product.quantity} uds',
                color: product.stockStatus == StockStatus.outOfStock
                    ? AppColors.error
                    : product.stockStatus == StockStatus.lowStock
                        ? AppColors.warning
                        : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _metricCard('Precio de Costo', product.costPrice.currencyFormatted)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('Margen', product.profitMargin.percentFormatted, color: AppColors.success)),
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
          Text(value, style: AppTypography.title3.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _smartFeatureCard(Product product, SmartProductAnalysis analysis) {
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
              _chip(product.marginHealth.label, product.marginHealth.icon, product.marginHealth.color),
              _chip('Tendencia ${product.stockTrend.label}', product.stockTrend.icon, product.stockTrend.color),
              _chip('Utilidad ${product.profitPerUnit.currencyFormatted}', Icons.attach_money, AppColors.success),
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
        color: color.withValues(alpha: 0.1),
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
          Icon(isOut ? Icons.cancel_rounded : Icons.warning_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOut ? 'Producto Agotado' : 'Stock Bajo',
                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  isOut
                      ? 'Este producto necesita reabastecimiento urgente'
                      : 'Solo quedan ${p.quantity} uds (mín: ${p.minStock})',
                  style: AppTypography.caption2.copyWith(color: AppColors.textSecondary),
                ),
                if (days != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reabastecer en ~$days día${days == 1 ? '' : 's'}',
                    style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsSection(Product product) {
    final parsed = _extractCoordinatesAndLabel(product.location);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalles del Producto', style: AppTypography.headline),
          const SizedBox(height: 10),
          _row('SKU', product.sku),
          _row('Código', product.barcode),
          _locationRow(
            displayText: parsed.$1,
            latitude: parsed.$2,
            longitude: parsed.$3,
          ),
          _row('Stock Mínimo', '${product.minStock} uds'),
        ],
      ),
    );
  }

  Widget _financialSection(Product product) {
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
        children: [Text(label), Text(value)],
      ),
    );
  }

  Widget _locationRow({
    required String displayText,
    required double? latitude,
    required double? longitude,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text('Ubicación'), Text(displayText)],
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _CoordinateMapViewScreen(
                        latitude: latitude,
                        longitude: longitude,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Ver en mapa: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.deepSpaceBlue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (String, double?, double?) _extractCoordinatesAndLabel(String location) {
    final raw = location.trim();
    if (raw.isEmpty) {
      return ('No se seleccionó ubicación', null, null);
    }

    final gpsMatch = RegExp(
      r'GPS:\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (gpsMatch != null) {
      final lat = double.tryParse(gpsMatch.group(1) ?? '');
      final lng = double.tryParse(gpsMatch.group(2) ?? '');
      final label = raw.replaceFirst(gpsMatch.group(0)!, '').trim();
      final cleanLabel = label.isEmpty ? 'Ubicación seleccionada' : label;
      if (lat != null && lng != null) {
        return (cleanLabel, lat, lng);
      }
    }

    final legacyMatch = RegExp(
      r'Lat:\s*(-?\d+(?:\.\d+)?)\s*,\s*Lng:\s*(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (legacyMatch != null) {
      final lat = double.tryParse(legacyMatch.group(1) ?? '');
      final lng = double.tryParse(legacyMatch.group(2) ?? '');
      final label = raw.replaceFirst(legacyMatch.group(0)!, '').trim();
      final cleanLabel = label.isEmpty ? 'Ubicación seleccionada' : label;
      if (lat != null && lng != null) {
        return (cleanLabel, lat, lng);
      }
    }

    return (raw, null, null);
  }

  Widget _actions(BuildContext context, Product product) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _saleLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.point_of_sale_rounded, size: 18),
            label: Text(_saleLoading ? 'Registrando...' : 'Registrar Venta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saleLoading ? null : () => _showSaleDialog(context, product),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final updated = await Navigator.push<Product>(
                context,
                MaterialPageRoute(builder: (_) => AddProductScreen(editingProduct: product)),
              );
              if (updated != null) {
                ref.read(inventoryProvider.notifier).updateProduct(updated);
              }
            },
            child: const Text('Editar Producto'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            onPressed: () => _confirmDelete(context),
            child: const Text('Eliminar Producto'),
          ),
        ),
      ],
    );
  }

  Future<void> _showSaleDialog(BuildContext context, Product product) async {
    if (product.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este producto no tiene unidades disponibles.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Venta'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: AppTypography.callout.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Precio: ${product.salePrice.currencyFormatted}  ·  Stock: ${product.quantity} uds',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Cantidad a vender',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixText: 'uds',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Ingresa una cantidad válida';
                  if (n > product.quantity) {
                    return 'Stock insuficiente (disponible: ${product.quantity})';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final qty = int.tryParse(qtyController.text) ?? 0;
    if (qty <= 0) return;

    final latest = _current;
    if (qty > latest.quantity) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock insuficiente. Disponible: ${latest.quantity} uds.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saleLoading = true);

    try {
      await ref
          .read(inventoryProvider.notifier)
          .recordSale(latest.id, qty, latest.salePrice);

      // Fuerza re-fetch de ventas en analytics (sin dependencia circular,
      // porque esto es un Widget, no un Provider).
      if (context.mounted) ref.invalidate(analyticsProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Venta registrada: $qty uds de ${latest.name} · ${(qty * latest.salePrice).currencyFormatted}',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar la venta: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _saleLoading = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final product = _current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que deseas eliminar "${product.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(inventoryProvider.notifier).deleteProduct(product);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar el producto. Verifica tu conexión e intenta de nuevo.\n'
            'Detalle: $e',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

class _CoordinateMapViewScreen extends StatelessWidget {
  final double latitude;
  final double longitude;

  const _CoordinateMapViewScreen({
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación del producto')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.inventaria.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 46,
                height: 46,
                child: const Icon(
                  Icons.location_pin,
                  size: 46,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
