import '../../core/errors/exceptions.dart';
import '../models/card/card_model.dart';
import '../models/card/card_type.dart';
import '../models/game/game_state.dart';
import '../models/player/player_model.dart';
import '../models/turn/turn_action.dart';
import '../models/turn/turn_model.dart';
import 'card_rules.dart';

/// Orquestador de reglas. Punto único de validación antes de aplicar acciones.
abstract final class GameRules {
  static void validate(TurnAction action, GameState state) {
    switch (action) {
      case DrawCardAction():
        _mustBeCurrentPlayer(action.playerId, state);
        _mustBeInPhase(state, TurnPhase.playing);
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
        _mustBeInPhase(state, TurnPhase.playing);
        if (!CardRules.isValidCatPair(cards)) {
          throw const InvalidActionException('Par de gatos inválido');
        }
        _playerMustHaveCards(action.playerId, cards, state);
        _targetMustBeAlive(targetPlayerId, state);
        _targetMustNotBeSelf(action.playerId, targetPlayerId);
      case PlayCatTrioAction(:final cards, :final targetPlayerId):
        _mustBeCurrentPlayer(action.playerId, state);
        _mustBeInPhase(state, TurnPhase.playing);
        if (!CardRules.isValidCatTrio(cards)) {
          throw const InvalidActionException('Trío de gatos inválido');
        }
        _playerMustHaveCards(action.playerId, cards, state);
        _targetMustBeAlive(targetPlayerId, state);
        _targetMustNotBeSelf(action.playerId, targetPlayerId);
      case DefuseBombAction():
        _mustBeCurrentPlayer(action.playerId, state);
        _mustBeInPhase(state, TurnPhase.resolving);
        if (state.pendingBomb == null) {
          throw const InvalidActionException(
            'No hay ninguna bomba pendiente de esconder',
          );
        }
        if (!CardRules.canDefuse(state.currentPlayer!)) {
          throw const InvalidActionException('No tienes Defuse');
        }
      case NopeAction(:final playerId):
        final player = state.playerById(playerId);
        if (player == null) throw const GameException('Jugador no encontrado');
        if (!CardRules.canNope(player, state)) {
          throw const InvalidActionException('No puedes jugar Nope ahora');
        }
      case ChooseCardAction(:final cardId):
        _mustBeInPhase(state, TurnPhase.awaitingCardChoice);
        switch (state.pendingAction) {
          // Favor: elige el objetivo, desde su propia mano.
          case PlayFavorAction(:final targetPlayerId):
            if (action.playerId != targetPlayerId) {
              throw const InvalidActionException('No te toca elegir una carta');
            }
            _playerMustHaveCard(targetPlayerId, cardId, state);
          // Trío de gatos: elige el actor (a ciegas), desde la mano rival.
          case PlayCatTrioAction(:final playerId, :final targetPlayerId):
            if (action.playerId != playerId) {
              throw const InvalidActionException('No te toca elegir una carta');
            }
            _playerMustHaveCard(targetPlayerId, cardId, state);
          default:
            throw const InvalidActionException(
              'No hay ninguna elección de carta pendiente',
            );
        }
    }
  }

  /// Todas las `TurnAction` que `playerId` puede ejecutar ahora mismo — no
  /// existía antes de esto (el motor solo sabía rechazar una acción ya
  /// construida). Genera candidatos baratos por fase y los filtra
  /// intentando `validate` de verdad: así nunca puede divergir de la única
  /// fuente de reglas, a costa de generar algún candidato de más que
  /// `validate` descarta. Pensado para el motor de bots (`game_engine/bot/`)
  /// — devuelve `[]` cuando no hay nada legal para hacer (p. ej. ventana de
  /// Nope sin Nope en mano), lo cual es una respuesta válida en sí misma.
  static List<TurnAction> legalActions(String playerId, GameState state) {
    return _candidateActions(playerId, state).where((action) {
      try {
        validate(action, state);
        return true;
      } on InvalidActionException {
        return false;
      }
    }).toList();
  }

  static List<TurnAction> _candidateActions(String playerId, GameState state) {
    final player = state.playerById(playerId);
    if (player == null || !player.isAlive) return const [];

    return switch (state.turn.phase) {
      TurnPhase.playing => _playingCandidates(playerId, player, state),
      TurnPhase.resolving => _resolvingCandidates(playerId, player, state),
      TurnPhase.nopeWindow => _nopeCandidates(playerId, player),
      TurnPhase.awaitingCardChoice =>
        _cardChoiceCandidates(playerId, player, state),
      TurnPhase.drawRequired || TurnPhase.ended => const [],
    };
  }

