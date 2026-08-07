import 'package:exploding_kittens/core/errors/exceptions.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:exploding_kittens/game_engine/rules/game_rules.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _state({
  required List<PlayerModel> players,
  TurnPhase phase = TurnPhase.playing,
  CardModel? pendingBomb,
  Object? pendingAction,
  String currentPlayerId = 'p1',
}) {
  return GameState(
    id: 'g1',
    config: const GameConfig(playerCount: 2),
    players: players,
    deck: const DeckModel(drawPile: [], discardPile: []),
    turn: TurnModel(currentPlayerId: currentPlayerId, phase: phase),
    phase: GamePhase.playing,
    pendingBomb: pendingBomb,
    pendingAction: pendingAction,
  );
}

void main() {
  group('GameRules.validate — fase del turno', () {
    test('DrawCardAction es válido en TurnPhase.playing', () {
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
      );
      expect(
        () => GameRules.validate(
          const DrawCardAction(playerId: 'p1'),
          state,
        ),
        returnsNormally,
      );
    });

    test(
      'DrawCardAction se rechaza durante una ventana de Nope abierta — '
      'no debe poder "colarse" y perder la acción pendiente',
      () {
        final state = _state(
          players: const [
            PlayerModel(id: 'p1', name: 'A', hand: []),
            PlayerModel(id: 'p2', name: 'B', hand: []),
          ],
          phase: TurnPhase.nopeWindow,
        );
        expect(
          () => GameRules.validate(
            const DrawCardAction(playerId: 'p1'),
            state,
          ),
          throwsA(isA<InvalidActionException>()),
        );
      },
    );

    test('DrawCardAction se rechaza mientras se resuelve una bomba', () {
      const bomb = CardModel(id: 'bomb-1', type: CardType.explodingKitten);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        phase: TurnPhase.resolving,
        pendingBomb: bomb,
      );
      expect(
        () => GameRules.validate(
          const DrawCardAction(playerId: 'p1'),
          state,
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('PlayCatPairAction se rechaza si ya hay una ventana de Nope abierta',
        () {
      const cat1 = CardModel(id: 'a', type: CardType.tacocat);
      const cat2 = CardModel(id: 'b', type: CardType.tacocat);
      final state = _state(
        players: [
          PlayerModel(id: 'p1', name: 'A', hand: const [cat1, cat2]),
          const PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        phase: TurnPhase.nopeWindow,
      );
      expect(
        () => GameRules.validate(
          const PlayCatPairAction(
            playerId: 'p1',
            cards: [cat1, cat2],
            targetPlayerId: 'p2',
          ),
          state,
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test(
      'DefuseBombAction es válido en TurnPhase.resolving con una bomba '
      'pendiente',
      () {
        const bomb = CardModel(id: 'bomb-1', type: CardType.explodingKitten);
        const defuse = CardModel(id: 'defuse-1', type: CardType.defuse);
        final state = _state(
          players: [
            PlayerModel(id: 'p1', name: 'A', hand: const [defuse]),
            const PlayerModel(id: 'p2', name: 'B', hand: []),
          ],
          phase: TurnPhase.resolving,
          pendingBomb: bomb,
        );
        expect(
          () => GameRules.validate(
            const DefuseBombAction(
              playerId: 'p1',
              defuseCard: defuse,
              insertAtPosition: 0,
            ),
            state,
          ),
          returnsNormally,
        );
      },
    );

    test('DefuseBombAction se rechaza si no hay ninguna bomba pendiente', () {
      const defuse = CardModel(id: 'defuse-1', type: CardType.defuse);
      final state = _state(
        players: [
          PlayerModel(id: 'p1', name: 'A', hand: const [defuse]),
          const PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        phase: TurnPhase.playing,
      );
      expect(
        () => GameRules.validate(
          const DefuseBombAction(
            playerId: 'p1',
            defuseCard: defuse,
            insertAtPosition: 0,
          ),
          state,
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });
  });

  group('GameRules.validate — ChooseCardAction (respuesta de Favor)', () {
    const favorCard = CardModel(id: 'favor-1', type: CardType.favor);
    const givenCard = CardModel(id: 'given-1', type: CardType.skip);

    GameState awaitingChoiceState() => _state(
          players: [
            const PlayerModel(id: 'p1', name: 'A', hand: []),
            PlayerModel(id: 'p2', name: 'B', hand: const [givenCard]),
          ],
          phase: TurnPhase.awaitingCardChoice,
          pendingAction: const PlayFavorAction(
            playerId: 'p1',
            card: favorCard,
            targetPlayerId: 'p2',
          ),
        );

    test(
        'es válido si lo elige el objetivo del Favor pendiente y tiene la '
        'carta', () {
      expect(
        () => GameRules.validate(
          const ChooseCardAction(playerId: 'p2', cardId: 'given-1'),
          awaitingChoiceState(),
        ),
        returnsNormally,
      );
    });

    test('se rechaza si lo intenta elegir alguien que no es el objetivo', () {
      expect(
        () => GameRules.validate(
          const ChooseCardAction(playerId: 'p1', cardId: 'given-1'),
          awaitingChoiceState(),
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('se rechaza si la carta no está en la mano del objetivo', () {
      expect(
        () => GameRules.validate(
          const ChooseCardAction(playerId: 'p2', cardId: 'no-existe'),
          awaitingChoiceState(),
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('se rechaza fuera de TurnPhase.awaitingCardChoice', () {
      final state = _state(
        players: [
          const PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: const [givenCard]),
        ],
        phase: TurnPhase.playing,
        pendingAction: const PlayFavorAction(
          playerId: 'p1',
          card: favorCard,
          targetPlayerId: 'p2',
        ),
      );
      expect(
        () => GameRules.validate(
          const ChooseCardAction(playerId: 'p2', cardId: 'given-1'),
          state,
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('se rechaza si no hay ninguna elección pendiente', () {
      final state = _state(
        players: [
          const PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: const [givenCard]),
        ],
        phase: TurnPhase.awaitingCardChoice,
      );
      expect(
        () => GameRules.validate(
          const ChooseCardAction(playerId: 'p2', cardId: 'given-1'),
          state,
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });
  });

  group('GameRules.validate — ChooseCardAction (trío de gatos)', () {
    const trioCards = [
      CardModel(id: 't1', type: CardType.tacocat),
      CardModel(id: 't2', type: CardType.tacocat),
      CardModel(id: 't3', type: CardType.tacocat),
    ];
    const rivalCard = CardModel(id: 'rival-1', type: CardType.skip);

    GameState awaitingTrioChoiceState() => _state(
          players: [
            const PlayerModel(id: 'p1', name: 'A', hand: []),
            PlayerModel(id: 'p2', name: 'B', hand: const [rivalCard]),
          ],
          phase: TurnPhase.awaitingCardChoice,
          pendingAction: const PlayCatTrioAction(
            playerId: 'p1',
            cards: trioCards,
            targetPlayerId: 'p2',
          ),
        );

    test(
        'es válido si lo elige el actor del trío pendiente y la carta está '
        'en la mano del objetivo', () {
      expect(
        () => GameRules.validate(
          const ChooseCardAction(playerId: 'p1', cardId: 'rival-1'),
          awaitingTrioChoiceState(),
        ),
        returnsNormally,
      );
    });

    test('se rechaza si lo intenta elegir alguien que no es el actor', () {
      expect(
        () => GameRules.validate(
          const ChooseCardAction(playerId: 'p2', cardId: 'rival-1'),
          awaitingTrioChoiceState(),
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('se rechaza si la carta no está en la mano del objetivo', () {
      expect(
        () => GameRules.validate(
          const ChooseCardAction(playerId: 'p1', cardId: 'no-existe'),
          awaitingTrioChoiceState(),
        ),
        throwsA(isA<InvalidActionException>()),
      );
    });
  });

  group('GameRules.legalActions', () {
    test(
        'jugador activo en TurnPhase.playing: robar, jugar carta suelta y '
        'par/trío de gato por cada target vivo', () {
      const attack = CardModel(id: 'atk-1', type: CardType.attack);
      const cat1 = CardModel(id: 'c1', type: CardType.tacocat);
      const cat2 = CardModel(id: 'c2', type: CardType.tacocat);
      const cat3 = CardModel(id: 'c3', type: CardType.tacocat);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: [attack, cat1, cat2, cat3]),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
      );

      final actions = GameRules.legalActions('p1', state);

      expect(actions, contains(const DrawCardAction(playerId: 'p1')));
      expect(
        actions,
        contains(const PlayCardAction(playerId: 'p1', card: attack)),
      );
      expect(
        actions,
        contains(const PlayCatPairAction(
          playerId: 'p1',
          cards: [cat1, cat2],
          targetPlayerId: 'p2',
        )),
      );
      expect(
        actions,
        contains(const PlayCatTrioAction(
          playerId: 'p1',
          cards: [cat1, cat2, cat3],
          targetPlayerId: 'p2',
        )),
      );
      // Ninguna PlayCardAction suelta con una carta de gato: siempre "agujero
      // negro" si se jugara sola (ver comentario de CardRules.canPlay).
      expect(
        actions.whereType<PlayCardAction>().map((a) => a.card.type),
        isNot(contains(CardType.tacocat)),
      );
    });

    test(
        'un jugador que no es el activo no tiene ninguna acción legal en '
        'TurnPhase.playing', () {
      const attack = CardModel(id: 'atk-1', type: CardType.attack);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: [attack]),
        ],
      );
      expect(GameRules.legalActions('p2', state), isEmpty);
    });

    test(
        'ventana de Nope sin Nope en mano: lista vacía (respuesta válida, '
        'no un error)', () {
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        phase: TurnPhase.nopeWindow,
        pendingAction: const DrawCardAction(playerId: 'p1'),
      );
      expect(GameRules.legalActions('p2', state), isEmpty);
    });

    test('ventana de Nope con Nope en mano: exactamente un NopeAction', () {
      const nope = CardModel(id: 'nope-1', type: CardType.nope);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: [nope]),
        ],
        phase: TurnPhase.nopeWindow,
        pendingAction: const DrawCardAction(playerId: 'p1'),
      );
      expect(
        GameRules.legalActions('p2', state),
        [const NopeAction(playerId: 'p2', nopeCard: nope)],
      );
    });

    test('bomba pendiente sin Defuse en mano: lista vacía', () {
      const bomb = CardModel(id: 'bomb-1', type: CardType.explodingKitten);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        phase: TurnPhase.resolving,
        pendingBomb: bomb,
      );
      expect(GameRules.legalActions('p1', state), isEmpty);
    });

    test(
        'bomba pendiente con Defuse: varias posiciones candidatas, todas '
        'DefuseBombAction válidas', () {
      const bomb = CardModel(id: 'bomb-1', type: CardType.explodingKitten);
      const defuse = CardModel(id: 'defuse-1', type: CardType.defuse);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: [defuse]),
          PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        phase: TurnPhase.resolving,
        pendingBomb: bomb,
      );
      final actions = GameRules.legalActions('p1', state);
      expect(actions, isNotEmpty);
      expect(actions.every((a) => a is DefuseBombAction), isTrue);
      final positions =
          actions.map((a) => (a as DefuseBombAction).insertAtPosition);
      expect(
        positions.length,
        positions.toSet().length,
        reason: 'no debería haber posiciones repetidas',
      );
    });

    test(
        'Favor pendiente: el objetivo tiene un ChooseCardAction por cada '
        'carta de su propia mano', () {
      const favorCard = CardModel(id: 'favor-1', type: CardType.favor);
      const given1 = CardModel(id: 'g1', type: CardType.skip);
      const given2 = CardModel(id: 'g2', type: CardType.shuffle);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: [given1, given2]),
        ],
        phase: TurnPhase.awaitingCardChoice,
        pendingAction: const PlayFavorAction(
          playerId: 'p1',
          card: favorCard,
          targetPlayerId: 'p2',
        ),
      );
      expect(
        GameRules.legalActions('p2', state).toSet(),
        {
          const ChooseCardAction(playerId: 'p2', cardId: 'g1'),
          const ChooseCardAction(playerId: 'p2', cardId: 'g2'),
        },
      );
      // El que pidió el Favor no es quien elige.
      expect(GameRules.legalActions('p1', state), isEmpty);
    });

    test(
        'trío de gatos pendiente: el actor tiene un ChooseCardAction por '
        'cada carta de la mano del objetivo (a ciegas)', () {
      const trioCards = [
        CardModel(id: 't1', type: CardType.tacocat),
        CardModel(id: 't2', type: CardType.tacocat),
        CardModel(id: 't3', type: CardType.tacocat),
      ];
      const rival1 = CardModel(id: 'r1', type: CardType.skip);
      const rival2 = CardModel(id: 'r2', type: CardType.attack);
      final state = _state(
        players: const [
          PlayerModel(id: 'p1', name: 'A', hand: []),
          PlayerModel(id: 'p2', name: 'B', hand: [rival1, rival2]),
        ],
        phase: TurnPhase.awaitingCardChoice,
        pendingAction: const PlayCatTrioAction(
          playerId: 'p1',
          cards: trioCards,
          targetPlayerId: 'p2',
        ),
      );
      expect(
        GameRules.legalActions('p1', state).toSet(),
        {
          const ChooseCardAction(playerId: 'p1', cardId: 'r1'),
          const ChooseCardAction(playerId: 'p1', cardId: 'r2'),
        },
      );
      // El dueño de la mano (objetivo) no es quien elige acá.
      expect(GameRules.legalActions('p2', state), isEmpty);
    });

    test('un jugador eliminado nunca tiene acciones legales', () {
      const attack = CardModel(id: 'atk-1', type: CardType.attack);
      final state = _state(
        players: [
          PlayerModel(
            id: 'p1',
            name: 'A',
            hand: const [attack],
            status: PlayerStatus.eliminated,
          ),
          const PlayerModel(id: 'p2', name: 'B', hand: []),
        ],
        currentPlayerId: 'p1',
      );
      expect(GameRules.legalActions('p1', state), isEmpty);
    });
  });
}
