import 'dart:math';
import '../deck/deck_manager.dart';
import '../events/game_event.dart';
import '../events/game_event_bus.dart';
import '../models/card/card_type.dart';
import '../models/game/game_state.dart';
import '../models/player/player_model.dart';
import '../models/player/player_status.dart';
import '../models/turn/turn_action.dart';
import '../models/turn/turn_model.dart';
import '../rules/nope_rules.dart';
import '../rules/win_condition.dart';
import '../turn/turn_manager.dart';

/// Aplica cada TurnAction al GameState y emite los GameEvents correspondientes.
abstract final class ActionProcessor {
  static GameState process(TurnAction action, GameState state) {
    return switch (action) {
      DrawCardAction() => _processDrawCard(action, state),
      PlayCardAction() => _processPlayCard(action, state),
      PlayFavorAction() => _processPlayFavor(action, state),
      PlayCatPairAction() => _processCatPair(action, state),
      PlayCatTrioAction() => _processCatTrio(action, state),
      DefuseBombAction() => _processDefuse(action, state),
      NopeAction() => _processNope(action, state),
    };
  }

  // ── DrawCard ────────────────────────────────────────────────────────────────

  static GameState _processDrawCard(DrawCardAction action, GameState state) {
    final (:deck, :drawn) = DeckManager.drawTop(state.deck);
    var next = state.copyWith(deck: deck);

    _emit(CardDrawnEvent(timestamp: _now(), playerId: action.playerId));

    if (drawn.type == CardType.explodingKitten) {
      _emit(BombTriggeredEvent(timestamp: _now(), playerId: action.playerId));

      final player = next.playerById(action.playerId)!;
      final hasDefuse = player.hand.any((c) => c.type == CardType.defuse);

      if (!hasDefuse) {
        // Eliminado
        next = _eliminatePlayer(action.playerId, next);
        _emit(PlayerEliminatedEvent(
          timestamp: _now(),
          playerId: action.playerId,
          playerName: player.name,
        ));
        final result = WinCondition.check(next);
        if (result != null) {
          _emit(GameOverEvent(
            timestamp: _now(),
            winnerId: result.winnerId,
            winnerName: result.winnerName,
          ));
          return next.copyWith(phase: GamePhase.finished, result: result);
        }
        return TurnManager.advance(next);
      }

      // Tiene Defuse → esperar DefuseBombAction (el jugador elige posición).
      // Se guarda la bomba robada para reinsertar exactamente esa carta.
      return next.copyWith(
        turn: next.turn.copyWith(phase: TurnPhase.resolving),
        pendingBomb: drawn,
      );
    }

    // Carta normal robada → añadir a la mano y terminar turno
    final updatedPlayers =
        _addCardToHand(action.playerId, drawn, state.players);
    next = next.copyWith(players: updatedPlayers);
    return TurnManager.advance(next);
  }

  // ── PlayCard ─────────────────────────────────────────────────────────────────

  static GameState _processPlayCard(PlayCardAction action, GameState state) {
    var next = _removeCardFromHand(action.playerId, action.card.id, state);
    next = next.copyWith(deck: DeckManager.discard(next.deck, action.card));

    _emit(CardPlayedEvent(
      timestamp: _now(),
      playerId: action.playerId,
      card: action.card,
    ));

    return switch (action.card.type) {
      CardType.attack => _applyAttack(action.playerId, next),
      CardType.skip => TurnManager.advance(next),
      CardType.seeTheFuture => _applySeeTheFuture(action.playerId, next),
      // Shuffle, cartas de gato sueltas, etc.: el efecto (si lo hay) se
      // difiere hasta resolveNopeWindow() para que un Nope pueda cancelarlo.
      _ => TurnManager.openNopeWindow(next, action),
    };
  }

  // ── Favor ────────────────────────────────────────────────────────────────────

  static GameState _processPlayFavor(PlayFavorAction action, GameState state) {
    var next = _removeCardFromHand(action.playerId, action.card.id, state);
    next = next.copyWith(deck: DeckManager.discard(next.deck, action.card));

    _emit(CardPlayedEvent(
        timestamp: _now(), playerId: action.playerId, card: action.card));

    // El robo de la carta objetivo se difiere: si lo nopean, no se roba nada.
    return TurnManager.openNopeWindow(next, action);
  }

  // ── Cat Pair ──────────────────────────────────────────────────────────────────

