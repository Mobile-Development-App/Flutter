import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _emailCtrl.text.isNotEmpty &&
      _passwordCtrl.text.isNotEmpty &&
      _emailCtrl.text.contains('@');

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final authState =
        ref.watch(authProvider).value;
    final isLoggingIn = authState?.isLoggingIn ?? false;
    final loginError = authState?.loginError;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Logo
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.deepSpaceBlue
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 36,
                      color: AppColors.deepSpaceBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'InventarIA',
                    style: AppTypography.largeTitle.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestión inteligente de inventario',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Email
              _formField(
                label: 'Correo electrónico',
                controller: _emailCtrl,
                icon: Icons.email_outlined,
                placeholder: 'tu@correo.com',
                keyboardType: TextInputType.emailAddress,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              // Password
              _passwordField(isDark: isDark),
              const SizedBox(height: 8),
              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showForgotPassword(context),
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.deepSpaceBlue),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Error
              if (loginError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_rounded,
                          color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(loginError,
                            style: AppTypography.caption.copyWith(
                                color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              // Login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isValid && !isLoggingIn)
                      ? () {
                          context.hideKeyboard();
                          final notifier = ref
                              .read(authProvider.notifier);
                          notifier.setLoginEmail(
                              _emailCtrl.text);
                          notifier.setLoginPassword(
                              _passwordCtrl.text);
                          notifier.login();
                        }
                      : null,
                  style: primaryButtonStyle,
                  child: isLoggingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.inkBlack),
                        )
                      : const Text('Iniciar Sesión'),
                ),
              ),
              const SizedBox(height: 24),
              // Demo hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.deepSpaceBlue
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Credenciales de demostración:',
                      style: AppTypography.caption2
                          .copyWith(color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'demo@inventory.com / demo123',
                      style: AppTypography.caption2.copyWith(
                          color: AppColors.deepSpaceBlue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿No tienes cuenta?',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => _showSignUp(context),
                    child: Text(
                      'Crear cuenta',
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
    );
  }

  Widget _formField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String placeholder,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
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
                child: Icon(icon,
                    color: AppColors.textTertiary, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
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

  Widget _passwordField({required bool isDark}) {
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
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.lock_outline_rounded,
                    color: AppColors.textTertiary, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '••••••••',
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
      ],
    );
  }

  void _showSignUp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SignUpScreen(),
    );
  }

  void _showForgotPassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ForgotPasswordScreen(),
    );
  }
}
