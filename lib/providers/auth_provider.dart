import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../core/utils/extensions.dart';

// ─────────────────────────────────────────────
// AuthState
// ─────────────────────────────────────────────
class AuthState {
  final bool isAuthenticated;
  final bool hasCompletedOnboarding;
  final User? currentUser;
  final String loginEmail;
  final String loginPassword;
  final String? loginError;
  final bool isLoggingIn;
  final String signUpName;
  final String signUpEmail;
  final String signUpPassword;
  final String signUpConfirmPassword;
  final String signUpStoreName;
  final bool signUpAcceptedTerms;
  final String? signUpError;
  final bool isSigningUp;
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
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? this.hasCompletedOnboarding,
        currentUser: clearUser ? null : (currentUser ?? this.currentUser),
        loginEmail: loginEmail ?? this.loginEmail,
        loginPassword: loginPassword ?? this.loginPassword,
        loginError:
            clearLoginError ? null : (loginError ?? this.loginError),
        isLoggingIn: isLoggingIn ?? this.isLoggingIn,
        signUpName: signUpName ?? this.signUpName,
        signUpEmail: signUpEmail ?? this.signUpEmail,
        signUpPassword: signUpPassword ?? this.signUpPassword,
        signUpConfirmPassword:
            signUpConfirmPassword ?? this.signUpConfirmPassword,
        signUpStoreName: signUpStoreName ?? this.signUpStoreName,
        signUpAcceptedTerms: signUpAcceptedTerms ?? this.signUpAcceptedTerms,
        signUpError:
            clearSignUpError ? null : (signUpError ?? this.signUpError),
        isSigningUp: isSigningUp ?? this.isSigningUp,
        forgotPasswordEmail: forgotPasswordEmail ?? this.forgotPasswordEmail,
        forgotPasswordSent: forgotPasswordSent ?? this.forgotPasswordSent,
        forgotPasswordError: clearForgotError
            ? null
            : (forgotPasswordError ?? this.forgotPasswordError),
      );
}

// ─────────────────────────────────────────────
// AuthNotifier
// Flow:
//   LOGIN:    FirebaseAuth.signInWithEmailAndPassword → uid → POST /auth/login
//   REGISTER: POST /auth/register → FirebaseAuth.signInWithEmailAndPassword
// ─────────────────────────────────────────────
class AuthNotifier extends AsyncNotifier<AuthState> {
  final _api    = ApiService.shared;
  final _fbAuth = fb.FirebaseAuth.instance;

  static const _onboardingKey = 'hasCompletedOnboarding';
  static const _userCacheKey  = 'inventaria_cached_user';

  @override
  Future<AuthState> build() async {
    final prefs     = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(_onboardingKey) ?? false;

    final hasToken = await _api.restoreAuth();
    if (!hasToken) {
      return AuthState(hasCompletedOnboarding: onboarded);
    }

    final cached = prefs.getString(_userCacheKey);
    if (cached != null) {
      try {
        final user =
            User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        return AuthState(
          isAuthenticated: true,
          hasCompletedOnboarding: onboarded,
          currentUser: user,
        );
      } catch (_) {}
    }

    return AuthState(
      isAuthenticated: true,
      hasCompletedOnboarding: onboarded,
    );
  }

