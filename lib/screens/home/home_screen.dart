import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/mock_data.dart';
import '../../models/analytics_data.dart';
import '../../providers/providers.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/widgets.dart';
import '../notifications/notifications_screen.dart';
import '../products/add_product_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late List<SalesDataPoint> _salesData;

  @override
  void initState() {
    super.initState();
    _salesData = MockData.generateSalesData(days: 7);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final invAsync = ref.watch(inventoryProvider);
    final authAsync = ref.watch(authProvider);

    final InventoryState? invState = invAsync.value;
    final authState = authAsync.value;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.background,
      appBar: AppBar(
        title: const Text('Inicio'),
        leading: IconButton(
          icon: Icon(
            Icons.settings_rounded,
            color: isDark
                ? AppColors.darkTextPrimary
                : Colors.white,
          ),
          onPressed: () => _showSettings(context),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_rounded,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : Colors.white),
                onPressed: () => _showNotifications(context),
              ),
              if ((invState?.unreadAlertCount ?? 0) > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${(invState?.unreadAlertCount ?? 0) > 9 ? '9+' : invState?.unreadAlertCount}',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(inventoryProvider.notifier).refreshData(),
        color: AppColors.freshSky,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _welcomeBanner(authState?.currentUser?.fullName),
              const SizedBox(height: 20),
              _statsGrid(invState),
              const SizedBox(height: 20),
              _salesChart(isDark),
              const SizedBox(height: 20),
              if ((invState?.alerts.isNotEmpty) ?? false)
                _alertsSection(context, invState!, isDark),
              const SizedBox(height: 20),
              _quickActions(context, isDark),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeBanner(String? fullName) {
    final firstName = fullName?.split(' ').firstOrNull ?? 'Usuario';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.deepSpaceBlue, AppColors.inkBlack],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bienvenido, $firstName 👋',
              style: AppTypography.title3
                  .copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Tu inventario está al día. Aquí tienes un resumen.',
            style: AppTypography.caption
                .copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(InventoryState? inventoryState) {
    final stats = inventoryState?.dashboardStats;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      children: [
        StatCard(
          title: 'Total Productos',
          value: '${stats?.totalProducts ?? 0}',
          icon: Icons.inventory_2_rounded,
          iconColor: AppColors.deepSpaceBlue,
          trend: 5.2,
        ),
        StatCard(
          title: 'Stock Bajo',
          value: '${stats?.lowStockCount ?? 0}',
          icon: Icons.warning_rounded,
          iconColor: AppColors.warning,
        ),
        StatCard(
          title: 'Agotados',
          value: '${stats?.outOfStockCount ?? 0}',
          icon: Icons.cancel_rounded,
          iconColor: AppColors.error,
        ),
        StatCard(
          title: 'Valor en Stock',
          value: (stats?.totalStockValue ?? 0.0).compactCurrency,
          icon: Icons.monetization_on_rounded,
          iconColor: AppColors.success,
          trend: 12.5,
        ),
      ],
    );
  }

  Widget _salesChart(bool isDark) {
    final totalSales =
        _salesData.fold<double>(0.0, (s, p) => s + p.sales);
    final spots = _salesData.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), e.value.sales / 1000000);
    }).toList();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ventas Semanales',
                  style: AppTypography.headline),
              Text(
                totalSales.compactCurrency,
                style: AppTypography.callout
                    .copyWith(color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
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
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        if (v.toInt() < _salesData.length) {
                          return Text(
                            _salesData[v.toInt()].date.dayOfWeek,
                            style: const TextStyle(fontSize: 10),
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
                    color: AppColors.freshSky,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.freshSky
                              .withValues(alpha: 0.3),
                          AppColors.freshSky
                              .withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertsSection(BuildContext context, InventoryState inventoryState, bool isDark) {
    final alerts = inventoryState.alerts.take(3).toList();
    final unread = inventoryState.unreadAlertCount;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.teaGreen, size: 18),
              const SizedBox(width: 6),
              Text('Alertas IA', style: AppTypography.headline),
              const Spacer(),
              if (unread > 0)
                BadgeWidget(
                  text: '$unread nuevas',
                  style: BadgeStyle.warning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AlertCard(
                  alert: alert,
                  onTap: () => ref
                      .read(inventoryProvider.notifier)
                      .markAlertAsRead(alert),
                ),
              )),
          if (inventoryState.alerts.length > 3)
            TextButton.icon(
              onPressed: () => _showNotifications(context),
              icon: const Icon(Icons.arrow_forward_rounded,
                  size: 14, color: AppColors.freshSky),
              label: Text(
                'Ver todas las alertas',
                style: AppTypography.callout
                    .copyWith(color: AppColors.freshSky),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acciones Rápidas',
            style: AppTypography.headline),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.camera_enhance_rounded,
                title: 'Escanear con IA',
                color: AppColors.deepSpaceBlue,
                isDark: isDark,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                icon: Icons.add_circle_rounded,
                title: 'Agregar Producto',
                color: AppColors.teaGreen,
                isDark: isDark,
                onTap: () => _showAddProduct(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticManager.impact();
      },
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FullSheet(child: NotificationsScreen()),
    );
  }

  void _showAddProduct(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FullSheet(child: AddProductScreen()),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FullSheet(child: SettingsScreen()),
    );
  }
}

class _FullSheet extends StatelessWidget {
  final Widget child;
  const _FullSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      maxChildSize: 0.95,
      builder: (_, __) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        child: child,
      ),
    );
  }
}