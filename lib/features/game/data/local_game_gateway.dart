import 'package:exploding_kittens/features/game/domain/i_game_gateway.dart';
import 'package:exploding_kittens/game_engine/engine/game_engine.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';

/// Partida local (pasar y jugar): envuelve un [GameEngine] en el propio
/// dispositivo. En la Fase 5 se añadirá un gateway remoto que implemente
/// la misma interfaz reenviando las acciones al host por WebSocket.
class LocalGameGateway implements IGameGateway {
  final _engine = GameEngine();

  @override
  Stream<GameEvent> get events => _engine.events;

  @override
  GameState startGame(List<PlayerModel> players, GameConfig config) =>
      _engine.startGame(players, config);

  @override
  GameState apply(TurnAction action) => _engine.apply(action);

  @override
  GameState resolveNopeWindow() => _engine.resolveNopeWindow();

  @override
  GameState eliminatePlayerForDisconnect(String playerId) =>
      _engine.eliminatePlayerForDisconnect(playerId);
}
