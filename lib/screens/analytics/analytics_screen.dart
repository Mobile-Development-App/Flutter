import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';
import '../../providers/analytics_provider.dart';
import '../../widgets/widgets.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() =>
      _AnalyticsScreenState();
}

class _AnalyticsScreenState
    extends ConsumerState<AnalyticsScreen> {

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final state = ref.watch(analyticsProvider).value;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Analítica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded),
            onPressed: () => ref
                .read(analyticsProvider.notifier)
                .exportReport(),
          ),
        ],
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _timeRangeSelector(state, isDark),
                  const SizedBox(height: 20),
                  _summaryStats(state, isDark),
                  const SizedBox(height: 20),
                  _salesTrendChart(state, isDark),
                  const SizedBox(height: 20),
                  _stockLevelsChart(state, isDark),
                  const SizedBox(height: 20),
                  _categoryDistributionChart(state, isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _timeRangeSelector(AnalyticsState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: TimeRange.values.map((range) {
          final isSelected = state.selectedTimeRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref
                    .read(analyticsProvider.notifier)
                    .loadData(range);
                HapticManager.selection();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.deepSpaceBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  range.value,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryStats(AnalyticsState state, bool isDark) {
    return Row(
      children: [
        Expanded(
            child: _summaryCard('Ventas Totales',
                state.totalSales.compactCurrency,
                Icons.monetization_on_rounded,
                AppColors.success,
                isDark,
                trend: state.salesTrend)),
        const SizedBox(width: 12),
        Expanded(
            child: _summaryCard(
                'Promedio Diario',
                state.averageDailySales.compactCurrency,
                Icons.trending_up_rounded,
                AppColors.deepSpaceBlue,
                isDark)),
        const SizedBox(width: 12),
        Expanded(
            child: _summaryCard(
                'Pedidos',
                '${state.totalOrders}',
                Icons.shopping_bag_rounded,
                AppColors.freshSky,
                isDark)),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon,
      Color color, bool isDark,
      {double? trend}) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.headline.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  trend >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 10,
                  color: trend >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
                Text(
                  '${trend.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: trend >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _salesTrendChart(AnalyticsState state, bool isDark) {
    final spots = state.salesData.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), e.value.sales / 1000000);
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tendencia de Ventas',
                  style: AppTypography.headline),
              Text(state.selectedTimeRange.label,
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: spots.isEmpty
                ? const Center(
                    child: Text('Sin datos'))
                : LineChart(LineChartData(
                    gridData:
                        FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppColors.border
                                .withValues(alpha: 0.5),
                            strokeWidth: 1,
                          ),
                        ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (v, _) => Text(
                            '\$${v.toStringAsFixed(1)}M',
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: state.salesData.length > 14
                              ? (state.salesData.length / 7)
                                  .ceilToDouble()
                              : 1,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i >= 0 &&
                                i < state.salesData.length) {
                              return Text(
                                state.salesData[i].date
                                    .dayMonth,
                                style: const TextStyle(
                                    fontSize: 9,
                                    color:
                                        AppColors.textSecondary),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.deepSpaceBlue,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.deepSpaceBlue
                                  .withValues(alpha: 0.2),
                              AppColors.deepSpaceBlue
                                  .withValues(alpha: 0.02),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  )),
          ),
        ],
      ),
    );
  }

  Widget _stockLevelsChart(AnalyticsState state, bool isDark) {
    final data = state.stockLevelData;

    if (data.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Niveles de Stock', style: AppTypography.headline),
          const SizedBox(height: 40),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart_rounded,
                  color: AppColors.textTertiary, size: 36),
              const SizedBox(height: 8),
              Text('Agrega productos para ver este gráfico',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Niveles de Stock', style: AppTypography.headline),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(BarChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i >= 0 && i < data.length) {
                        // Safe truncation — never crash on short strings
                        final cat = data[i].category;
                        final label = cat.length > 4
                            ? cat.substring(0, 4)
                            : cat;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label,
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              barGroups: data.asMap().entries.map((e) {
                final d = e.value;
                return BarChartGroupData(
                  x: e.key,
                  groupVertically: false,
                  barRods: [
                    BarChartRodData(
                        toY: d.inStock.toDouble(),
                        color: AppColors.success,
                        width: 8,
                        borderRadius: BorderRadius.circular(3)),
                    BarChartRodData(
                        toY: d.lowStock.toDouble(),
                        color: AppColors.warning,
                        width: 8,
                        borderRadius: BorderRadius.circular(3)),
                    BarChartRodData(
                        toY: d.outOfStock.toDouble(),
                        color: AppColors.error,
                        width: 8,
                        borderRadius: BorderRadius.circular(3)),
                  ],
                );
              }).toList(),
            )),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(AppColors.success, 'En Stock'),
              const SizedBox(width: 16),
              _legendItem(AppColors.warning, 'Stock Bajo'),
              const SizedBox(width: 16),
              _legendItem(AppColors.error, 'Agotado'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryDistributionChart(AnalyticsState state, bool isDark) {
    final dist = state.categoryDistribution;

    if (dist.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Distribución por Categoría', style: AppTypography.headline),
          const SizedBox(height: 40),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.pie_chart_outline_rounded,
                  color: AppColors.textTertiary, size: 36),
              const SizedBox(height: 8),
              Text('Agrega productos para ver este gráfico',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      );
    }

    // Palette for pie slices — cycles through if more categories than colors
    const palette = [
      AppColors.freshSky, AppColors.success, AppColors.warning,
      AppColors.deepSpaceBlue, AppColors.error, AppColors.teaGreen,
      Color(0xFF9B59B6), Color(0xFFE67E22), Color(0xFF1ABC9C),
      Color(0xFF34495E),
    ];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distribución por Categoría', style: AppTypography.headline),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sections: dist.asMap().entries.map((e) {
                final color = palette[e.key % palette.length];
                return PieChartSectionData(
                  value: e.value.count.toDouble(),
                  color: color,
                  radius: 70,
                  title: e.value.count > 0
                      ? '${e.value.percentage.toStringAsFixed(0)}%'
                      : '',
                  titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            )),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: dist.asMap().entries.map((e) {
              final color = palette[e.key % palette.length];
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  '${e.value.category} (${e.value.count})',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: AppTypography.caption2
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

}
