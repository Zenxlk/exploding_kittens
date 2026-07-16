import 'package:flutter/material.dart';

import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';

/// Mano del jugador local en abanico. Selección por tap (no drag & drop):
/// más simple, más fiable y necesario de todos modos para pares/tríos de
/// gato, que requieren elegir varias cartas antes de confirmar la jugada.
/// Widget "tonto": no lee providers ni decide reglas, solo reporta taps.
class PlayerHandWidget extends StatelessWidget {
  const PlayerHandWidget({
    super.key,
    required this.hand,
    this.selectedCardIds = const {},
    this.playableCardIds = const {},
    this.onCardTap,
    this.cardWidth = 64,
    this.assetPathFor,
  });

  final List<CardModel> hand;
  final Set<String> selectedCardIds;
  final Set<String> playableCardIds;
  final ValueChanged<CardModel>? onCardTap;
  final double cardWidth;
  final String? Function(CardType type)? assetPathFor;

  static const double _selectedLift = 12;

  @override
  Widget build(BuildContext context) {
    final height = cardWidth * 1.4 + _selectedLift;

    if (hand.isEmpty) {
      return SizedBox(height: height);
    }

    final overlap = cardWidth * 0.55;
    final totalWidth = cardWidth + overlap * (hand.length - 1);

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < hand.length; i++)
                Positioned(
                  left: overlap * i,
                  top: selectedCardIds.contains(hand[i].id) ? 0 : _selectedLift,
                  child: CardWidget(
                    key: ValueKey(hand[i].id),
                    type: hand[i].type,
                    assetPath: assetPathFor?.call(hand[i].type),
                    isSelected: selectedCardIds.contains(hand[i].id),
                    isPlayable: playableCardIds.contains(hand[i].id),
                    width: cardWidth,
                    onTap: onCardTap == null ? null : () => onCardTap!(hand[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
