import '../../core/errors/exceptions.dart';
import '../models/card/card_model.dart';
import '../models/game/game_state.dart';
import '../models/turn/turn_action.dart';
import 'card_rules.dart';

/// Orquestador de reglas. Punto único de validación antes de aplicar acciones.
abstract final class GameRules {
  static void validate(TurnAction action, GameState state) {
    switch (action) {
      case DrawCardAction():
        _mustBeCurrentPlayer(action.playerId, state);
      case PlayCardAction(:final card):
        _mustBeCurrentPlayer(action.playerId, state);
        _mustBeAbleToPlay(card, state);
      case PlayFavorAction(:final card, :final targetPlayerId):
        _mustBeCurrentPlayer(action.playerId, state);
        _mustBeAbleToPlay(card, state);
        _targetMustBeAlive(targetPlayerId, state);
        _targetMustNotBeSelf(action.playerId, targetPlayerId);
      case PlayCatPairAction(:final cards, :final targetPlayerId):
        _mustBeCurrentPlayer(action.playerId, state);
        if (!CardRules.isValidCatPair(cards)) {
          throw const InvalidActionException('Par de gatos inválido');
        }
        _playerMustHaveCards(action.playerId, cards, state);
        _targetMustBeAlive(targetPlayerId, state);
        _targetMustNotBeSelf(action.playerId, targetPlayerId);
      case PlayCatTrioAction(:final cards, :final targetPlayerId):
        _mustBeCurrentPlayer(action.playerId, state);
        if (!CardRules.isValidCatTrio(cards)) {
          throw const InvalidActionException('Trío de gatos inválido');
        }
        _playerMustHaveCards(action.playerId, cards, state);
        _targetMustBeAlive(targetPlayerId, state);
        _targetMustNotBeSelf(action.playerId, targetPlayerId);
      case DefuseBombAction():
        _mustBeCurrentPlayer(action.playerId, state);
        if (!CardRules.canDefuse(state.currentPlayer!)) {
          throw const InvalidActionException('No tienes Defuse');
        }
      case NopeAction(:final playerId):
        final player = state.playerById(playerId);
        if (player == null) throw const GameException('Jugador no encontrado');
        if (!CardRules.canNope(player, state)) {
          throw const InvalidActionException('No puedes jugar Nope ahora');
        }
    }
  }

  static void _mustBeCurrentPlayer(String playerId, GameState state) {
    if (state.turn.currentPlayerId != playerId) {
      throw const InvalidActionException('No es tu turno');
    }
  }

  static void _mustBeAbleToPlay(CardModel card, GameState state) {
    if (!CardRules.canPlay(card, state)) {
      throw InvalidActionException('No puedes jugar ${card.type.name}');
    }
  }

  static void _targetMustBeAlive(String targetId, GameState state) {
    final target = state.playerById(targetId);
    if (target == null || !target.isAlive) {
      throw const InvalidActionException('El objetivo no está en juego');
    }
  }

  static void _targetMustNotBeSelf(String playerId, String targetId) {
    if (playerId == targetId) {
      throw const InvalidActionException('No puedes elegirte a ti mismo');
    }
  }

  static void _playerMustHaveCards(
      String playerId, List<CardModel> cards, GameState state) {
    final player = state.playerById(playerId);
    if (player == null) throw const GameException('Jugador no encontrado');
    for (final card in cards) {
      if (!player.hand.any((c) => c.id == card.id)) {
        throw InvalidActionException('No tienes la carta ${card.id}');
      }
    }
  }
}
