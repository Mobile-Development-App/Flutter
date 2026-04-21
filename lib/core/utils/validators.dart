
final _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
);

/// Detecta emojis y símbolos gráficos — rango amplio para Unicode 15+
final _emojiRegex = RegExp(
  r'[\u{1F000}-\u{1FFFF}]'
  r'|[\u{2600}-\u{27BF}]'
  r'|[\u{FE00}-\u{FE0F}]'
  r'|[\u{1F900}-\u{1FAFF}]'
  r'|\u{200D}'
  r'|\u{20E3}',
  unicode: true,
);

/// Regla individual de contraseña con descripción e indicador de estado.
class PasswordRule {
  final String label;
  final bool Function(String) check;
  const PasswordRule({required this.label, required this.check});
}

abstract final class AppValidators {
  // ── Email ────────────────────────────────────

  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    if (email.contains(' ')) return false;
    if (hasEmoji(email)) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  // ── Emojis ───────────────────────────────────

  static bool hasEmoji(String text) => _emojiRegex.hasMatch(text);

  // ── Nombre / texto libre ──────────────────────

  static bool isValidName(String name) {
    final t = name.trim();
    return t.isNotEmpty && !hasEmoji(t);
  }

  // ── Contraseña ───────────────────────────────

  /// Lista de reglas individuales para mostrar en la UI.
  ///
  /// Caracteres especiales permitidos: ! @ # $ % ^ & * ( ) _ + - = [ ] { } | ; : ' " , . / < > ? ` ~
  static final List<PasswordRule> passwordRules = [
    PasswordRule(
      label: 'Entre 8 y 20 caracteres',
      check: (p) => p.length >= 8 && p.length <= 20,
    ),
    PasswordRule(
      label: 'Al menos una letra mayúscula (A–Z)',
      check: (p) => RegExp(r'[A-Z]').hasMatch(p),
    ),
    PasswordRule(
      label: 'Al menos una letra minúscula (a–z)',
      check: (p) => RegExp(r'[a-z]').hasMatch(p),
    ),
    PasswordRule(
      label: 'Al menos un número (0–9)',
      check: (p) => RegExp(r'[0-9]').hasMatch(p),
    ),
    PasswordRule(
      label: 'Al menos un carácter especial (!@#...)',
      check: (p) => RegExp(r'''[!@#$%^&*()_+\-=[\]{}|;':",./<>?`~]''').hasMatch(p),
    ),
    PasswordRule(
      label: 'Sin espacios en blanco',
      check: (p) => !p.contains(' '),
    ),
    PasswordRule(
      label: 'Sin emojis ni símbolos gráficos',
      check: (p) => !hasEmoji(p),
    ),
  ];

  /// Contraseña válida: cumple TODAS las reglas de [passwordRules].
  static bool isValidPassword(String password) =>
      passwordRules.every((r) => r.check(password));

  /// Las dos contraseñas coinciden Y la contraseña es válida.
  static bool passwordsMatch(String pass, String confirm) =>
      pass == confirm && isValidPassword(pass);

  // ── Números para productos ───────────────────

  /// Entero estrictamente positivo (> 0). Solo dígitos, sin decimales.
  /// Uso: cantidad en stock.
  static bool isPositiveInteger(String value) {
    if (value.trim().isEmpty) return false;
    final n = int.tryParse(value.trim());
    return n != null && n > 0;
  }

  /// Entero no-negativo (>= 0). Permite 0 como umbral sin límite inferior.
  /// Uso: stock mínimo.
  static bool isNonNegativeInteger(String value) {
    if (value.trim().isEmpty) return false;
    final n = int.tryParse(value.trim());
    return n != null && n >= 0;
  }

  /// Número decimal estrictamente positivo (> 0). Con hasta 2 decimales.
  /// Uso: precio de costo, precio de venta.
  static bool isPositivePrice(String value) {
    if (value.trim().isEmpty) return false;
    final n = double.tryParse(value.trim());
    return n != null && n > 0;
  }
}
