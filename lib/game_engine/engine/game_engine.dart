import '../deck/deck_builder.dart';
import '../events/game_event.dart';
import '../events/game_event_bus.dart';
import '../models/game/game_config.dart';
import '../models/game/game_state.dart';
import '../models/player/player_model.dart';
import '../models/turn/turn_action.dart';
import '../models/turn/turn_model.dart';
import '../rules/game_rules.dart';
import 'action_processor.dart';
import 'package:uuid/uuid.dart';

/// Fachada pública del motor de juego.
/// Uso:
///   final engine = GameEngine();
///   engine.startGame(players, config);
///   engine.apply(DrawCardAction(playerId: '...'));
class GameEngine {
  GameEngine({GameEventBus? bus}) : _bus = bus ?? GameEventBus.instance;

  final GameEventBus _bus;
  final _uuid = const Uuid();

  GameState? _state;

  GameState get state {
    assert(_state != null, 'Llama a startGame() antes de usar el engine');
    return _state!;
  }

  Stream<GameEvent> get events => _bus.stream;
  Stream<T> on<T extends GameEvent>() => _bus.on<T>();

  /// Inicializa la partida con los jugadores y configuración dados.
  GameState startGame(List<PlayerModel> players, GameConfig config) {
    assert(players.length >= 2 && players.length <= 5,
        'Se requieren 2-5 jugadores');

    final (:deck, :players as updatedPlayers) =
        DeckBuilder.build(players: players, config: config);

    _state = GameState(
      id: _uuid.v4(),
      config: config,
      players: updatedPlayers,
      deck: deck,
      turn: TurnModel(
        currentPlayerId: updatedPlayers.first.id,
        phase: TurnPhase.playing,
        actionsLeft: 1,
      ),
      phase: GamePhase.playing,
    );

    return _state!;
  }

  /// Aplica una acción al estado actual. Valida primero, luego procesa.
  /// Lanza [InvalidActionException] si la acción no es válida.
  GameState apply(TurnAction action) {
    GameRules.validate(action, state);
    _state = ActionProcessor.process(action, _state!);
    return _state!;
  }

  void dispose() => _bus.dispose();
}
