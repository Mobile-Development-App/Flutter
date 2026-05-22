import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/inventory_health_provider.dart';
import '../../services/inventory_health_service.dart';

class InventoryHealthScreen extends ConsumerStatefulWidget {
  const InventoryHealthScreen({super.key});

  @override
  ConsumerState<InventoryHealthScreen> createState() => _InventoryHealthScreenState();
}

class _InventoryHealthScreenState extends ConsumerState<InventoryHealthScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _ringCtrl.reset();
    await ref.read(inventoryHealthProvider.notifier).refresh();
    _ringCtrl.forward();
  }

  Future<void> _copyReport() async {
    final text = await ref.read(inventoryHealthProvider.notifier).generateTextReport();
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte copiado al portapapeles'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final healthAsync = ref.watch(inventoryHealthProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkNavBackground : AppColors.inkBlack,
        foregroundColor: Colors.white,
        title: const Text('Salud del Inventario'),
        actions: [
          IconButton(icon: const Icon(Icons.content_copy_rounded), tooltip: 'Copiar reporte', onPressed: healthAsync.value != null ? _copyReport : null),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Recalcular', onPressed: _refresh),
        ],
      ),
      body: healthAsync.when(
        loading: () => _LoadingView(isDark: isDark),
        error: (e, _) => _ErrorView(error: e, onRetry: _refresh),
        data: (report) {
          if (report == null) return _EmptyView(onAnalyse: _refresh);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Stack(
              children: [
                Positioned(top: -120, right: -80, child: _AmbientGlow(color: AppColors.freshSky.withValues(alpha: isDark ? 0.18 : 0.12), size: 280)),
                Positioned(bottom: -120, left: -70, child: _AmbientGlow(color: AppColors.teaGreen.withValues(alpha: isDark ? 0.12 : 0.1), size: 260)),
                _ReportView(report: report, ringAnim: _ringAnim, isDark: isDark),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report, required this.ringAnim, required this.isDark});

  final InventoryHealthReport report;
  final Animation<double> ringAnim;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final seqMs = report.cards.fold<int>(0, (s, c) => s + c.computedIn.inMilliseconds);
    final parallelMs = report.totalComputedIn.inMilliseconds;
    final affectedTotal = report.cards.fold<int>(0, (s, c) => s + c.affectedCount);
    final scoreColor = _scoreColor(report.overallScore);
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
    final criticalCount = report.cards.where((c) => c.score < 60).length;
    final warningCount = report.cards.where((c) => c.score >= 60 && c.score < 80).length;
    final stableCount = report.cards.where((c) => c.score >= 80).length;

    return AnimatedBuilder(
      animation: ringAnim,
      builder: (context, _) {
        final fade = CurvedAnimation(parent: ringAnim, curve: const Interval(0.15, 1, curve: Curves.easeOut)).value;
        return Opacity(
          opacity: fade.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - fade) * 14),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [
                Container(
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: border), boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 8))]),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final compact = constraints.maxWidth < 580;
                      if (compact) {
                        return Column(children: [
                          _ScoreRing(report: report, animation: ringAnim, isDark: isDark, size: 160),
                          const SizedBox(height: 14),
                          Align(alignment: Alignment.centerLeft, child: _HeroSummary(scoreColor: scoreColor, textTertiary: textTertiary, textSecondary: textSecondary, report: report, isDark: isDark, affectedTotal: affectedTotal, parallelMs: parallelMs)),
                        ]);
                      }
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _ScoreRing(report: report, animation: ringAnim, isDark: isDark, size: 164),
                        const SizedBox(width: 14),
                        Expanded(child: _HeroSummary(scoreColor: scoreColor, textTertiary: textTertiary, textSecondary: textSecondary, report: report, isDark: isDark, affectedTotal: affectedTotal, parallelMs: parallelMs)),
                      ]);
                    }),
                    const SizedBox(height: 12),
                    _ConcurrencyBanner(parallelMs: parallelMs, seqMs: seqMs, isDark: isDark),
                  ]),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _StatusChip(label: 'Estables', value: '$stableCount', color: AppColors.success, isDark: isDark),
                  _StatusChip(label: 'Atencion', value: '$warningCount', color: AppColors.warning, isDark: isDark),
                  _StatusChip(label: 'Criticos', value: '$criticalCount', color: AppColors.error, isDark: isDark),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Text('DIMENSIONES DE SALUD', style: AppTypography.overline.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary, letterSpacing: 1.2)),
                  const SizedBox(width: 8),
                  const Expanded(child: Divider(height: 1)),
                ]),
                const SizedBox(height: 12),
                ...report.cards.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TweenAnimationBuilder<double>(duration: Duration(milliseconds: 350 + (entry.key * 80)), curve: Curves.easeOutCubic, tween: Tween(begin: 0.0, end: 1.0), builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: child)), child: _HealthCard(card: entry.value, isDark: isDark)))),
                const SizedBox(height: 8),
                Text('Generado el ${_fmt(report.generatedAt)} - Desliza hacia abajo para recalcular', style: AppTypography.caption2.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.freshSky;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.report, required this.animation, required this.isDark, this.size = 200});
  final InventoryHealthReport report;
  final Animation<double> animation;
  final bool isDark;
  final double size;

  Color get _scoreColor {
    final s = report.overallScore;
    if (s >= 80) return AppColors.success;
    if (s >= 60) return AppColors.freshSky;
    if (s >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          final progress = animation.value;
          return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(progress: report.overallScore / 100 * progress, color: _scoreColor, bgColor: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text((report.overallScore * progress).toStringAsFixed(0), style: AppTypography.largeTitle.copyWith(fontSize: size * 0.24, fontWeight: FontWeight.w800, color: _scoreColor, height: 1.0)),
                  Text('/ 100', style: AppTypography.caption.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: _scoreColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), child: Text(report.scoreLabel, style: AppTypography.caption.copyWith(color: _scoreColor, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color, required this.bgColor});
  final double progress;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    const strokeWidth = 14.0;
    final paint = Paint()..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    paint.color = bgColor;
    canvas.drawCircle(center, radius, paint);
    paint.color = color;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.bgColor != bgColor;
}

class _ConcurrencyBanner extends StatelessWidget {
  const _ConcurrencyBanner({required this.parallelMs, required this.seqMs, required this.isDark});
  final int parallelMs;
  final int seqMs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final speedup = seqMs > 0 ? seqMs / math.max(parallelMs, 1) : 1.0;
    final cardColor = isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary;
    final borderColor = isDark ? AppColors.darkBorderStrong : AppColors.border;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.bolt_rounded, color: AppColors.teaGreen, size: 18), const SizedBox(width: 8), Text('Procesamiento concurrente', style: AppTypography.caption.copyWith(color: textPrimary, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _MetricTile(label: 'Paralelo', value: '$parallelMs ms', color: AppColors.freshSky, isDark: isDark)), const SizedBox(width: 10), Expanded(child: _MetricTile(label: 'Secuencial', value: '$seqMs ms', color: AppColors.warning, isDark: isDark)), const SizedBox(width: 10), Expanded(child: _MetricTile(label: 'Speed-up', value: '${speedup.toStringAsFixed(1)}x', color: AppColors.success, isDark: isDark))]),
        const SizedBox(height: 8),
        Text('Los 4 analisis se ejecutan en paralelo para reducir latencia total.', style: AppTypography.caption2.copyWith(color: textSecondary)),
      ]),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.card, required this.isDark});
  final HealthCard card;
  final bool isDark;

  Color get _scoreColor {
    final s = card.score;
    if (s >= 80) return AppColors.success;
    if (s >= 60) return AppColors.freshSky;
    if (s >= 40) return AppColors.warning;
    return AppColors.error;
  }

  IconData get _icon {
    switch (card.dimension) {
      case HealthDimension.deadStock:
        return Icons.inventory_2_outlined;
      case HealthDimension.expiryRisk:
        return Icons.hourglass_bottom_rounded;
      case HealthDimension.marginHealth:
        return Icons.trending_up_rounded;
      case HealthDimension.categoryBalance:
        return Icons.donut_small_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Container(
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor), boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(height: 4, decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(17)), gradient: LinearGradient(colors: [_scoreColor.withValues(alpha: 0.85), _scoreColor.withValues(alpha: 0.45)]))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: _scoreColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(_icon, color: _scoreColor, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(card.dimension.label, style: AppTypography.callout.copyWith(color: textPrimary, fontWeight: FontWeight.w600)), Text('Peso: ${(card.dimension.weight * 100).toStringAsFixed(0)} %', style: AppTypography.caption2.copyWith(color: textTertiary))])), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _scoreColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text(card.score.toStringAsFixed(1), style: AppTypography.headline.copyWith(color: _scoreColor, fontWeight: FontWeight.w700))) ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TweenAnimationBuilder<double>(duration: const Duration(milliseconds: 850), curve: Curves.easeOutCubic, tween: Tween<double>(begin: 0, end: card.score / 100), builder: (context, value, _) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: value, minHeight: 6, backgroundColor: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary, valueColor: AlwaysStoppedAnimation(_scoreColor))))),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [_StatusPill(label: card.score >= 80 ? 'Estable' : card.score >= 60 ? 'Atencion' : 'Critico', color: _scoreColor, isDark: isDark), const SizedBox(width: 8), _StatusPill(label: '${card.affectedCount} afectados', color: AppColors.freshSky, isDark: isDark)])),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(card.headline, style: AppTypography.callout.copyWith(color: textPrimary)), const SizedBox(height: 4), Text(card.insight, style: AppTypography.caption.copyWith(color: textSecondary))])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12), child: Row(children: [Icon(Icons.memory_rounded, size: 12, color: textTertiary), const SizedBox(width: 4), Text('Isolate: ${card.computedIn.inMilliseconds} ms', style: AppTypography.caption2.copyWith(color: textTertiary)), const SizedBox(width: 8), Text('${card.affectedCount} afectados', style: AppTypography.caption2.copyWith(color: textTertiary)), const Spacer(), Icon(Icons.assessment_outlined, size: 12, color: textTertiary), const SizedBox(width: 4), Text(card.score.toStringAsFixed(1), style: AppTypography.caption2.copyWith(color: textTertiary, fontWeight: FontWeight.w600))])),
      ]),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 5, valueColor: AlwaysStoppedAnimation(AppColors.freshSky))), const SizedBox(height: 20), Text('Ejecutando 4 Isolates en paralelo...', style: AppTypography.title3.copyWith(color: textPrimary)), const SizedBox(height: 6), Text('Stock Muerto - Vencimiento - Margenes - Balance', style: AppTypography.caption2.copyWith(color: textSecondary), textAlign: TextAlign.center), const SizedBox(height: 16), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border)), child: Text('Preparando reporte consolidado...', style: AppTypography.caption.copyWith(color: textTertiary))) ]));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Container(width: 420, constraints: const BoxConstraints(maxWidth: 420), padding: const EdgeInsets.fromLTRB(20, 22, 20, 18), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error), const SizedBox(height: 14), Text('Error al calcular salud', style: AppTypography.title3.copyWith(color: textPrimary)), const SizedBox(height: 8), Text(error.toString(), style: AppTypography.caption.copyWith(color: textSecondary), textAlign: TextAlign.center), const SizedBox(height: 18), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar'))]))));
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAnalyse});
  final VoidCallback onAnalyse;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Container(constraints: const BoxConstraints(maxWidth: 480), padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 76, height: 76, decoration: BoxDecoration(color: AppColors.freshSky.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.health_and_safety_outlined, size: 40, color: AppColors.freshSky)), const SizedBox(height: 16), Text('Analiza la salud de tu inventario', style: AppTypography.title2.copyWith(color: textPrimary), textAlign: TextAlign.center), const SizedBox(height: 8), Text('Obtén un puntaje consolidado de riesgo y desempeño en segundos, incluso con datos locales ya sincronizados.', style: AppTypography.callout.copyWith(color: textSecondary), textAlign: TextAlign.center), const SizedBox(height: 18), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppColors.freshSky, foregroundColor: AppColors.inkBlack, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)), onPressed: onAnalyse, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Analizar ahora'))]))));
  }
}

