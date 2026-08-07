import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:exploding_kittens/game_engine/turn/turn_manager.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _state({
  required List<PlayerModel> players,
  required String currentPlayerId,
  int actionsLeft = 1,
}) {
  return GameState(
    id: 'g1',
    config: GameConfig(playerCount: players.length),
    players: players,
    deck: const DeckModel(drawPile: [], discardPile: []),
    turn: TurnModel(
      currentPlayerId: currentPlayerId,
      phase: TurnPhase.playing,
      actionsLeft: actionsLeft,
    ),
    phase: GamePhase.playing,
  );
}

void main() {
  group('TurnManager.advance', () {
    test('sin Attack pendiente, pasa al siguiente jugador vivo', () {
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        currentPlayerId: 'p1',
      );
      final next = TurnManager.advance(state);
      expect(next.turn.currentPlayerId, 'p2');
      expect(next.turn.actionsLeft, 1);
    });

    test('con Attack pendiente y el jugador vivo, sigue jugando él', () {
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        currentPlayerId: 'p1',
        actionsLeft: 2,
      );
      final next = TurnManager.advance(state);
      expect(next.turn.currentPlayerId, 'p1');
      expect(next.turn.actionsLeft, 1);
    });

    test(
        'si el jugador con Attack pendiente acaba de ser eliminado (explotó '
        'en el primer robo de la cadena), pasa al siguiente vivo en vez de '
        'quedarse trabado en un currentPlayerId muerto', () {
      final state = _state(
        players: const [
          PlayerModel(
            id: 'p1',
            name: 'A',
            hand: [],
            status: PlayerStatus.eliminated,
          ),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        currentPlayerId: 'p1',
        actionsLeft: 2, // todavía "debía" un robo más cuando explotó
      );
      final next = TurnManager.advance(state);
      expect(next.turn.currentPlayerId, 'p2');
      expect(next.turn.actionsLeft, 1);
    });
  });
}
