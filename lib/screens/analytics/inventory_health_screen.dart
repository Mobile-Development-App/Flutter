import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/inventory_health_provider.dart';
import '../../services/inventory_health_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventoryHealthScreen — Sprint 4 (New Feature)
//
// WHAT THIS SCREEN DOES:
//   Presents a consolidated "Store Health Score" derived from 4 concurrent
//   Isolate analyses running in parallel via Future.wait() + compute().
//
// WHY IT'S NEW:
//   • No Health Score or consolidated multi-dimension analysis existed before.
//   • The animated score ring, per-card timing footer, and copy-to-clipboard
//     report are all brand-new UI patterns not present in Sprint 2 or Sprint 3.
//
// CONCURRENCY MADE VISIBLE:
//   • Each HealthCard shows its Isolate wall-clock time.
//   • The AppBar footer shows the TOTAL parallel time.
//   • A "sum of sequential" label lets the user compare and see the speedup.
// ─────────────────────────────────────────────────────────────────────────────

class InventoryHealthScreen extends ConsumerStatefulWidget {
  const InventoryHealthScreen({super.key});

  @override
  ConsumerState<InventoryHealthScreen> createState() =>
      _InventoryHealthScreenState();
}

class _InventoryHealthScreenState extends ConsumerState<InventoryHealthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnim =
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

    // Auto-refresh on first open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
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
    final text =
        await ref.read(inventoryHealthProvider.notifier).generateTextReport();
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reporte copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final healthAsync = ref.watch(inventoryHealthProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkNavBackground : AppColors.inkBlack,
        foregroundColor: Colors.white,
        title: const Text('Salud del Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_rounded),
            tooltip: 'Copiar reporte',
            onPressed: healthAsync.value != null ? _copyReport : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recalcular',
            onPressed: _refresh,
          ),
        ],
      ),
      body: healthAsync.when(
        loading: () => _LoadingView(isDark: isDark),
        error: (e, _) => _ErrorView(error: e, onRetry: _refresh),
        data: (report) {
          if (report == null) return _EmptyView(onAnalyse: _refresh);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _ReportView(
              report: report,
              ringAnim: _ringAnim,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReportView — main content
// ─────────────────────────────────────────────────────────────────────────────

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.ringAnim,
    required this.isDark,
  });

  final InventoryHealthReport report;
  final Animation<double> ringAnim;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final seqMs = report.cards
        .fold<int>(0, (s, c) => s + c.computedIn.inMilliseconds);
    final parallelMs = report.totalComputedIn.inMilliseconds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // ── Score ring ──────────────────────────────────────────────────────
        _ScoreRing(report: report, animation: ringAnim, isDark: isDark),
        const SizedBox(height: 8),

        // ── Concurrency timing banner ────────────────────────────────────────
        _ConcurrencyBanner(
          parallelMs: parallelMs,
          seqMs: seqMs,
          isDark: isDark,
        ),
        const SizedBox(height: 24),

        // ── Section label ────────────────────────────────────────────────────
        Text(
          'DIMENSIONES DE SALUD',
          style: AppTypography.overline.copyWith(
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // ── 4 health cards ───────────────────────────────────────────────────
        ...report.cards.map((card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HealthCard(card: card, isDark: isDark),
            )),

        // ── Generated-at footer ──────────────────────────────────────────────
        const SizedBox(height: 8),
        Text(
          'Generado el ${_fmt(report.generatedAt)}  ·  '
          'Jala hacia abajo para recalcular',
          style: AppTypography.caption2.copyWith(
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScoreRing — animated arc + score display
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.report,
    required this.animation,
    required this.isDark,
  });

  final InventoryHealthReport report;
  final Animation<double> animation;
  final bool isDark;

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
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _RingPainter(
                progress: report.overallScore / 100 * progress,
                color: _scoreColor,
                bgColor: isDark
                    ? AppColors.darkSurface
                    : AppColors.surfaceSecondary,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (report.overallScore * progress)
                          .toStringAsFixed(0),
                      style: AppTypography.largeTitle.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: _scoreColor,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _scoreColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        report.scoreLabel,
                        style: AppTypography.caption.copyWith(
                          color: _scoreColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  final double progress;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    const strokeWidth = 14.0;
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Background track
    paint.color = bgColor;
    canvas.drawCircle(center, radius, paint);

    // Arc
    paint.color = color;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// _ConcurrencyBanner — shows parallel vs sequential time
// ─────────────────────────────────────────────────────────────────────────────

class _ConcurrencyBanner extends StatelessWidget {
  const _ConcurrencyBanner({
    required this.parallelMs,
    required this.seqMs,
    required this.isDark,
  });

  final int parallelMs;
  final int seqMs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final speedup = seqMs > 0 ? seqMs / math.max(parallelMs, 1) : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.teaGreen.withOpacity(isDark ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.teaGreen.withOpacity(isDark ? 0.3 : 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded,
              color: AppColors.teaGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4 Isolates en paralelo — ${parallelMs} ms total',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Secuencial estimado: ${seqMs} ms  ·  '
                  '${speedup.toStringAsFixed(1)}× más rápido',
                  style: AppTypography.caption2.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HealthCard — one analysis dimension
// ─────────────────────────────────────────────────────────────────────────────

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
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.border;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _scoreColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: _scoreColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.dimension.label,
                        style: AppTypography.callout.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Peso: ${(card.dimension.weight * 100).toStringAsFixed(0)} %',
                        style: AppTypography.caption2
                            .copyWith(color: textTertiary),
                      ),
                    ],
                  ),
                ),
                // Score chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    card.score.toStringAsFixed(1),
                    style: AppTypography.headline.copyWith(
                      color: _scoreColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Score bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: card.score / 100,
                minHeight: 6,
                backgroundColor:
                    isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation(_scoreColor),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Headline + insight ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.headline,
                  style: AppTypography.callout
                      .copyWith(color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  card.insight,
                  style: AppTypography.caption
                      .copyWith(color: textSecondary),
                ),
              ],
            ),
          ),

          // ── Wall-clock footer (concurrency proof) ───────────────────────────
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Icon(Icons.memory_rounded,
                    size: 12, color: textTertiary),
                const SizedBox(width: 4),
                Text(
                  'Isolate: ${card.computedIn.inMilliseconds} ms',
                  style: AppTypography.caption2
                      .copyWith(color: textTertiary),
                ),
                const SizedBox(width: 8),
                Text(
                  '·',
                  style: AppTypography.caption2
                      .copyWith(color: textTertiary),
                ),
                const SizedBox(width: 8),
                Text(
                  '${card.affectedCount} afectados',
                  style: AppTypography.caption2
                      .copyWith(color: textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error / Empty states
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation(AppColors.freshSky)),
          const SizedBox(height: 20),
          Text(
            'Ejecutando 4 Isolates en paralelo…',
            style: AppTypography.callout.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stock Muerto · Vencimiento · Márgenes · Balance',
            style: AppTypography.caption2.copyWith(
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error al calcular salud',
                style: AppTypography.headline),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: AppTypography.caption,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAnalyse});
  final VoidCallback onAnalyse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.health_and_safety_outlined,
                size: 64, color: AppColors.freshSky),
            const SizedBox(height: 16),
            Text('Analiza la salud de tu inventario',
                style: AppTypography.title2,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Ejecuta 4 análisis concurrentes en Isolates separados '
              'y obtén un puntaje consolidado.',
              style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.freshSky),
              onPressed: onAnalyse,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Analizar ahora'),
            ),
          ],
        ),
      ),
    );
  }
}