  static GameState _processCatPair(PlayCatPairAction action, GameState state) {
    var next = state;
    for (final c in action.cards) {
      next = _removeCardFromHand(action.playerId, c.id, next);
      next = next.copyWith(deck: DeckManager.discard(next.deck, c));
    }

    // El robo se difiere hasta la resolución de la ventana de Nope.
    return TurnManager.openNopeWindow(next, action);
  }

  // ── Cat Trio ──────────────────────────────────────────────────────────────────

  static GameState _processCatTrio(PlayCatTrioAction action, GameState state) {
    var next = state;
    for (final c in action.cards) {
      next = _removeCardFromHand(action.playerId, c.id, next);
      next = next.copyWith(deck: DeckManager.discard(next.deck, c));
    }

    // El robo se difiere hasta la resolución de la ventana de Nope.
    return TurnManager.openNopeWindow(next, action);
  }

  // ── Defuse ────────────────────────────────────────────────────────────────────

  static GameState _processDefuse(DefuseBombAction action, GameState state) {
    var next =
        _removeCardFromHand(action.playerId, action.defuseCard.id, state);

    // Reinsertar exactamente la bomba que se robó (guardada en pendingBomb),
    // no otra bomba cualquiera del mazo restante.
    final bomb = state.pendingBomb;
    if (bomb != null) {
      next = next.copyWith(
        deck: DeckManager.insertAt(next.deck, bomb, action.insertAtPosition),
        clearPendingBomb: true,
      );
    }

    _emit(BombDefusedEvent(
      timestamp: _now(),
      playerId: action.playerId,
      insertedAtPosition: action.insertAtPosition,
    ));

    return TurnManager.advance(next);
  }

  // ── Nope ──────────────────────────────────────────────────────────────────────

  static GameState _processNope(NopeAction action, GameState state) {
    var next = _removeCardFromHand(action.playerId, action.nopeCard.id, state);
    next = next.copyWith(deck: DeckManager.discard(next.deck, action.nopeCard));

    final newChain = NopeRules.incrementNopeChain(next.turn.nopeChainCount);
    next = next.copyWith(turn: next.turn.copyWith(nopeChainCount: newChain));

    _emit(NopedEvent(
        timestamp: _now(), playerId: action.playerId, chainCount: newChain));

    return next;
  }

  // ── Resolución de la ventana de Nope ──────────────────────────────────────────

  /// Cierra la ventana de Nope: si la cadena quedó cancelada (nopeChainCount
  /// impar) descarta el efecto pendiente sin aplicarlo; si no, lo aplica ahora.
  /// No es una acción de jugador (la dispara un temporizador), por lo que no
  /// pasa por GameRules.validate.
  static GameState resolveNopeWindow(GameState state) {
    var next = state;

    if (!state.turn.isNoped) {
      next = switch (state.pendingAction) {
        PlayFavorAction(:final playerId, :final targetPlayerId) =>
          _stealRandomCard(playerId, targetPlayerId, next),
        PlayCatPairAction(:final playerId, :final targetPlayerId) =>
          _stealRandomCard(playerId, targetPlayerId, next),
        PlayCatTrioAction(
          :final playerId,
          :final targetPlayerId,
          :final chosenCardId
        ) =>
          _stealChosenCard(playerId, targetPlayerId, chosenCardId, next),
        PlayCardAction(:final card) when card.type == CardType.shuffle =>
          _resolveShuffle(next),
        _ => next,
      };
    }

    return next.copyWith(
      turn: next.turn.copyWith(phase: TurnPhase.playing, nopeChainCount: 0),
      clearPendingAction: true,
    );
  }

  static GameState _stealRandomCard(
      String playerId, String targetPlayerId, GameState state) {
    final target = state.playerById(targetPlayerId);
    if (target == null || target.hand.isEmpty) return state;

    final stolen = target.hand[Random().nextInt(target.hand.length)];
    var next = _removeCardFromHand(targetPlayerId, stolen.id, state);
    return next.copyWith(
        players: _addCardToHand(playerId, stolen, next.players));
  }

  static GameState _stealChosenCard(String playerId, String targetPlayerId,
      String chosenCardId, GameState state) {
    final target = state.playerById(targetPlayerId);
    final chosen = target?.hand.where((c) => c.id == chosenCardId).firstOrNull;
    if (chosen == null) return state;

    var next = _removeCardFromHand(targetPlayerId, chosen.id, state);
    return next.copyWith(
        players: _addCardToHand(playerId, chosen, next.players));
  }

