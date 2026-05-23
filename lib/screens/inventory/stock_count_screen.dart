import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../models/stock_count.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_count_provider.dart';
import '../../core/utils/screen_tracker_mixin.dart';
import '../../widgets/widgets.dart';

class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({super.key});

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen>
    with ScreenTrackerMixin {
  @override
  String get trackedScreenName => 'stock_count';

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sc = ref.watch(stockCountProvider);
    final inv = ref.watch(inventoryProvider).value;
    final products = inv?.products ?? <Product>[];
    final filtered = _filterProducts(products);

    return PopScope(
      canPop: sc.activeSession == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || sc.activeSession == null) return;
        await _confirmAbandon(context);
      },
      child: Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Conteo en góndola'),
        actions: [
          if (sc.activeSession != null)
            TextButton(
              onPressed: sc.isSyncing
                  ? null
                  : () => _confirmAbandon(context),
              child: const Text('Salir'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (sc.activeSession == null && sc.lastSummary == null)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _WelcomeHero(onStart: () =>
                      ref.read(stockCountProvider.notifier).startSession()),
                ],
              ),
            ),
          if (sc.activeSession != null) ...[
            _CountingGuide(
              counted: sc.activeSession!.lines.length,
              total: products.length,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AppSearchBar(
                controller: _searchCtrl,
                placeholder: '¿Qué producto buscas?',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (sc.activeSession!.lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Toca un producto de la lista y escribe cuántas unidades '
                  'ves en la góndola. No hace falta contarlos todos hoy.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No encontramos productos con esa búsqueda.',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        StockCountLine? line;
                        for (final l in sc.activeSession!.lines) {
                          if (l.productId == p.id) {
                            line = l;
                            break;
                          }
                        }
                        return _ProductCountTile(
                          product: p,
                          line: line,
                          onCount: () => _showCountSheet(p, line?.countedQuantity),
                        );
                      },
                    ),
            ),
          ] else if (sc.lastSummary != null) ...[
            Expanded(
              child: _ResultsView(
                summary: sc.lastSummary!,
                isDark: isDark,
                onNewCount: () =>
                    ref.read(stockCountProvider.notifier).startSession(),
              ),
            ),
          ],
          if (sc.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(sc.error!, style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
      floatingActionButton: sc.activeSession != null &&
              sc.activeSession!.lines.isNotEmpty
          ? FloatingActionButton(
              tooltip: 'Guardar conteo',
              onPressed: sc.isSyncing
                  ? null
                  : () => ref
                      .read(stockCountProvider.notifier)
                      .finalizeSession(),
              child: sc.isSyncing
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 30),
            )
          : null,
    ),
    );
  }

  Future<void> _confirmAbandon(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del conteo?'),
        content: const Text(
          'No se guardará nada de lo que contaste. '
          'Solo el botón ✓ al final guarda el conteo en el inventario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir contando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(stockCountProvider.notifier).abandonSession();
    }
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_query.trim().isEmpty) return products;
    final q = _query.toLowerCase();
    return products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.barcode.contains(q))
        .toList();
  }

  Future<void> _showCountSheet(Product product, int? current) async {
    final ctrl = TextEditingController(
      text: current?.toString() ?? '',
    );
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Cuántas unidades ves?',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.name,
                style: AppTypography.title3,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.freshSky.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: AppColors.deepSpaceBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El sistema dice que hay ${product.quantity} '
                        'unidad${product.quantity == 1 ? '' : 'es'}. '
                        'Cuenta lo que hay en la góndola.',
                        style: AppTypography.caption.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTypography.title2,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Ej: ${product.quantity}',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _QuickQtyButton(
                    label: '−1',
                    onTap: () => _bump(ctrl, -1, product.quantity),
                  ),
                  const SizedBox(width: 8),
                  _QuickQtyButton(
                    label: 'Igual al sistema',
                    onTap: () => ctrl.text = '${product.quantity}',
                  ),
                  const SizedBox(width: 8),
                  _QuickQtyButton(
                    label: '+1',
                    onTap: () => _bump(ctrl, 1, product.quantity),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final n = int.tryParse(ctrl.text.trim());
                  if (n == null || n < 0) return;
                  Navigator.pop(ctx, n);
                },
                child: const Text('Guardar este conteo'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Volver a la lista'),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    await ref.read(stockCountProvider.notifier).recordCount(product, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Anotado: $result unidades (aún no guardado en inventario)'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _bump(TextEditingController ctrl, int delta, int fallback) {
    final n = int.tryParse(ctrl.text.trim()) ?? fallback;
    final next = (n + delta).clamp(0, 999999);
    ctrl.text = '$next';
  }
}

