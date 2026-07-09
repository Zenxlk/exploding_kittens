import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';

/// Animación de explosión cuando un jugador queda eliminado (robó una
/// Exploding Kitten sin Defuse). Se cierra sola tras [duration], sin
/// necesitar ninguna acción del jugador. Placeholder con Flutter puro
/// (escala con rebote); se reemplaza por el Lottie real de
/// `AssetPaths.animExplosion` cuando exista ese asset (todavía no está en
/// el repo, ver `assets/animations/`).
class ExplosionOverlay extends StatefulWidget {
  const ExplosionOverlay({
    super.key,
    required this.eliminatedPlayerName,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 1600),
  });

  final String eliminatedPlayerName;
  final VoidCallback onFinished;
  final Duration duration;

  @override
  State<ExplosionOverlay> createState() => _ExplosionOverlayState();
}

class _ExplosionOverlayState extends State<ExplosionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      })
      ..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: AppColors.primary,
                  size: 96,
                ),
                const SizedBox(height: 12),
                Text('¡BOOM!', style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(
                  '${widget.eliminatedPlayerName} explotó',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
