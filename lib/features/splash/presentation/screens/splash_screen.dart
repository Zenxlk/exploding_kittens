import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/router/route_names.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(AppConstants.splashDuration, () {
      if (mounted) context.go(RouteNames.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 96,
              color: AppColors.primary,
            )
                .animate()
                .scale(
                  duration: 700.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.3, 0.3),
                  end: const Offset(1, 1),
                )
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            Text(AppConstants.appName, style: AppTextStyles.headline)
                .animate()
                .fadeIn(delay: 450.ms, duration: 500.ms)
                .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),

            const SizedBox(height: 6),

            Text(
              AppConstants.company,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onBackground.withValues(alpha: 0.55),
                letterSpacing: 2,
              ),
            )
                .animate()
                .fadeIn(delay: 700.ms, duration: 500.ms),

            const SizedBox(height: 56),

            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.55),
              ),
            )
                .animate()
                .fadeIn(delay: 950.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
