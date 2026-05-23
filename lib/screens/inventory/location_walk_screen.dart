import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/location_walk.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/location_walk_provider.dart';
import '../../core/utils/screen_tracker_mixin.dart';
import '../../widgets/widgets.dart';
import '../products/product_detail_screen.dart';

class LocationWalkScreen extends ConsumerStatefulWidget {
  const LocationWalkScreen({super.key});

  @override
  ConsumerState<LocationWalkScreen> createState() => _LocationWalkScreenState();
}

class _LocationWalkScreenState extends ConsumerState<LocationWalkScreen>
    with ScreenTrackerMixin {
  @override
  String get trackedScreenName => 'location_walk';

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final lw = ref.watch(locationWalkProvider);
    final inv = ref.watch(inventoryProvider).value;
    final productCount = inv?.products.where((p) => p.isActive).length ?? 0;

    return PopScope(
      canPop: lw.activeSession == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || lw.activeSession == null) return;
        await _confirmAbandon();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: const Text('Recorrido por ubicación'),
          actions: [
            if (lw.activeSession != null)
              TextButton(
                onPressed: lw.isComputing ? null : _confirmAbandon,
                child: const Text('Salir'),
              ),
          ],
        ),
        body: lw.activeSession == null
            ? _idleBody(context, lw, productCount, isDark)
            : _activeBody(context, lw, isDark),
      ),
    );
  }

  Widget _idleBody(
    BuildContext context,
    LocationWalkState lw,
    int productCount,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.freshSky.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_rounded,
                  size: 36,
                  color: AppColors.deepSpaceBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Recorre la tienda por pasillos',
                style: AppTypography.title2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'La app agrupa tus productos por ubicación en góndola. '
                'Marca cada pasillo cuando lo hayas revisado.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              if (productCount == 0)
                Text(
                  'Primero agrega productos con ubicación '
                  '(ej: Pasillo 3, Estante A).',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  '$productCount productos activos en inventario',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: productCount == 0 || lw.isComputing
                    ? null
                    : () =>
                        ref.read(locationWalkProvider.notifier).startWalk(),
                icon: const Icon(Icons.directions_walk_rounded),
                label: const Text('Iniciar recorrido'),
              ),
            ],
          ),
        ),
        if (lw.lastSummary != null) ...[
          const SizedBox(height: 16),
          _LastSummaryCard(summary: lw.lastSummary!, source: lw.summarySource),
        ],
      ],
    );
  }

  Widget _activeBody(
    BuildContext context,
    LocationWalkState lw,
    bool isDark,
  ) {
    final session = lw.activeSession!;
    final summary = session.summary ?? lw.lastSummary;
    final progress = summary?.progress ?? 0.0;
    final pending = session.aisles
        .where((a) => !session.isChecked(a.key))
        .toList();
    final done = session.aisles
        .where((a) => session.isChecked(a.key))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Avance del recorrido',
                        style: AppTypography.title3,
                      ),
                    ),
                    if (lw.isComputing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        AppColors.textTertiary.withValues(alpha: 0.2),
                    color: AppColors.teaGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary != null
                      ? '${summary.checkedAisles} de ${summary.aisleCount} pasillos · '
                          '${summary.productsCovered} productos cubiertos'
                      : 'Calculando…',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (summary != null && summary.lowStockSpotted > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${summary.lowStockSpotted} con stock bajo aún sin revisar',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (pending.isNotEmpty) ...[
                Text('Por revisar', style: AppTypography.headline),
                const SizedBox(height: 8),
                ...pending.map(
                  (a) => _AisleTile(
                    aisle: a,
                    checked: false,
                    onCheck: lw.isComputing
                        ? null
                        : () => ref
                            .read(locationWalkProvider.notifier)
                            .toggleAisle(a.key),
                    onOpenProduct: (id) => _openProduct(context, ref, id),
                  ),
                ),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Revisados', style: AppTypography.headline),
                const SizedBox(height: 8),
                ...done.map(
                  (a) => _AisleTile(
                    aisle: a,
                    checked: true,
                    onCheck: lw.isComputing
                        ? null
                        : () => ref
                            .read(locationWalkProvider.notifier)
                            .toggleAisle(a.key),
                    onOpenProduct: (id) => _openProduct(context, ref, id),
                  ),
                ),
              ],
              if (session.aisles.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Ningún producto tiene ubicación definida.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: lw.isComputing ||
                      (summary?.checkedAisles ?? 0) == 0
                  ? null
                  : _finalize,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Terminar recorrido'),
            ),
          ),
        ),
      ],
    );
  }

  void _openProduct(BuildContext context, WidgetRef ref, String productId) {
    final product = ref
        .read(inventoryProvider)
        .value
        ?.products
        .where((p) => p.id == productId)
        .firstOrNull;
    if (product == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  Future<void> _confirmAbandon() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text(
          'El avance de este recorrido se descartará. '
          'No se guardará ningún resumen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(locationWalkProvider.notifier).abandonWalk();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _finalize() async {
    final summary =
        await ref.read(locationWalkProvider.notifier).finalizeWalk();
    if (!mounted || summary == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recorrido guardado'),
        content: Text(
          'Revisaste ${summary.checkedAisles} pasillos y cubriste '
          '${summary.productsCovered} productos.\n\n'
          'Pendiente con stock bajo sin revisar: '
          '${summary.lowStockSpotted}.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}

class _AisleTile extends StatefulWidget {
  const _AisleTile({
    required this.aisle,
    required this.checked,
    required this.onCheck,
    required this.onOpenProduct,
  });

  final LocationAisle aisle;
  final bool checked;
  final VoidCallback? onCheck;
  final void Function(String productId) onOpenProduct;

  @override
  State<_AisleTile> createState() => _AisleTileState();
}

class _AisleTileState extends State<_AisleTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final aisle = widget.aisle;
    final items = aisle.products;
    final showList = items.isNotEmpty;
    final preview = items.take(2).toList();
    final hasMore = items.length > 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: widget.onCheck,
                  icon: Icon(
                    widget.checked
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: widget.checked
                        ? AppColors.teaGreen
                        : AppColors.textTertiary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aisle.displayLabel,
                        style: AppTypography.callout.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: widget.checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${aisle.productCount} producto'
                        '${aisle.productCount == 1 ? '' : 's'}'
                        '${aisle.lowStockCount > 0 ? ' · ${aisle.lowStockCount} stock bajo' : ''}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showList && items.length > 1)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            if (showList) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...(_expanded ? items : preview).map(
                (p) => _ProductRow(
                  product: p,
                  onTap: () => widget.onOpenProduct(p.id),
                ),
              ),
              if (!_expanded && hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = true),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Ver ${items.length - 2} más',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.deepSpaceBlue,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onTap,
  });

  final LocationAisleProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: product.lowStock
                      ? AppColors.warning
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTypography.callout.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${product.quantity} uds en góndola'
                        '${product.lowStock ? ' · Stock bajo' : ''}',
                        style: AppTypography.caption2.copyWith(
                          color: product.lowStock
                              ? AppColors.warning
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastSummaryCard extends StatelessWidget {
  const _LastSummaryCard({
    required this.summary,
    required this.source,
  });

  final LocationWalkSummary summary;
  final LocationWalkDataSource? source;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (source) {
      LocationWalkDataSource.live => 'Último recorrido',
      LocationWalkDataSource.cache => 'Resumen en caché',
      LocationWalkDataSource.offlineStorage => 'Guardado en el dispositivo',
      null => 'Último recorrido',
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sourceLabel, style: AppTypography.caption),
          const SizedBox(height: 6),
          Text(
            '${summary.checkedAisles}/${summary.aisleCount} pasillos · '
            '${summary.productsCovered} productos',
            style: AppTypography.title3,
          ),
          if (summary.lowStockSpotted > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${summary.lowStockSpotted} pasillos con stock bajo sin revisar',
                style: AppTypography.caption.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
