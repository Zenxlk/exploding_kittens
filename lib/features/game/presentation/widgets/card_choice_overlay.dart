import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';

/// Selector genérico de "elegí una carta de esta lista", tocando la carta
/// misma en vez de un botón aparte. Lo usan Favor (el objetivo elige, boca
/// arriba, qué carta de su propia mano entregar) y el trío de gatos (el
/// actor elige a ciegas, boca abajo con [faceUp] en falso, de la mano del
/// objetivo — no puede ver de qué se trata, solo la posición). Widget
/// "tonto": no decide de dónde salen [candidates] ni a quién llega la
/// elegida, solo reporta el id de la carta tocada.
class CardChoiceOverlay extends StatelessWidget {
  const CardChoiceOverlay({
    super.key,
    required this.title,
    required this.candidates,
    required this.onSelect,
    this.faceUp = true,
    this.assetPathFor,
  });

  final String title;
  final List<CardModel> candidates;
  final ValueChanged<String> onSelect;
  final bool faceUp;
  final String? Function(CardType type)? assetPathFor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final card in candidates)
                  CardWidget(
                    key: ValueKey(card.id),
                    type: card.type,
                    faceUp: faceUp,
                    assetPath: faceUp ? assetPathFor?.call(card.type) : null,
                    isPlayable: true,
                    onTap: () => onSelect(card.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
