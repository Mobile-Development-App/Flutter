import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';
import '../home/home_screen.dart';
import '../products/products_screen.dart';
import '../restock/restock_screen.dart';
import '../analytics/analytics_screen.dart';
import '../scan/scan_screen.dart';

class MainTabView extends ConsumerStatefulWidget {
  const MainTabView({super.key});

  @override
  ConsumerState<MainTabView> createState() =>
      _MainTabViewState();
}

class _MainTabViewState extends ConsumerState<MainTabView> {
  int _selectedIndex = 0;

  static const _screens = [
    HomeScreen(),
    ProductsScreen(),
    SizedBox.shrink(), // placeholder for scan
    RestockScreen(),
    AnalyticsScreen(),
  ];

  static const _tabs = [
    _TabItem(Icons.home_rounded, 'Inicio'),
    _TabItem(Icons.inventory_2_rounded, 'Inventario'),
    _TabItem(Icons.camera_enhance_rounded, 'Escanear'),
    _TabItem(Icons.refresh_rounded, 'Reabastecer'),
    _TabItem(Icons.bar_chart_rounded, 'Analítica'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final invState = ref.watch(inventoryProvider).value;

    return Scaffold(
      body: Stack(
        children: [
          // Screen content
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          // Custom tab bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildTabBar(isDark, invState),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark, invState) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              // Center scan button
              if (i == 2) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticManager.impact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            const _FullScreenModal(
                                child: ScanScreen()),
                      ).then((_) => null);
                    },
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.teaGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.teaGreen
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            tab.icon,
                            color: AppColors.inkBlack,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final isSelected = _selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    HapticManager.selection();
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              tab.icon,
                              size: 22,
                              color: isSelected
                                  ? AppColors.freshSky
                                  : AppColors.textTertiary,
                            ),
                            // Unread badge on Inicio tab
                            if (i == 0 &&
                                (invState?.unreadAlertCount ??
                                        0) >
                                    0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration:
                                      const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.freshSky
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}

class _FullScreenModal extends StatelessWidget {
  final Widget child;
  const _FullScreenModal({required this.child});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 1.0,
      child: child,
    );
  }
}
