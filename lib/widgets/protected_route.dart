import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/user.dart';
import '../providers/providers.dart';  // authProvider
import '../screens/auth/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProtectedRoute
//
// Widget declarativo que protege cualquier pantalla basándose en:
//   • isAuthenticated → redirige a LoginScreen si no hay sesión activa.
//   • allowedRoles    → muestra _AccessDeniedScreen si el rol del usuario
//                       no está en la lista.
//
// ARQUITECTURA:
//   Encaja en el patrón declarativo de _AppRouter (no go_router).
//   Lee authProvider directamente, por lo que reacciona automáticamente
//   a cambios de sesión / cambios de rol sin ningún código adicional.
//
// USO BÁSICO — pantalla solo para autenticados (cualquier rol):
//   ProtectedRoute(child: AnalyticsScreen())
//
// USO CON ROL — solo owner y manager pueden ver Analytics:
//   ProtectedRoute(
//     allowedRoles: {UserRole.owner, UserRole.manager},
//     child: AnalyticsScreen(),
//   )
//
// USO EN IndexedStack de MainTabView:
//   ProtectedRoute(
//     allowedRoles: {UserRole.owner, UserRole.manager},
//     accessDeniedTitle: 'Analítica restringida',
//     accessDeniedSubtitle: 'Necesitas ser propietario o gerente.',
//     child: AnalyticsScreen(),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class ProtectedRoute extends ConsumerWidget {
  const ProtectedRoute({
    super.key,
    required this.child,
    this.allowedRoles,
    this.accessDeniedTitle   = 'Acceso restringido',
    this.accessDeniedSubtitle =
        'No tienes los permisos necesarios para ver esta sección.',
  });

  /// Widget a renderizar si se cumplen todas las condiciones.
  final Widget child;

  /// Roles que tienen acceso. `null` = cualquier usuario autenticado.
  final Set<UserRole>? allowedRoles;

  /// Textos personalizables de la pantalla de acceso denegado.
  final String accessDeniedTitle;
  final String accessDeniedSubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      // Mientras se carga el estado de auth → spinner neutro.
      loading: () => const _LoadingGuard(),

      // Error de auth → tratar como no autenticado → LoginScreen.
      error: (_, __) => const LoginScreen(),

      data: (authState) {
        // ── Regla 1: debe estar autenticado ──────────────────────────────────
        if (!authState.isAuthenticated) {
          return const LoginScreen();
        }

        // ── Regla 2: debe tener un rol permitido (si se especifica) ──────────
        if (allowedRoles != null) {
          final userRole = authState.currentUser?.role;
          final hasAccess = userRole != null && allowedRoles!.contains(userRole);

          if (!hasAccess) {
            return _AccessDeniedScreen(
              title: accessDeniedTitle,
              subtitle: accessDeniedSubtitle,
              userRole: userRole,
            );
          }
        }

        // ── Acceso concedido ─────────────────────────────────────────────────
        return child;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadingGuard — spinner mientras authProvider resuelve
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingGuard extends StatelessWidget {
  const _LoadingGuard();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.deepSpaceBlue),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AccessDeniedScreen
//
// Se muestra dentro del IndexedStack cuando el usuario está autenticado pero
// no tiene el rol requerido.  NO hace pop ni push — es puramente declarativa,
// consistente con la arquitectura de _AppRouter.
// ─────────────────────────────────────────────────────────────────────────────

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({
    required this.title,
    required this.subtitle,
    this.userRole,
  });

  final String title;
  final String subtitle;
  final UserRole? userRole;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icono ──────────────────────────────────────────────────────
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 36,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),

              // ── Título ─────────────────────────────────────────────────────
              Text(
                title,
                style: AppTypography.title.copyWith(

                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ── Subtítulo ──────────────────────────────────────────────────
              Text(
                subtitle,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              // ── Rol actual (debug-friendly) ────────────────────────────────
              if (userRole != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceSecondary
                        : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tu rol actual: ${userRole!.label}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
