import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/theme.dart';
import 'providers/providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_tab_view.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  await initializeDateFormatting('es_CO', null);

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

/// Mirrors ContentView.swift — routes between Onboarding, Login, and MainTabView
class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
              color: AppColors.deepSpaceBlue),
        ),
      ),
      error: (_, __) => const LoginScreen(),
      data: (authState) {
        if (!authState.hasCompletedOnboarding) {
          return const OnboardingScreen();
        }
        if (!authState.isAuthenticated) {
          return const LoginScreen();
        }
        return const MainTabView();
      },
    );
  }
}
