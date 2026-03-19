import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/mock_data.dart';
import '../../models/store.dart';
import '../../models/employee.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

// ─────────────────────────────────────────────
// AddStoreScreen
// ─────────────────────────────────────────────
class AddStoreScreen extends ConsumerStatefulWidget {
  const AddStoreScreen({super.key});

  @override
  ConsumerState<AddStoreScreen> createState() =>
      _AddStoreScreenState();
}

class _AddStoreScreenState
    extends ConsumerState<AddStoreScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();

  bool get _isValid =>
      _nameCtrl.text.isNotEmpty &&
      _addressCtrl.text.isNotEmpty &&
      _phoneCtrl.text.isNotEmpty;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _addressCtrl, _phoneCtrl,
      _emailCtrl, _managerCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Nueva Tienda'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _field('Nombre de la tienda',
                      _nameCtrl, 'Ej: Sucursal Centro',
                      Icons.storefront_rounded, isDark),
                  const SizedBox(height: 14),
                  _field('Dirección', _addressCtrl,
                      'Ej: Cra 15 #45-20',
                      Icons.location_on_outlined, isDark),
                  const SizedBox(height: 14),
                  _field('Teléfono', _phoneCtrl,
                      '+57 300 000 0000',
                      Icons.phone_outlined, isDark,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  _field('Correo electrónico', _emailCtrl,
                      'tienda@email.com',
                      Icons.email_outlined, isDark,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _field('Gerente', _managerCtrl,
                      'Nombre del gerente',
                      Icons.person_outlined, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: secondaryButtonStyle,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValid
                        ? () {
                            final n = ref.read(
                                storeProvider.notifier);
                            n.setNewStoreName(_nameCtrl.text);
                            n.setNewStoreAddress(
                                _addressCtrl.text);
                            n.setNewStorePhone(
                                _phoneCtrl.text);
                            n.setNewStoreEmail(
                                _emailCtrl.text);
                            n.setNewStoreManager(
                                _managerCtrl.text);
                            n.addStore();
                            Navigator.pop(context);
                          }
                        : null,
                    style: primaryButtonStyle,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool isDark, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSecondary
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(icon,
                    color: AppColors.textTertiary, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboardType,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// StoreDetailScreen
// ─────────────────────────────────────────────
class StoreDetailScreen extends ConsumerStatefulWidget {
  final Store store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  ConsumerState<StoreDetailScreen> createState() =>
      _StoreDetailScreenState();
}

class _StoreDetailScreenState
    extends ConsumerState<StoreDetailScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final storeState = ref.watch(storeProvider).value;
    final invState = ref.watch(inventoryProvider).value;
    final s = widget.store;
    final salesData = MockData.generateSalesData(days: 7);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(s.name),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hero
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.deepSpaceBlue,
                    AppColors.primaryLight
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 36, color: Colors.white),
                    const SizedBox(height: 4),
                    Text(s.name,
                        style: AppTypography.title3
                            .copyWith(color: Colors.white)),
                    Text(s.address,
                        style: AppTypography.caption2
                            .copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Mini stats
            GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.9,
              children: [
                _miniStat(Icons.inventory_2_outlined,
                    '${s.productCount}', 'Productos'),
                _miniStat(Icons.monetization_on_outlined,
                    s.formattedSales, 'Ventas/mes'),
                _miniStat(Icons.shopping_bag_outlined,
                    '${(s.productCount * 0.3).toInt()}', 'Pedidos'),
                _miniStat(Icons.group_outlined,
                    '${s.employeeCount}', 'Equipo'),
              ],
            ),
            const SizedBox(height: 16),
            // Tab selector
            _tabSelector(isDark),
            const SizedBox(height: 16),
            // Tab content
            if (_tab == 0)
              _overviewTab(s, salesData, isDark),
            if (_tab == 1)
              _analyticsTab(salesData, s, isDark),
            if (_tab == 2)
              _productsTab(invState, s, isDark),
            if (_tab == 3)
              _teamTab(storeState, s, isDark),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.deepSpaceBlue),
          const SizedBox(height: 6),
          Text(value,
              style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _tabSelector(bool isDark) {
    const tabs = ['General', 'Analítica', 'Productos', 'Equipo'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final sel = _tab == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _tab = e.key);
                HapticManager.selection();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.deepSpaceBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(e.value,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: sel
                          ? Colors.white
                          : AppColors.textSecondary,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _overviewTab(Store s, salesData, bool isDark) {
    final spots = (salesData as List).asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(),
          (e.value.sales as double) / 1000000);
    }).toList();

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tendencia de Ventas',
                  style: AppTypography.headline),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: LineChart(LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    topTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
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
                                .withValues(alpha: 0.3),
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
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Información de la Tienda',
                  style: AppTypography.headline),
              const SizedBox(height: 14),
              _infoRow(Icons.location_on_outlined,
                  'Dirección', s.address, isDark),
              _infoRow(Icons.phone_outlined, 'Teléfono',
                  s.phone, isDark),
              _infoRow(Icons.email_outlined, 'Email',
                  s.email, isDark),
              _infoRow(Icons.person_outlined, 'Gerente',
                  s.manager, isDark),
              _infoRow(Icons.calendar_today_outlined,
                  'Creada', s.createdAt.shortFormatted,
                  isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _analyticsTab(salesData, Store s, bool isDark) {
    final spots = (salesData as List).asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: (e.value.sales as double) / 1000000,
            color: AppColors.deepSpaceBlue.withValues(alpha: 0.7),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ventas vs Pedidos',
                  style: AppTypography.headline),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: BarChart(BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false))),
                  barGroups: spots,
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            _metricCard('Tasa de Rotación', '4.2x',
                AppColors.success, isDark),
            _metricCard('Margen Promedio', '32.5%',
                AppColors.deepSpaceBlue, isDark),
            _metricCard('Productos Activos',
                '${s.productCount}', AppColors.info, isDark),
            _metricCard('Alertas Activas', '5',
                AppColors.warning, isDark),
          ],
        ),
      ],
    );
  }

  Widget _productsTab(invState, Store s, bool isDark) {
    final products =
        (invState?.products ?? []).take(3).toList();
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            _metricCard('Total', '${s.productCount}',
                AppColors.deepSpaceBlue, isDark),
            _metricCard(
                'En Stock',
                '${s.productCount - 15}',
                AppColors.success, isDark),
            _metricCard(
                'Stock Bajo', '12', AppColors.warning, isDark),
            _metricCard(
                'Agotados', '3', AppColors.error, isDark),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Productos Principales',
                  style: AppTypography.headline),
              const SizedBox(height: 12),
              ...products.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.deepSpaceBlue
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Icon(p.category.icon,
                              size: 16,
                              color: AppColors.deepSpaceBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: AppTypography
                                      .caption.copyWith(
                                          fontWeight:
                                              FontWeight.w500)),
                              Text('${p.quantity} unidades',
                                  style:
                                      AppTypography.caption2
                                          .copyWith(
                                              color: AppColors
                                                  .textSecondary)),
                            ],
                          ),
                        ),
                        Text(p.salePrice.currencyFormatted,
                            style:
                                AppTypography.caption.copyWith(
                                    fontWeight:
                                        FontWeight.w600)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teamTab(storeState, Store s, bool isDark) {
    final employees = (storeState?.employees ?? <Employee>[])
        .where((e) => e.storeId == s.id)
        .toList();

    if (employees.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        title: 'Sin miembros',
        description: 'No hay miembros asignados a esta tienda',
      );
    }

    return Column(
      children: employees.map((emp) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.deepSpaceBlue
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(emp.initials,
                        style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepSpaceBlue)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(emp.fullName,
                          style: AppTypography.callout
                              .copyWith(
                                  fontWeight: FontWeight.w500)),
                      Text(emp.role.label,
                          style: AppTypography.caption2
                              .copyWith(
                                  color:
                                      AppColors.textSecondary)),
                    ],
                  ),
                ),
                BadgeWidget(
                  text:
                      emp.isActive ? 'Activo' : 'Inactivo',
                  style: emp.isActive
                      ? BadgeStyle.success
                      : BadgeStyle.secondary,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppTypography.caption
                    .copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
      String title, String value, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: AppTypography.caption2
                  .copyWith(color: AppColors.textSecondary)),
          Text(value,
              style:
                  AppTypography.title3.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// StoreManagementScreen
// ─────────────────────────────────────────────
class StoreManagementScreen extends ConsumerStatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  ConsumerState<StoreManagementScreen> createState() =>
      _StoreManagementScreenState();
}

