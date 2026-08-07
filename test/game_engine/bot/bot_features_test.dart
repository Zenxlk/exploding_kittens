import 'package:exploding_kittens/game_engine/bot/bot_features.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _state({
  required List<PlayerModel> players,
  List<CardModel> drawPile = const [],
  List<CardModel>? seeTheFutureCards,
}) {
  return GameState(
    id: 'g1',
    config: const GameConfig(playerCount: 2),
    players: players,
    deck: DeckModel(drawPile: drawPile, discardPile: const []),
    turn: const TurnModel(currentPlayerId: 'p1', phase: TurnPhase.playing),
    phase: GamePhase.playing,
    seeTheFutureCards: seeTheFutureCards,
  );
}

void main() {
  group('BotFeatures.explosionProbability', () {
    test('mazo vacío: 0', () {
      expect(
        BotFeatures.explosionProbability(_state(players: const [])),
        0,
      );
    });

    test('proporción de kittens en el mazo restante', () {
      final state = _state(
        players: const [],
        drawPile: const [
          CardModel(id: 'k1', type: CardType.explodingKitten),
          CardModel(id: 's1', type: CardType.skip),
          CardModel(id: 's2', type: CardType.skip),
          CardModel(id: 's3', type: CardType.skip),
        ],
      );
      expect(BotFeatures.explosionProbability(state), 0.25);
    });
  });

  group('BotFeatures.defuseCount / escapeCardCount', () {
    test('cuenta solo la mano del jugador pedido', () {
      const hand = [
        CardModel(id: 'd1', type: CardType.defuse),
        CardModel(id: 'd2', type: CardType.defuse),
        CardModel(id: 'atk', type: CardType.attack),
        CardModel(id: 'sk', type: CardType.skip),
        CardModel(id: 'fav', type: CardType.favor),
      ];
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: hand),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
      );
      expect(BotFeatures.defuseCount(state, 'p1'), 2);
      expect(BotFeatures.escapeCardCount(state, 'p1'), 2); // attack + skip
      expect(BotFeatures.defuseCount(state, 'p2'), 0);
    });
  });

  group('BotFeatures.hasSafeKnownDraw', () {
    test('sin Ver el Futuro activo: false', () {
      expect(BotFeatures.hasSafeKnownDraw(_state(players: const [])), isFalse);
    });

    test('tope conocido es una bomba: false', () {
      final state = _state(
        players: const [],
        seeTheFutureCards: const [
          CardModel(id: 'k1', type: CardType.explodingKitten),
        ],
      );
      expect(BotFeatures.hasSafeKnownDraw(state), isFalse);
    });

    test('tope conocido no es una bomba: true', () {
      final state = _state(
        players: const [],
        seeTheFutureCards: const [CardModel(id: 's1', type: CardType.skip)],
      );
      expect(BotFeatures.hasSafeKnownDraw(state), isTrue);
    });
  });

  group('BotFeatures.weakestOpponentHandSize', () {
    test('devuelve el tamaño de mano más chico entre rivales vivos', () {
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(
            id: 'p2',
            name: 'B',
            hand: [
              CardModel(id: 'a', type: CardType.skip),
              CardModel(id: 'b', type: CardType.skip),
            ],
          ),
          PlayerModel(id: 'p3', name: 'C', hand: [
            CardModel(id: 'c', type: CardType.skip),
          ]),
        ],
      );
      expect(BotFeatures.weakestOpponentHandSize(state, 'p1'), 1);
    });

    test('sin rivales vivos: 0', () {
      final state = _state(
        players: const [PlayerModel(id: 'p1', name: 'A', hand: [])],
      );
      expect(BotFeatures.weakestOpponentHandSize(state, 'p1'), 0);
    });
  });
}
