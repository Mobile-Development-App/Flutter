import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/validators.dart';
import 'package:flutter/services.dart';
import '../../providers/providers.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _passwordCtrl.text.isNotEmpty &&
      AppValidators.isValidEmail(_emailCtrl.text); // FIX: validación real

  @override
  Widget build(BuildContext context) {
    final authState   = ref.watch(authProvider).value;
    final isLoggingIn = authState?.isLoggingIn ?? false;
    final loginError  = authState?.loginError;

    // Auth screens always use the dark brand aesthetic
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 52),

              // ── Logo + wordmark ──────────────────────────────────────────
              _buildHeader(),

              const SizedBox(height: 44),

              // ── Form card ───────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0x1AFFFFFF),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Iniciar sesión',
                      style: AppTypography.title3.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Accede a tu panel de inventario',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email
                    _formField(
                      label: 'Correo electrónico',
                      controller: _emailCtrl,
                      icon: Icons.email_outlined,
                      placeholder: 'tu@correo.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _passwordField(),
                    const SizedBox(height: 8),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _showForgotPassword(context),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.freshSky,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Error banner
                    if (loginError != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(loginError,
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.error)),
                          ),
                        ]),
                      ),
                    ],

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isValid && !isLoggingIn)
                            ? () {
                                context.hideKeyboard();
                                final n = ref.read(authProvider.notifier);
                                n.setLoginEmail(_emailCtrl.text);
                                n.setLoginPassword(_passwordCtrl.text);
                                n.login();
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
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿No tienes cuenta?',
                    style: AppTypography.callout.copyWith(
                        color: AppColors.darkTextSecondary),
                  ),
                  TextButton(
                    onPressed: () => _showSignUp(context),
                    child: Text(
                      'Crear cuenta',
                      style: AppTypography.callout.copyWith(
                        color: AppColors.teaGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo container with Tea Green accent ring
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.teaGreen.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.teaGreen.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 72,
              height: 72,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'InventarIA',
          style: AppTypography.largeTitle.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Gestión inteligente de inventario',
          style: AppTypography.callout.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _formField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.darkTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder, width: 1),
          ),
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(icon, color: AppColors.darkTextTertiary, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                onChanged: (_) => setState(() {}),
                style: AppTypography.body.copyWith(
                    color: AppColors.darkTextPrimary),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: AppTypography.body.copyWith(
                      color: AppColors.darkTextTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contraseña',
          style: AppTypography.caption.copyWith(
            color: AppColors.darkTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder, width: 1),
          ),
          child: Row(children: [
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Icon(Icons.lock_outline_rounded,
                  color: AppColors.darkTextTertiary, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                onChanged: (_) => setState(() {}),
                style: AppTypography.body.copyWith(
                    color: AppColors.darkTextPrimary),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: AppTypography.body.copyWith(
                      color: AppColors.darkTextTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.darkTextTertiary,
                size: 18,
              ),
            ),
          ]),
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
