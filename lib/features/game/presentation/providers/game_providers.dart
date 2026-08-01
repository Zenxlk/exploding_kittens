import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:exploding_kittens/core/constants/game_constants.dart';
import 'package:exploding_kittens/core/errors/exceptions.dart';
import 'package:exploding_kittens/features/game/data/local_game_gateway.dart';
import 'package:exploding_kittens/features/game/data/online_wire_codec.dart';
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
  GameNotifier({
    IGameGateway? gateway,
    Duration? nopeWindowDuration,
    Duration? turnTimeout,
  })  : _gateway = gateway ?? LocalGameGateway(),
        _nopeWindowDuration = nopeWindowDuration ??
            const Duration(milliseconds: GameConstants.nopeWindowMs),
        _turnTimeout = turnTimeout ??
            const Duration(seconds: GameConstants.turnTimeoutSeconds);

  final IGameGateway _gateway;
  final Duration _nopeWindowDuration;
  final Duration _turnTimeout;
  Timer? _nopeTimer;
  Timer? _turnTimer;
  String? _turnTimerPlayerId;
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
      _turnTimer?.cancel();
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
  ) =>
      _apply(
        PlayCatTrioAction(
          playerId: playerId,
          cards: cards,
          targetPlayerId: targetPlayerId,
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

  void chooseCard(String playerId, String cardId) =>
      _apply(ChooseCardAction(playerId: playerId, cardId: cardId));

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

  /// [playerId] se desconectó a mitad de partida — arranca su grace period
  /// (Fase 5, `WsServer.onPlayerDisconnected` vía el puente host↔red).
  ///
  /// `WsServer.onPlayerReconnected`/`onPlayerDisconnected` pueden dispararse
  /// para un jugador que ya estaba `active`/no estaba `disconnected` (p. ej.
  /// `_onJoin` los llama para cualquier join de un id ya conocido, no solo
  /// para una reconexión real tras una caída) — el motor ya lo trata como
  /// no-op, pero solo re-emitimos el estado si de verdad cambió, para no
  /// retransmitir un `GameState` idéntico a todos los clientes.
  void markPlayerDisconnected(String playerId) {
    final current = state;
    if (current is! GameRunning) return;
    final next = _gateway.markPlayerDisconnected(playerId);
    if (next == current.state) return;
    _setFromGameState(next);
  }

  /// [playerId] reconectó a tiempo (Fase 5, `WsServer.onPlayerReconnected`).
  void markPlayerReconnected(String playerId) {
    final current = state;
    if (current is! GameRunning) return;
    final next = _gateway.markPlayerReconnected(playerId);
    if (next == current.state) return;
    _setFromGameState(next);
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
    if (next is GameFinished) {
      _nopeTimer?.cancel();
      _turnTimer?.cancel();
    }
    state = next;
    if (next is GameRunning) {
      _scheduleNopeWindowIfNeeded(gameState);
      _scheduleTurnTimerIfNeeded(gameState);
    }
  }

  void _scheduleNopeWindowIfNeeded(GameState gameState) {
    _nopeTimer?.cancel();
    if (gameState.turn.phase != TurnPhase.nopeWindow) return;
    _nopeTimer = Timer(_nopeWindowDuration, _resolveNopeWindow);
  }

  /// Un solo cronómetro por turno completo: mientras `currentPlayerId` no
  /// cambie (jugar cartas de acción a mitad de turno pasa por otras fases
  /// pero no rota el turno), no se reinicia.
  void _scheduleTurnTimerIfNeeded(GameState gameState) {
    final playerId = gameState.turn.currentPlayerId;
    if (playerId == _turnTimerPlayerId) return;
    _turnTimer?.cancel();
    _turnTimerPlayerId = playerId;
    _turnTimer = Timer(_turnTimeout, () => _onTurnTimeout(playerId));
  }

  void _onTurnTimeout(String playerId) {
    final current = state;
    if (current is! GameRunning) return;
    final turn = current.state.turn;
    // El turno ya avanzó por otro camino o está resolviendo otra cosa
    // (nopeWindow, resolving, awaitingCardChoice): el robo automático ya
    // no aplica.
    if (turn.currentPlayerId != playerId || turn.phase != TurnPhase.playing) {
      return;
    }
    drawCard(playerId);
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
  // true contra el backend online (cards_game_service): el GameState que
  // llega es la proyección redactada `View`, no el GameState completo que
  // manda WsServer en LAN, así que hace falta un parser distinto (y
  // recodificar las acciones salientes) — ver online_wire_codec.dart.
  bool _isOnline = false;
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
  ///
  /// [initialGameState] cubre una carrera real entre el host y un cliente
  /// remoto: el host arranca el motor y transmite el primer `GameState`
  /// casi al instante (todo local, vía loopback — ver
  /// `gameNetworkBridgeProvider`), mientras acá recién se llega a suscribir
  /// después de navegar y montar `GameScreen` — un viaje de red real que en
  /// modo online puede tardar más que ese primer broadcast. Como [messages]
  /// es un stream broadcast sin replay, ese primer mensaje se perdería para
  /// siempre sin este catch-up (pasar `WsClient.lastGameState`, que si
  /// llegó a tiempo por la red ya quedó cacheado ahí aunque nadie lo
  /// escuchara todavía).
  void listenTo(
    Stream<WsMessage> messages,
    void Function(WsMessage) send, {
    GameStateMessage? initialGameState,
    bool isOnline = false,
  }) {
    if (_listening) return;
    _listening = true;
    _isOnline = isOnline;
    _send = send;
    _sub = messages.listen(_onMessage);
    if (initialGameState != null) _onMessage(initialGameState);
  }

  void _onMessage(WsMessage msg) {
    switch (msg) {
      case GameStateMessage(:final stateJson):
        state = sessionStateFrom(_isOnline
            ? gameStateFromOnlineView(stateJson)
            : GameState.fromJson(stateJson));
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
  ) =>
      _dispatch(
        PlayCatTrioAction(
          playerId: playerId,
          cards: cards,
          targetPlayerId: targetPlayerId,
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

  void chooseCard(String playerId, String cardId) =>
      _dispatch(ChooseCardAction(playerId: playerId, cardId: cardId));

  void _dispatch(TurnAction action) => _send?.call(ActionMessage(
        actionJson:
            _isOnline ? turnActionToOnlineJson(action) : action.toJson(),
      ));
}
