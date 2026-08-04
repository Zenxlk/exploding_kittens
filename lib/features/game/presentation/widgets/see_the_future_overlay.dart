import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/l10n/app_localizations.dart';

/// Muestra las 3 cartas de arriba del mazo tras jugar See the Future.
/// Widget "tonto": la visibilidad la decide el caller a partir de
/// `GameState.seeTheFutureCards`, este widget solo pinta y reporta el cierre.
class SeeTheFutureOverlay extends StatelessWidget {
  const SeeTheFutureOverlay({
    super.key,
    required this.topCards,
    required this.onDismiss,
    this.assetPathFor,
  });

  final List<CardModel> topCards;
  final VoidCallback onDismiss;
  final String? Function(CardType type)? assetPathFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.seeTheFutureTitle, style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              l10n.seeTheFutureSubtitle,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final card in topCards)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: CardWidget(
                      type: card.type,
                      assetPath: assetPathFor?.call(card.type),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onDismiss,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(l10n.seeTheFutureContinue),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
