import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/extensions.dart';
import '../services/notification_service.dart';

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────
class SettingsState {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final String selectedLanguage;
  final bool showingLogoutConfirmation;

  const SettingsState({
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.selectedLanguage = 'es',
    this.showingLogoutConfirmation = false,
  });

  // mirrors languageName computed var
  String get languageName {
    switch (selectedLanguage) {
      case 'es':
        return 'Español';
      case 'en':
        return 'English';
      default:
        return 'Español';
    }
  }

  // mirrors appVersion / buildNumber — hardcoded here,
  // replace with package_info_plus if needed
  String get appVersion => '1.0.0';
  String get buildNumber => '1';

  SettingsState copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    String? selectedLanguage,
    bool? showingLogoutConfirmation,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      showingLogoutConfirmation:
          showingLogoutConfirmation ?? this.showingLogoutConfirmation,
    );
  }
}

// ─────────────────────────────────────────────
// Notifier  (mirrors SettingsViewModel)
// @AppStorage → SharedPreferences
// ─────────────────────────────────────────────
class SettingsNotifier extends AsyncNotifier<SettingsState> {
  static const _darkModeKey = 'isDarkMode';
  static const _notificationsKey = 'notificationsEnabled';
  static const _languageKey = 'selectedLanguage';

  @override
  Future<SettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsState(
      isDarkMode: prefs.getBool(_darkModeKey) ?? false,
      notificationsEnabled: prefs.getBool(_notificationsKey) ?? true,
      selectedLanguage: prefs.getString(_languageKey) ?? 'es',
    );
  }

  Future<void> toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !(state.value?.isDarkMode ?? false);
    await prefs.setBool(_darkModeKey, next);
    await HapticManager.impact();
    _update((s) => s.copyWith(isDarkMode: next));
  }

  Future<void> toggleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !(state.value?.notificationsEnabled ?? true);

    if (next) {
      // El usuario ACTIVA notificaciones:
      // 1. Solicitar permiso al SO (iOS / Android 13+)
      final granted = await NotificationService.shared.requestPermission();
      if (!granted) {
        // Si el usuario deniega el permiso, no cambiamos el toggle
        debugPrint('[Settings] Notification permission denied by user');
        return;
      }
    } else {
      // El usuario DESACTIVA: cancelar todas las notificaciones pendientes
      await NotificationService.shared.cancelAll();
    }

    await prefs.setBool(_notificationsKey, next);
    await HapticManager.impact();
    _update((s) => s.copyWith(notificationsEnabled: next));
    debugPrint('[Settings] Notifications ${next ? "enabled" : "disabled"}');
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, lang);
    _update((s) => s.copyWith(selectedLanguage: lang));
  }

  void setShowingLogoutConfirmation(bool v) =>
      _update((s) => s.copyWith(showingLogoutConfirmation: v));

  void _update(SettingsState Function(SettingsState) fn) {
    final current = state.value;
    if (current != null) state = AsyncData(fn(current));
  }
}

// ─────────────────────────────────────────────
// Provider + ThemeMode derived provider
// ─────────────────────────────────────────────
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(
        SettingsNotifier.new);

/// Derived provider — lets MaterialApp watch ThemeMode reactively
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.when(
    data: (s) => s.isDarkMode ? ThemeMode.dark : ThemeMode.light,
    loading: () => ThemeMode.system,
    error: (_, __) => ThemeMode.system,
  );
});
