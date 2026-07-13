import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';

/// Selector genérico de "elegí una carta de esta lista", tocando la carta
/// misma en vez de un botón aparte. Hoy solo lo usa Favor (el objetivo elige
/// qué carta de su propia mano entregar), pero está pensado para reusarse
/// con cualquier otra "elegí una carta concreta" futura (p. ej. el trío de
/// gatos, donde en cambio elegiría el actor desde la mano del rival).
/// Widget "tonto": no decide de dónde salen [candidates] ni a quién llega la
/// elegida, solo reporta el id de la carta tocada.
class CardChoiceOverlay extends StatelessWidget {
  const CardChoiceOverlay({
    super.key,
    required this.title,
    required this.candidates,
    required this.onSelect,
    this.assetPathFor,
  });

  final String title;
  final List<CardModel> candidates;
  final ValueChanged<String> onSelect;
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
                    type: card.type,
                    assetPath: assetPathFor?.call(card.type),
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
