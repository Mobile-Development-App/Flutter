import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final authState = ref.watch(authProvider).value;
    final sent = authState?.forgotPasswordSent ?? false;
    final error = authState?.forgotPasswordError;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Spacer(),
                  const SizedBox(width: 40),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: sent
                    ? _successView(context, authState?.forgotPasswordEmail ?? '')
                    : _formView(context, isDark, error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successView(BuildContext context, String email) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              size: 56, color: AppColors.success),
        ),
        const SizedBox(height: 24),
        Text('Correo Enviado', style: AppTypography.title),
        const SizedBox(height: 8),
        Text(
          'Hemos enviado instrucciones para restablecer tu contraseña a $email',
          style: AppTypography.body
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: primaryButtonStyle,
            child: const Text('Volver al inicio de sesión'),
          ),
        ),
      ],
    );
  }

  Widget _formView(BuildContext context, bool isDark, String? error) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.deepSpaceBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_reset_rounded,
              size: 36, color: AppColors.deepSpaceBlue),
        ),
        const SizedBox(height: 16),
        Text('Recuperar Contraseña', style: AppTypography.title),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu correo electrónico y te enviaremos instrucciones para restablecer tu contraseña',
          style:
              AppTypography.callout.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Correo electrónico',
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
                    child: Icon(Icons.email_outlined,
                        color: AppColors.textTertiary, size: 18),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      onChanged: (v) => ref
                          .read(authProvider.notifier)
                          .setForgotPasswordEmail(v),
                      decoration: const InputDecoration(
                        hintText: 'tu@correo.com',
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
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error,
              style: AppTypography.caption
                  .copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _emailCtrl.text.isEmpty
                ? null
                : () {
                    context.hideKeyboard();
                    ref
                        .read(authProvider.notifier)
                        .sendPasswordReset();
                  },
            style: primaryButtonStyle,
            child: const Text('Enviar Instrucciones'),
          ),
        ),
      ],
    );
  }
}
