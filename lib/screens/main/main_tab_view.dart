import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
  ConsumerState<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends ConsumerState<MainTabView> {
  int _selectedIndex = 0;

  static const _screens = [
    HomeScreen(),
    ProductsScreen(),
    SizedBox.shrink(),
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
    final invState = ref.watch(inventoryProvider).value;
    final isOnline = invState?.isOnline ?? true;
    final pending  = invState?.pendingOpsCount ?? 0;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          // ── Offline / syncing banner (Sprint 4) ──────────────────────────
          if (!isOnline || (isOnline && pending > 0))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _OfflineBanner(isOnline: isOnline, pendingCount: pending),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildTabBar(invState),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(invState) {
    return Container(
      decoration: const BoxDecoration(
        // Ink Black per spec — "Footer / bottom navigation background"
        color: AppColors.inkBlack,
        border: Border(
          top: BorderSide(color: Color(0x33FFFFFF), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];

              // ── Scan button (center) ─────────────────────────────────────
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
                            const _FullScreenModal(child: ScanScreen()),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            // Tea Green per spec — FAB / primary action
                            color: AppColors.teaGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.teaGreen.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_enhance_rounded,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Indicator + icon ─────────────────────────────
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          width: isSelected ? 40 : 26,
                          height: 26,
                          decoration: BoxDecoration(
                            // Dust Gray indicator per spec — "Selected tab indicators"
                            color: isSelected
                                ? AppColors.dustGrey.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                tab.icon,
                                size: 20,
                                // Selected: white. Inactive: Fresh Sky per spec
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.freshSky
                                        .withValues(alpha: 0.7),
                              ),
                              // Alert badge on Inicio tab
                              if (i == 0 &&
                                  (invState?.unreadAlertCount ?? 0) > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: AppTypography.overline.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.freshSky.withValues(alpha: 0.65),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
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



// ─────────────────────────────────────────────────────────────────────────────
// _OfflineBanner — Sprint 4 (Eventual Connectivity)
//
// Muestra una barra animada en la parte superior de la pantalla:
//   • Rojo   — sin conexión (modo offline)
//   • Ámbar  — reconectado pero con ops pendientes de sincronizar
//
// Se usa AnimatedSlide + AnimatedOpacity para que la entrada/salida sea suave.
// Respeta el SafeArea para no solapar el notch/status bar del dispositivo.
// ─────────────────────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;

  const _OfflineBanner({required this.isOnline, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final isSyncing = isOnline && pendingCount > 0;
    final color     = isSyncing ? const Color(0xFFE69B1E) : const Color(0xFFD94040);
    final icon      = isSyncing ? Icons.sync_rounded       : Icons.wifi_off_rounded;
    final label     = isSyncing
        ? 'Sincronizando $pendingCount operación${pendingCount == 1 ? "" : "es"}...'
        : 'Sin conexión — cambios guardados localmente';

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 1.8,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
class _FullScreenModal extends StatelessWidget {
  final Widget child;
  const _FullScreenModal({required this.child});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(heightFactor: 1.0, child: child);
  }
}
