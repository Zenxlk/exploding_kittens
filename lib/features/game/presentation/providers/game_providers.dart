import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:exploding_kittens/core/constants/game_constants.dart';
import 'package:exploding_kittens/core/errors/exceptions.dart';
import 'package:exploding_kittens/features/game/data/local_game_gateway.dart';
import 'package:exploding_kittens/features/game/domain/i_game_gateway.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_result.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class GameSessionState {
  const GameSessionState();
}

class GameIdle extends GameSessionState {
  const GameIdle();
}

class GameRunning extends GameSessionState {
  const GameRunning({required this.state, this.error});

  final GameState state;

  // Error transitorio de la última acción inválida (ej. jugar fuera de
  // turno). Se limpia solo en cuanto una acción posterior tiene éxito.
  final String? error;

  GameRunning copyWith({GameState? state, String? error}) {
    return GameRunning(state: state ?? this.state, error: error);
  }
}

class GameFinished extends GameSessionState {
  const GameFinished(this.result);
  final GameResult result;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

final gameProvider =
    NotifierProvider<GameNotifier, GameSessionState>(GameNotifier.new);

class GameNotifier extends Notifier<GameSessionState> {
  GameNotifier({IGameGateway? gateway, Duration? nopeWindowDuration})
      : _gateway = gateway ?? LocalGameGateway(),
        _nopeWindowDuration = nopeWindowDuration ??
            const Duration(milliseconds: GameConstants.nopeWindowMs);

  final IGameGateway _gateway;
  final Duration _nopeWindowDuration;
  Timer? _nopeTimer;

  /// Eventos del motor (animaciones, sonidos) para que la UI se suscriba
  /// directamente sin pasar por el estado del `Notifier`.
  Stream<GameEvent> get events => _gateway.events;

  @override
  GameSessionState build() {
    ref.onDispose(() => _nopeTimer?.cancel());
    return const GameIdle();
  }

  void startLocalGame(List<PlayerModel> players, GameConfig config) {
    _setFromGameState(_gateway.startGame(players, config));
  }

  void drawCard(String playerId) => _apply(DrawCardAction(playerId: playerId));

  void playCard(String playerId, CardModel card) =>
      _apply(PlayCardAction(playerId: playerId, card: card));

  void playFavor(String playerId, CardModel card, String targetPlayerId) =>
      _apply(
        PlayFavorAction(
          playerId: playerId,
          card: card,
          targetPlayerId: targetPlayerId,
        ),
      );

  void playCatPair(
    String playerId,
    List<CardModel> cards,
    String targetPlayerId,
  ) =>
      _apply(
        PlayCatPairAction(
          playerId: playerId,
          cards: cards,
          targetPlayerId: targetPlayerId,
        ),
      );

  void playCatTrio(
    String playerId,
    List<CardModel> cards,
    String targetPlayerId,
    String chosenCardId,
  ) =>
      _apply(
        PlayCatTrioAction(
          playerId: playerId,
          cards: cards,
          targetPlayerId: targetPlayerId,
          chosenCardId: chosenCardId,
        ),
      );

  void playNope(String playerId, CardModel nopeCard) =>
      _apply(NopeAction(playerId: playerId, nopeCard: nopeCard));

  void defuse(String playerId, CardModel defuseCard, int insertAtPosition) =>
      _apply(
        DefuseBombAction(
          playerId: playerId,
          defuseCard: defuseCard,
          insertAtPosition: insertAtPosition,
        ),
      );

  // ── internals ────────────────────────────────────────────────────────────

  void _apply(TurnAction action) {
    if (state is! GameRunning) return;
    try {
      _setFromGameState(_gateway.apply(action));
    } on InvalidActionException catch (e) {
      final current = state;
      if (current is GameRunning) state = current.copyWith(error: e.message);
    }
  }

  void _resolveNopeWindow() {
    if (state is! GameRunning) return;
    _setFromGameState(_gateway.resolveNopeWindow());
  }

  void _setFromGameState(GameState gameState) {
    final result = gameState.result;
    if (gameState.phase == GamePhase.finished && result != null) {
      _nopeTimer?.cancel();
      state = GameFinished(result);
      return;
    }
    state = GameRunning(state: gameState);
    _scheduleNopeWindowIfNeeded(gameState);
  }

  void _scheduleNopeWindowIfNeeded(GameState gameState) {
    _nopeTimer?.cancel();
    if (gameState.turn.phase != TurnPhase.nopeWindow) return;
    _nopeTimer = Timer(_nopeWindowDuration, _resolveNopeWindow);
  }
}
