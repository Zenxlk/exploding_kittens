import '../card/card_model.dart';

/// Todas las acciones posibles que un jugador puede ejecutar en su turno.
sealed class TurnAction {
  const TurnAction({required this.playerId});
  final String playerId;
}

/// Robar la carta de arriba del mazo
final class DrawCardAction extends TurnAction {
  const DrawCardAction({required super.playerId});
}

/// Jugar una carta de la mano (sin objetivo)
final class PlayCardAction extends TurnAction {
  const PlayCardAction({
    required super.playerId,
    required this.card,
  });
  final CardModel card;
}

/// Favor: pedir una carta a otro jugador
final class PlayFavorAction extends TurnAction {
  const PlayFavorAction({
    required super.playerId,
    required this.card,
    required this.targetPlayerId,
  });
  final CardModel card;
  final String targetPlayerId;
}

/// Jugar par de gatos para robar carta aleatoria a otro
final class PlayCatPairAction extends TurnAction {
  const PlayCatPairAction({
    required super.playerId,
    required this.cards,       // exactamente 2 cartas del mismo tipo gato
    required this.targetPlayerId,
  });
  final List<CardModel> cards;
  final String targetPlayerId;
}

/// Jugar trío de gatos para ver la mano de otro y elegir
final class PlayCatTrioAction extends TurnAction {
  const PlayCatTrioAction({
    required super.playerId,
    required this.cards,        // exactamente 3 cartas del mismo tipo gato
    required this.targetPlayerId,
    required this.chosenCardId,
  });
  final List<CardModel> cards;
  final String targetPlayerId;
  final String chosenCardId;
}

/// Usar Defuse cuando se roba un Exploding Kitten
final class DefuseBombAction extends TurnAction {
  const DefuseBombAction({
    required super.playerId,
    required this.defuseCard,
    required this.insertAtPosition, // dónde reinserta la bomba
  });
  final CardModel defuseCard;
  final int insertAtPosition;
}

/// Jugar Nope sobre la acción anterior en cadena
final class NopeAction extends TurnAction {
  const NopeAction({
    required super.playerId,
    required this.nopeCard,
  });
  final CardModel nopeCard;
}
