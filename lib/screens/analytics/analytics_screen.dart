import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/analytics_data.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../widgets/app_card.dart';
import '../../services/usage_tracking_service.dart';
import 'business_questions_screen.dart';
import '../inventory/location_walk_screen.dart';
import 'usage_insights_screen.dart';
import '../inventory/stock_count_screen.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedRange = 0;
  bool _analyticsTracked = false;
  bool _animate = false;

  static const List<String> _ranges = ['7d', '30d', '90d', '1a'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animate = true);
    });
  }

  int get _selectedDays {
    switch (_selectedRange) {
      case 0:
        return 7;
      case 1:
        return 30;
      case 2:
        return 90;
      case 3:
        return 365;
      default:
        return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final inventoryAsync = ref.watch(inventoryProvider);
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Analítica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Recorrido por ubicación',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LocationWalkScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_rounded),
            tooltip: 'Conteo en góndola',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StockCountScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.quiz_rounded),
            tooltip: 'Business Questions',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BusinessQuestionsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Uso y Analítica · BQ2',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UsageInsightsScreen(initialTabIndex: 1),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Uso y analítica (todas las BQ)',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UsageInsightsScreen(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
      body: inventoryAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error cargando analítica:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (inventoryState) {
          final products = inventoryState.products;

          final analyticsState = analyticsAsync.value;
          final salesData = analyticsState?.salesData ?? [];
          final hasSales = salesData.isNotEmpty;

          final totalSales = hasSales ? (analyticsState?.totalSales ?? 0.0) : null;
          final averageDaily = hasSales ? (analyticsState?.averageDailySales ?? 0.0) : null;
          final totalOrders = hasSales ? (analyticsState?.totalOrders ?? 0) : null;

          final salesSpots = _buildSalesTrend(salesData);
          final stockBars = _buildStockBarData(products);
          final categorySections = _buildCategorySections(products);

          // BQ8 — registra UNA SOLA VEZ que el usuario accedió a analítica.
          // El flag evita re-registrar el evento en cada rebuild del widget.
          if (!_analyticsTracked) {
            _analyticsTracked = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              UsageTrackingService.shared.trackFeatureUsed('salesTrendChart');
              UsageTrackingService.shared.trackFeatureUsed('stockBarChart');
              UsageTrackingService.shared.trackFeatureUsed('categoryPieChart');
            });
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              10, 14, 10,
              MediaQuery.of(context).padding.bottom + 64 + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    _insightsEntryBanner(context, isDark),
                    const SizedBox(height: 14),
                    _rangeSelector(isDark),
                    const SizedBox(height: 18),

                    AnimatedOpacity(
                      opacity: _animate ? 1 : 0,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutQuad,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _summaryCard(
                              icon: Icons.attach_money_rounded,
                              iconColor: AppColors.success,
                              value: totalSales != null
                                  ? _compactCurrency(totalSales)
                                  : '—',
                              title: 'Ventas del Período',
                              subtitle: _labelRangeText(),
                              subtitleColor: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _summaryCard(
                              icon: Icons.show_chart_rounded,
                              iconColor: AppColors.deepSpaceBlue,
                              value: averageDaily != null
                                  ? _compactCurrency(averageDaily)
                                  : '—',
                              title: 'Promedio Diario',
                              subtitle: '$_selectedDays días',
                              subtitleColor: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _summaryCard(
                              icon: Icons.shopping_bag_outlined,
                              iconColor: AppColors.info,
                              value: totalOrders != null ? '$totalOrders' : '—',
                              title: 'Órdenes',
                              subtitle: '${products.length} productos',
                              subtitleColor: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),
                    _chartCard(
                  title: 'Tendencia de Ventas',
                  trailing: _labelRangeText(),
                  child: salesData.isEmpty
                          ? AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _emptySalesChartState(),
                            )
                          : AnimatedOpacity(
                              duration: const Duration(milliseconds: 420),
                              opacity: _animate ? 1 : 0,
                              child: SizedBox(
                                height: 290,
                                child: LineChart(
                                  LineChartData(
                                    minY: _minY(salesSpots),
                                    maxY: _maxY(salesSpots),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: _horizontalStep(salesSpots),
                                      getDrawingHorizontalLine: (_) => FlLine(
                                        color: Colors.grey.withValues(alpha: 0.15),
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 68,
                                          interval: _horizontalStep(salesSpots),
                                          getTitlesWidget: (value, meta) {
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: Text(
                                                _compactCurrency(value),
                                                style: AppTypography.caption2.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 10,
                                                ),
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < 0 || index >= salesData.length) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(
                                                _xLabel(index, salesData),
                                                style: AppTypography.caption2.copyWith(
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: salesSpots,
                                        isCurved: true,
                                        barWidth: 3,
                                        color: const Color(0xFF083D68),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              const Color(0xFF083D68).withValues(alpha: 0.18),
                                              const Color(0xFF083D68).withValues(alpha: 0.03),
                                            ],
                                          ),
                                        ),
                                        dotData: const FlDotData(show: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                ),

                const SizedBox(height: 16),
                _chartCard(
                  title: 'Niveles de Stock',
                  child: SizedBox(
                    height: 310,
                    child: Column(
                      children: [
                        Expanded(
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _stockMaxY(stockBars),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= stockBars.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          stockBars[i].label,
                                          style: AppTypography.caption2.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (int i = 0; i < stockBars.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barsSpace: 6,
                                    barRods: [
                                      for (final rod in stockBars[i].rods)
                                        BarChartRodData(
                                          toY: rod.value,
                                          width: 12,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          color: rod.color,
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 20,
                          runSpacing: 10,
                          children: const [
                            _LegendDot(
                              color: Color(0xFF37C66B),
                              label: 'En Stock',
                            ),
                            _LegendDot(
                              color: Color(0xFFF39C12),
                              label: 'Stock Bajo',
                            ),
                            _LegendDot(
                              color: Color(0xFFE74C3C),
                              label: 'Agotado',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _chartCard(
                  title: 'Distribución por Categoría',
                  child: SizedBox(
                    height: 320,
                    child: Column(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 42,
                              startDegreeOffset: -90,
                              sections: categorySections,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 18,
                          runSpacing: 10,
                          children: [
                            for (final item in _categoryLegend(products))
                              _LegendDot(
                                color: item.color,
                                label: '${item.label} (${item.count})',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _chartCard(
                  title: 'Smart Feature',
                  child: _smartFeatureSection(products, isDark),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _insightsEntryBanner(BuildContext context, bool isDark) {
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const UsageInsightsScreen(initialTabIndex: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bug_report_rounded,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uso & Analítica · mi BQ2',
                      style: AppTypography.callout.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pantallas con más crashes al actualizar inventario. '
                      'Toca aquí → pestaña «BQ2 Crashes».',
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rangeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: List.generate(_ranges.length, (index) {
          final selected = _selectedRange == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedRange = index);
                const ranges = [
                  TimeRange.week,
                  TimeRange.month,
                  TimeRange.quarter,
                  TimeRange.year,
                ];
                ref
                    .read(analyticsProvider.notifier)
                    .loadData(ranges[index]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF063B63)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _ranges[index],
                  textAlign: TextAlign.center,
                  style: AppTypography.callout.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String title,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.title2.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption2.copyWith(
              color: subtitleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard({
    required String title,
    String? trailing,
    required Widget child,
  }) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.title3.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _smartFeatureSection(List<Product> products, bool isDark) {
    final healthy = products.where((p) {
      return p.marginHealth == MarginHealth.high &&
          p.stockTrend != StockTrend.down &&
          p.stockStatus == StockStatus.inStock;
    }).toList();

    final risk = products.where((p) {
      return p.stockTrend == StockTrend.down ||
          p.stockStatus == StockStatus.lowStock ||
          p.stockStatus == StockStatus.outOfStock;
    }).toList();

    final lowMargin =
        products.where((p) => p.marginHealth == MarginHealth.low).toList();

    final loss =
        products.where((p) => p.marginHealth == MarginHealth.loss).toList();

    final topRestock = [...products]
      ..sort((a, b) {
        final aScore = _restockPriorityScore(a);
        final bScore = _restockPriorityScore(b);
        return bScore.compareTo(aScore);
      });

    final topProfitable = [...products]
      ..sort((a, b) => b.profitValue.compareTo(a.profitValue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visualiza automáticamente el estado del inventario según rentabilidad, disponibilidad y tendencia de stock.',
          style: AppTypography.body.copyWith(
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _smartStat(
              title: 'Saludables',
              value: '${healthy.length}',
              subtitle: 'Buen margen y stock',
              color: AppColors.success,
              icon: Icons.favorite_rounded,
            ),
            _smartStat(
              title: 'Riesgo',
              value: '${risk.length}',
              subtitle: 'Tendencia baja',
              color: AppColors.warning,
              icon: Icons.warning_amber_rounded,
            ),
            _smartStat(
              title: 'Margen bajo',
              value: '${lowMargin.length}',
              subtitle: 'Rentabilidad ajustada',
              color: Colors.orange,
              icon: Icons.trending_flat_rounded,
            ),
            _smartStat(
              title: 'Pérdida',
              value: '${loss.length}',
              subtitle: 'Precio < costo',
              color: AppColors.error,
              icon: Icons.trending_down_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _smartList(
          title: 'Prioridad de reposición',
          color: AppColors.warning,
          products: topRestock.take(3).toList(),
          formatter: (p) =>
              'Stock ${p.quantity} / mín ${p.minStock} · ${p.stockTrend.label}',
          emptyText: 'No hay productos críticos por reabastecer.',
        ),
        const SizedBox(height: 16),
        _smartList(
          title: 'Mayor ganancia potencial',
          color: AppColors.success,
          products: topProfitable.take(3).toList(),
          formatter: (p) =>
              'Ganancia ${p.profitValue.currencyFormatted} · Margen ${p.profitMargin.percentFormatted}',
          emptyText: 'No hay datos suficientes para calcular ganancias.',
        ),
        const SizedBox(height: 16),
        _smartRecommendation(products, isDark),
      ],
    );
  }

  Widget _smartStat({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title3.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.callout.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smartList({
    required String title,
    required Color color,
    required List<Product> products,
    required String Function(Product) formatter,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.callout.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          Text(
            emptyText,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          ...products.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        p.category.icon,
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.callout.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatter(p),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _smartRecommendation(List<Product> products, bool isDark) {
    final lossCount =
        products.where((p) => p.marginHealth == MarginHealth.loss).length;
    final lowStockCount = products
        .where((p) =>
            p.stockStatus == StockStatus.lowStock ||
            p.stockStatus == StockStatus.outOfStock)
        .length;
    final healthyCount = products
        .where((p) =>
            p.marginHealth == MarginHealth.high &&
            p.stockStatus == StockStatus.inStock)
        .length;

    String message;
    Color color;
    IconData icon;

    if (lossCount > 0) {
      message =
          'Hay productos vendiéndose con pérdida. La prioridad debe ser corregir precios o costos.';
      color = AppColors.error;
      icon = Icons.trending_down_rounded;
    } else if (lowStockCount > healthyCount) {
      message =
          'El principal riesgo actual es el abastecimiento. Conviene priorizar compras y reposición.';
      color = AppColors.warning;
      icon = Icons.inventory_2_rounded;
    } else {
      message =
          'El inventario se ve estable. Puedes potenciar los productos con mayor ganancia potencial.';
      color = AppColors.success;
      icon = Icons.insights_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recomendación automática',
                  style: AppTypography.callout.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTypography.caption.copyWith(
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

  List<FlSpot> _buildSalesTrend(List<SalesDataPoint> salesData) {
    return List.generate(salesData.length, (i) {
      return FlSpot(i.toDouble(), salesData[i].sales);
    });
  }

  Widget _emptySalesChartState() {
    return SizedBox(
      height: 290,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Sin historial de ventas',
              style: AppTypography.callout.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra ventas para ver tu tendencia',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_StockGroup> _buildStockBarData(List<Product> products) {
    final groups = <String, List<Product>>{};

    for (final p in products) {
      final label = _shortCategory(p.category.label);
      groups.putIfAbsent(label, () => []).add(p);
    }

    final entries = groups.entries.toList();

    if (entries.isEmpty) {
      return [
        _StockGroup(
          label: 'Sin',
          rods: [
            _StockRod(value: 1, color: const Color(0xFF37C66B)),
          ],
        ),
      ];
    }

    return entries.take(5).map((entry) {
      final items = entry.value;
      final inStock =
          items.where((p) => p.stockStatus == StockStatus.inStock).length;
      final low =
          items.where((p) => p.stockStatus == StockStatus.lowStock).length;
      final out =
          items.where((p) => p.stockStatus == StockStatus.outOfStock).length;

      final rods = <_StockRod>[];

      if (inStock > 0) {
        rods.add(
          _StockRod(
            value: inStock.toDouble(),
            color: const Color(0xFF37C66B),
          ),
        );
      }
      if (low > 0) {
        rods.add(
          _StockRod(
            value: low.toDouble(),
            color: const Color(0xFFF39C12),
          ),
        );
      }
      if (out > 0) {
        rods.add(
          _StockRod(
            value: out.toDouble(),
            color: const Color(0xFFE74C3C),
          ),
        );
      }

      if (rods.isEmpty) {
        rods.add(
          _StockRod(
            value: 1,
            color: const Color(0xFF37C66B),
          ),
        );
      }

      return _StockGroup(
        label: entry.key,
        rods: rods,
      );
    }).toList();
  }

  List<PieChartSectionData> _buildCategorySections(List<Product> products) {
    final legend = _categoryLegend(products);

    if (legend.isEmpty) {
      return [
        PieChartSectionData(
          color: AppColors.deepSpaceBlue,
          value: 1,
          title: '100%',
          radius: 86,
          titleStyle: AppTypography.callout.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ];
    }

    final total = legend.fold<int>(0, (sum, item) => sum + item.count);

    return legend.map((item) {
      final percentage = total == 0 ? 0 : (item.count / total) * 100;

      return PieChartSectionData(
        color: item.color,
        value: item.count.toDouble(),
        title: '${percentage.round()}%',
        radius: 86,
        titleStyle: AppTypography.callout.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );
    }).toList();
  }

  List<_CategoryLegendItem> _categoryLegend(List<Product> products) {
    final colors = [
      const Color(0xFF1CA0D6),
      const Color(0xFF37C66B),
      const Color(0xFFF39C12),
      const Color(0xFF083D68),
      const Color(0xFFE74C3C),
      const Color(0xFF8E44AD),
    ];

    final map = <String, int>{};

    for (final p in products) {
      map[p.category.label] = (map[p.category.label] ?? 0) + 1;
    }

    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return List.generate(entries.take(6).length, (i) {
      return _CategoryLegendItem(
        label: entries[i].key,
        count: entries[i].value,
        color: colors[i % colors.length],
      );
    });
  }

  double _restockPriorityScore(Product p) {
    double score = 0;

    if (p.stockStatus == StockStatus.outOfStock) score += 100;
    if (p.stockStatus == StockStatus.lowStock) score += 60;
    if (p.stockTrend == StockTrend.down) score += 35;
    if (p.marginHealth == MarginHealth.high) score += 25;
    if (p.marginHealth == MarginHealth.medium) score += 10;
    if (p.profitPerUnit > 0) score += p.profitPerUnit;

    return score;
  }

  double _stockMaxY(List<_StockGroup> groups) {
    double maxValue = 0;

    for (final g in groups) {
      for (final rod in g.rods) {
        if (rod.value > maxValue) maxValue = rod.value;
      }
    }

    return math.max(maxValue + 1, 4);
  }

  double _minY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    final min = spots.map((e) => e.y).reduce(math.min);
    return min * 0.92;
  }

  double _maxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    final max = spots.map((e) => e.y).reduce(math.max);
    return max * 1.08;
  }

  double _horizontalStep(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    final range = _maxY(spots) - _minY(spots);
    return range <= 0 ? 1 : range / 4;
  }

  String _xLabel(int index, List<SalesDataPoint> salesData) {
    if (index < 0 || index >= salesData.length) return '';
    final date = salesData[index].date;
    return '${date.day} ${_monthShort(date.month)}';
  }

  String _monthShort(int month) {
    const months = [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return months[month];
  }

  String _labelRangeText() {
    switch (_selectedRange) {
      case 0:
        return '7 días';
      case 1:
        return '30 días';
      case 2:
        return '90 días';
      case 3:
        return '1 año';
      default:
        return '7 días';
    }
  }

  String _compactCurrency(num value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  String _shortCategory(String label) {
    if (label.length <= 4) return label;
    return label.substring(0, 4);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.callout.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StockGroup {
  final String label;
  final List<_StockRod> rods;

  _StockGroup({
    required this.label,
    required this.rods,
  });
}

class _StockRod {
  final double value;
  final Color color;

  _StockRod({
    required this.value,
    required this.color,
  });
}

class _CategoryLegendItem {
  final String label;
  final int count;
  final Color color;

  _CategoryLegendItem({
    required this.label,
    required this.count,
    required this.color,
  });
}