class _StoreManagementScreenState
    extends ConsumerState<StoreManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final storeState = ref.watch(storeProvider).value;
    final stores = storeState?.stores ?? [];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(title: const Text('Gestión de Tiendas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active store
            if (storeState?.activeStore != null)
              _activeStoreCard(
                  storeState!.activeStore!, isDark),
            const SizedBox(height: 16),
            // All stores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Todas las Tiendas',
                    style: AppTypography.headline),
                Text('${stores.length} tiendas',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            ...stores.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _storeCard(s, storeState!, isDark),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddStoreScreen()),
                ),
                style: secondaryButtonStyle,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar Nueva Tienda'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _activeStoreCard(Store store, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepSpaceBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.deepSpaceBlue.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded,
                  color: AppColors.deepSpaceBlue, size: 18),
              const SizedBox(width: 6),
              Text('Tienda Activa',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepSpaceBlue,
                  )),
              const Spacer(),
              BadgeWidget(
                  text: 'Activa', style: BadgeStyle.success),
            ],
          ),
          const SizedBox(height: 8),
          Text(store.name, style: AppTypography.title3),
          const SizedBox(height: 2),
          Text(store.address,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.group_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('${store.employeeCount} empleados',
                  style: AppTypography.caption2
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              Icon(Icons.inventory_2_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('${store.productCount} productos',
                  style: AppTypography.caption2
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storeCard(Store store, storeState, bool isDark) {
    final isActive = store.id == storeState.activeStoreId;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                StoreDetailScreen(store: store)),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(store.name,
                      style: AppTypography.headline.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary)),
                ),
                if (isActive)
                  BadgeWidget(
                      text: 'Activa',
                      style: BadgeStyle.success),
              ],
            ),
            const SizedBox(height: 4),
            Text(store.address,
                style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 12,
                    color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(store.phone,
                    style: AppTypography.caption2.copyWith(
                        color: AppColors.textSecondary)),
                const Spacer(),
                Icon(Icons.group_outlined,
                    size: 12,
                    color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${store.employeeCount}',
                    style: AppTypography.caption2.copyWith(
                        color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Icon(Icons.inventory_2_outlined,
                    size: 12,
                    color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${store.productCount}',
                    style: AppTypography.caption2.copyWith(
                        color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Text(store.formattedSales,
                    style: AppTypography.caption2.copyWith(
                        color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TeamMembersScreen
// ─────────────────────────────────────────────
class TeamMembersScreen extends ConsumerStatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  ConsumerState<TeamMembersScreen> createState() =>
      _TeamMembersScreenState();
}

class _TeamMembersScreenState
    extends ConsumerState<TeamMembersScreen> {
  String? _filterStoreId;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final storeState = ref.watch(storeProvider).value;
    final stores = storeState?.stores ?? [];
    final employees = (storeState?.employees ?? <Employee>[])
        .where((e) =>
            _filterStoreId == null ||
            e.storeId == _filterStoreId)
        .toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(title: const Text('Equipo')),
      body: Column(
        children: [
          // Header card
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.deepSpaceBlue
                          .withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_rounded,
                        size: 24,
                        color: AppColors.deepSpaceBlue),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('Miembros del Equipo',
                          style: AppTypography.headline),
                      Text(
                          '${storeState?.employees.length ?? 0} miembros en total',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Store filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _filterChip('Todas', _filterStoreId == null,
                    () => setState(() => _filterStoreId = null),
                    isDark),
                ...stores.map((s) => _filterChip(
                    s.name,
                    _filterStoreId == s.id,
                    () => setState(
                        () => _filterStoreId = s.id),
                    isDark)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Employee list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  16, 4, 16, 80),
              itemCount: employees.length + 1,
              itemBuilder: (_, i) {
                if (i == employees.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      style: secondaryButtonStyle,
                      icon: const Icon(
                          Icons.person_add_rounded),
                      label:
                          const Text('Invitar Miembro'),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _employeeCard(
                      employees[i], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String title, bool selected,
      VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          onTap();
          HapticManager.selection();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.deepSpaceBlue
                : (isDark
                    ? AppColors.darkSurface
                    : AppColors.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            title,
            style: AppTypography.caption.copyWith(
              color: selected
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _employeeCard(Employee emp, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.deepSpaceBlue
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emp.initials,
                  style: AppTypography.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepSpaceBlue,
                  )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp.fullName,
                    style: AppTypography.headline.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(emp.role.icon,
                        size: 12,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(emp.role.label,
                        style: AppTypography.caption2
                            .copyWith(
                                color:
                                    AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    BadgeWidget(
                        text: emp.storeName),
                    Text(
                        'Desde ${emp.joinDate.shortFormatted}',
                        style: AppTypography.caption2.copyWith(
                            color: AppColors.textTertiary)),
                  ],
                ),
              ],
            ),
          ),
          BadgeWidget(
            text: emp.isActive ? 'Activo' : 'Inactivo',
            style: emp.isActive
                ? BadgeStyle.success
                : BadgeStyle.secondary,
          ),
        ],
      ),
    );
  }
}
