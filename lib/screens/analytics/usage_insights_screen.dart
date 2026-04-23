import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/usage_analytics_provider.dart';
import '../../services/usage_tracking_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UsageInsightsScreen
// Sprint 3 Business Questions: BQ1 · BQ5 · BQ7 · BQ8
// ─────────────────────────────────────────────────────────────────────────────

class UsageInsightsScreen extends ConsumerStatefulWidget {
  const UsageInsightsScreen({super.key});

  @override
  ConsumerState<UsageInsightsScreen> createState() =>
      _UsageInsightsScreenState();
}

class _UsageInsightsScreenState extends ConsumerState<UsageInsightsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    UsageTrackingService.shared.trackFeatureUsed('usageInsights');
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.read(bq1Provider.notifier).refresh();
    ref.read(bq5Provider.notifier).refresh();
    ref.read(bq7Provider.notifier).refresh();
    ref.read(bq8Provider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Uso & Analítica',
                style: AppTypography.headline
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            Text('Sprint 3 — BQ1 · BQ5 · BQ7 · BQ8',
                style: AppTypography.caption2
                    .copyWith(color: Colors.white54)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
            tooltip: 'Actualizar datos',
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.teaGreen,
          indicatorWeight: 3,
          labelColor: AppColors.teaGreen,
          unselectedLabelColor: Colors.white54,
          labelStyle: AppTypography.caption
              .copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTypography.caption,
          tabs: const [
            Tab(text: 'Latencia'),
            Tab(text: 'Horas Pico'),
            Tab(text: 'Escaneo vs Manual'),
            Tab(text: 'Funciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _BQ1Tab(),
          _BQ5Tab(),
          _BQ7Tab(),
          _BQ8Tab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TabScaffold extends StatelessWidget {
  final String bqTag;
  final Color tagColor;
  final String title;
  final String description;
  final Widget body;

  const _TabScaffold({
    required this.bqTag,
    required this.tagColor,
    required this.title,
    required this.description,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // ── Header card ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tagColor.withValues(alpha: isDark ? 0.25 : 0.12),
                tagColor.withValues(alpha: isDark ? 0.08 : 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tagColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  bqTag,
                  style: AppTypography.overline
                      .copyWith(color: tagColor, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.callout.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        body,
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: cardDecoration(isDark: isDark),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: AppTypography.overline.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surfaceSecondary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 32,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.callout.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Los datos aparecerán aquí al usar la app',
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _InsightBanner({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTypography.caption.copyWith(
                    color: color, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BQ1 — Latencia de procesamiento (Tipo 1 – Telemetría)
// ─────────────────────────────────────────────────────────────────────────────

class _BQ1Tab extends ConsumerWidget {
  const _BQ1Tab();

  static const _stages = [
    (label: 'Ingesta → API',             key: 'ingestion',   icon: Icons.cloud_upload_rounded,       color: AppColors.freshSky),
    (label: 'Storage (Firebase + Hive)', key: 'storage',     icon: Icons.storage_rounded,            color: Color(0xFF8B5CF6)),
    (label: 'Procesamiento',             key: 'processing',  icon: Icons.settings_rounded,           color: AppColors.warning),
    (label: 'Cómputo (Riverpod)',        key: 'computation', icon: Icons.speed_rounded,              color: AppColors.success),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bq1 = ref.watch(bq1Provider);
    final isDark = context.isDark;

    return _TabScaffold(
      bqTag: 'BQ1 · TIPO 1',
      tagColor: AppColors.freshSky,
      title: 'Latencia promedio de procesamiento',
      description: '¿Cuál es la latencia promedio entre la recepción de '
          'un evento de inventario y su persistencia en base de datos?',
      body: bq1.when(
        loading: () => const _SectionCard(child: _LoadingState()),
        error: (e, _) => _InsightBanner(
          text: 'Error al cargar: $e',
          color: AppColors.error,
          icon: Icons.error_outline_rounded,
        ),
        data: (state) {
          if (state.totalRecords == 0) {
            return _SectionCard(
              child: _EmptyState(
                icon: Icons.timer_outlined,
                message: 'Realiza acciones en el inventario\npara generar registros de latencia',
              ),
            );
          }

          final values = [
            state.avgIngestionMs,
            state.avgStorageMs,
            state.avgProcessingMs,
            state.avgComputationMs,
          ];
          final totalLatencyMs = values.fold<double>(0, (sum, value) => sum + value);
          final maxMs = values.reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);

          return Column(
            children: [
              // KPI summary row
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Registros',
                      value: '${state.totalRecords}',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.freshSky,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Latencia total',
                      value: '${totalLatencyMs.toStringAsFixed(0)} ms',
                      icon: Icons.timeline_rounded,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                        label: 'Latencia por etapa',
                        color: AppColors.freshSky),
                    const SizedBox(height: 16),
                    ..._stages.asMap().entries.map((e) {
                      final stage = e.value;
                      final ms = values[e.key];
                      final ratio = (ms / maxMs).clamp(0.0, 1.0);
                      return _LatencyBar(
                        icon: stage.icon,
                        label: stage.label,
                        ms: ms,
                        ratio: ratio,
                        color: stage.color,
                        isDark: isDark,
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _InsightBanner(
                icon: Icons.info_outline_rounded,
                color: AppColors.freshSky,
                text: 'La vista combina telemetría real de HTTP, caché/persistencia local, '
                    'procesamiento y cómputo reactivo para cada etapa del flujo.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LatencyBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final double ms;
  final double ratio;
  final Color color;
  final bool isDark;

  const _LatencyBar({
    required this.icon,
    required this.label,
    required this.ms,
    required this.ratio,
    required this.color,
    required this.isDark,
  });

  Color get _statusColor {
    if (ms == 0) return AppColors.textTertiary;
    if (ms < 100) return AppColors.success;
    if (ms < 300) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ms == 0 ? '—' : '${ms.toStringAsFixed(1)} ms',
                  style: AppTypography.caption2
                      .copyWith(color: _statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceSecondary
                  : AppColors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: AppTypography.title2.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BQ5 — Horas pico (Tipo 2 – UX)
// ─────────────────────────────────────────────────────────────────────────────

class _BQ5Tab extends ConsumerWidget {
  const _BQ5Tab();

  static const _screenNames = <String, String>{
    'home':         'Inicio',
    'products':     'Inventario',
    'restock':      'Reabastecer',
    'analytics':    'Analítica',
    'scan':         'Escanear',
    'notifications':'Notificaciones',
    'settings':     'Configuración',
    'usageInsights':'Uso & Analítica',
  };

  static const _screenIcons = <String, IconData>{
    'home':         Icons.home_rounded,
    'products':     Icons.inventory_2_rounded,
    'restock':      Icons.refresh_rounded,
    'analytics':    Icons.bar_chart_rounded,
    'scan':         Icons.camera_enhance_rounded,
    'notifications':Icons.notifications_rounded,
    'settings':     Icons.settings_rounded,
    'usageInsights':Icons.insights_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bq5 = ref.watch(bq5Provider);
    final isDark = context.isDark;

    return _TabScaffold(
      bqTag: 'BQ5 · TIPO 2',
      tagColor: AppColors.success,
      title: 'Pantallas en horas pico',
      description: '¿En qué pantallas interactúa el usuario más durante '
          'sus horas de mayor actividad de negocio?',
      body: bq5.when(
        loading: () => const _SectionCard(child: _LoadingState()),
        error: (e, _) => _InsightBanner(
          text: 'Error al cargar: $e',
          color: AppColors.error,
          icon: Icons.error_outline_rounded,
        ),
        data: (insights) {
          if (insights.isEmpty) {
            return _SectionCard(
              child: _EmptyState(
                icon: Icons.access_time_rounded,
                message: 'Navega por las pantallas de la app\npara registrar datos de sesión',
              ),
            );
          }

          // Detect peak hour
          final hourTotals = <int, double>{};
          for (final i in insights) {
            hourTotals[i.hour] = (hourTotals[i.hour] ?? 0) + i.totalSeconds;
          }
          final peakHour = hourTotals.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;

          final peakScreens = insights
              .where((i) => i.hour == peakHour)
              .toList()
            ..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));

          final maxSec = peakScreens.isEmpty ? 1.0 : peakScreens.first.totalSeconds;
          final colors = [
            AppColors.success, AppColors.freshSky,
            const Color(0xFF8B5CF6), AppColors.warning,
            AppColors.error, AppColors.deepSpaceBlue,
          ];

          return Column(
            children: [
              // Peak hour tile
              _SectionCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.schedule_rounded,
                          color: AppColors.success, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hora pico detectada',
                            style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '${peakHour.toString().padLeft(2, '0')}:00 – '
                          '${(peakHour + 1).toString().padLeft(2, '0')}:00',
                          style: AppTypography.title2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                        label: 'Pantallas más activas a las $peakHour:00',
                        color: AppColors.success),
                    const SizedBox(height: 16),
                    ...peakScreens.take(6).toList().asMap().entries.map((e) {
                      final s = e.value;
                      final color = colors[e.key % colors.length];
                      final name = _screenNames[s.screenName] ?? s.screenName;
                      final icon = _screenIcons[s.screenName] ?? Icons.apps_rounded;
                      final ratio = (s.totalSeconds / maxSec).clamp(0.0, 1.0);
                      final mins = (s.totalSeconds / 60).toStringAsFixed(1);
                      return _ScreenRow(
                        rank: e.key + 1,
                        name: name,
                        icon: icon,
                        mins: mins,
                        visits: s.visits,
                        ratio: ratio,
                        color: color,
                        isDark: isDark,
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScreenRow extends StatelessWidget {
  final int rank;
  final String name;
  final IconData icon;
  final String mins;
  final int visits;
  final double ratio;
  final Color color;
  final bool isDark;

  const _ScreenRow({
    required this.rank,
    required this.name,
    required this.icon,
    required this.mins,
    required this.visits,
    required this.ratio,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$rank',
                style: AppTypography.caption2.copyWith(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                )),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        )),
                    Text('$mins min · $visits visitas',
                        style: AppTypography.caption2.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        )),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceSecondary
                        : AppColors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation(color),
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
// BQ7 — Escaneo vs Manual (Tipo 3 – Features)
// ─────────────────────────────────────────────────────────────────────────────

class _BQ7Tab extends ConsumerWidget {
  const _BQ7Tab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bq7 = ref.watch(bq7Provider);
    final isDark = context.isDark;

    return _TabScaffold(
      bqTag: 'BQ7 · TIPO 3',
      tagColor: const Color(0xFF8B5CF6),
      title: 'Precisión: escaneo vs entrada manual',
      description: '¿Cómo afecta el uso del escáner de código de barras '
          'vs la entrada manual la precisión del inventario en 30 días?',
      body: bq7.when(
        loading: () => const _SectionCard(child: _LoadingState()),
        error: (e, _) => _InsightBanner(
          text: 'Error al cargar: $e',
          color: AppColors.error,
          icon: Icons.error_outline_rounded,
        ),
        data: (insights) {
          final hasData = insights.any((i) => i.total > 0);
          if (!hasData) {
            return _SectionCard(
              child: _EmptyState(
                icon: Icons.qr_code_scanner_rounded,
                message: 'Agrega productos escaneando o manualmente\npara ver la comparativa de precisión',
              ),
            );
          }

          final barcode = insights.firstWhere(
              (i) => i.method == 'barcode',
              orElse: () => ScanAccuracyInsight(method: 'barcode', total: 0, accurate: 0));
          final manual = insights.firstWhere(
              (i) => i.method == 'manual',
              orElse: () => ScanAccuracyInsight(method: 'manual', total: 0, accurate: 0));

          final barcodeColor = const Color(0xFF8B5CF6);
          const manualColor = AppColors.warning;

          final diff = ((barcode.accuracyRate - manual.accuracyRate) * 100).abs();
          final better = barcode.accuracyRate >= manual.accuracyRate
              ? 'el escaneo de código'
              : 'la entrada manual';

          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AccuracyCard(
                      icon: Icons.qr_code_scanner_rounded,
                      method: 'Escaneo',
                      accurate: barcode.accurate,
                      total: barcode.total,
                      rate: barcode.accuracyRate,
                      color: barcodeColor,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AccuracyCard(
                      icon: Icons.edit_rounded,
                      method: 'Manual',
                      accurate: manual.accurate,
                      total: manual.total,
                      rate: manual.accuracyRate,
                      color: manualColor,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                        label: 'Comparativa visual', color: Color(0xFF8B5CF6)),
                    const SizedBox(height: 14),
                    _CompareRow(
                      label: 'Escaneo',
                      value: barcode.accuracyRate,
                      color: barcodeColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _CompareRow(
                      label: 'Manual',
                      value: manual.accuracyRate,
                      color: manualColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (diff > 0)
                _InsightBanner(
                  icon: Icons.lightbulb_outline_rounded,
                  color: const Color(0xFF8B5CF6),
                  text: '$better es ${diff.toStringAsFixed(1)}% más preciso '
                      'en los últimos 30 días. '
                      '${barcode.total + manual.total} productos registrados en total.',
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  final IconData icon;
  final String method;
  final int accurate;
  final int total;
  final double rate;
  final Color color;
  final bool isDark;

  const _AccuracyCard({
    required this.icon,
    required this.method,
    required this.accurate,
    required this.total,
    required this.rate,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(isDark: isDark),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0 ? '—' : '${(rate * 100).toStringAsFixed(0)}%',
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text('precisión',
              style: AppTypography.overline.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              )),
          const SizedBox(height: 8),
          Text(method,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              )),
          const SizedBox(height: 4),
          Text('$accurate / $total registros',
              style: AppTypography.caption2.copyWith(
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              )),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isDark;

  const _CompareRow({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: AppTypography.caption.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceSecondary
                  : AppColors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${(value * 100).toStringAsFixed(0)}%',
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BQ8 — Frecuencia de funciones (Tipo 3 – Features)
// ─────────────────────────────────────────────────────────────────────────────

class _BQ8Tab extends ConsumerWidget {
  const _BQ8Tab();

  static const _names = <String, String>{
    'salesTrendChart':    'Tendencia de Ventas',
    'categoryPieChart':  'Distribución Categorías',
    'stockBarChart':     'Stock por Categoría',
    'alertsPanel':       'Panel de Alertas',
    'aiAssistant':       'Asistente IA',
    'reports':           'Exportar Reportes',
    'usageInsights':     'Uso & Analítica',
    'restockSuggestions':'Sugerencias de Reabasto',
  };

  static const _icons = <String, IconData>{
    'salesTrendChart':   Icons.show_chart_rounded,
    'categoryPieChart':  Icons.pie_chart_rounded,
    'stockBarChart':     Icons.bar_chart_rounded,
    'alertsPanel':       Icons.notifications_active_rounded,
    'aiAssistant':       Icons.smart_toy_rounded,
    'reports':           Icons.file_download_rounded,
    'usageInsights':     Icons.insights_rounded,
    'restockSuggestions':Icons.refresh_rounded,
  };

  static const _palette = [
    AppColors.freshSky,
    AppColors.success,
    Color(0xFF8B5CF6),
    AppColors.warning,
    AppColors.error,
    AppColors.deepSpaceBlue,
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bq8 = ref.watch(bq8Provider);
    final isDark = context.isDark;

    return _TabScaffold(
      bqTag: 'BQ8 · TIPO 3',
      tagColor: AppColors.warning,
      title: 'Funciones analíticas más usadas',
      description: '¿Qué funciones (alertas, reportes, recomendaciones) '
          'accede el usuario más en una semana, y cuáles usa poco?',
      body: bq8.when(
        loading: () => const _SectionCard(child: _LoadingState()),
        error: (e, _) => _InsightBanner(
          text: 'Error al cargar: $e',
          color: AppColors.error,
          icon: Icons.error_outline_rounded,
        ),
        data: (insights) {
          if (insights.isEmpty) {
            return _SectionCard(
              child: _EmptyState(
                icon: Icons.bar_chart_rounded,
                message: 'Usa las funciones analíticas de la app\npara ver cuáles son más valiosas',
              ),
            );
          }

          final maxCount = insights.first.usageCount;

          return Column(
            children: [
              // Top 3 podium
              if (insights.length >= 2)
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                          label: 'Top funciones esta semana',
                          color: AppColors.warning),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (insights.length >= 2)
                            Expanded(
                              child: _PodiumTile(
                                rank: 2,
                                name: _names[insights[1].featureName] ??
                                    insights[1].featureName,
                                icon: _icons[insights[1].featureName] ??
                                    Icons.star_rounded,
                                count: insights[1].usageCount,
                                color: const Color(0xFF94A3B8),
                                height: 80,
                                isDark: isDark,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _PodiumTile(
                              rank: 1,
                              name: _names[insights[0].featureName] ??
                                  insights[0].featureName,
                              icon: _icons[insights[0].featureName] ??
                                  Icons.star_rounded,
                              count: insights[0].usageCount,
                              color: AppColors.warning,
                              height: 100,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (insights.length >= 3)
                            Expanded(
                              child: _PodiumTile(
                                rank: 3,
                                name: _names[insights[2].featureName] ??
                                    insights[2].featureName,
                                icon: _icons[insights[2].featureName] ??
                                    Icons.star_rounded,
                                count: insights[2].usageCount,
                                color: const Color(0xFFCD7F32),
                                height: 65,
                                isDark: isDark,
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                        label: 'Ranking completo', color: AppColors.warning),
                    const SizedBox(height: 14),
                    ...insights.take(8).toList().asMap().entries.map((e) {
                      final ins = e.value;
                      final color = _palette[e.key % _palette.length];
                      final name = _names[ins.featureName] ?? ins.featureName;
                      final icon = _icons[ins.featureName] ?? Icons.apps_rounded;
                      final ratio =
                          (ins.usageCount / maxCount).clamp(0.0, 1.0);
                      return _FeatureRow(
                        rank: e.key + 1,
                        name: name,
                        icon: icon,
                        count: ins.usageCount,
                        weeks: ins.weekCount,
                        ratio: ratio,
                        color: color,
                        isDark: isDark,
                      );
                    }),
                  ],
                ),
              ),
              if (insights.length >= 2) ...[
                const SizedBox(height: 10),
                _InsightBanner(
                  icon: Icons.lightbulb_outline_rounded,
                  color: AppColors.warning,
                  text: '"${_names[insights.first.featureName] ?? insights.first.featureName}" '
                      'es la función más usada. '
                      '"${_names[insights.last.featureName] ?? insights.last.featureName}" '
                      'tiene baja adopción — considera añadir acceso directo o tutorial.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PodiumTile extends StatelessWidget {
  final int rank;
  final String name;
  final IconData icon;
  final int count;
  final Color color;
  final double height;
  final bool isDark;

  const _PodiumTile({
    required this.rank,
    required this.name,
    required this.icon,
    required this.count,
    required this.color,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          name,
          style: AppTypography.caption2.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text('$count',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            )),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text('#$rank',
                style: AppTypography.overline
                    .copyWith(color: color, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final int rank;
  final String name;
  final IconData icon;
  final int count;
  final int weeks;
  final double ratio;
  final Color color;
  final bool isDark;

  const _FeatureRow({
    required this.rank,
    required this.name,
    required this.icon,
    required this.count,
    required this.weeks,
    required this.ratio,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text('$rank',
                style: AppTypography.caption2.copyWith(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                )),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(name,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('$count uso${count == 1 ? '' : 's'}',
                        style: AppTypography.caption2.copyWith(
                            color: color, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceSecondary
                        : AppColors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 2),
                Text('$weeks semana${weeks == 1 ? '' : 's'} con actividad',
                    style: AppTypography.caption2.copyWith(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
