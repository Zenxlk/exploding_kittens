import 'dart:math';

import 'package:exploding_kittens/game_engine/bot/bot_determinizer.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:flutter_test/flutter_test.dart';

List<CardModel> _cards(String prefix, int n, CardType type) =>
    List.generate(n, (i) => CardModel(id: '$prefix$i', type: type));

GameState _state({
  required List<PlayerModel> players,
  required List<CardModel> drawPile,
  List<CardModel>? seeTheFutureCards,
}) {
  return GameState(
    id: 'g1',
    config: GameConfig(playerCount: players.length),
    players: players,
    deck: DeckModel(drawPile: drawPile, discardPile: const []),
    turn: const TurnModel(currentPlayerId: 'p1', phase: TurnPhase.playing),
    phase: GamePhase.playing,
    seeTheFutureCards: seeTheFutureCards,
  );
}

void main() {
  group('Determinizer.sample', () {
    late GameState state;

    setUp(() {
      state = _state(
        players: [
          PlayerModel(
              id: 'p1', name: 'A', hand: _cards('p1_', 3, CardType.skip)),
          PlayerModel(
              id: 'p2', name: 'B', hand: _cards('p2_', 2, CardType.attack)),
          PlayerModel(
              id: 'p3', name: 'C', hand: _cards('p3_', 4, CardType.favor)),
        ],
        drawPile: _cards('deck_', 10, CardType.shuffle),
      );
    });

    test('mantiene el largo del mazo y el tamaño de mano de cada jugador', () {
      final world = Determinizer.sample(state, 'p1', Random(1));
      expect(world.deck.drawPile.length, state.deck.drawPile.length);
      for (final p in state.players) {
        final worldPlayer = world.playerById(p.id)!;
        expect(worldPlayer.hand.length, p.hand.length);
      }
    });

    test('no toca la mano del observador', () {
      final world = Determinizer.sample(state, 'p1', Random(1));
      expect(world.playerById('p1')!.hand, state.playerById('p1')!.hand);
    });

    test(
        'conserva el mismo conjunto de identidades de carta (nada se '
        'crea ni se pierde)', () {
      final world = Determinizer.sample(state, 'p1', Random(1));

      Set<String> idsOf(GameState s) => {
            ...s.deck.drawPile.map((c) => c.id),
            for (final p in s.players) ...p.hand.map((c) => c.id),
          };

      expect(idsOf(world), idsOf(state));
    });

    test('re-sortea la zona oculta entre corridas con distinta seed', () {
      final worldA = Determinizer.sample(state, 'p1', Random(1));
      final worldB = Determinizer.sample(state, 'p1', Random(2));
      // Extremadamente improbable que dos sorteos independientes den
      // exactamente el mismo mazo con 10 cartas — si esto falla de forma
      // consistente, es señal de que no se está mezclando de verdad.
      expect(worldA.deck.drawPile, isNot(worldB.deck.drawPile));
    });

    test('mantiene fijo el tope conocido por Ver el Futuro, mezcla el resto',
        () {
      final known = state.deck.drawPile.take(3).toList();
      final withFuture = _state(
        players: state.players,
        drawPile: state.deck.drawPile,
        seeTheFutureCards: known,
      );

      final world = Determinizer.sample(withFuture, 'p1', Random(1));
      expect(world.deck.drawPile.take(3).toList(), known);
    });

    test(
        'el objetivo (observerId) puede ser cualquier jugador, no solo '
        'p1', () {
      final world = Determinizer.sample(state, 'p2', Random(1));
      expect(world.playerById('p2')!.hand, state.playerById('p2')!.hand);
    });
  });
}
