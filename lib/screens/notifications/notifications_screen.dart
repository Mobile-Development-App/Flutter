import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/alert.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  bool _showAll = true;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    // Rebuild periodically so the "days remaining" snapshot updates
    // as time passes (based on `alert.createdAt`).
    _tickTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tickTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = context.isDark;
    final invState = ref.watch(inventoryProvider).value;
    final ctx      = ref.watch(contextProvider);
    final allAlerts = invState?.alerts ?? [];
    final unread    = invState?.unreadAlertCount ?? 0;
    final shown =
        _showAll ? allAlerts : allAlerts.where((a) => !a.isRead).toList();

    // Group by priority for context-aware display
    final urgent  = shown.where((a) => a.priority == AlertPriority.high).toList();
    final medium  = shown.where((a) => a.priority == AlertPriority.medium).toList();
    final low     = shown.where((a) => a.priority == AlertPriority.low).toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkNavBackground : AppColors.inkBlack,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Notificaciones',
                style: AppTypography.headline
                    .copyWith(color: Colors.white)),
            if (unread > 0)
              Text('$unread sin leer',
                  style: AppTypography.caption2.copyWith(
                      color: AppColors.teaGreen)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () {
                ref.read(inventoryProvider.notifier).markAllAlertsAsRead();
                HapticManager.success();
              },
              child: Text('Leer todo',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.teaGreen,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Context summary bar ──
          if (ctx.hasUrgentAction)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFF453A).withValues(alpha: 0.08),
              child: Row(children: [
                const Icon(Icons.priority_high_rounded,
                    color: Color(0xFFFF453A), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${ctx.urgentAlerts.length} alerta${ctx.urgentAlerts.length > 1 ? 's' : ''} de alta prioridad requiere${ctx.urgentAlerts.length == 1 ? '' : 'n'} acción',
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFFFF453A),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),

          // ── Filter toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                _filterBtn('Todas (${allAlerts.length})', _showAll,
                    () => setState(() => _showAll = true)),
                _filterBtn(
                    'Sin leer ($unread)',
                    !_showAll,
                    () => setState(() => _showAll = false)),
              ]),
            ),
          ),
          const SizedBox(height: 8),

          // ── Grouped list ──
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'Sin notificaciones',
                    description: _showAll
                        ? 'No tienes notificaciones aún'
                        : 'No tienes notificaciones sin leer',
                  )
                : ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (urgent.isNotEmpty) ...[
                        _groupHeader('Alta Prioridad',
                            const Color(0xFFFF453A),
                            Icons.priority_high_rounded),
                        const SizedBox(height: 8),
                        ...urgent.map((a) => _alertRow(a)),
                        const SizedBox(height: 16),
                      ],
                      if (medium.isNotEmpty) ...[
                        _groupHeader('Media Prioridad',
                            const Color(0xFFFF9F0A),
                            Icons.warning_rounded),
                        const SizedBox(height: 8),
                        ...medium.map((a) => _alertRow(a)),
                        const SizedBox(height: 16),
                      ],
                      if (low.isNotEmpty) ...[
                        _groupHeader('Informativas',
                            AppColors.textTertiary,
                            Icons.info_outline_rounded),
                        const SizedBox(height: 8),
                        ...low.map((a) => _alertRow(a)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _alertRow(InventoryAlert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AlertCardRestockDaysV2(
        alert: alert,
        onTap: () =>
            ref.read(inventoryProvider.notifier).markAlertAsRead(alert),
      ),
    );
  }

  Widget _groupHeader(String title, Color color, IconData icon) {
    return Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(title,
          style: AppTypography.caption.copyWith(
              color: color, fontWeight: FontWeight.w700)),
      Expanded(
          child: Divider(
              indent: 8,
              color: color.withValues(alpha: 0.2))),
    ]);
  }

  Widget _filterBtn(String title, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          onTap();
          HapticManager.selection();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.deepSpaceBlue
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(title,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : AppColors.textSecondary,
              )),
        ),
      ),
    );
  }
}
