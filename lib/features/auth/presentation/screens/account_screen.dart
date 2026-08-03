import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/auth/domain/auth_session.dart';
import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:exploding_kittens/l10n/app_localizations.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSession = ref.watch(authSessionProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text(l10n.accountTitle, style: AppTextStyles.title),
      ),
      body: asyncSession.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text(l10n.accountLoadError('$e'), style: AppTextStyles.body),
        ),
        data: (session) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: session == null || session.isAnonymous
              ? const _GuestView()
              : _SignedInView(session: session),
        ),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.accountGuestExplanation, style: AppTextStyles.body),
        const Gap(24),
        ElevatedButton.icon(
          onPressed: () => context.push(RouteNames.accountSignUp),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: Text(l10n.authCreateAccount, style: AppTextStyles.body),
        ),
        const Gap(12),
        OutlinedButton.icon(
          onPressed: () => context.push(RouteNames.accountLogin),
          icon: const Icon(Icons.login_rounded, size: 20),
          label:
              Text(l10n.accountAlreadyHaveAccount, style: AppTextStyles.body),
        ),
      ],
    );
  }
}

class _SignedInView extends ConsumerWidget {
  const _SignedInView({required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.account_circle_rounded,
            color: AppColors.secondary,
            size: 32,
          ),
          title: Text(
            session.email ?? l10n.accountLinkedFallback,
            style: AppTextStyles.body,
          ),
        ),
        const Gap(24),
        OutlinedButton.icon(
          onPressed: () => ref.read(authSessionProvider.notifier).signOut(),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: Text(l10n.accountLogout, style: AppTextStyles.body),
        ),
      ],
    );
  }
}
