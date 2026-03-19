
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/persistence_service.dart';
import '../core/utils/extensions.dart';

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────
class AuthState {
  final bool isAuthenticated;
  final bool hasCompletedOnboarding;
  final User? currentUser;

  // Login fields
  final String loginEmail;
  final String loginPassword;
  final String? loginError;
  final bool isLoggingIn;

  // Sign up fields
  final String signUpName;
  final String signUpEmail;
  final String signUpPassword;
  final String signUpConfirmPassword;
  final String signUpStoreName;
  final bool signUpAcceptedTerms;
  final String? signUpError;
  final bool isSigningUp;

  // Forgot password fields
  final String forgotPasswordEmail;
  final bool forgotPasswordSent;
  final String? forgotPasswordError;

  const AuthState({
    this.isAuthenticated = false,
    this.hasCompletedOnboarding = false,
    this.currentUser,
    this.loginEmail = '',
    this.loginPassword = '',
    this.loginError,
    this.isLoggingIn = false,
    this.signUpName = '',
    this.signUpEmail = '',
    this.signUpPassword = '',
    this.signUpConfirmPassword = '',
    this.signUpStoreName = '',
    this.signUpAcceptedTerms = false,
    this.signUpError,
    this.isSigningUp = false,
    this.forgotPasswordEmail = '',
    this.forgotPasswordSent = false,
    this.forgotPasswordError,
  });

  // ── Computed validators (mirrors Swift computed vars) ──

  bool get isLoginValid =>
      loginEmail.isNotEmpty &&
      loginPassword.isNotEmpty &&
      loginEmail.contains('@');

  bool get isSignUpValid =>
      signUpName.isNotEmpty &&
      signUpEmail.isNotEmpty &&
      signUpEmail.contains('@') &&
      signUpPassword.length >= 8 &&
      signUpPassword == signUpConfirmPassword &&
      signUpStoreName.isNotEmpty &&
      signUpAcceptedTerms;

  bool get passwordsMatch => signUpPassword == signUpConfirmPassword;
  bool get passwordLengthValid => signUpPassword.length >= 8;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? hasCompletedOnboarding,
    User? currentUser,
    bool clearUser = false,
    String? loginEmail,
    String? loginPassword,
    String? loginError,
    bool clearLoginError = false,
    bool? isLoggingIn,
    String? signUpName,
    String? signUpEmail,
    String? signUpPassword,
    String? signUpConfirmPassword,
    String? signUpStoreName,
    bool? signUpAcceptedTerms,
    String? signUpError,
    bool clearSignUpError = false,
    bool? isSigningUp,
    String? forgotPasswordEmail,
    bool? forgotPasswordSent,
    String? forgotPasswordError,
    bool clearForgotError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      loginEmail: loginEmail ?? this.loginEmail,
      loginPassword: loginPassword ?? this.loginPassword,
      loginError: clearLoginError ? null : (loginError ?? this.loginError),
      isLoggingIn: isLoggingIn ?? this.isLoggingIn,
      signUpName: signUpName ?? this.signUpName,
      signUpEmail: signUpEmail ?? this.signUpEmail,
      signUpPassword: signUpPassword ?? this.signUpPassword,
      signUpConfirmPassword:
          signUpConfirmPassword ?? this.signUpConfirmPassword,
      signUpStoreName: signUpStoreName ?? this.signUpStoreName,
      signUpAcceptedTerms: signUpAcceptedTerms ?? this.signUpAcceptedTerms,
      signUpError: clearSignUpError ? null : (signUpError ?? this.signUpError),
      isSigningUp: isSigningUp ?? this.isSigningUp,
      forgotPasswordEmail: forgotPasswordEmail ?? this.forgotPasswordEmail,
      forgotPasswordSent: forgotPasswordSent ?? this.forgotPasswordSent,
      forgotPasswordError: clearForgotError
          ? null
          : (forgotPasswordError ?? this.forgotPasswordError),
    );
  }
}

// ─────────────────────────────────────────────
// Notifier  (mirrors AuthViewModel)
// ─────────────────────────────────────────────
class AuthNotifier extends AsyncNotifier<AuthState> {
  final _persistence = PersistenceService.shared;
  static const _onboardingKey = 'hasCompletedOnboarding';

  @override
  Future<AuthState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(_onboardingKey) ?? false;
    final savedUser = await _persistence.loadUser();