  // ── Login ─────────────────────────────────
  Future<void> login() async {
    final s = state.value;
    if (s == null || !s.isLoginValid) return;
    _update((c) => c.copyWith(isLoggingIn: true, clearLoginError: true));

    try {
      // Step 1 — Firebase Auth SDK
      debugPrint('[AUTH] Signing in with Firebase: ${s.loginEmail}');
      final credential = await _fbAuth.signInWithEmailAndPassword(
        email:    s.loginEmail.trim(),
        password: s.loginPassword,
      );

      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        throw Exception('Firebase no devolvió un UID válido');
      }
      debugPrint('[AUTH] Firebase OK — uid: $uid');

      // Step 2 — Backend exchange
      debugPrint('[AUTH] Calling backend /auth/login with uid');
      final body = await _api.post(kAuthLogin, {'uid': uid})
          as Map<String, dynamic>;
      debugPrint('[AUTH] Backend OK — storeId: ${body['storeId']}');

      final storeId = body['storeId'] as String? ?? '';
      final user    = User.fromBackendJson(body);

      await _api.setAuth(uid, storeId);
      await _saveUserCache(user);
      await HapticManager.success();

      _update((c) => c.copyWith(
            isLoggingIn: false,
            isAuthenticated: true,
            currentUser: user,
          ));
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('[AUTH] FirebaseAuthException: code=${e.code} msg=${e.message}');
      await HapticManager.error();
      _update((c) => c.copyWith(
            isLoggingIn: false,
            loginError: _mapFirebaseError(e.code),
          ));
    } on ApiException catch (e) {
      debugPrint('[AUTH] ApiException: status=${e.statusCode} msg=${e.message}');
      await HapticManager.error();
      _update((c) => c.copyWith(
            isLoggingIn: false,
            loginError: _mapApiError(e),
          ));
    } catch (e, stack) {
      // Log the REAL error so we can debug it
      debugPrint('[AUTH] Unexpected error: $e');
      debugPrint('[AUTH] Stack: $stack');
      await HapticManager.error();
      _update((c) => c.copyWith(
            isLoggingIn: false,
            // Show real error in debug, generic in release
            loginError: kDebugMode
                ? 'Error: $e'
                : 'Error de conexión. Verifica tu internet.',
          ));
    }
  }

  // ── Register ──────────────────────────────
  Future<void> signUp() async {
    final s = state.value;
    if (s == null || !s.isSignUpValid) return;
    _update((c) => c.copyWith(isSigningUp: true, clearSignUpError: true));

    try {
      debugPrint('[AUTH] Registering via backend: ${s.signUpEmail}');
      final body = await _api.post(kAuthRegister, {
        'name':      s.signUpName,
        'email':     s.signUpEmail,
        'password':  s.signUpPassword,
        'storeName': s.signUpStoreName,
      }) as Map<String, dynamic>;

      final storeId = body['storeId'] as String? ?? '';
      final uid     = body['uid']     as String? ?? '';
      debugPrint('[AUTH] Register OK — uid=$uid storeId=$storeId');

      // Sign in with Firebase SDK to get a valid session
      await _fbAuth.signInWithEmailAndPassword(
        email:    s.signUpEmail.trim(),
        password: s.signUpPassword,
      );

      final user = User.fromBackendJson(body);
      await _api.setAuth(uid, storeId);
      await _saveUserCache(user);
      await HapticManager.success();

      _update((c) => c.copyWith(
            isSigningUp: false,
            isAuthenticated: true,
            currentUser: user,
          ));
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('[AUTH] FirebaseAuthException on signUp: ${e.code}');
      await HapticManager.error();
      _update((c) => c.copyWith(
            isSigningUp: false,
            signUpError: _mapFirebaseError(e.code),
          ));
    } on ApiException catch (e) {
      debugPrint('[AUTH] ApiException on signUp: ${e.statusCode} ${e.message}');
      await HapticManager.error();
      _update((c) => c.copyWith(
            isSigningUp: false,
            signUpError: _mapApiError(e),
          ));
    } catch (e, stack) {
      debugPrint('[AUTH] Unexpected signUp error: $e');
      debugPrint('[AUTH] Stack: $stack');
      _update((c) => c.copyWith(
            isSigningUp: false,
            signUpError: kDebugMode
                ? 'Error: $e'
                : 'Error de conexión. Verifica tu internet.',
          ));
    }
  }

  // ── Password Reset ────────────────────────
  Future<void> sendPasswordReset() async {
    final s = state.value;
    if (s == null ||
        s.forgotPasswordEmail.isEmpty ||
        !s.forgotPasswordEmail.contains('@')) {
      _update((c) => c.copyWith(
            forgotPasswordError: 'Ingresa un correo electrónico válido'));
      return;
    }
    try {
      await _fbAuth.sendPasswordResetEmail(
          email: s.forgotPasswordEmail.trim());
      _update((c) =>
          c.copyWith(forgotPasswordSent: true, clearForgotError: true));
    } on fb.FirebaseAuthException catch (e) {
      _update((c) =>
          c.copyWith(forgotPasswordError: _mapFirebaseError(e.code)));
    } catch (_) {
      _update((c) =>
          c.copyWith(forgotPasswordError: 'Error al enviar el correo.'));
    }
  }

  // ── Onboarding ────────────────────────────
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    _update((s) => s.copyWith(hasCompletedOnboarding: true));
  }

  // ── Logout ────────────────────────────────
  Future<void> logout() async {
    try { await _api.post(kAuthLogout, {}); } catch (_) {}
    try { await _fbAuth.signOut(); } catch (_) {}
    await _api.clearAuth();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userCacheKey);
    _update((s) => s.copyWith(
          isAuthenticated: false,
          clearUser: true,
          loginEmail: '',
          loginPassword: '',
          clearLoginError: true,
        ));
  }

  // ── Field setters ─────────────────────────
  void setLoginEmail(String v) =>
      _update((s) => s.copyWith(loginEmail: v, clearLoginError: true));
  void setLoginPassword(String v) =>
      _update((s) => s.copyWith(loginPassword: v, clearLoginError: true));
  void setSignUpName(String v) =>
      _update((s) => s.copyWith(signUpName: v));
  void setSignUpEmail(String v) =>
      _update((s) => s.copyWith(signUpEmail: v));
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
  void clearLoginFields() => _update((s) =>
      s.copyWith(loginEmail: '', loginPassword: '', clearLoginError: true));
  void clearSignUpFields() => _update((s) => s.copyWith(
        signUpName: '',
        signUpEmail: '',
        signUpPassword: '',
        signUpConfirmPassword: '',
        signUpStoreName: '',
        signUpAcceptedTerms: false,
        clearSignUpError: true,
      ));

  // ── Private ───────────────────────────────
  void _update(AuthState Function(AuthState) fn) {
    final current = state.value;
    if (current != null) state = AsyncData(fn(current));
  }

  Future<void> _saveUserCache(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userCacheKey, jsonEncode(user.toJson()));
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 8 caracteres.';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet.';
      case 'operation-not-allowed':
        return 'Método de login no habilitado en Firebase Console.';
      default:
        // En debug mostramos el código real para poder diagnosticar
        return kDebugMode
            ? 'Firebase error: $code'
            : 'Error de autenticación. Intenta de nuevo.';
    }
  }

  String _mapApiError(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return 'Credenciales inválidas.';
      case 404:
        return 'No se encontró la cuenta en el sistema.';
      case 409:
        return 'Ya existe una cuenta con este correo.';
      default:
        return e.message.isNotEmpty ? e.message : 'Error inesperado.';
    }
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
