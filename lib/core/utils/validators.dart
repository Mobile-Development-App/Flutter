
final _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
);

/// Detecta emojis y símbolos gráficos — rango amplio para Unicode 15+
final _emojiRegex = RegExp(
  r'[\u{1F000}-\u{1FFFF}]'   // Supplementary Multilingual Plane (emojis principales)
  r'|[\u{2600}-\u{27BF}]'    // Misc Symbols, Dingbats
  r'|[\u{FE00}-\u{FE0F}]'    // Variation Selectors (modificadores de emoji)
  r'|[\u{1F900}-\u{1FAFF}]'  // Supplemental Symbols & Pictographs
  r'|\u{200D}'               // Zero-Width Joiner (combina emojis de familia)
  r'|\u{20E3}',              // Combining Enclosing Keycap
  unicode: true,
);

abstract final class AppValidators {
  // ── Email ────────────────────────────────────

  /// Valida que el correo:
  ///  • No esté vacío
  ///  • No contenga espacios (ni al inicio, ni en medio, ni al final)
  ///  • Tenga formato real: local@dominio.tld
  ///  • No contenga emojis
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    if (email.contains(' ')) return false;          // espacio en cualquier pos.
    if (hasEmoji(email)) return false;              // emojis
    return _emailRegex.hasMatch(email.trim());
  }

  // ── Emojis ───────────────────────────────────

  /// Devuelve true si el texto contiene al menos un emoji o símbolo gráfico.
  static bool hasEmoji(String text) => _emojiRegex.hasMatch(text);

  // ── Nombre / texto libre ──────────────────────

  /// Nombre válido: no vacío (tras trim) y sin emojis.
  static bool isValidName(String name) {
    final t = name.trim();
    return t.isNotEmpty && !hasEmoji(t);
  }

  // ── Contraseña ───────────────────────────────

  /// Mínimo 8 caracteres (la contraseña nunca se trim-ea).
  static bool isValidPassword(String password) => password.length >= 8;

  /// Las dos contraseñas coinciden Y tienen longitud mínima.
  static bool passwordsMatch(String pass, String confirm) =>
      pass == confirm && isValidPassword(pass);
}
