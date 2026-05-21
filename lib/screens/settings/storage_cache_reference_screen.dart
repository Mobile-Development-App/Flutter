import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../services/local_file_service.dart';
import '../../services/local_store_service.dart';

/// Notas internas sobre cómo la app guarda datos y evita pedir todo al servidor.
class StorageCacheReferenceScreen extends ConsumerStatefulWidget {
  const StorageCacheReferenceScreen({super.key});

  @override
  ConsumerState<StorageCacheReferenceScreen> createState() =>
      _StorageCacheReferenceScreenState();
}

class _StorageCacheReferenceScreenState
    extends ConsumerState<StorageCacheReferenceScreen> {
  String _movimientosCacheados = '—';
  String _sqliteResumen = '—';
  String _hiveResumen = '—';
  String _archivosResumen = '—';
  String _prefsResumen = '—';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    try {
      final movBox = Hive.box<String>('movements_cache_v1');
      _movimientosCacheados =
          '${movBox.length} producto${movBox.length == 1 ? '' : 's'} en caché';
    } catch (_) {
      _movimientosCacheados = 'Aún no hay movimientos guardados';
    }

    if (!kIsWeb) {
      try {
        await LocalDatabaseService.shared.init();
        final stores = await LocalDatabaseService.shared.getStores();
        final products = await LocalDatabaseService.shared.getProducts();
        _sqliteResumen =
            '${stores.length} tienda(s), ${products.length} producto(s) en SQLite';
      } catch (e) {
        _sqliteResumen = 'SQLite no disponible';
      }

      try {
        final files = await LocalFileService.shared.listFiles();
        _archivosResumen = files.isEmpty
            ? 'Todavía no hay JSON en disco'
            : files
                .map((f) => f.path.split(RegExp(r'[/\\]')).last)
                .join(', ');
      } catch (_) {
        _archivosResumen = 'No se pudo leer la carpeta';
      }
    } else {
      _sqliteResumen = 'Solo en app móvil';
      _archivosResumen = 'No aplica en web';
    }

    const cajas = [
      'api_cache',
      'stock_count_sessions_v1',
      'stock_count_summary_cache_v1',
      'stock_count_pending_sync_v1',
      'movements_cache_v1',
      'open_food_facts_v1',
      'dashboard_snapshot_v1',
      'pending_ops',
    ];
    final abiertas = cajas.where(Hive.isBoxOpen).toList();
    _hiveResumen = abiertas.isEmpty
        ? 'Hive listo, sin cajas abiertas todavía'
        : '${abiertas.length} caja(s) activa(s)';

    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getKeys().where((k) => k.startsWith('inventaria')).length;
    _prefsResumen = '$n preferencia(s) de la app';

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Datos en el dispositivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _loading
                ? null
                : () {
                    setState(() => _loading = true);
                    _cargarEstado();
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _cargarEstado();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Text(
                    'Resumen de lo que implementamos en el sprint: la app '
                    'recuerda cosas en el teléfono para no depender siempre de '
                    'internet. Nada de esto borra tu inventario; solo ayuda '
                    'cuando la red falla o vas a Reabastecer / Escanear.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Ahora mismo'),
                  _card(isDark, [
                    _filaEstado(
                      Icons.speed_rounded,
                      'Caché de movimientos',
                      _movimientosCacheados,
                      AppColors.teaGreen,
                    ),
                    _divider(),
                    _filaEstado(
                      Icons.table_chart_outlined,
                      'Base SQLite',
                      _sqliteResumen,
                      AppColors.deepSpaceBlue,
                    ),
                    _divider(),
                    _filaEstado(
                      Icons.inbox_outlined,
                      'Cajas Hive',
                      _hiveResumen,
                      AppColors.warning,
                    ),
                    _divider(),
                    _filaEstado(
                      Icons.folder_outlined,
                      'Archivos JSON',
                      _archivosResumen,
                      AppColors.info,
                    ),
                    _divider(),
                    _filaEstado(
                      Icons.tune_rounded,
                      'Preferencias',
                      _prefsResumen,
                      AppColors.success,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel('Caché LRU'),
                  _card(isDark, [
                    _filaTappable(
                      isDark: isDark,
                      icon: Icons.history_rounded,
                      title: 'Movimientos de stock',
                      subtitle:
                          'Reabastecer y analíticas. Memoria + Hive, 15 min.',
                      color: AppColors.teaGreen,
                      onTap: () => _mostrarDetalle(
                        context,
                        'Movimientos de stock',
                        'Cuando abres un producto en Reabastecer, la app guarda '
                        'el historial un rato (LRU en RAM y Hive en disco). '
                        'Así no repetimos la misma llamada al API cada vez.\n\n'
                        'Código: lib/storage/cache/inventory_movements_cache.dart',
                      ),
                    ),
                    _divider(),
                    _filaTappable(
                      isDark: isDark,
                      icon: Icons.lightbulb_outline_rounded,
                      title: 'Sugerencias de pedido',
                      subtitle: 'Respuesta del backend, 6 horas en caché.',
                      color: AppColors.freshSky,
                      onTap: () => _mostrarDetalle(
                        context,
                        'Sugerencias de pedido',
                        'Las tarjetas de sugerencias en Reabastecer se guardan '
                        'unas horas porque tardan en generarse. LRU pequeño (10) '
                        'y SharedPreferences por tienda.\n\n'
                        'Código: lib/storage/cache/restock_suggestions_cache.dart',
                      ),
                    ),
                    _divider(),
                    _filaTappable(
                      isDark: isDark,
                      icon: Icons.fact_check_outlined,
                      title: 'Conteo físico',
                      subtitle: 'Sesiones Hive + resumen LRU, 6 h.',
                      color: AppColors.deepSpaceBlue,
                      onTap: () => _mostrarDetalle(
                        context,
                        'Conteo físico',
                        'Inventario → Conteo físico guarda cada sesión en Hive. '
                        'Al finalizar, 4 isolates calculan coincidencias y diferencias. '
                        'Sin red, los ajustes quedan en cola hasta sincronizar.\n\n'
                        'Código: lib/storage/persistence/stock_count_local_store.dart',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel('También usamos'),
                  _card(isDark, [
                    _filaTappable(
                      isDark: isDark,
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Escaneo (Open Food Facts)',
                      subtitle: 'Códigos de barras, 30 días en Hive.',
                      color: AppColors.deepSpaceBlue,
                      onTap: () => _mostrarDetalle(
                        context,
                        'Escaneo',
                        'Si ya buscaste un código, la próxima vez sale del '
                        'dispositivo. El historial de escaneos va a '
                        'scan_history.json.\n\n'
                        'Código: lib/storage/open_food_facts_lookup.dart',
                      ),
                    ),
                    _divider(),
                    _filaTappable(
                      isDark: isDark,
                      icon: Icons.home_outlined,
                      title: 'Resumen del inicio',
                      subtitle: 'Copia del dashboard por si falla el API.',
                      color: AppColors.warning,
                      onTap: () => _mostrarDetalle(
                        context,
                        'Inicio',
                        'El home guarda el último resumen válido hasta 24 h. '
                        'Sirve cuando hay mala señal.\n\n'
                        'Código: lib/storage/cache/dashboard_snapshot_store.dart',
                      ),
                    ),
                    _divider(),
                    _filaTappable(
                      isDark: isDark,
                      icon: Icons.notifications_outlined,
                      title: 'Alertas leídas sin red',
                      subtitle: 'SharedPreferences si el PATCH falla.',
                      color: AppColors.success,
                      onTap: () => _mostrarDetalle(
                        context,
                        'Alertas',
                        'Marcas una alerta como leída y no hay internet: lo '
                        'recordamos local y al volver online cuadra con el servidor.\n\n'
                        'Código: lib/storage/persistence/alerts_read_preferences_store.dart',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Todo lo nuevo vive en lib/storage/. Lo viejo (CacheService, '
                      'productos en API) sigue igual.',
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _card(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? AppShadows.darkCard : AppShadows.medium,
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56, endIndent: 16);

  Widget _filaEstado(
    IconData icon,
    String titulo,
    String valor,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTypography.body),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaTappable({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.body),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, String titulo, String cuerpo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(titulo, style: AppTypography.title3),
              const SizedBox(height: 12),
              Text(
                cuerpo,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