  static List<TurnAction> _playingCandidates(
    String playerId,
    PlayerModel player,
    GameState state,
  ) {
    final candidates = <TurnAction>[DrawCardAction(playerId: playerId)];
    final targets = state.alivePlayers.where((p) => p.id != playerId).toList();

    for (final card in player.hand) {
      if (!card.type.isPlayable || card.type.isCatCard) continue;
      if (card.type == CardType.favor) {
        for (final target in targets) {
          candidates.add(PlayFavorAction(
            playerId: playerId,
            card: card,
            targetPlayerId: target.id,
          ));
        }
      } else {
        candidates.add(PlayCardAction(playerId: playerId, card: card));
      }
    }

    final catCardsByType = <CardType, List<CardModel>>{};
    for (final card in player.hand.where((c) => c.type.isCatCard)) {
      (catCardsByType[card.type] ??= []).add(card);
    }
    for (final cards in catCardsByType.values) {
      if (cards.length < 2) continue;
      for (final target in targets) {
        candidates.add(PlayCatPairAction(
          playerId: playerId,
          cards: cards.sublist(0, 2),
          targetPlayerId: target.id,
        ));
        if (cards.length >= 3) {
          candidates.add(PlayCatTrioAction(
            playerId: playerId,
            cards: cards.sublist(0, 3),
            targetPlayerId: target.id,
          ));
        }
      }
    }
    return candidates;
  }

  static List<TurnAction> _resolvingCandidates(
    String playerId,
    PlayerModel player,
    GameState state,
  ) {
    if (state.turn.currentPlayerId != playerId) return const [];
    if (state.pendingBomb == null) return const [];
    final defuseCard =
        player.hand.where((c) => c.type == CardType.defuse).firstOrNull;
    if (defuseCard == null) return const [];

    // Un puñado de posiciones representativas, no las ~50 posiciones reales
    // del mazo — alcanza para que el evaluador distinga "arriba" (riesgo
    // inmediato para el próximo en robar) de "abajo" (riesgo diferido).
    // `DeckManager.insertAt` clampea cualquier valor fuera de rango, así que
    // no hace falta más cuidado acá.
    final pileLength = state.deck.drawPileCount;
    final positions = {
      0,
      pileLength ~/ 4,
      pileLength ~/ 2,
      (pileLength * 3) ~/ 4,
      pileLength,
    };
    return positions
        .map((pos) => DefuseBombAction(
              playerId: playerId,
              defuseCard: defuseCard,
              insertAtPosition: pos,
            ))
        .toList();
  }

  static List<TurnAction> _nopeCandidates(String playerId, PlayerModel player) {
    final nopeCard =
        player.hand.where((c) => c.type == CardType.nope).firstOrNull;
    if (nopeCard == null) return const [];
    return [NopeAction(playerId: playerId, nopeCard: nopeCard)];
  }

  static List<TurnAction> _cardChoiceCandidates(
    String playerId,
    PlayerModel player,
    GameState state,
  ) {
    return switch (state.pendingAction) {
      // Favor: el propio player elige qué carta de SU mano entregar.
      PlayFavorAction(targetPlayerId: final chooserId)
          when chooserId == playerId =>
        player.hand
            .map((c) => ChooseCardAction(playerId: playerId, cardId: c.id))
            .toList(),
      // Trío de gatos: el actor elige a ciegas de la mano del objetivo.
      PlayCatTrioAction(
        playerId: final actorId,
        targetPlayerId: final handOwnerId
      )
          when actorId == playerId =>
        (state.playerById(handOwnerId)?.hand ?? const [])
            .map((c) => ChooseCardAction(playerId: playerId, cardId: c.id))
            .toList(),
      _ => const [],
    };
  }

  static void _mustBeCurrentPlayer(String playerId, GameState state) {
    if (state.turn.currentPlayerId != playerId) {
      throw const InvalidActionException('No es tu turno');
    }
  }

  /// `PlayCardAction`/`PlayFavorAction` ya quedan cubiertas por el chequeo de
  /// fase dentro de `CardRules.canPlay`; `DrawCardAction`, los pares/tríos de
  /// gato y `DefuseBombAction` necesitaban el mismo candado explícito. Sin
  /// esto, una acción "atrasada" por latencia de red (p. ej. un robo que
  /// salió justo antes de que se abriera una ventana de Nope, y llega al
  /// host cuando esta ya está abierta) pasaba la validación igual,
  /// `TurnManager.advance` limpiaba `pendingAction` de golpe y cancelaba el
  /// `Timer` de `resolveNopeWindow` en `GameNotifier` (se reprograma en cada
  /// cambio de estado) — el Favor/par de gatos pendiente se perdía sin
  /// resolverse y el turno quedaba en un estado inconsistente.
  static void _mustBeInPhase(GameState state, TurnPhase phase) {
    if (state.turn.phase != phase) {
      throw const InvalidActionException('No puedes hacer eso ahora');
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

  static void _playerMustHaveCard(
      String playerId, String cardId, GameState state) {
    final player = state.playerById(playerId);
    if (player == null) throw const GameException('Jugador no encontrado');
    if (!player.hand.any((c) => c.id == cardId)) {
      throw InvalidActionException('No tienes la carta $cardId');
    }
  }
}
