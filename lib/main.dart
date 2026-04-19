import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/theme.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_tab_view.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/usage_tracking_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('es_ES', null);
  await initializeDateFormatting('es_CO', null);

  // Estrategia de almacenamiento local (Hive) — Sprint 3.
  await UsageTrackingService.shared.init();

  // Inicializar notificaciones locales (canales Android + config iOS).
  // El permiso real se pide cuando el usuario activa el toggle en Ajustes.
  await NotificationService.shared.init();

  runApp(
    const ProviderScope(
      child: InventarIAApp(),
    ),
  );
}

class InventarIAApp extends ConsumerWidget {
  const InventarIAApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'InventarIA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const _AppRouter(),
    );
  }
}

/// Routes between Onboarding, Login, and MainTabView.
///
/// Architecture: _AppRouter lives as the HOME route permanently.
/// - LOGIN transitions: handled declaratively by build() — when isAuthenticated
///   changes to true, build() returns MainTabView and Flutter reconciles.
/// - LOGOUT transitions: ref.listen pops any pushed routes (e.g. SettingsScreen)
///   back to this root with popUntil, then build() returns LoginScreen.
///
/// WHY NOT pushAndRemoveUntil:
///   That call removes _AppRouter itself from the Navigator stack (because the
///   predicate `(route) => false` deletes ALL routes, including the home route
///   that contains _AppRouter). Once _AppRouter is disposed, ref.listen and
///   ref.watch stop firing — future auth changes are never handled.
class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter();

  @override
  ConsumerState<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<_AppRouter> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      final wasAuth = previous?.valueOrNull?.isAuthenticated ?? false;
      final isAuth  = next.valueOrNull?.isAuthenticated ?? false;

      if (wasAuth && !isAuth) {
        // LOGOUT — pop any pushed routes (SettingsScreen, detail screens, etc.)
        // back to this root widget. build() will then return LoginScreen.
        // We use popUntil so _AppRouter stays alive and keeps listening.
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
      }
      // LOGIN is intentionally NOT handled here.
      // build() returning MainTabView when isAuthenticated == true is enough.
      // Pushing imperatively on top of _AppRouter would create a second
      // MainTabView and eventually remove _AppRouter when navigating away.
    });

    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.deepSpaceBlue),
        ),
      ),
      error: (_, __) => const LoginScreen(),
      data: (authState) {
        if (!authState.hasCompletedOnboarding) return const OnboardingScreen();
        if (!authState.isAuthenticated)        return const LoginScreen();
        return const MainTabView();
      },
    );
  }
}
