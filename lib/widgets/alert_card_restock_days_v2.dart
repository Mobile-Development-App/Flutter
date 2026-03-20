import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/alert.dart';

/// Notification card that shows an "estimated days remaining" snapshot
/// derived from the alert message at send-time, and updates it over time
/// using `createdAt`.
class AlertCardRestockDaysV2 extends StatelessWidget {
  final InventoryAlert alert;
  final VoidCallback? onTap;

  const AlertCardRestockDaysV2({
    super.key,
    required this.alert,
    this.onTap,
  });

  int? _snapshotRestockDaysFromMessage() {
    if (alert.type != AlertType.lowStock && alert.type != AlertType.outOfStock) {
      return null;
    }

    // Snapshot at send-time (prevents changes when product is edited later).
    if (alert.type == AlertType.outOfStock) {
      return 1;
    }

    final lowStockMatch = RegExp(
      r'tiene solo\s+(\d+)\s+uds\s+\(mín:\s*(\d+)\)',
    ).firstMatch(alert.message);

    if (lowStockMatch == null) return null;

    final q = int.tryParse(lowStockMatch.group(1) ?? '');
    final min = int.tryParse(lowStockMatch.group(2) ?? '');

    if (q == null || min == null || min <= 0) return null;

    final deficitRatio = ((min - q) / min).clamp(0.0, 1.0);
    // Maps deficit ratio [0..1] to days [7..1]
    return (7 - (deficitRatio * 6)).round().clamp(1, 7);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = alert.type.color;
    final unreadBg = isDark
        ? AppColors.darkSurfaceSecondary
        : AppColors.deepSpaceBlue.withValues(alpha: 0.03);
    final readBg = isDark ? AppColors.darkSurface : AppColors.surface;

    final now = DateTime.now();
    final createdAtLocal = alert.createdAt.toLocal();
    final sentTime =
        '${createdAtLocal.hour.toString().padLeft(2, '0')}:${createdAtLocal.minute.toString().padLeft(2, '0')}';

    final snapshotDays = _snapshotRestockDaysFromMessage();
    final remainingDays = snapshotDays == null
        ? null
        : (snapshotDays - now.difference(alert.createdAt).inDays).clamp(0, 9999);

    String? remainingText;
    if (remainingDays != null) {
      if (remainingDays == 0) {
        remainingText = 'Queda aprox. Hoy';
      } else {
        remainingText =
            'Queda aprox. ~$remainingDays día${remainingDays == 1 ? '' : 's'}';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: alert.isRead ? readBg : unreadBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: alert.isRead
                ? Colors.transparent
                : AppColors.deepSpaceBlue.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(alert.type.icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        alert.title,
                        style: AppTypography.callout.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            alert.relativeTime,
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            'Enviado: $sentTime',
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (remainingText != null) ...[
                    Text(
                      remainingText,
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  Text(
                    alert.message,
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!alert.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.deepSpaceBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

