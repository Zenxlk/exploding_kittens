import 'package:exploding_kittens/features/game/data/online_wire_codec.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:flutter_test/flutter_test.dart';

// JSON de ejemplo tal como lo manda games/explodingkittens/view.go — a mano,
// no generado desde GameState.toJson(), a propósito: es justamente el
// dialecto *distinto* (snake_case, estado redactado) que este codec tiene
// que traducir.
Map<String, dynamic> _viewJson({
  String phase = 'playing',
  String turnPhase = 'playing',
  Map<String, dynamic>? pendingAction,
  bool pendingBomb = false,
  Map<String, dynamic>? result,
}) {
  return {
    'id': 'g1',
    'players': [
      {
        'id': 'p1',
        'name': 'A',
        'handSize': 2,
        'hand': [
          {'id': 'c1', 'type': 'exploding_kitten'},
          {'id': 'c2', 'type': 'see_the_future'},
        ],
        'status': 'active',
      },
      {
        'id': 'p2',
        'name': 'B',
        'handSize': 3,
        // Sin 'hand': el servidor no le manda a p1 la mano de p2.
        'status': 'active',
      },
    ],
    'deckSize': 10,
    'discardTop': {'id': 'd1', 'type': 'rainbow_ralphing_cat'},
    'turn': {
      'currentPlayerId': 'p1',
      'phase': turnPhase,
      'actionsLeft': 1,
      'nopeChainCount': 0,
    },
    'phase': phase,
    'pendingAction': pendingAction,
    'pendingBomb': pendingBomb,
    'turnCount': 4,
    'eliminationOrder': <String>[],
    if (result != null) 'result': result,
  };
}

