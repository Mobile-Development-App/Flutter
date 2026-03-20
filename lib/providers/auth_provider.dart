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
  final String signUpStoreAddress;
  final String signUpStorePhone;
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
    this.signUpStoreAddress = '',
    this.signUpStorePhone = '',
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

  bool get passwordsMatch    => signUpPassword == signUpConfirmPassword;
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
    String? signUpStoreAddress,
    String? signUpStorePhone,
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
        isAuthenticated:        isAuthenticated ?? this.isAuthenticated,
        hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
        currentUser:  clearUser ? null : (currentUser ?? this.currentUser),
        loginEmail:   loginEmail   ?? this.loginEmail,
        loginPassword: loginPassword ?? this.loginPassword,
        loginError:   clearLoginError ? null : (loginError ?? this.loginError),
        isLoggingIn:  isLoggingIn  ?? this.isLoggingIn,
        signUpName:   signUpName   ?? this.signUpName,
        signUpEmail:  signUpEmail  ?? this.signUpEmail,
        signUpPassword: signUpPassword ?? this.signUpPassword,
        signUpConfirmPassword: signUpConfirmPassword ?? this.signUpConfirmPassword,
        signUpStoreName:    signUpStoreName    ?? this.signUpStoreName,
        signUpStoreAddress: signUpStoreAddress ?? this.signUpStoreAddress,
        signUpStorePhone:   signUpStorePhone   ?? this.signUpStorePhone,
        signUpAcceptedTerms: signUpAcceptedTerms ?? this.signUpAcceptedTerms,
        signUpError:  clearSignUpError ? null : (signUpError ?? this.signUpError),
        isSigningUp:  isSigningUp  ?? this.isSigningUp,
        forgotPasswordEmail: forgotPasswordEmail ?? this.forgotPasswordEmail,
        forgotPasswordSent:  forgotPasswordSent  ?? this.forgotPasswordSent,
        forgotPasswordError: clearForgotError
            ? null
            : (forgotPasswordError ?? this.forgotPasswordError),
      );
}

