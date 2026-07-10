import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';

/// Punto único por el que la UI habla con "la partida", sin saber si es
/// local (envuelve un [GameEngine] en el propio dispositivo) o remota
/// (Fase 5: reenvía acciones al host por WebSocket y recibe el estado).
abstract interface class IGameGateway {
  Stream<GameEvent> get events;

  GameState startGame(List<PlayerModel> players, GameConfig config);

  /// Lanza [InvalidActionException] si la acción no es válida.
  GameState apply(TurnAction action);

  /// Cierra la ventana de Nope (temporizador expirado).
  GameState resolveNopeWindow();

  /// Expiró el grace period de reconexión (Fase 5) sin que [playerId]
  /// volviera: lo elimina de la partida. No es un `TurnAction`, igual que
  /// `resolveNopeWindow`.
  GameState eliminatePlayerForDisconnect(String playerId);
}
