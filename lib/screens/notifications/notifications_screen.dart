import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final invState = ref.watch(inventoryProvider).value;
    final allAlerts = invState?.alerts ?? [];
    final unread = invState?.unreadAlertCount ?? 0;
    final shown =
        _showAll ? allAlerts : allAlerts.where((a) => !a.isRead).toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () {
                ref
                    .read(inventoryProvider.notifier)
                    .markAllAlertsAsRead();
                HapticManager.success();
              },
              child: Text('Leer todo',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.deepSpaceBlue)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _filterBtn('Todas', _showAll,
                      () => setState(() => _showAll = true)),
                  _filterBtn(
                      'No leídas ($unread)',
                      !_showAll,
                      () => setState(() => _showAll = false)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'Sin notificaciones',
                    description: _showAll
                        ? 'No tienes notificaciones aún'
                        : 'No tienes notificaciones sin leer',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        16, 4, 16, 20),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AlertCard(
                        alert: shown[i],
                        onTap: () => ref
                            .read(inventoryProvider.notifier)
                            .markAlertAsRead(shown[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(
      String title, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          onTap();
          HapticManager.selection();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.deepSpaceBlue
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w500,
              color:
                  selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
