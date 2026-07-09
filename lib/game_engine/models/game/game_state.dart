import 'package:equatable/equatable.dart';
import '../card/card_model.dart';
import '../deck/deck_model.dart';
import '../player/player_model.dart';
import '../player/player_status.dart';
import '../turn/turn_model.dart';
import 'game_config.dart';
import 'game_result.dart';

enum GamePhase {
  waiting, // sala creada, esperando jugadores
  playing, // partida en curso
  finished, // partida terminada
}

class GameState extends Equatable {
  const GameState({
    required this.id,
    required this.config,
    required this.players,
    required this.deck,
    required this.turn,
    required this.phase,
    this.pendingAction,
    this.pendingBomb,
    this.seeTheFutureCards,
    this.result,
    this.turnCount = 0,
    this.eliminationOrder = const [],
  });

  final String id;
  final GameConfig config;
  final List<PlayerModel> players;
  final DeckModel deck;
  final TurnModel turn;
  final GamePhase phase;

  // Acción en espera de resolución (Nope window abierta)
  final Object? pendingAction;

  // Exploding Kitten robado, en espera de reinserción (Defuse en curso)
  final CardModel? pendingBomb;

  // Top 3 cartas visibles (See the Future activo)
  final List<CardModel>? seeTheFutureCards;

  final GameResult? result;
  final int turnCount;

  // Ids en el orden cronológico real en que fueron eliminados (a diferencia
  // de recorrer `players` filtrando por status, que sigue el orden de la
  // lista, no el de eliminación) — ver `ActionProcessor._eliminatePlayer`.
  final List<String> eliminationOrder;

  List<PlayerModel> get alivePlayers =>
      players.where((p) => p.status == PlayerStatus.active).toList();

  PlayerModel? get currentPlayer =>
      players.where((p) => p.id == turn.currentPlayerId).firstOrNull;

  PlayerModel? playerById(String id) =>
      players.where((p) => p.id == id).firstOrNull;

  bool get isOver => phase == GamePhase.finished;

  GameState copyWith({
    GameConfig? config,
    List<PlayerModel>? players,
    DeckModel? deck,
    TurnModel? turn,
    GamePhase? phase,
    Object? pendingAction,
    CardModel? pendingBomb,
    List<CardModel>? seeTheFutureCards,
    GameResult? result,
    int? turnCount,
    List<String>? eliminationOrder,
    bool clearPendingAction = false,
    bool clearPendingBomb = false,
    bool clearSeeTheFuture = false,
  }) {
    return GameState(
      id: id,
      config: config ?? this.config,
      players: players ?? this.players,
      deck: deck ?? this.deck,
      turn: turn ?? this.turn,
      phase: phase ?? this.phase,
      pendingAction:
          clearPendingAction ? null : (pendingAction ?? this.pendingAction),
      pendingBomb: clearPendingBomb ? null : (pendingBomb ?? this.pendingBomb),
      seeTheFutureCards: clearSeeTheFuture
          ? null
          : (seeTheFutureCards ?? this.seeTheFutureCards),
      result: result ?? this.result,
      turnCount: turnCount ?? this.turnCount,
      eliminationOrder: eliminationOrder ?? this.eliminationOrder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        config,
        players,
        deck,
        turn,
        phase,
        pendingAction,
        pendingBomb,
        seeTheFutureCards,
        result,
        turnCount,
        eliminationOrder,
      ];
}
