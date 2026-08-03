import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:exploding_kittens/features/auth/presentation/widgets/auth_text_field.dart';

// Vincula correo/contraseña a la sesión anónima actual (ver
// SupabaseAuthService.signUpAndLinkAnonymous) — no crea una cuenta
// separada, así que no hay ambigüedad de a qué identidad asociar el
// historial que ya tenía el jugador.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Completá correo y contraseña');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authSessionProvider.notifier)
          .signUpAndLinkAnonymous(email: email, password: password);
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo crear la cuenta');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text('Crear cuenta', style: AppTextStyles.title),
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
            const Gap(12),
            AuthTextField(
              controller: _confirmController,
              label: 'Confirmar contraseña',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            if (_error != null) ...[
              const Gap(12),
              Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            ],
            const Gap(24),
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
                  : Text('Crear cuenta', style: AppTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }
}