class _KpiPill extends StatelessWidget {
  const _KpiPill({required this.icon, required this.label, required this.value, required this.isDark});
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(icon, size: 14, color: AppColors.freshSky), const SizedBox(width: 6), Expanded(child: Text(label, style: AppTypography.caption2.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Text(value, style: AppTypography.caption.copyWith(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary, fontWeight: FontWeight.w700))]));
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.scoreColor, required this.textTertiary, required this.textSecondary, required this.report, required this.isDark, required this.affectedTotal, required this.parallelMs});
  final Color scoreColor;
  final Color textTertiary;
  final Color textSecondary;
  final InventoryHealthReport report;
  final bool isDark;
  final int affectedTotal;
  final int parallelMs;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Puntaje General', style: AppTypography.overline.copyWith(color: textTertiary, letterSpacing: 1.1)), const SizedBox(height: 4), Text(report.scoreLabel, style: AppTypography.title2.copyWith(color: scoreColor, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text('Diagnostico consolidado con ${report.cards.length} dimensiones.', style: AppTypography.caption.copyWith(color: textSecondary)), const SizedBox(height: 12), _KpiPill(icon: Icons.inventory_2_rounded, label: 'Afectados', value: '$affectedTotal', isDark: isDark), const SizedBox(height: 8), _KpiPill(icon: Icons.timer_outlined, label: 'Calculo total', value: '$parallelMs ms', isDark: isDark)]);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value, required this.color, required this.isDark});
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.28))), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 7), Text('$label: $value', style: AppTypography.caption.copyWith(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary, fontWeight: FontWeight.w600))]));
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color, required this.isDark});
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.16 : 0.12), borderRadius: BorderRadius.circular(999)), child: Text(label, style: AppTypography.caption2.copyWith(color: color, fontWeight: FontWeight.w700)));
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]))));
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.color, required this.isDark});
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.surface, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTypography.caption2.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 3), Text(value, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)]));
  }
}