    return AuthState(
      isAuthenticated: savedUser != null,
      hasCompletedOnboarding: onboarded,
      currentUser: savedUser,
    );
  }

  // ── Field update helpers ──────────────────

  void setLoginEmail(String v) =>
      _update((s) => s.copyWith(loginEmail: v, clearLoginError: true));
  void setLoginPassword(String v) =>
      _update((s) => s.copyWith(loginPassword: v, clearLoginError: true));

  void setSignUpName(String v) => _update((s) => s.copyWith(signUpName: v));
  void setSignUpEmail(String v) => _update((s) => s.copyWith(signUpEmail: v));
  void setSignUpPassword(String v) =>
      _update((s) => s.copyWith(signUpPassword: v));
  void setSignUpConfirmPassword(String v) =>
      _update((s) => s.copyWith(signUpConfirmPassword: v));
  void setSignUpStoreName(String v) =>
      _update((s) => s.copyWith(signUpStoreName: v));
  void setSignUpAcceptedTerms(bool v) =>
      _update((s) => s.copyWith(signUpAcceptedTerms: v));

  void setForgotPasswordEmail(String v) =>
      _update((s) => s.copyWith(forgotPasswordEmail: v));

  // ── Actions ───────────────────────────────

  /// Login with simulated async auth (mirrors login() in Swift)
  Future<void> login() async {
    final current = state.value;
    if (current == null || !current.isLoginValid) return;

    _update((s) => s.copyWith(isLoggingIn: true, clearLoginError: true));

    // Simulate network delay (1.5s like Swift)
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final s = state.value!;
    final isDemo =
        s.loginEmail == 'demo@inventory.com' && s.loginPassword == 'demo123';
    final isValid =
        s.loginEmail.contains('@') && s.loginPassword.length >= 4;

    if (isDemo || isValid) {
      final name = isDemo
          ? 'Sarah Johnson'
          : (s.loginEmail.split('@').first.isEmpty
              ? 'Usuario'
              : _capitalize(s.loginEmail.split('@').first));

      final user = User(
        id: const Uuid().v4(),
        fullName: name,
        email: s.loginEmail,
        phone: '+57 301 123 4567',
        role: UserRole.owner,
        storeName: 'Tienda Principal',
        joinDate: DateTime.now(),
        isActive: true,
      );

      await _persistence.saveUser(user);
      await HapticManager.success();
      _update((s) => s.copyWith(
            isLoggingIn: false,
            isAuthenticated: true,
            currentUser: user,
          ));
    } else {
      await HapticManager.error();
      _update((s) => s.copyWith(
            isLoggingIn: false,
            loginError: 'Credenciales inválidas. Intenta de nuevo.',
          ));
    }
  }

  /// Sign up (mirrors signUp())
  Future<void> signUp() async {
    final s = state.value;
    if (s == null || !s.isSignUpValid) return;

    _update((c) => c.copyWith(isSigningUp: true, clearSignUpError: true));
    await Future<void>.delayed(const Duration(milliseconds: 2000));

    final current = state.value!;
    final newUser = User(
      id: const Uuid().v4(),
      fullName: current.signUpName,
      email: current.signUpEmail,
      phone: '',
      role: UserRole.owner,
      storeName: current.signUpStoreName,
      joinDate: DateTime.now(),
      isActive: true,
    );

    await _persistence.saveUser(newUser);
    await HapticManager.success();
    _update((c) => c.copyWith(
          isSigningUp: false,
          isAuthenticated: true,
          currentUser: newUser,
        ));
  }

  /// Send password reset email (mirrors sendPasswordReset())
  Future<void> sendPasswordReset() async {
    final s = state.value;
    if (s == null ||
        s.forgotPasswordEmail.isEmpty ||
        !s.forgotPasswordEmail.contains('@')) {
      _update((c) => c.copyWith(
            forgotPasswordError: 'Ingresa un correo electrónico válido',
          ));
      return;
    }

    await Future<void>.delayed(const Duration(seconds: 1));
    _update((c) =>
        c.copyWith(forgotPasswordSent: true, clearForgotError: true));
  }

  /// Marks onboarding as complete (mirrors completeOnboarding())
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    _update((s) => s.copyWith(hasCompletedOnboarding: true));
  }

  /// Log out (mirrors logout())
  Future<void> logout() async {
    await _persistence.clearUser();
    _update((s) => s.copyWith(
          isAuthenticated: false,
          clearUser: true,
          loginEmail: '',
          loginPassword: '',
          clearLoginError: true,
        ));
  }

  void clearLoginFields() =>
      _update((s) => s.copyWith(loginEmail: '', loginPassword: '', clearLoginError: true));

  void clearSignUpFields() => _update((s) => s.copyWith(
        signUpName: '',
        signUpEmail: '',
        signUpPassword: '',
        signUpConfirmPassword: '',
        signUpStoreName: '',
        signUpAcceptedTerms: false,
        clearSignUpError: true,
      ));

  // ── Private helpers ───────────────────────

  void _update(AuthState Function(AuthState) fn) {
    final current = state.value;
    if (current != null) state = AsyncData(fn(current));
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
