import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/router/route_names.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo ──────────────────────────────────────────
              const Icon(
                Icons.local_fire_department_rounded,
                size: 80,
                color: AppColors.primary,
              )
                  .animate()
                  .scale(
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                  ),

              const Gap(16),

              Text(AppConstants.appName, style: AppTextStyles.headline)
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: -0.2, end: 0, curve: Curves.easeOut),

              const Gap(4),

              Text(
                'Fan Edition · ${AppConstants.company}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onBackground.withValues(alpha: 0.45),
                  letterSpacing: 1.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 400.ms),

              const Spacer(flex: 3),

              // ── Botones principales ───────────────────────────
              _MenuButton(
                label: 'Crear sala',
                icon: Icons.add_circle_outline_rounded,
                onTap: () => context.push(RouteNames.lobby),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 400.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

              const Gap(12),

              _MenuButton(
                label: 'Unirse a sala',
                icon: Icons.wifi_rounded,
                onTap: () => context.push(RouteNames.lobby),
              )
                  .animate()
                  .fadeIn(delay: 620.ms, duration: 400.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

              const Gap(28),

              // ── Ajustes ───────────────────────────────────────
              TextButton.icon(
                onPressed: () => context.push(RouteNames.settings),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Ajustes'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onBackground.withValues(alpha: 0.65),
                ),
              )
                  .animate()
                  .fadeIn(delay: 740.ms, duration: 400.ms),

              const Spacer(),

              // ── Pie de página ─────────────────────────────────
              Text(
                'Proyecto de fans · Sin fines comerciales',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onBackground.withValues(alpha: 0.25),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 900.ms, duration: 600.ms),

              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: AppTextStyles.body),
      ),
    );
  }
}
