import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/providers.dart';

/// Widget que muestra el estado de conectividad y sincronización.
/// Apto para una demostración en Viva-voce.
///
/// Uso:
/// ```dart
/// Scaffold(
///   appBar: AppBar(...),
///   body: Column(
///     children: [
///       ConnectivityStatusBar(),  // ← Agregar aquí
///       Expanded(child: SuContent()),
///     ],
///   ),
/// );
/// ```
class ConnectivityStatusBar extends ConsumerWidget {
  final bool compact;
  final VoidCallback? onSyncPressed;

  const ConnectivityStatusBar({
    super.key,
    this.compact = false,
    this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityProvider);
    final inventoryAsync = ref.watch(inventoryProvider);

    return connectivityAsync.when(
      data: (isOnline) {
        final pendingOps = inventoryAsync.valueOrNull?.pendingOpsCount ?? 0;
        final isSync = pendingOps == 0 || isOnline;

        return _buildStatusBar(
          context: context,
          ref: ref,
          isOnline: isOnline,
          pendingOps: pendingOps,
          isSync: isSync,
        );
      },
      loading: () => _buildLoadingBar(context),
      error: (err, _) => _buildErrorBar(context),
    );
  }

  Widget _buildStatusBar({
    required BuildContext context,
    required WidgetRef ref,
    required bool isOnline,
    required int pendingOps,
    required bool isSync,
  }) {
    if (compact && isSync) return const SizedBox.shrink();

    final backgroundColor = isOnline
        ? Colors.green[100]
        : pendingOps > 0
            ? Colors.orange[100]
            : Colors.red[100];

    final textColor = isOnline
        ? Colors.green[900]
        : pendingOps > 0
            ? Colors.orange[900]
            : Colors.red[900];

    final icon = isOnline
        ? Icons.cloud_done_rounded
        : pendingOps > 0
            ? Icons.cloud_queue_rounded
            : Icons.cloud_off_rounded;

    final status = isOnline
        ? 'En línea'
        : pendingOps > 0
            ? 'Offline (sync pendiente)'
            : 'Sin conexión';

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      status,
                      style: AppTypography.caption.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pendingOps > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$pendingOps pendientes',
                          style: AppTypography.caption2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isOnline && pendingOps == 0)
                  Text(
                    'Los datos se sincronizarán automáticamente cuando conectes',
                    style: AppTypography.caption2.copyWith(
                      color: textColor,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          if (!isSync) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: onSyncPressed ??
                    () {
                      ref.read(offlineQueueWatcherProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Intentando sincronizar...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                icon: const Icon(Icons.sync, size: 14),
                label: const Text('Sincronizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingBar(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Verificando conexión...',
            style: AppTypography.caption.copyWith(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBar(BuildContext context) {
    return Container(
      color: Colors.red[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[900], size: 18),
          const SizedBox(width: 8),
          Text(
            'Error al detectar conectividad',
            style: AppTypography.caption.copyWith(
              color: Colors.red[900],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget compacto que solo muestra un badge si hay operaciones pendientes.
/// Útil para AppBar o esquina del status bar.
class PendingOpsIndicator extends ConsumerWidget {
  final bool showLabel;

  const PendingOpsIndicator({
    super.key,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final connectivityAsync = ref.watch(connectivityProvider);

    return inventoryAsync.when(
      data: (invState) {
        final pendingOps = invState.pendingOpsCount;
        final isOnline = connectivityAsync.valueOrNull ?? true;

        if (pendingOps == 0) {
          return const SizedBox.shrink();
        }

        return Tooltip(
          message:
              '$pendingOps operaciones pendientes. ${isOnline ? 'Sincronizando...' : 'Se sincronizarán cuando conectes'}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 12,
                  width: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$pendingOps',
                    style: AppTypography.caption2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Widget que muestra un modal con detalles de sincronización.
/// Útil para debugging durante Viva-voce.
class SyncDebugModal extends ConsumerWidget {
  const SyncDebugModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityProvider);
    final inventoryAsync = ref.watch(inventoryProvider);

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Eventual Connectivity Debug',
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              connectivityAsync.when(
                data: (isOnline) => _buildDebugInfo(
                  context: context,
                  isOnline: isOnline,
                  inventory: inventoryAsync.valueOrNull,
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (err, _) => Text('Error: $err'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugInfo({
    required BuildContext context,
    required bool isOnline,
    required dynamic inventory,
  }) {
    final pendingOps = (inventory as dynamic)?.pendingOpsCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _debugRow('Estado de Red', isOnline ? '🟢 Online' : '🔴 Offline'),
        _debugRow('Operaciones Pendientes', '$pendingOps'),
        _debugRow(
          'Estado de Sincronización',
          pendingOps == 0 ? '✅ Sincronizado' : '⏳ En sincronización',
        ),
        const Divider(height: 16),
        Text(
          'Capas de Persistencia:',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _debugRow('L1: LRU Cache', 'En memoria'),
        _debugRow('L2: Hive Boxes', 'pending_ops, screen_sessions, etc.'),
        _debugRow('L3: SharedPreferences', 'BQ cache, search history'),
        _debugRow('L4: SQLite', 'stores, products, movements'),
        const Divider(height: 16),
        Text(
          'Servicios Activados:',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _debugRow('ConnectivityService', '✅'),
        _debugRow('OfflineQueueService', '✅'),
        _debugRow('CacheService (2-layer)', '✅'),
        _debugRow('LocalDatabaseService', '✅'),
        _debugRow('SearchHistoryCacheService', '✅'),
      ],
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption2.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.caption2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
