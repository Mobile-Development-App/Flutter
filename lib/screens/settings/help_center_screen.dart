import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';
import '../../widgets/badge_widget.dart';

// ─────────────────────────────────────────────
// HelpCenterScreen
// ─────────────────────────────────────────────
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const _categories = [
    _HelpCat('Inventario', Icons.inventory_2_rounded,
        AppColors.deepSpaceBlue, [
      _HelpItem('Agregar Productos',
          'Registra nuevos productos manualmente o mediante escaneo con IA.'),
      _HelpItem('Gestión de Stock',
          'Monitorea niveles de stock y configura alertas de stock mínimo.'),
      _HelpItem('Control de Vencimiento',
          'Configura alertas para productos próximos a vencer.'),
    ]),
    _HelpCat('Analítica', Icons.bar_chart_rounded,
        AppColors.teaGreen, [
      _HelpItem('Reportes de Ventas',
          'Visualiza tendencias de ventas por período de tiempo.'),
      _HelpItem('Exportar Datos',
          'Exporta reportes en formato PDF o CSV para contabilidad.'),
    ]),
    _HelpCat('Escaneo', Icons.camera_enhance_rounded,
        AppColors.freshSky, [
      _HelpItem('Escaneo con IA',
          'Usa la cámara para identificar productos automáticamente.'),
      _HelpItem('Códigos de Barras',
          'Escanea códigos de barras para buscar productos.'),
      _HelpItem('Detección de Duplicados',
          'El sistema detecta automáticamente si un producto ya existe.'),
    ]),
    _HelpCat('Gestión', Icons.group_rounded, AppColors.warning, [
      _HelpItem('Multi-tienda',
          'Administra múltiples ubicaciones desde una sola cuenta.'),
      _HelpItem('Roles de Equipo',
          'Asigna roles y permisos a los miembros del equipo.'),
      _HelpItem('Seguridad',
          'Configura autenticación de dos factores y gestiona accesos.'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(title: const Text('Centro de Ayuda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _catCard(cat, isDark),
              )),
          // Contact support
          Container(
            padding: const EdgeInsets.all(20),
            decoration:
                cardDecoration(isDark: isDark),
            child: Column(
              children: [
                const Icon(Icons.headset_mic_rounded,
                    size: 40, color: AppColors.deepSpaceBlue),
                const SizedBox(height: 12),
                Text('¿Necesitas más ayuda?',
                    style: AppTypography.headline),
                const SizedBox(height: 4),
                Text('Contacta a nuestro equipo de soporte',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: primaryButtonStyle,
                    child: const Text('Contactar Soporte'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catCard(_HelpCat cat, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cat.icon, color: cat.color, size: 18),
              const SizedBox(width: 8),
              Text(cat.name, style: AppTypography.headline),
            ],
          ),
          const SizedBox(height: 12),
          ...cat.items.map((item) => _expandable(item, isDark)),
        ],
      ),
    );
  }

  Widget _expandable(_HelpItem item, bool isDark) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(item.title, style: AppTypography.callout),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            item.description,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _HelpCat {
  final String name;
  final IconData icon;
  final Color color;
  final List<_HelpItem> items;
  const _HelpCat(this.name, this.icon, this.color, this.items);
}

class _HelpItem {
  final String title, description;
  const _HelpItem(this.title, this.description);
}

// ─────────────────────────────────────────────
// LanguageSettingsScreen
// ─────────────────────────────────────────────
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  static const _languages = [
    ('es', 'Español', '🇨🇴'),
    ('en', 'English', '🇺🇸'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final selected =
        ref.watch(settingsProvider).value?.selectedLanguage ??
            'es';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(title: const Text('Idioma')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _languages.map((lang) {
            final (code, name, flag) = lang;
            final isSelected = selected == code;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setLanguage(code);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.deepSpaceBlue
                            .withValues(alpha: 0.08)
                        : (isDark
                            ? AppColors.darkSurface
                            : AppColors.surface),
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.deepSpaceBlue
                              .withValues(alpha: 0.3)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isDark
                        ? AppShadows.darkCard
                        : AppShadows.medium,
                  ),
                  child: Row(
                    children: [
                      Text(flag,
                          style:
                              const TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(name,
                              style:
                                  AppTypography.body)),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.deepSpaceBlue,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SecurityScreen
// ─────────────────────────────────────────────
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() =>
      _SecurityScreenState();
}

class _SecurityScreenState
    extends ConsumerState<SecurityScreen> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final user =
        ref.watch(authProvider).value?.currentUser;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(title: const Text('Seguridad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Overview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(isDark: isDark),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded,
                      size: 36, color: AppColors.success),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Seguridad de la Cuenta',
                            style: AppTypography.headline),
                        Text(
                            'Tu cuenta tiene un nivel de seguridad bueno',
                            style:
                                AppTypography.caption.copyWith(
                                    color: AppColors
                                        .textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Credentials
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Credenciales',
                      style: AppTypography.headline),
                  const SizedBox(height: 12),
                  _credentialRow(
                    icon: Icons.email_outlined,
                    value: user?.email ?? '',
                    isDark: isDark,
                    trailing: BadgeWidget(
                        text: 'Verificado',
                        style: BadgeStyle.success),
                  ),
                  const SizedBox(height: 10),
                  _credentialRow(
                    icon: Icons.lock_outline_rounded,
                    value: _showPassword
                        ? 'demo123'
                        : '••••••••',
                    isDark: isDark,
                    trailing: IconButton(
                      onPressed: () => setState(
                          () => _showPassword =
                              !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Acciones de Seguridad',
                      style: AppTypography.headline),
                  const SizedBox(height: 12),
                  _actionRow(Icons.key_rounded,
                      'Cambiar Contraseña',
                      AppColors.deepSpaceBlue, isDark),
                  _actionRow(Icons.lock_person_rounded,
                      'Autenticación de 2 Factores',
                      AppColors.teaGreen, isDark),
                  _actionRow(Icons.history_rounded,
                      'Historial de Acceso',
                      AppColors.info, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Text('Consejos de Seguridad',
                          style: AppTypography.headline),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...const [
                    'Usa una contraseña de al menos 8 caracteres',
                    'Activa la autenticación de 2 factores',
                    'No compartas tus credenciales de acceso',
                    'Revisa periódicamente el historial de acceso',
                  ].map((tip) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(tip,
                                  style:
                                      AppTypography.caption.copyWith(
                                          color: AppColors
                                              .textSecondary)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentialRow({
    required IconData icon,
    required String value,
    required bool isDark,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceSecondary
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: AppColors.textTertiary, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(value, style: AppTypography.body)),
          trailing,
        ],
      ),
    );
  }

  Widget _actionRow(IconData icon, String title,
      Color color, bool isDark) {
    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                child: Text(title,
                    style: AppTypography.callout)),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
