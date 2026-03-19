import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';
import '../stores/store_management_screen.dart'
    show StoreManagementScreen, TeamMembersScreen;
import 'help_center_screen.dart'
    show HelpCenterScreen, LanguageSettingsScreen, SecurityScreen;

// ─────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final settingsState = ref.watch(settingsProvider).value;
    final authState = ref.watch(authProvider).value;
    final user = authState?.currentUser;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(title: const Text('Ajustes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
            _profileCard(user, isDark),
            const SizedBox(height: 20),
            // Preferences
            _sectionLabel('Preferencias'),
            _card([
              _toggle(
                icon: Icons.dark_mode_rounded,
                title: 'Modo Oscuro',
                color: AppColors.deepSpaceBlue,
                value: settingsState?.isDarkMode ?? false,
                onChanged: (_) => ref
                    .read(settingsProvider.notifier)
                    .toggleDarkMode(),
              ),
              _divider(),
              _toggle(
                icon: Icons.notifications_rounded,
                title: 'Notificaciones',
                color: AppColors.warning,
                value:
                    settingsState?.notificationsEnabled ?? true,
                onChanged: (_) => ref
                    .read(settingsProvider.notifier)
                    .toggleNotifications(),
              ),
              _divider(),
              _navRow(
                icon: Icons.language_rounded,
                title: 'Idioma',
                color: AppColors.info,
                value: settingsState?.languageName,
                onTap: () => _push(
                    context, const LanguageSettingsScreen()),
              ),
            ], isDark),
            const SizedBox(height: 16),
            // Account
            _sectionLabel('Cuenta'),
            _card([
              _navRow(
                icon: Icons.storefront_rounded,
                title: 'Gestión de Tiendas',
                color: AppColors.teaGreen,
                onTap: () => _push(
                    context, const StoreManagementScreen()),
              ),
              _divider(),
              _navRow(
                icon: Icons.group_rounded,
                title: 'Miembros del Equipo',
                color: AppColors.freshSky,
                onTap: () =>
                    _push(context, const TeamMembersScreen()),
              ),
              _divider(),
              _navRow(
                icon: Icons.shield_rounded,
                title: 'Seguridad',
                color: AppColors.success,
                onTap: () =>
                    _push(context, const SecurityScreen()),
              ),
            ], isDark),
            const SizedBox(height: 16),
            // Support
            _sectionLabel('Soporte'),
            _card([
              _navRow(
                icon: Icons.help_rounded,
                title: 'Centro de Ayuda',
                color: AppColors.info,
                onTap: () =>
                    _push(context, const HelpCenterScreen()),
              ),
              _divider(),
              _navRow(
                icon: Icons.description_rounded,
                title: 'Términos y Condiciones',
                color: AppColors.textSecondary,
                onTap: () {},
              ),
            ], isDark),
            const SizedBox(height: 16),
            // Logout
            GestureDetector(
              onTap: () => _confirmLogout(context),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.error
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Cerrar Sesión',
                        style: AppTypography.headline
                            .copyWith(
                                color: AppColors.error)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'InventarIA v${settingsState?.appVersion ?? '1.0.0'} (${settingsState?.buildNumber ?? '1'})',
                style: AppTypography.caption2
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(user, bool isDark) {
    return GestureDetector(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? AppShadows.darkMedium
              : AppShadows.medium,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.deepSpaceBlue
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user?.initials ?? '??',
                  style: AppTypography.title3.copyWith(
                      color: AppColors.deepSpaceBlue),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.fullName ?? 'Usuario',
                      style: AppTypography.headline.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary)),
                  Text(user?.storeName ?? 'Mi Tienda',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary)),
                  Text(user?.email ?? '',
                      style: AppTypography.caption2.copyWith(
                          color: AppColors.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title,
          style: AppTypography.caption
              .copyWith(color: AppColors.textSecondary)),
    );
  }

  Widget _card(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            isDark ? AppShadows.darkMedium : AppShadows.medium,
      ),
      child: Column(children: children),
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title, style: AppTypography.body)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.deepSpaceBlue,
            activeTrackColor: AppColors.deepSpaceBlue.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _navRow({
    required IconData icon,
    required String title,
    required Color color,
    String? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
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
                child:
                    Text(title, style: AppTypography.body)),
            if (value != null) ...[
              Text(value,
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary)),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 60, endIndent: 16);

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => screen));
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text(
            '¿Estás seguro de que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: Text('Cerrar Sesión',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
