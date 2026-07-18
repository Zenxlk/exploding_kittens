import 'package:flutter/material.dart';

import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';

/// Mano del jugador local en abanico. Selección por tap (necesaria de todos
/// modos para pares/tríos de gato, que requieren elegir varias cartas antes
/// de confirmar la jugada) más arrastre opcional: una carta en
/// [playableCardIds] se puede soltar sobre el `DragTarget` de mazo/descarte
/// en `GameTableView` para jugarla directo, sin pasar por el botón
/// "Jugar"; soltarla en cualquier otro lado (o arrastrar una carta que no
/// está en [playableCardIds]) simplemente la selecciona, igual que un tap.
/// Widget "tonto": no lee providers ni decide reglas, solo reporta taps.
class PlayerHandWidget extends StatelessWidget {
  const PlayerHandWidget({
    super.key,
    required this.hand,
    this.selectedCardIds = const {},
    this.playableCardIds = const {},
    this.justDrawnCardIds = const {},
    this.onCardTap,
    this.cardWidth = 64,
    this.assetPathFor,
  });

  final List<CardModel> hand;
  final Set<String> selectedCardIds;
  final Set<String> playableCardIds;
  final Set<String> justDrawnCardIds;
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
                  child: _buildCard(hand[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(CardModel card) {
    final cardWidget = CardWidget(
      key: ValueKey(card.id),
      type: card.type,
      assetPath: assetPathFor?.call(card.type),
      isSelected: selectedCardIds.contains(card.id),
      isPlayable: playableCardIds.contains(card.id),
      justDrawn: justDrawnCardIds.contains(card.id),
      width: cardWidth,
      onTap: onCardTap == null ? null : () => onCardTap!(card),
    );

    if (onCardTap == null) return cardWidget;

    return Draggable<CardModel>(
      key: ValueKey('drag-${card.id}'),
      data: card,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.08, child: cardWidget),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: cardWidget),
      // Soltarla fuera de un DragTarget que la acepte (o directamente sobre
      // una zona que la rechaza, p. ej. no es mi turno o la carta necesita
      // objetivo) equivale a un tap: la selecciona en vez de jugarla.
      onDragEnd: (details) {
        if (!details.wasAccepted) onCardTap!(card);
      },
      child: cardWidget,
    );
  }
}
