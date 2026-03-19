import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  bool _showPassword = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _storeCtrl.dispose();
    super.dispose();
  }

  bool get _passwordsMatch =>
      _passCtrl.text == _confirmPassCtrl.text;
  bool get _passwordLengthValid => _passCtrl.text.length >= 8;
  bool get _isValid =>
      _nameCtrl.text.isNotEmpty &&
      _emailCtrl.text.isNotEmpty &&
      _emailCtrl.text.contains('@') &&
      _passwordLengthValid &&
      _passwordsMatch &&
      _storeCtrl.text.isNotEmpty &&
      _acceptedTerms;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final authState = ref.watch(authProvider).value;
    final isSigningUp = authState?.isSigningUp ?? false;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Spacer(),
                  Text('Crear Cuenta', style: AppTypography.title),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Text(
              'Completa tus datos para comenzar',
              style: AppTypography.callout
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _formField(
                        label: 'Nombre completo',
                        ctrl: _nameCtrl,
                        icon: Icons.person_outline_rounded,
                        placeholder: 'Tu nombre completo',
                        isDark: isDark,
                        textCapitalization: TextCapitalization.words),
                    const SizedBox(height: 14),
                    _formField(
                        label: 'Correo electrónico',
                        ctrl: _emailCtrl,
                        icon: Icons.email_outlined,
                        placeholder: 'tu@correo.com',
                        isDark: isDark,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _passwordSection(isDark: isDark),
                    const SizedBox(height: 14),
                    _formField(
                        label: 'Nombre de tu tienda',
                        ctrl: _storeCtrl,
                        icon: Icons.storefront_outlined,
                        placeholder: 'Mi Tienda',
                        isDark: isDark,
                        textCapitalization: TextCapitalization.words),
                    const SizedBox(height: 16),
                    // Terms
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isValid && !isSigningUp)
                            ? () {
                                context.hideKeyboard();
                                final n = ref
                                    .read(authProvider.notifier);
                                n.setSignUpName(_nameCtrl.text);
                                n.setSignUpEmail(_emailCtrl.text);
                                n.setSignUpPassword(_passCtrl.text);
                                n.setSignUpConfirmPassword(
                                    _confirmPassCtrl.text);
                                n.setSignUpStoreName(
                                    _storeCtrl.text);
                                n.setSignUpAcceptedTerms(
                                    _acceptedTerms);
                                n.signUp();
                              }
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
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordSection({required bool isDark}) {
    return Column(
      children: [
        Column(
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
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Icon(Icons.lock_outline_rounded,
                        color: AppColors.textTertiary, size: 18),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _passCtrl,
                      obscureText: !_showPassword,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Mínimo 8 caracteres',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 14),
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
                ],
              ),
            ),
            if (_passCtrl.text.isNotEmpty && !_passwordLengthValid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'La contraseña debe tener al menos 8 caracteres',
                  style: AppTypography.caption2
                      .copyWith(color: AppColors.error),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
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
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Icon(Icons.lock_rounded,
                        color: AppColors.textTertiary, size: 18),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _confirmPassCtrl,
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Repite tu contraseña',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_confirmPassCtrl.text.isNotEmpty &&
                !_passwordsMatch)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Las contraseñas no coinciden',
                  style: AppTypography.caption2
                      .copyWith(color: AppColors.error),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _formField({
    required String label,
    required TextEditingController ctrl,
    required IconData icon,
    required String placeholder,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
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
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child:
                    Icon(icon, color: AppColors.textTertiary, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
