import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:exploding_kittens/features/auth/presentation/widgets/auth_text_field.dart';

// A diferencia de sign_up_screen.dart, esto reemplaza la sesión anónima
// por la de una cuenta ya existente (ver
// SupabaseAuthService.signInWithPassword) — recupera el historial de esa
// cuenta, en vez de conservar el de la sesión anónima actual.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Completá correo y contraseña');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authSessionProvider.notifier)
          .signInWithPassword(email: email, password: password);
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final controller = TextEditingController(text: _emailController.text);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Recuperar contraseña', style: AppTextStyles.title),
        content: TextField(
          controller: controller,
          style: AppTextStyles.body,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'tu@correo.com',
            hintStyle: AppTextStyles.caption.copyWith(
              color: AppColors.onBackground.withValues(alpha: 0.4),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: AppTextStyles.body.copyWith(
                color: AppColors.onBackground.withValues(alpha: 0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              // Supabase no revela si el correo existe — mismo mensaje
              // pase lo que pase, para no filtrar esa información.
              try {
                await ref
                    .read(authSessionProvider.notifier)
                    .resetPasswordForEmail(email);
              } catch (_) {
                // Ignorado a propósito, ver comentario de arriba.
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Si el correo existe, te llegará un enlace para '
                      'restablecer la contraseña.',
                    ),
                    backgroundColor: AppColors.surface,
                  ),
                );
              }
            },
            child: Text(
              'Enviar',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text('Iniciar sesión', style: AppTextStyles.title),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _emailController,
              label: 'Correo',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const Gap(12),
            AuthTextField(
              controller: _passwordController,
              label: 'Contraseña',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const Gap(4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onBackground.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const Gap(8),
              Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            ],
            const Gap(16),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text('Iniciar sesión', style: AppTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }
}