  static GameState _resolveShuffle(GameState state) {
    final shuffled = DeckManager.shuffle(state.deck);
    _emit(DeckShuffledEvent(timestamp: _now()));
    return state.copyWith(deck: shuffled);
  }

  // ── Efectos de cartas específicas ─────────────────────────────────────────────

  static GameState _applyAttack(String playerId, GameState state) {
    final next = TurnManager.advance(state);
    // El siguiente jugador debe jugar 2 veces
    return next.copyWith(turn: next.turn.copyWith(actionsLeft: 2));
  }

  static GameState _applySeeTheFuture(String playerId, GameState state) {
    final top3 = DeckManager.peekTop(state.deck, 3);
    _emit(SeeTheFutureEvent(
        timestamp: _now(), playerId: playerId, topCards: top3));
    return state.copyWith(seeTheFutureCards: top3);
  }

  // ── Desconexión (Fase 5) ──────────────────────────────────────────────────────
  //
  // Ninguna de las dos operaciones siguientes es un TurnAction: las dispara la
  // red (WsServer.onPlayerDisconnected/onPlayerReconnected vía
  // ReconnectionManager), no un jugador jugando su turno, así que no pasan por
  // GameRules.validate — mismo patrón que resolveNopeWindow().

  /// Marca a [playerId] como desconectado (mientras corre su grace period).
  /// No-op si ya no está activo (p. ej. ya fue eliminado o ganó).
  static GameState markDisconnected(String playerId, GameState state) {
    final player = state.playerById(playerId);
    if (player == null || player.status != PlayerStatus.active) return state;
    return _setStatus(playerId, PlayerStatus.disconnected, state);
  }

  /// Reconectó a tiempo: vuelve a `active`. No-op si no estaba `disconnected`.
  static GameState markReconnected(String playerId, GameState state) {
    final player = state.playerById(playerId);
    if (player == null || player.status != PlayerStatus.disconnected) {
      return state;
    }
    return _setStatus(playerId, PlayerStatus.active, state);
  }

  /// Expiró el grace period sin reconectar: elimina a [playerId] reutilizando
  /// el mismo camino que la eliminación por bomba (eliminationOrder +
  /// WinCondition). Si tenía el turno, lo pasa al siguiente jugador vivo;
  /// si no, el turno en curso no se ve afectado.
  static GameState eliminateForDisconnect(String playerId, GameState state) {
    final player = state.playerById(playerId);
    if (player == null || player.status == PlayerStatus.eliminated) {
      return state;
    }

    var next = _eliminatePlayer(playerId, state);
    _emit(PlayerEliminatedEvent(
      timestamp: _now(),
      playerId: playerId,
      playerName: player.name,
    ));

    final result = WinCondition.check(next);
    if (result != null) {
      _emit(GameOverEvent(
        timestamp: _now(),
        winnerId: result.winnerId,
        winnerName: result.winnerName,
      ));
      return next.copyWith(phase: GamePhase.finished, result: result);
    }

    if (state.turn.currentPlayerId == playerId) {
      return TurnManager.advance(next);
    }
    return next;
  }

  static GameState _setStatus(
      String playerId, PlayerStatus status, GameState state) {
    final updated = state.players
        .map((p) => p.id == playerId ? p.copyWith(status: status) : p)
        .toList();
    return state.copyWith(players: updated);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static GameState _eliminatePlayer(String playerId, GameState state) {
    final updated = state.players
        .map((p) =>
            p.id == playerId ? p.copyWith(status: PlayerStatus.eliminated) : p)
        .toList();
    return state.copyWith(
      players: updated,
      eliminationOrder: [...state.eliminationOrder, playerId],
    );
  }

  static GameState _removeCardFromHand(
      String playerId, String cardId, GameState state) {
    final updated = state.players.map((p) {
      if (p.id != playerId) return p;
      return p.copyWith(hand: p.hand.where((c) => c.id != cardId).toList());
    }).toList();
    return state.copyWith(players: updated);
  }

  static List<PlayerModel> _addCardToHand(
      String playerId, cardModel, List<PlayerModel> players) {
    return players.map((p) {
      if (p.id != playerId) return p;
      return p.copyWith(hand: [...p.hand, cardModel]);
    }).toList();
  }

  static void _emit(GameEvent event) => GameEventBus.instance.emit(event);
  static DateTime _now() => DateTime.now();
}
