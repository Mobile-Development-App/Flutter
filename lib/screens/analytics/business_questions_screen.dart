import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../services/usage_tracking_service.dart';

class BusinessQuestionsScreen extends StatelessWidget {
  const BusinessQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(title: const Text('Business Questions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BQCard(
            title: 'BQ3',
            subtitle: 'Tiempo entre alerta de bajo stock y reposición efectiva por producto',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _BQ3RestockScreen())),
          ),
          const SizedBox(height: 12),
          _BQCard(
            title: 'BQ4',
            subtitle: 'Productos próximos a vencer y acciones sugeridas de venta o eliminación',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _BQ4ExpiryPriorityScreen())),
          ),
          const SizedBox(height: 12),
          _BQCard(
            title: 'BQ6',
            subtitle: 'Correcciones manuales realizadas después de actualizaciones automáticas',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _BQ6ManualCorrectionsScreen())),
          ),
        ],
      ),
    );
  }
}

class _BQCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BQCard({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.deepSpaceBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(title, style: AppTypography.caption.copyWith(color: AppColors.deepSpaceBlue, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(subtitle, style: AppTypography.caption.copyWith(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _BQ3RestockScreen extends ConsumerWidget {
  const _BQ3RestockScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bq = ref.watch(bq3Provider);
    final online = ref.watch(connectivityProvider).value ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('BQ3 - Latencia de reposición')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(bq3Provider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectivityBanner(isOnline: online),
            const SizedBox(height: 12),
            bq.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (dashboard) {
                if (dashboard.products.isEmpty) {
                  return const _EmptyCopy(message: 'Aún no hay ciclos completos de alerta y reposición. Cuando un producto reciba una alerta y luego se reponga, aquí verás el tiempo promedio, los casos más lentos y los pendientes.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Resumen ejecutivo'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _KpiTile(label: 'Promedio', value: '${dashboard.averageDays.toStringAsFixed(1)} días'),
                        _KpiTile(label: 'Ciclos resueltos', value: '${dashboard.completedCycles}'),
                        _KpiTile(label: 'Alertas pendientes', value: '${dashboard.pendingAlerts}'),
                        _KpiTile(label: 'Ciclo más largo', value: '${dashboard.longestCycleDays} días'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InsightBanner(text: 'Esta vista muestra cuánto tarda la tienda en reaccionar a una alerta de bajo stock. Así puedes detectar productos que demoran demasiado en reponerse.'),
                    const SizedBox(height: 16),
                    _SectionTitle('Detalle por producto'),
                    const SizedBox(height: 8),
                    ...dashboard.products.map((item) => _ProductInsightCard(
                      title: item.productName,
                      chips: [
                        _chip('Stock ${item.currentStock}/${item.minStock}'),
                        _chip(item.hasPendingAlert ? 'Alerta pendiente' : 'Ciclo resuelto'),
                        _chip('${item.cycles} ciclos'),
                      ],
                      lines: [
                        'Promedio: ${item.averageDays.toStringAsFixed(1)} días',
                        'Rango: ${item.minDays} - ${item.maxDays} días',
                        if (item.lastAlertAt != null) 'Última alerta: ${_fmt(item.lastAlertAt!)}',
                        if (item.lastRestockAt != null) 'Última reposición: ${_fmt(item.lastRestockAt!)}',
                      ],
                    )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BQ4ExpiryPriorityScreen extends ConsumerWidget {
  const _BQ4ExpiryPriorityScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bq = ref.watch(bq4Provider);
    final inv = ref.watch(inventoryProvider).value;
    final products = inv?.expiringProducts ?? const <Product>[];
    final online = ref.watch(connectivityProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('BQ4 - Prioridad por vencimiento')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(bq4Provider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectivityBanner(isOnline: online),
            const SizedBox(height: 12),
            _SectionTitle('Registrar prioridad'),
            const SizedBox(height: 8),
            if (products.isEmpty)
              const _EmptyCopy(message: 'No hay productos próximos a vencer todavía. Cuando existan, aquí podrás marcar si deben venderse primero o retirarse.'),
            ...products.take(6).map((p) => _ActionCard(
              title: p.name,
              subtitle: p.expirationDate == null ? 'Sin fecha de vencimiento' : 'Vence: ${_fmt(p.expirationDate!)} · Stock: ${p.quantity}',
              onSell: () => ref.read(bq4Provider.notifier).saveAction(product: p, action: 'sell'),
              onRemove: () => ref.read(bq4Provider.notifier).saveAction(product: p, action: 'remove'),
            )),
            const SizedBox(height: 16),
            bq.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (dashboard) {
                if (dashboard.products.isEmpty) {
                  return const _EmptyCopy(message: 'Aún no hay acciones registradas para productos por vencer. Usa los botones de arriba para empezar a generar evidencia de la BQ4.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Resultado BQ4 (30 días)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _KpiTile(label: 'Productos seguidos', value: '${dashboard.trackedProducts}'),
                        _KpiTile(label: 'Acciones venta', value: '${dashboard.saleActions}'),
                        _KpiTile(label: 'Acciones eliminación', value: '${dashboard.removeActions}'),
                        _KpiTile(label: 'Enfoque sugerido', value: dashboard.topRecommendedAction),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InsightBanner(text: 'La recomendación se basa en días restantes para vencimiento, stock actual y decisiones previas tomadas por el usuario.'),
                    const SizedBox(height: 16),
                    ...dashboard.products.map((item) => _ProductInsightCard(
                      title: item.productName,
                      chips: [
                        _chip('Stock ${item.currentStock}'),
                        _chip('Vence en ${item.daysToExpire} días'),
                        _chip(item.recommendedAction == 'remove' ? 'Sugerido: eliminar' : 'Sugerido: vender'),
                      ],
                      lines: [
                        'Marcado para venta: ${item.sellCount} veces',
                        'Marcado para eliminación: ${item.removeCount} veces',
                        if (item.expirationDate != null) 'Fecha de vencimiento: ${_fmt(item.expirationDate!)}',
                      ],
                    )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BQ6ManualCorrectionsScreen extends ConsumerWidget {
  const _BQ6ManualCorrectionsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bq = ref.watch(bq6Provider);
    final online = ref.watch(connectivityProvider).value ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('BQ6 - Correcciones manuales')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(bq6Provider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectivityBanner(isOnline: online),
            const SizedBox(height: 12),
            bq.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (dashboard) {
                if (dashboard.items.isEmpty) {
                  return const _EmptyCopy(message: 'Todavía no hay correcciones manuales registradas después de ventas o reposiciones automáticas. Cuando el usuario edite manualmente una cantidad, aquí verás qué producto se corrigió y en qué magnitud.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Resumen ejecutivo'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _KpiTile(label: 'Productos corregidos', value: '${dashboard.correctedProducts}'),
                        _KpiTile(label: 'Correcciones', value: '${dashboard.totalCorrections}'),
                        _KpiTile(label: 'Ajuste promedio', value: dashboard.averageAdjustment.toStringAsFixed(1)),
                        _KpiTile(label: 'Origen más común', value: dashboard.topSource == 'sale' ? 'Venta' : 'Reposición'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InsightBanner(text: 'Esta BQ evidencia qué productos requieren intervención manual luego de un cambio automático, útil para detectar errores de captura o ajustes recurrentes.'),
                    const SizedBox(height: 16),
                    ...dashboard.items.map((item) => _ProductInsightCard(
                      title: item.productName,
                      chips: [
                        _chip('${item.correctionCount} correcciones'),
                        _chip('Ajuste total ${item.totalAdjustment >= 0 ? '+' : ''}${item.totalAdjustment}'),
                        _chip(item.lastAutoSource == 'sale' ? 'Origen: venta' : 'Origen: reposición'),
                      ],
                      lines: [
                        'Ajuste promedio: ${item.averageAdjustment.toStringAsFixed(1)} unidades',
                        'Última corrección: ${_fmt(item.lastCorrectionAt)}',
                      ],
                    )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  final bool isOnline;
  const _ConnectivityBanner({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : AppColors.warning;
    final text = isOnline ? 'Conectado: datos en vivo + caché' : 'Sin conexión: mostrando datos desde caché local';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [Icon(isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, size: 16, color: color), const SizedBox(width: 8), Expanded(child: Text(text, style: AppTypography.caption2))]),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  const _KpiTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTypography.caption2), const SizedBox(height: 6), Text(value, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700))]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700));
}

class _InsightBanner extends StatelessWidget {
  final String text;
  const _InsightBanner({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.deepSpaceBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [const Icon(Icons.insights_rounded, color: AppColors.deepSpaceBlue), const SizedBox(width: 8), Expanded(child: Text(text, style: AppTypography.caption2))]),
  );
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSell;
  final VoidCallback onRemove;
  const _ActionCard({required this.title, required this.subtitle, required this.onSell, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, style: AppTypography.caption2), const SizedBox(height: 8), Row(children: [Expanded(child: OutlinedButton(onPressed: onSell, child: const Text('Priorizar venta'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: onRemove, child: const Text('Eliminar')))])]),
    );
  }
}

class _ProductInsightCard extends StatelessWidget {
  final String title;
  final List<Widget> chips;
  final List<String> lines;
  const _ProductInsightCard({required this.title, required this.chips, required this.lines});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: chips), const SizedBox(height: 8), ...lines.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(e, style: AppTypography.caption2)))]),
    );
  }
}

class _EmptyCopy extends StatelessWidget {
  final String message;
  const _EmptyCopy({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.warning.withValues(alpha: 0.08)),
    child: Text(message, style: AppTypography.caption2),
  );
}

Widget _chip(String label) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(color: AppColors.deepSpaceBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
  child: Text(label, style: AppTypography.caption2),
);

String _fmt(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
