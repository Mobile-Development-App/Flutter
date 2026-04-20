import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/validators.dart';
import '../../providers/providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  // ── Personal ──
  final _nameCtrl         = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _passCtrl         = TextEditingController();
  final _confirmPassCtrl  = TextEditingController();

  // ── Store ──
  final _storeNameCtrl    = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _storePhoneCtrl   = TextEditingController();

  bool _showPassword        = false;
  bool _showConfirmPassword = false;
  bool _acceptedTerms       = false;
  /// Muestra el panel de reglas de contraseña al hacer foco en el campo.
  bool _showPasswordRules   = false;

  // ── Formatters reutilizables ──────────────────

  static final _noEmojiFormatter = FilteringTextInputFormatter.deny(
    RegExp(
      r'[\u{1F000}-\u{1FFFF}]'
      r'|[\u{2600}-\u{27BF}]'
      r'|[\u{FE00}-\u{FE0F}]'
      r'|[\u{1F900}-\u{1FAFF}]'
      r'|\u{200D}'
      r'|\u{20E3}',
      unicode: true,
    ),
  );

  /// Bloquea espacios y emojis (para el campo email).
  static final _emailFormatter = FilteringTextInputFormatter.deny(
    RegExp(
      r'\s'
      r'|[\u{1F000}-\u{1FFFF}]'
      r'|[\u{2600}-\u{27BF}]'
      r'|[\u{FE00}-\u{FE0F}]'
      r'|[\u{1F900}-\u{1FAFF}]'
      r'|\u{200D}'
      r'|\u{20E3}',
      unicode: true,
    ),
  );

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _emailCtrl, _passCtrl, _confirmPassCtrl,
      _storeNameCtrl, _storeAddressCtrl, _storePhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validaciones ──────────────────────────────

  bool get _passwordsMatch      => _passCtrl.text == _confirmPassCtrl.text;
  bool get _passwordValid       => AppValidators.isValidPassword(_passCtrl.text);
  bool get _emailValid          => AppValidators.isValidEmail(_emailCtrl.text);
  bool get _nameValid           =>
      _nameCtrl.text.trim().isNotEmpty &&
      !AppValidators.hasEmoji(_nameCtrl.text);
  bool get _storeNameValid      =>
      _storeNameCtrl.text.trim().isNotEmpty &&
      !AppValidators.hasEmoji(_storeNameCtrl.text);

  bool get _isValid =>
      _nameValid &&
      _emailValid &&
      _passwordValid &&
      _passwordsMatch &&
      _storeNameValid &&
      _acceptedTerms;

  @override
  Widget build(BuildContext context) {
    final isDark      = context.isDark;
    final authState   = ref.watch(authProvider).value;
    final isSigningUp = authState?.isSigningUp ?? false;
    final signUpError = authState?.signUpError;

    ref.listen(authProvider, (prev, next) {
      final error = next.value?.signUpError;
      if (error != null && error != prev?.value?.signUpError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });

    ref.listen(authProvider, (prev, next) {
      if (next.value?.isAuthenticated == true &&
          prev?.value?.isAuthenticated == false) {
        Navigator.pop(context);
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkNavBackground : AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                const Spacer(),
                Text('Crear Cuenta', style: AppTypography.title),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
            ),
            Text(
              'Completa tus datos para comenzar',
              style: AppTypography.callout
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Error banner ──
                    if (signUpError != null) ...[
                      _errorBanner(signUpError),
                      const SizedBox(height: 16),
                    ],

                    // ── Section: Datos personales ──
                    _sectionLabel(
                        'Datos Personales', Icons.person_outline_rounded),
                    const SizedBox(height: 10),

                    _formField(
                      label: 'Nombre completo',
                      ctrl: _nameCtrl,
                      hint: 'Juan Pérez',
                      icon: Icons.person_outline_rounded,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_noEmojiFormatter],
                    ),
                    if (_nameCtrl.text.isNotEmpty &&
                        AppValidators.hasEmoji(_nameCtrl.text)) ...[
                      const SizedBox(height: 4),
                      _fieldError('El nombre no puede contener emojis'),
                    ],
                    const SizedBox(height: 12),

                    _formField(
                      label: 'Correo electrónico',
                      ctrl: _emailCtrl,
                      hint: 'tu@correo.com',
                      icon: Icons.email_outlined,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [_emailFormatter],
                    ),
                    if (_emailCtrl.text.isNotEmpty && !_emailValid) ...[
                      const SizedBox(height: 4),
                      _fieldError('Ingresa un correo válido (ej: tu@correo.com)'),
                    ],
                    const SizedBox(height: 12),

                    _passwordField(isDark),
                    const SizedBox(height: 12),
                    _confirmPasswordField(isDark),

                    const SizedBox(height: 20),

                    // ── Section: Datos de la tienda ──
                    _sectionLabel(
                        'Datos de tu Tienda', Icons.storefront_outlined),
                    const SizedBox(height: 4),
                    Text(
                      'Podrás editarlos después desde configuración',
                      style: AppTypography.caption2
                          .copyWith(color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 10),

                    _formField(
                      label: 'Nombre de la tienda *',
                      ctrl: _storeNameCtrl,
                      hint: 'Tienda Don Juan',
                      icon: Icons.storefront_outlined,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_noEmojiFormatter],
                    ),
                    const SizedBox(height: 12),
                    _formField(
                      label: 'Dirección (opcional)',
                      ctrl: _storeAddressCtrl,
                      hint: 'Calle 10 #5-23, Bogotá',
                      icon: Icons.location_on_outlined,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    _formField(
                      label: 'Teléfono (opcional)',
                      ctrl: _storePhoneCtrl,
                      hint: '3001234567',
                      icon: Icons.phone_outlined,
                      isDark: isDark,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Terms ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(
                                () => _acceptedTerms = !_acceptedTerms);
                            HapticManager.impact();
                          },
                          child: Icon(
                            _acceptedTerms
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: _acceptedTerms
                                ? AppColors.deepSpaceBlue
                                : AppColors.textTertiary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Acepto los términos y condiciones y la política de privacidad',
                            style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Submit ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isValid && !isSigningUp)
                            ? _submit
                            : null,
                        style: primaryButtonStyle,
                        child: isSigningUp
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.inkBlack),
                              )
                            : const Text('Crear Cuenta'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Already have account ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('¿Ya tienes cuenta?',
                            style: AppTypography.callout.copyWith(
                                color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Iniciar sesión',
                            style: AppTypography.callout.copyWith(
                              color: AppColors.deepSpaceBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    context.hideKeyboard();
    final n = ref.read(authProvider.notifier);
    n.setSignUpName(_nameCtrl.text.trim());
    n.setSignUpEmail(_emailCtrl.text.trim());
    n.setSignUpPassword(_passCtrl.text);          // contraseña NO se trim-ea
    n.setSignUpConfirmPassword(_confirmPassCtrl.text);
    n.setSignUpStoreName(_storeNameCtrl.text.trim());
    n.setSignUpStoreAddress(_storeAddressCtrl.text.trim());
    n.setSignUpStorePhone(_storePhoneCtrl.text.trim());
    n.setSignUpAcceptedTerms(_acceptedTerms);
    n.signUp();
  }

  // ── Widgets ───────────────────────────────────

  Widget _sectionLabel(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.deepSpaceBlue),
      const SizedBox(width: 6),
      Text(title,
          style: AppTypography.headline
              .copyWith(color: AppColors.deepSpaceBlue)),
    ]);
  }

  Widget _errorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(error,
              style: AppTypography.caption.copyWith(color: AppColors.error)),
        ),
      ]),
    );
  }

  Widget _fieldError(String message) {
    return Row(
      children: [
        const Icon(Icons.cancel_outlined, size: 13, color: AppColors.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            message,
            style: AppTypography.caption2.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  // ── Campo de contraseña con panel de reglas ───

  Widget _passwordField(bool isDark) {
    final password = _passCtrl.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contraseña',
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSecondary
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Icon(Icons.lock_outline_rounded,
                  color: AppColors.textTertiary, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: _passCtrl,
                obscureText: !_showPassword,
                maxLength: 20,
                buildCounter:
                    (context, {required currentLength, required isFocused, required maxLength}) =>
                        null,
                onChanged: (_) => setState(() {}),
                onTap: () => setState(() => _showPasswordRules = true),
                decoration: const InputDecoration(
                  hintText: 'Crea una contraseña segura',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                ),
              ),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.textTertiary,
                size: 18,
              ),
            ),
          ]),
        ),

        // ── Panel de reglas de contraseña ──────────
        // Se muestra al tocar el campo y permanece hasta que la contraseña sea válida.
        if (_showPasswordRules || (password.isNotEmpty && !_passwordValid)) ...[
          const SizedBox(height: 8),
          _passwordRulesPanel(password, isDark),
        ],
      ],
    );
  }

  /// Panel visual que muestra cada regla de contraseña con estado ✓ / ✗.
  Widget _passwordRulesPanel(String password, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceSecondary.withValues(alpha: 0.7)
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.textTertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              'Requisitos de la contraseña',
              style: AppTypography.caption2.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          ...AppValidators.passwordRules.map((rule) {
            final ok = password.isNotEmpty && rule.check(password);
            final pending = password.isEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(
                    ok
                        ? Icons.check_circle_rounded
                        : pending
                            ? Icons.radio_button_unchecked_rounded
                            : Icons.cancel_rounded,
                    size: 14,
                    color: ok
                        ? AppColors.success
                        : pending
                            ? AppColors.textTertiary
                            : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: AppTypography.caption2.copyWith(
                        color: ok
                            ? AppColors.success
                            : pending
                                ? AppColors.textTertiary
                                : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            'Caracteres especiales permitidos: ! @ # \$ % ^ & * ( ) _ + - = [ ] { } | ; : \' " , . / < > ? ` ~',
            style: AppTypography.caption2.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmPasswordField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confirmar contraseña',
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSecondary
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Icon(Icons.lock_rounded,
                  color: AppColors.textTertiary, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: _confirmPassCtrl,
                obscureText: !_showConfirmPassword,
                maxLength: 20,
                buildCounter:
                    (context, {required currentLength, required isFocused, required maxLength}) =>
                        null,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Repite tu contraseña',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword),
              icon: Icon(
                _showConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.textTertiary,
                size: 18,
              ),
            ),
          ]),
        ),
        if (_confirmPassCtrl.text.isNotEmpty && !_passwordsMatch) ...[
          const SizedBox(height: 4),
          _fieldError('Las contraseñas no coinciden'),
        ],
      ],
    );
  }

  Widget _formField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSecondary
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(icon, color: AppColors.textTertiary, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: keyboardType,
                textCapitalization: textCapitalization,
                autocorrect: false,
                inputFormatters: inputFormatters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 14),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
