import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';

/// Ventana de tiempo para que cualquier jugador vivo con un Nope en mano
/// cancele la acción pendiente. El motor (temporizador de `GameNotifier`) es
/// quien decide cuándo se cierra; no hay timestamp de apertura en
/// `GameState`, así que la cuenta regresiva es puramente visual y se
/// reinicia localmente cada vez que `nopeChainCount` cambia, igual que hace
/// el notifier con su propio `Timer`.
class NopeWindowOverlay extends StatefulWidget {
  const NopeWindowOverlay({
    super.key,
    required this.duration,
    required this.nopeChainCount,
    required this.canPlayNope,
    required this.onPlayNope,
  });

  final Duration duration;
  final int nopeChainCount;
  final bool canPlayNope;
  final VoidCallback onPlayNope;

  @override
  State<NopeWindowOverlay> createState() => _NopeWindowOverlayState();
}

class _NopeWindowOverlayState extends State<NopeWindowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant NopeWindowOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nopeChainCount != oldWidget.nopeChainCount) {
      _controller
        ..duration = widget.duration
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = widget.nopeChainCount.isOdd;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ventana de Nope', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              isCancelled
                  ? 'Cancelada… alguien más puede reactivarla'
                  : 'Cualquiera puede cancelar esto con un Nope',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => LinearProgressIndicator(
                  value: 1 - _controller.value,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.canPlayNope ? widget.onPlayNope : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('¡Nope!'),
            ),
          ],
        ),
      ),
    );
  }
}
