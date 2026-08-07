import 'package:exploding_kittens/game_engine/bot/bot_config.dart';
import 'package:exploding_kittens/game_engine/bot/bot_evaluator.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _state({required List<PlayerModel> players}) {
  return GameState(
    id: 'g1',
    config: const GameConfig(playerCount: 2),
    players: players,
    deck: const DeckModel(drawPile: [], discardPile: []),
    turn: const TurnModel(currentPlayerId: 'p1', phase: TurnPhase.playing),
    phase: GamePhase.playing,
  );
}

void main() {
  group('GameStateEvaluator.evaluate', () {
    const weights = BotWeights.standard;

    test('jugador inexistente: -infinito', () {
      final state = _state(players: const []);
      expect(
        GameStateEvaluator.evaluate(state, 'nadie', weights),
        double.negativeInfinity,
      );
    });

    test('jugador eliminado: -infinito', () {
      final state = _state(
        players: const [
          PlayerModel(
            id: 'p1',
            name: 'A',
            hand: [],
            status: PlayerStatus.eliminated,
          ),
        ],
      );
      expect(
        GameStateEvaluator.evaluate(state, 'p1', weights),
        double.negativeInfinity,
      );
    });

    test('más Defuse en mano puntúa mejor, todo lo demás igual', () {
      final withoutDefuse = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
      );
      final withDefuse = _state(
        players: const [
          PlayerModel(
            id: 'p1',
            name: 'A',
            hand: [CardModel(id: 'd1', type: CardType.defuse)],
          ),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
      );
      expect(
        GameStateEvaluator.evaluate(withDefuse, 'p1', weights),
        greaterThan(GameStateEvaluator.evaluate(withoutDefuse, 'p1', weights)),
      );
    });

    test('mayor probabilidad de explotar puntúa peor', () {
      final safe = GameState(
        id: 'g1',
        config: const GameConfig(playerCount: 2),
        players: const [PlayerModel(id: 'p1', name: 'A', hand: [])],
        deck: const DeckModel(
          drawPile: [CardModel(id: 's1', type: CardType.skip)],
          discardPile: [],
        ),
        turn: const TurnModel(currentPlayerId: 'p1', phase: TurnPhase.playing),
        phase: GamePhase.playing,
      );
      final risky = GameState(
        id: 'g1',
        config: const GameConfig(playerCount: 2),
        players: const [PlayerModel(id: 'p1', name: 'A', hand: [])],
        deck: const DeckModel(
          drawPile: [CardModel(id: 'k1', type: CardType.explodingKitten)],
          discardPile: [],
        ),
        turn: const TurnModel(currentPlayerId: 'p1', phase: TurnPhase.playing),
        phase: GamePhase.playing,
      );
      expect(
        GameStateEvaluator.evaluate(safe, 'p1', weights),
        greaterThan(GameStateEvaluator.evaluate(risky, 'p1', weights)),
      );
    });
  });
}
