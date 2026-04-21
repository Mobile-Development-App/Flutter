import 'package:flutter/foundation.dart' show kIsWeb;

import '../../firebase_options.dart';

/// Parámetros `mode` / `oobCode` del enlace de restablecimiento (web).
abstract final class AuthActionUri {
  static const _fromDefine = String.fromEnvironment(
    'AUTH_ACTION_BASE_URL',
    defaultValue: '',
  );

  /// URL de continuación del correo de Firebase. En web usa el origen actual
  /// si no defines [AUTH_ACTION_BASE_URL] al compilar.
  static String passwordResetContinueUrl() {
    if (_fromDefine.isNotEmpty) {
      final t = _fromDefine.trim();
      return t.endsWith('/') ? t : '$t/';
    }
    if (kIsWeb) {
      final u = Uri.base;
      return u.replace(
        queryParameters: const {},
        fragment: '',
        path: u.path.isEmpty ? '/' : u.path,
      ).toString();
    }
    final host = DefaultFirebaseOptions.web.authDomain ??
        'inventaria-app-ae5ce.firebaseapp.com';
    return Uri.https(host, '/').toString();
  }

  static Map<String, String> _allQueryLikeParams() {
    if (!kIsWeb) return {};
    final u = Uri.base;
    if (u.queryParameters.isNotEmpty) {
      return Map<String, String>.from(u.queryParameters);
    }
    final frag = u.fragment;
    if (frag.isEmpty) return {};
    final q = frag.indexOf('?');
    if (q >= 0) {
      return Uri.splitQueryString(frag.substring(q + 1));
    }
    return Uri.splitQueryString(frag);
  }

  /// Código OOB si la URL es de restablecimiento de contraseña.
  static String? resetPasswordOobCode() {
    final m = _allQueryLikeParams();
    if (m['mode'] != 'resetPassword') return null;
    final c = m['oobCode'];
    if (c == null || c.isEmpty) return null;
    return c;
  }
}
