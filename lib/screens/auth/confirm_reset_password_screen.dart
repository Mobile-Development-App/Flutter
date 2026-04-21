import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/strip_auth_url.dart';
import '../../core/utils/validators.dart';

/// Pantalla tras abrir el enlace del correo con `mode=resetPassword` y `oobCode`
/// (p. ej. app web en el mismo origen configurado en ActionCodeSettings).
class ConfirmResetPasswordScreen extends StatefulWidget {
  final String oobCode;
  final VoidCallback onFinished;

  const ConfirmResetPasswordScreen({
    super.key,
    required this.oobCode,
    required this.onFinished,
  });

  @override
  State<ConfirmResetPasswordScreen> createState() =>
      _ConfirmResetPasswordScreenState();
}

class _ConfirmResetPasswordScreenState extends State<ConfirmResetPasswordScreen> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;
  bool _showRules = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      AppValidators.isValidPassword(_pass.text) &&
      _pass.text == _confirm.text;

  Future<void> _submit() async {
    if (!_valid) {
      setState(() => _error = 'Revisa que la contraseña cumpla todas las reglas.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    context.hideKeyboard();
    try {
      await fb.FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: _pass.text,
      );
      if (!mounted) return;
      stripPasswordResetFromBrowserUrl();
      widget.onFinished();
    } on fb.FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _firebaseMessage(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'No se pudo guardar la contraseña. Intenta de nuevo.';
      });
    }
  }

  String _firebaseMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'La contraseña es demasiado débil para Firebase. Cumple todos los requisitos.';
      case 'expired-action-code':
      case 'invalid-action-code':
        return 'El enlace caducó o ya se usó. Solicita un correo nuevo desde "Olvidé mi contraseña".';
      default:
        return 'Error: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pass = _pass.text;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nueva contraseña',
                style: AppTypography.title3.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Elige una contraseña con los mismos requisitos que al registrarte.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Contraseña',
                style: AppTypography.caption
                    .copyWith(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _pass,
                obscureText: !_showPass,
                maxLength: 20,
                buildCounter:
                    (context, {required currentLength, required isFocused, required maxLength}) =>
                        null,
                onChanged: (_) => setState(() {}),
                onTap: () => setState(() => _showRules = true),
                style: AppTypography.callout.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showPass = !_showPass),
                    icon: Icon(
                      _showPass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.darkTextTertiary,
                      size: 20,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                  ),
                ),
              ),
              if (_showRules || (pass.isNotEmpty && !AppValidators.isValidPassword(pass))) ...[
                const SizedBox(height: 10),
                _rulesPanel(pass),
              ],
              const SizedBox(height: 20),
              Text(
                'Confirmar contraseña',
                style: AppTypography.caption
                    .copyWith(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirm,
                obscureText: !_showConfirm,
                maxLength: 20,
                buildCounter:
                    (context, {required currentLength, required isFocused, required maxLength}) =>
                        null,
                onChanged: (_) => setState(() {}),
                style: AppTypography.callout.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    icon: Icon(
                      _showConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.darkTextTertiary,
                      size: 20,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                  ),
                ),
              ),
              if (_confirm.text.isNotEmpty && _pass.text != _confirm.text) ...[
                const SizedBox(height: 8),
                Text(
                  'Las contraseñas no coinciden.',
                  style: AppTypography.caption2.copyWith(color: AppColors.error),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting || !_valid
                      ? null
                      : _submit,
                  style: primaryButtonStyle,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.inkBlack,
                          ),
                        )
                      : const Text('Guardar contraseña'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rulesPanel(String password) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.darkTextTertiary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requisitos',
            style: AppTypography.caption2.copyWith(
              color: AppColors.darkTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
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
                            ? AppColors.darkTextTertiary
                            : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
