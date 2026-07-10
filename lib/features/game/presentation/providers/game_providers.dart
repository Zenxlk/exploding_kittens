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
import 'package:exploding_kittens/network/websocket/websocket_message.dart';

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

/// De un `GameState` crudo a lo que la UI consume. Compartida por
/// `GameNotifier` (motor local) y `RemoteGameNotifier` (Fase 5: refleja el
/// `GameState` que llega por red) para no duplicar esta decisión.
GameSessionState sessionStateFrom(GameState gameState) {
  final result = gameState.result;
  if (gameState.phase == GamePhase.finished && result != null) {
    return GameFinished(result);
  }
  return GameRunning(state: gameState);
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
  final _rawStatesController = StreamController<GameState>.broadcast(
    sync: true,
  );

  /// Eventos del motor (animaciones, sonidos) para que la UI se suscriba
  /// directamente sin pasar por el estado del `Notifier`.
  Stream<GameEvent> get events => _gateway.events;

  /// El `GameState` crudo tal cual sale del gateway en cada cambio, incluso
  /// en el instante en que la partida termina (que `state` "pierde" al
  /// convertirse en `GameFinished`). Fase 5: el puente host↔red se suscribe
  /// aquí para reenviar cada estado a los demás dispositivos.
  Stream<GameState> get rawStates => _rawStatesController.stream;

  @override
  GameSessionState build() {
    ref.onDispose(() {
      _nopeTimer?.cancel();
      _rawStatesController.close();
    });
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

  /// Aplica un `TurnAction` ya construido — usado por el puente host↔red
  /// (Fase 5) para procesar la acción que llegó de un cliente no-host por
  /// `ActionMessage`, en vez de ir método por método como hace la UI local.
  /// A diferencia de los métodos de despacho locales (playCard, drawCard,
  /// ...), devuelve el mensaje de error si `GameRules` la rechazó, para que
  /// el puente sepa contestarle solo a quien la mandó (`ActionRejectedMessage`)
  /// en vez de limitarse a dejarlo como error transitorio del estado.
  String? applyAction(TurnAction action) => _apply(action);

  /// Expiró el grace period de reconexión de [playerId] sin que volviera
  /// (Fase 5, disparado por `ReconnectionManager` vía el puente host↔red).
  void eliminateForDisconnect(String playerId) {
    if (state is! GameRunning) return;
    _setFromGameState(_gateway.eliminatePlayerForDisconnect(playerId));
  }

  // ── internals ────────────────────────────────────────────────────────────

  String? _apply(TurnAction action) {
    if (state is! GameRunning) return null;
    try {
      _setFromGameState(_gateway.apply(action));
      return null;
    } on InvalidActionException catch (e) {
      final current = state;
      if (current is GameRunning) state = current.copyWith(error: e.message);
      return e.message;
    }
  }

  void _resolveNopeWindow() {
    if (state is! GameRunning) return;
    _setFromGameState(_gateway.resolveNopeWindow());
  }

  void _setFromGameState(GameState gameState) {
    _rawStatesController.add(gameState);
    final next = sessionStateFrom(gameState);
    if (next is GameFinished) _nopeTimer?.cancel();
    state = next;
    if (next is GameRunning) _scheduleNopeWindowIfNeeded(gameState);
  }

  void _scheduleNopeWindowIfNeeded(GameState gameState) {
    _nopeTimer?.cancel();
    if (gameState.turn.phase != TurnPhase.nopeWindow) return;
    _nopeTimer = Timer(_nopeWindowDuration, _resolveNopeWindow);
  }
}

// ── RemoteGameNotifier (Fase 5) ────────────────────────────────────────────────

/// Partida vista desde un dispositivo no-host: no corre ningún `GameEngine`
/// local (por eso no implementa `IGameGateway` — no hay nada síncrono que
/// devolver), solo refleja el `GameState`/`GameEvent` que el host reenvía por
/// WebSocket y manda las acciones locales como `ActionMessage`. Expone el
/// mismo `GameSessionState` que `GameNotifier`, así que `GameTableView` y el
/// resto de la UI de la mesa no necesitan saber cuál de los dos los alimenta.
final remoteGameProvider =
    NotifierProvider<RemoteGameNotifier, GameSessionState>(
  RemoteGameNotifier.new,
);

class RemoteGameNotifier extends Notifier<GameSessionState> {
  StreamSubscription<WsMessage>? _sub;
  void Function(WsMessage)? _send;
  bool _listening = false;
  final _eventsController = StreamController<GameEvent>.broadcast();

  /// Eventos reenviados por el host (`GameEventMessage`) — mismo tipo que
  /// `GameNotifier.events`, para que `GameSoundController` no distinga entre
  /// host y no-host.
  Stream<GameEvent> get events => _eventsController.stream;

  @override
  GameSessionState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _eventsController.close();
    });
    return const GameIdle();
  }

  /// Empieza a reflejar la partida que llega por [messages], mandando las
  /// acciones locales por [send]. Idempotente — llamarlo de nuevo (p. ej. en
  /// cada rebuild de `GameScreen`) no vuelve a suscribirse.
  void listenTo(Stream<WsMessage> messages, void Function(WsMessage) send) {
    if (_listening) return;
    _listening = true;
    _send = send;
    _sub = messages.listen(_onMessage);
  }

  void _onMessage(WsMessage msg) {
    switch (msg) {
      case GameStateMessage(:final stateJson):
        state = sessionStateFrom(GameState.fromJson(stateJson));
      case GameEventMessage(:final eventJson):
        _eventsController.add(GameEvent.fromJson(eventJson));
      case ActionRejectedMessage(:final message):
        final current = state;
        if (current is GameRunning) state = current.copyWith(error: message);
      default:
        break;
    }
  }

  void drawCard(String playerId) =>
      _dispatch(DrawCardAction(playerId: playerId));

  void playCard(String playerId, CardModel card) =>
      _dispatch(PlayCardAction(playerId: playerId, card: card));

  void playFavor(String playerId, CardModel card, String targetPlayerId) =>
      _dispatch(
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
      _dispatch(
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
      _dispatch(
        PlayCatTrioAction(
          playerId: playerId,
          cards: cards,
          targetPlayerId: targetPlayerId,
          chosenCardId: chosenCardId,
        ),
      );

  void playNope(String playerId, CardModel nopeCard) =>
      _dispatch(NopeAction(playerId: playerId, nopeCard: nopeCard));

  void defuse(String playerId, CardModel defuseCard, int insertAtPosition) =>
      _dispatch(
        DefuseBombAction(
          playerId: playerId,
          defuseCard: defuseCard,
          insertAtPosition: insertAtPosition,
        ),
      );

  void _dispatch(TurnAction action) =>
      _send?.call(ActionMessage(actionJson: action.toJson()));
}