void main() {
  group('gameStateFromOnlineView', () {
    test('mapea id, deckSize→drawPile, discardTop y turnCount directo', () {
      final state = gameStateFromOnlineView(_viewJson());

      expect(state.id, 'g1');
      expect(state.deck.drawPile, hasLength(10));
      expect(state.deck.topDiscard?.type, CardType.rainbowRalphingCat);
      expect(state.turnCount, 4);
      expect(state.config.playerCount, 2);
    });

    test(
        'la mano propia llega completa; la de un rival, con placeholders '
        'del tamaño de handSize', () {
      final state = gameStateFromOnlineView(_viewJson());

      final me = state.playerById('p1')!;
      expect(me.hand.map((c) => c.type), [
        CardType.explodingKitten,
        CardType.seeTheFuture,
      ]);

      final rival = state.playerById('p2')!;
      expect(rival.cardCount, 3);
      expect(rival.hand.map((c) => c.id).toSet(), hasLength(3)); // ids únicos
    });

    test('convierte CardType multi-palabra de snake_case a camelCase', () {
      final state = gameStateFromOnlineView(_viewJson());
      final me = state.playerById('p1')!;
      expect(me.hand[0].type, CardType.explodingKitten);
      expect(me.hand[1].type, CardType.seeTheFuture);
    });

    test('CardType desconocido del backend lanza FormatException', () {
      final json = _viewJson();
      (json['players'] as List)[0]['hand'][0]['type'] = 'not_a_real_card';
      expect(() => gameStateFromOnlineView(json), throwsFormatException);
    });

    for (final entry in {
      'playing': TurnPhase.playing,
      'nope_window': TurnPhase.nopeWindow,
      'draw_required': TurnPhase.drawRequired,
      'resolving': TurnPhase.resolving,
      'ended': TurnPhase.ended,
      'awaiting_card_choice': TurnPhase.awaitingCardChoice,
    }.entries) {
      test('TurnPhase "${entry.key}" (snake_case) → ${entry.value}', () {
        final state = gameStateFromOnlineView(_viewJson(turnPhase: entry.key));
        expect(state.turn.phase, entry.value);
      });
    }

    test('TurnPhase desconocida del backend lanza FormatException', () {
      expect(
        () => gameStateFromOnlineView(_viewJson(turnPhase: 'not_a_phase')),
        throwsFormatException,
      );
    });

    test('GamePhase "finished" mapea directo (match trivial, sin conversión)',
        () {
      final state = gameStateFromOnlineView(_viewJson(phase: 'finished'));
      expect(state.phase, GamePhase.finished);
    });

    test('pendingBomb en true sintetiza una carta placeholder no-nula', () {
      final state = gameStateFromOnlineView(_viewJson(pendingBomb: true));
      expect(state.pendingBomb, isNotNull);
    });

    test('pendingBomb en false deja pendingBomb null', () {
      final state = gameStateFromOnlineView(_viewJson());
      expect(state.pendingBomb, isNull);
    });

    test('pendingAction null cuando el backend no manda ninguno', () {
      final state = gameStateFromOnlineView(_viewJson());
      expect(state.pendingAction, isNull);
    });

    test(
        'pendingAction play_favor arma un PlayFavorAction con '
        'playerId/targetPlayerId reales', () {
      final state = gameStateFromOnlineView(_viewJson(pendingAction: {
        'type': 'play_favor',
        'playerId': 'p2',
        'targetPlayerId': 'p1',
      }));

      final pending = state.pendingAction;
      expect(pending, isA<PlayFavorAction>());
      expect((pending as PlayFavorAction).playerId, 'p2');
      expect(pending.targetPlayerId, 'p1');
    });

    test(
        'pendingAction play_cat_trio arma un PlayCatTrioAction con 3 '
        'cartas placeholder', () {
      final state = gameStateFromOnlineView(_viewJson(pendingAction: {
        'type': 'play_cat_trio',
        'playerId': 'p1',
        'targetPlayerId': 'p2',
      }));

      final pending = state.pendingAction;
      expect(pending, isA<PlayCatTrioAction>());
      expect((pending as PlayCatTrioAction).cards, hasLength(3));
      expect(pending.targetPlayerId, 'p2');
    });

    test('resultado mapea con GameResult.fromJson tal cual (mismo shape)', () {
      final state = gameStateFromOnlineView(_viewJson(result: {
        'winnerId': 'p1',
        'winnerName': 'A',
        'totalTurns': 7,
        'eliminationOrder': ['p2'],
      }));

      expect(state.result?.winnerId, 'p1');
      expect(state.result?.totalTurns, 7);
    });

    test('status del jugador mapea directo (mismos valores en los dos lados)',
        () {
      final json = _viewJson();
      (json['players'] as List)[1]['status'] = 'disconnected';
      final state = gameStateFromOnlineView(json);
      expect(state.playerById('p2')?.status, PlayerStatus.disconnected);
    });
  });

  group('turnActionToOnlineJson', () {
    test(
        'DrawCardAction y ChooseCardAction pasan sin cambios (sin cartas '
        'embebidas, nada que recodificar)', () {
      expect(
        turnActionToOnlineJson(const DrawCardAction(playerId: 'p1')),
        const DrawCardAction(playerId: 'p1').toJson(),
      );
      expect(
        turnActionToOnlineJson(
          const ChooseCardAction(playerId: 'p1', cardId: 'c1'),
        ),
        const ChooseCardAction(playerId: 'p1', cardId: 'c1').toJson(),
      );
    });

    test('PlayCardAction recodifica el type de la carta a snake_case', () {
      final json = turnActionToOnlineJson(const PlayCardAction(
        playerId: 'p1',
        card: CardModel(id: 'c1', type: CardType.explodingKitten),
      ));

      expect(json['type'], 'play_card');
      expect(json['card'], {'id': 'c1', 'type': 'exploding_kitten'});
    });

    test('PlayFavorAction recodifica la carta y conserva targetPlayerId', () {
      final json = turnActionToOnlineJson(const PlayFavorAction(
        playerId: 'p1',
        card: CardModel(id: 'c1', type: CardType.favor),
        targetPlayerId: 'p2',
      ));

      expect(json['card'], {'id': 'c1', 'type': 'favor'});
      expect(json['targetPlayerId'], 'p2');
    });

    test(
        'PlayCatPairAction/PlayCatTrioAction recodifican cada carta de la '
        'lista', () {
      final json = turnActionToOnlineJson(const PlayCatTrioAction(
        playerId: 'p1',
        cards: [
          CardModel(id: 'a', type: CardType.hairyPotatoCat),
          CardModel(id: 'b', type: CardType.hairyPotatoCat),
          CardModel(id: 'c', type: CardType.hairyPotatoCat),
        ],
        targetPlayerId: 'p2',
      ));

      final cards = json['cards'] as List;
      expect(cards, hasLength(3));
      expect(cards.every((c) => c['type'] == 'hairy_potato_cat'), isTrue);
      expect(cards.map((c) => c['id']), ['a', 'b', 'c']);
    });

    test('DefuseBombAction recodifica defuseCard', () {
      final json = turnActionToOnlineJson(const DefuseBombAction(
        playerId: 'p1',
        defuseCard: CardModel(id: 'd1', type: CardType.defuse),
        insertAtPosition: 2,
      ));

      expect(json['defuseCard'], {'id': 'd1', 'type': 'defuse'});
      expect(json['insertAtPosition'], 2);
    });

    test('NopeAction recodifica nopeCard', () {
      final json = turnActionToOnlineJson(const NopeAction(
        playerId: 'p1',
        nopeCard: CardModel(id: 'n1', type: CardType.nope),
      ));

      expect(json['nopeCard'], {'id': 'n1', 'type': 'nope'});
    });
  });

  group('gameEventFromOnlineWire', () {
    test('card_played recodifica el type de la carta embebida', () {
      final event = gameEventFromOnlineWire(
        {
          'type': 'card_played',
          'timestamp': '2026-08-01T00:00:00.000Z',
          'playerId': 'p1',
          'card': {'id': 'c1', 'type': 'exploding_kitten'},
        },
        localPlayerId: 'p1',
      );

      expect(event, isA<CardPlayedEvent>());
      expect((event as CardPlayedEvent).card.type, CardType.explodingKitten);
    });

    test(
        'see_the_future completa playerId con el jugador local cuando el '
        'backend no lo manda (a propósito, ver comentario en el codec)', () {
      final event = gameEventFromOnlineWire(
        {
          'type': 'see_the_future',
          'timestamp': '2026-08-01T00:00:00.000Z',
          'topCards': [
            {'id': 'c1', 'type': 'exploding_kitten'},
            {'id': 'c2', 'type': 'skip'},
          ],
        },
        localPlayerId: 'p1',
      );

      expect(event, isA<SeeTheFutureEvent>());
      final seeTheFuture = event as SeeTheFutureEvent;
      expect(seeTheFuture.playerId, 'p1');
      expect(
        seeTheFuture.topCards.map((c) => c.type),
        [CardType.explodingKitten, CardType.skip],
      );
    });

    test('bomb_defused completa playerId con el jugador local', () {
      final event = gameEventFromOnlineWire(
        {
          'type': 'bomb_defused',
          'timestamp': '2026-08-01T00:00:00.000Z',
          'insertedAtPosition': 3,
        },
        localPlayerId: 'p2',
      );

      expect(event, isA<BombDefusedEvent>());
      expect((event as BombDefusedEvent).playerId, 'p2');
      expect(event.insertedAtPosition, 3);
    });

    test(
        'eventos sin cartas ni playerId omitido pasan sin cambios '
        '(card_drawn, turn_changed, etc.)', () {
      final event = gameEventFromOnlineWire(
        {
          'type': 'card_drawn',
          'timestamp': '2026-08-01T00:00:00.000Z',
          'playerId': 'p1',
        },
        localPlayerId: 'p1',
      );

      expect(event, isA<CardDrawnEvent>());
      expect((event as CardDrawnEvent).playerId, 'p1');
    });
  });
}