class _QuickQtyButton extends StatelessWidget {
  const _QuickQtyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: AppTypography.caption2),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.teaGreen.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded,
                size: 36, color: AppColors.deepSpaceBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Revisa el inventario como en el supermercado',
            style: AppTypography.title2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Camina por las góndolas, cuenta productos y la app te dice '
            'si el stock del sistema coincide con lo que hay en la tienda.',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _StepRow(
            number: '1',
            text: 'Inicia una ronda de conteo',
            icon: Icons.play_circle_outline_rounded,
          ),
          const SizedBox(height: 10),
          _StepRow(
            number: '2',
            text: 'Toca cada producto y anota lo que ves',
            icon: Icons.touch_app_rounded,
          ),
          const SizedBox(height: 10),
          _StepRow(
            number: '3',
            text: 'Pulsa ✓ para guardar y ver el informe',
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Empezar a contar'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
    required this.icon,
  });

  final String number;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.deepSpaceBlue,
          child: Text(
            number,
            style: AppTypography.caption2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 20, color: AppColors.freshSky),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTypography.callout)),
      ],
    );
  }
}

class _CountingGuide extends StatelessWidget {
  const _CountingGuide({
    required this.counted,
    required this.total,
    required this.isDark,
  });

  final int counted;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (counted / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu ronda de conteo',
              style: AppTypography.headline,
            ),
            const SizedBox(height: 6),
            Text(
              counted == 0
                  ? 'Empieza por el pasillo que prefieras.'
                  : 'Llevas $counted producto${counted == 1 ? '' : 's'} revisado${counted == 1 ? '' : 's'}.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (total > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? AppColors.darkSurfaceSecondary
                      : AppColors.surfaceSecondary,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.teaGreen),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$counted de $total en el catálogo (no es obligatorio contarlos todos)',
                style: AppTypography.caption2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCountTile extends StatelessWidget {
  const _ProductCountTile({
    required this.product,
    required this.line,
    required this.onCount,
  });

  final Product product;
  final StockCountLine? line;
  final VoidCallback onCount;

  String? _statusLabel(int? variance) {
    if (variance == null) return null;
    if (variance == 0) return 'Cuadra con el sistema';
    if (variance > 0) return 'Hay $variance más en góndola';
    return 'Faltan ${variance.abs()} en góndola';
  }

  @override
  Widget build(BuildContext context) {
    final counted = line?.countedQuantity;
    final variance = line?.variance;
    final status = _statusLabel(variance);
    Color? accent;
    if (variance != null) {
      if (variance == 0) {
        accent = AppColors.success;
      } else if (variance > 0) {
        accent = AppColors.warning;
      } else {
        accent = AppColors.error;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCount,
          borderRadius: BorderRadius.circular(16),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: product.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(product.category.icon,
                      color: product.category.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.callout.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'En sistema: ${product.quantity}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: AppTypography.caption2.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          'Toca para contar en góndola',
                          style: AppTypography.caption2.copyWith(
                            color: AppColors.freshSky,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (counted != null)
                  Column(
                    children: [
                      Text('Contaste', style: AppTypography.caption2),
                      Text(
                        '$counted',
                        style: AppTypography.title2.copyWith(color: accent),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.teaGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: AppColors.deepSpaceBlue),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.summary,
    required this.isDark,
    required this.onNewCount,
  });

  final StockCountSummary summary;
  final bool isDark;
  final VoidCallback onNewCount;

  @override
  Widget build(BuildContext context) {
    final total = summary.totalLines;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(Icons.celebration_rounded,
                  size: 40, color: AppColors.teaGreen),
              const SizedBox(height: 10),
              Text(
                'Conteo guardado',
                style: AppTypography.title2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                total == 0
                    ? 'No había productos para comparar.'
                    : 'Revisaste $total producto${total == 1 ? '' : 's'} y '
                        'actualizamos el inventario según lo que contaste.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('¿Qué encontramos?', style: AppTypography.title3),
        const SizedBox(height: 12),
        _ResultCard(
          title: 'Cuadra con el sistema',
          subtitle:
              'La cantidad en góndola es igual a la del inventario digital.',
          value: summary.matchCount,
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
        ),
        _ResultCard(
          title: 'Sobrante en góndola',
          subtitle:
              'Contaste más unidades de las que dice el sistema. Revisa reposición o errores de carga.',
          value: summary.overCount,
          icon: Icons.trending_up_rounded,
          color: AppColors.warning,
        ),
        _ResultCard(
          title: 'Faltante en góndola',
          subtitle:
              'Hay menos en la góndola que en el sistema. Puede haber rotura o venta no registrada.',
          value: summary.underCount,
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
        ),
        _ResultCard(
          title: 'Unidades de diferencia (total)',
          subtitle:
              'Suma de todas las unidades que no coinciden, sin importar si sobran o faltan.',
          value: summary.totalVarianceUnits,
          icon: Icons.calculate_outlined,
          color: AppColors.freshSky,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onNewCount,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Hacer otra ronda de conteo'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.headline),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$value',
                  style: AppTypography.title2.copyWith(color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
