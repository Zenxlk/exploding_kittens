import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/constants/game_constants.dart';
import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/l10n/app_localizations.dart';

/// Cuenta regresiva del turno actual. El temporizador real (que roba una
/// carta automáticamente al expirar) vive en `GameNotifier`; no hay
/// timestamp de inicio de turno en `GameState`, así que esta barra es
/// puramente visual y se reinicia localmente cada vez que
/// `currentPlayerId` cambia, igual que hace el notifier con su propio
/// `Timer` — mismo patrón que `NopeWindowOverlay`.
class TurnTimerBar extends StatefulWidget {
  const TurnTimerBar({
    super.key,
    required this.currentPlayerId,
    required this.currentPlayerName,
    this.duration = const Duration(seconds: GameConstants.turnTimeoutSeconds),
  });

  final String currentPlayerId;
  final String currentPlayerName;
  final Duration duration;

  @override
  State<TurnTimerBar> createState() => _TurnTimerBarState();
}

class _TurnTimerBarState extends State<TurnTimerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant TurnTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPlayerId != oldWidget.currentPlayerId) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final secondsLeft =
              (widget.duration.inSeconds * (1 - _controller.value))
                  .ceil()
                  .clamp(0, widget.duration.inSeconds);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context)!
                    .gameTurnTimerLabel(widget.currentPlayerName, secondsLeft),
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - _controller.value,
                  minHeight: 4,
                  color: AppColors.warning,
                  backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