// ─────────────────────────────────────────────
// AuthNotifier
//
// LOGIN flow:
//   1. FirebaseAuth.signInWithEmailAndPassword  → fbUser
//   2. fbUser.getIdToken()                      → idToken (JWT)
//   3. POST /auth/login { uid }                 → { uid, storeId, name, role }
//   4. ApiService.setAuth(idToken, storeId)     → headers ready
//
// REGISTER flow:
//   1. POST /auth/register { name, email, password, storeName }
//   2. FirebaseAuth.signInWithEmailAndPassword  → fbUser
//   3. fbUser.getIdToken()                      → idToken (JWT)
//   4. ApiService.setAuth(idToken, storeId)     → headers ready
//
// TOKEN REFRESH:
//   On app restart → Firebase re-signs silently → fresh idToken
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

    // Check if Firebase still has a logged-in user
    final fbUser = _fbAuth.currentUser;
    if (fbUser == null) {
      debugPrint('[AUTH] No Firebase session — showing login');
      return AuthState(hasCompletedOnboarding: onboarded);
    }

    // Refresh the ID token (Firebase handles expiry automatically)
    try {
      final idToken = await fbUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        debugPrint('[AUTH] Could not get ID token — showing login');
        return AuthState(hasCompletedOnboarding: onboarded);
      }

      // Restore storeId from local cache
      final prefs2   = await SharedPreferences.getInstance();
      final storeId  = prefs2.getString('inventaria_store_id') ?? '';

      if (storeId.isEmpty) {
        debugPrint('[AUTH] No storeId cached — need to re-login');
        return AuthState(hasCompletedOnboarding: onboarded);
      }

      // Set fresh token in ApiService so all requests work
      await _api.setAuth(idToken, storeId, uid: fbUser.uid);
      debugPrint('[AUTH] Session restored — uid: ${fbUser.uid} storeId: $storeId');

      // Load cached user profile
      final cached = prefs2.getString(_userCacheKey);
      if (cached != null) {
        try {
          final user = User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
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
    } catch (e) {
      debugPrint('[AUTH] Session restore error: $e');
      return AuthState(hasCompletedOnboarding: onboarded);
    }
  }

  // ── Login ─────────────────────────────────

  Future<void> login() async {
    final s = state.value;
    if (s == null || !s.isLoginValid) return;
    _update((c) => c.copyWith(isLoggingIn: true, clearLoginError: true));

    try {
      // Step 1 — Firebase Auth → get fbUser
      debugPrint('[AUTH] Step 1: Firebase signIn for ${s.loginEmail}');
      final credential = await _fbAuth.signInWithEmailAndPassword(
        email:    s.loginEmail.trim(),
        password: s.loginPassword,
      );
      final fbUser = credential.user;
      if (fbUser == null) throw Exception('Firebase no devolvió usuario');

      // Step 2 — Get Firebase ID Token (real JWT, not uid)
      debugPrint('[AUTH] Step 2: Getting Firebase ID Token');
      final idToken = await fbUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw Exception('No se pudo obtener el ID Token de Firebase');
      }
      debugPrint('[AUTH] ID Token obtained (${idToken.length} chars)');

      // Step 3 — Exchange uid with our backend → get storeId + user data
      debugPrint('[AUTH] Step 3: POST /auth/login with uid: ${fbUser.uid}');
      final body = await _api.post(kAuthLogin, {'uid': fbUser.uid})
          as Map<String, dynamic>;
      debugPrint('[AUTH] Backend response: $body');

      final storeId = body['storeId'] as String? ?? '';
      if (storeId.isEmpty) {
        throw Exception('El backend no devolvió storeId');
      }

      // Step 4 — Store ID Token (not uid) as the auth token
      await _api.setAuth(idToken, storeId, uid: fbUser.uid);
      debugPrint('[AUTH] Login complete — storeId: $storeId');

      final user = User.fromBackendJson(body);
      await _saveUserCache(user);
      await HapticManager.success();

      _update((c) => c.copyWith(
            isLoggingIn: false,
            isAuthenticated: true,
            currentUser: user,
          ));
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('[AUTH] FirebaseAuthException: ${e.code} — ${e.message}');
      await HapticManager.error();
      _update((c) => c.copyWith(
            isLoggingIn: false,
            loginError: _mapFirebaseError(e.code),
          ));
    } on ApiException catch (e) {
      debugPrint('[AUTH] ApiException: ${e.statusCode} — ${e.message}');
      await HapticManager.error();
      _update((c) => c.copyWith(
            isLoggingIn: false,
            loginError: _mapApiError(e),
          ));
    } catch (e, stack) {
      debugPrint('[AUTH] Unexpected error: $e\n$stack');
      await HapticManager.error();
      _update((c) => c.copyWith(
            isLoggingIn: false,
            loginError: kDebugMode ? 'Error: $e' : 'Error de conexión.',
          ));
    }
  }

  // ── Register ──────────────────────────────

  Future<void> signUp() async {
    final s = state.value;
    if (s == null || !s.isSignUpValid) return;
    _update((c) => c.copyWith(isSigningUp: true, clearSignUpError: true));

    try {
      // Step 1 — Backend creates Firebase Auth user + Firestore docs
      debugPrint('[AUTH] Step 1: POST /auth/register');
      final body = await _api.post(kAuthRegister, {
        'name':         s.signUpName.trim(),
        'email':        s.signUpEmail.trim(),
        'password':     s.signUpPassword,
        'storeName':    s.signUpStoreName.trim(),
        if (s.signUpStoreAddress.isNotEmpty)
          'storeAddress': s.signUpStoreAddress.trim(),
        if (s.signUpStorePhone.isNotEmpty)
          'storePhone':   s.signUpStorePhone.trim(),
      }) as Map<String, dynamic>;

      final storeId = body['storeId'] as String? ?? '';
      debugPrint('[AUTH] Register OK — storeId: $storeId');

      // Step 2 — Sign in to get real Firebase session + ID Token
      debugPrint('[AUTH] Step 2: Firebase signIn after register');
      final credential = await _fbAuth.signInWithEmailAndPassword(
        email:    s.signUpEmail.trim(),
        password: s.signUpPassword,
      );
      final fbUser = credential.user!;

      // Step 3 — Get Firebase ID Token
      final idToken = await fbUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw Exception('No se pudo obtener el ID Token tras registro');
      }
      debugPrint('[AUTH] ID Token obtained after register');

      await _api.setAuth(idToken, storeId, uid: fbUser.uid);
      final user = User.fromBackendJson(body);
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
      debugPrint('[AUTH] Unexpected signUp error: $e\n$stack');
      _update((c) => c.copyWith(
            isSigningUp: false,
            signUpError: kDebugMode ? 'Error: $e' : 'Error de conexión.',
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
      _update((c) => c.copyWith(
            forgotPasswordSent: true,
            clearForgotError: true,
          ));
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
    debugPrint('[AUTH] Logged out');
  }

  // ── Field setters ─────────────────────────

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
  void setSignUpStoreAddress(String v) =>
      _update((s) => s.copyWith(signUpStoreAddress: v));
  void setSignUpStorePhone(String v) =>
      _update((s) => s.copyWith(signUpStorePhone: v));
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
        signUpStoreAddress: '',
        signUpStorePhone: '',
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
        return kDebugMode
            ? 'Firebase error: $code'
            : 'Error de autenticación. Intenta de nuevo.';
    }
  }

  String _mapApiError(ApiException e) {
    switch (e.statusCode) {
      case 401: return 'Sesión inválida. Vuelve a iniciar sesión.';
      case 404: return 'No se encontró la cuenta en el sistema.';
      case 409: return 'Ya existe una cuenta con este correo.';
      default:  return e.message.isNotEmpty ? e.message : 'Error inesperado.';
    }
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
