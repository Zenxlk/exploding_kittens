import 'dart:math';

import 'package:exploding_kittens/game_engine/bot/bot_config.dart';
import 'package:exploding_kittens/game_engine/bot/bot_player.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _state({
  required List<PlayerModel> players,
  TurnPhase phase = TurnPhase.playing,
  List<CardModel> drawPile = const [],
  Object? pendingAction,
  String currentPlayerId = 'p1',
}) {
  return GameState(
    id: 'g1',
    config: GameConfig(playerCount: players.length),
    players: players,
    deck: DeckModel(drawPile: drawPile, discardPile: const []),
    turn: TurnModel(currentPlayerId: currentPlayerId, phase: phase),
    phase: GamePhase.playing,
    pendingAction: pendingAction,
  );
}

void main() {
  group('BotPlayer.decide', () {
    test('devuelve null si no hay ninguna acción legal', () {
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        phase: TurnPhase.nopeWindow,
        pendingAction: const DrawCardAction(playerId: 'p1'),
      );
      final action = BotPlayer.decide(state, 'p2', BotConfig.normal, Random(1));
      expect(action, isNull);
    });

    test(
        'con temperatura 0 elige el candidato de mayor puntaje de forma '
        'determinista', () {
      const defuse = CardModel(id: 'defuse-1', type: CardType.defuse);
      const skip = CardModel(id: 'skip-1', type: CardType.skip);
      const deckCard = CardModel(id: 'atk-deck', type: CardType.attack);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: [defuse, skip]),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        drawPile: const [deckCard],
      );
      const config = BotConfig(
        weights: BotWeights.standard,
        determinizations: 1,
        temperature: 0,
      );

      // Robar deja [defuse, skip, atk] (2 cartas de escape); jugar el skip
      // deja solo [defuse] (0 cartas de escape) — la heurística debería
      // preferir robar acá, y hacerlo siempre igual con temperatura 0.
      for (final seed in [1, 2, 3, 4, 5]) {
        final action = BotPlayer.decide(state, 'p1', config, Random(seed));
        expect(action, isA<DrawCardAction>());
      }
    });

    test('la elección a ciegas del trío de gatos no muestra un patrón fijo',
        () {
      const trioCards = [
        CardModel(id: 't1', type: CardType.tacocat),
        CardModel(id: 't2', type: CardType.tacocat),
        CardModel(id: 't3', type: CardType.tacocat),
      ];
      final rivalHand = List.generate(
        6,
        (i) => CardModel(id: 'r$i', type: CardType.skip),
      );
      final state = _state(
        players: [
          const PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: rivalHand),
        ],
        phase: TurnPhase.awaitingCardChoice,
        pendingAction: const PlayCatTrioAction(
          playerId: 'p1',
          cards: trioCards,
          targetPlayerId: 'p2',
        ),
      );

      final chosen = <String>{};
      for (var seed = 0; seed < 300; seed++) {
        final action =
            BotPlayer.decide(state, 'p1', BotConfig.normal, Random(seed));
        expect(action, isA<ChooseCardAction>());
        final cardId = (action as ChooseCardAction).cardId;
        expect(rivalHand.map((c) => c.id), contains(cardId));
        chosen.add(cardId);
      }
      // Con 300 tiradas sobre 6 cartas, un pick realmente uniforme no
      // debería converger siempre a la misma — si esto falla, es señal de
      // que se está usando información real de la mano en vez de rng.
      expect(chosen.length, greaterThan(1));
    });

    test(
        'en la ventana de Nope, a veces nopea y a veces no (ambos '
        'resultados aparecen en muchas corridas)', () {
      const nope = CardModel(id: 'nope-1', type: CardType.nope);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: [nope]),
        ],
        phase: TurnPhase.nopeWindow,
        pendingAction: const DrawCardAction(playerId: 'p1'),
      );

      var nopedCount = 0;
      var passedCount = 0;
      for (var seed = 0; seed < 200; seed++) {
        final action =
            BotPlayer.decide(state, 'p2', BotConfig.normal, Random(seed));
        if (action == null) {
          passedCount++;
        } else {
          expect(action, isA<NopeAction>());
          nopedCount++;
        }
      }
      expect(nopedCount, greaterThan(0));
      expect(passedCount, greaterThan(0));
    });
  });
}
