import 'dart:async';

import 'package:exploding_kittens/features/game/presentation/providers/game_providers.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_result.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:exploding_kittens/network/websocket/websocket_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _state({
  TurnPhase phase = TurnPhase.playing,
  GamePhase gamePhase = GamePhase.playing,
  GameResult? result,
}) {
  return GameState(
    id: 'g1',
    config: const GameConfig(playerCount: 2),
    players: const [PlayerModel(id: 'p1', name: 'A', hand: [])],
    deck: const DeckModel(drawPile: [], discardPile: []),
    turn: TurnModel(currentPlayerId: 'p1', phase: phase),
    phase: gamePhase,
    result: result,
  );
}

void main() {
  group('RemoteGameNotifier', () {
    late StreamController<WsMessage> incoming;
    late List<WsMessage> sent;
    late ProviderContainer container;

    setUp(() {
      incoming = StreamController<WsMessage>.broadcast();
      sent = [];
      container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(incoming.close);
    });

    void listen() {
      container
          .read(remoteGameProvider.notifier)
          .listenTo(incoming.stream, sent.add);
    }

    test('empieza en GameIdle', () {
      expect(container.read(remoteGameProvider), isA<GameIdle>());
    });

    test('un GameStateMessage pasa a GameRunning con el estado recibido',
        () async {
      listen();
      final state = _state();
      incoming.add(GameStateMessage(stateJson: state.toJson()));
      await Future<void>.delayed(Duration.zero);

      final sessionState = container.read(remoteGameProvider);
      expect(sessionState, isA<GameRunning>());
      expect((sessionState as GameRunning).state, state);
    });

    test('un GameStateMessage con partida terminada pasa a GameFinished',
        () async {
      listen();
      const result = GameResult(
        winnerId: 'p1',
        winnerName: 'A',
        totalTurns: 3,
        eliminationOrder: ['p2'],
      );
      final finished = _state(gamePhase: GamePhase.finished, result: result);
      incoming.add(GameStateMessage(stateJson: finished.toJson()));
      await Future<void>.delayed(Duration.zero);

      final sessionState = container.read(remoteGameProvider);
      expect(sessionState, isA<GameFinished>());
      expect((sessionState as GameFinished).result, result);
    });

    test('un GameEventMessage se reexpone en events', () async {
      listen();
      final notifier = container.read(remoteGameProvider.notifier);
      final events = <GameEvent>[];
      notifier.events.listen(events.add);

      final event = CardDrawnEvent(timestamp: DateTime.now(), playerId: 'p1');
      incoming.add(GameEventMessage(eventJson: event.toJson()));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<CardDrawnEvent>());
      expect((events.first as CardDrawnEvent).playerId, 'p1');
    });

    test('un ActionRejectedMessage deja un error transitorio', () async {
      listen();
      incoming.add(GameStateMessage(stateJson: _state().toJson()));
      await Future<void>.delayed(Duration.zero);

      incoming.add(const ActionRejectedMessage(message: 'no es tu turno'));
      await Future<void>.delayed(Duration.zero);

      final sessionState = container.read(remoteGameProvider) as GameRunning;
      expect(sessionState.error, 'no es tu turno');
    });

    test('listenTo es idempotente: no se vuelve a suscribir', () async {
      listen();
      listen(); // segunda llamada no debería duplicar el envío

      const card = CardModel(id: 'a', type: CardType.skip);
      container.read(remoteGameProvider.notifier).playCard('p1', card);

      expect(sent, hasLength(1));
    });

    group('acciones — cada método manda el ActionMessage correcto', () {
      setUp(listen);

      TurnAction lastSentAction() {
        final msg = sent.single as ActionMessage;
        return TurnAction.fromJson(msg.actionJson);
      }

      test('drawCard manda DrawCardAction', () {
        container.read(remoteGameProvider.notifier).drawCard('p1');
        expect(lastSentAction(), isA<DrawCardAction>());
      });

      test('playCard manda PlayCardAction con la carta', () {
        const card = CardModel(id: 'a', type: CardType.skip);
        container.read(remoteGameProvider.notifier).playCard('p1', card);

        final action = lastSentAction() as PlayCardAction;
        expect(action.playerId, 'p1');
        expect(action.card, card);
      });

      test('playFavor manda PlayFavorAction con la carta y el objetivo', () {
        const card = CardModel(id: 'a', type: CardType.favor);
        container.read(remoteGameProvider.notifier).playFavor('p1', card, 'p2');

        final action = lastSentAction() as PlayFavorAction;
        expect(action.card, card);
        expect(action.targetPlayerId, 'p2');
      });

      test('playCatPair manda PlayCatPairAction', () {
        const cards = [
          CardModel(id: 'a', type: CardType.tacocat),
          CardModel(id: 'b', type: CardType.tacocat),
        ];
        container
            .read(remoteGameProvider.notifier)
            .playCatPair('p1', cards, 'p2');

        final action = lastSentAction() as PlayCatPairAction;
        expect(action.cards, cards);
        expect(action.targetPlayerId, 'p2');
      });

      test('playCatTrio manda PlayCatTrioAction', () {
        const cards = [
          CardModel(id: 'a', type: CardType.tacocat),
          CardModel(id: 'b', type: CardType.tacocat),
          CardModel(id: 'c', type: CardType.tacocat),
        ];
        container
            .read(remoteGameProvider.notifier)
            .playCatTrio('p1', cards, 'p2', 'chosen-1');

        final action = lastSentAction() as PlayCatTrioAction;
        expect(action.cards, cards);
        expect(action.chosenCardId, 'chosen-1');
      });

      test('playNope manda NopeAction', () {
        const card = CardModel(id: 'a', type: CardType.nope);
        container.read(remoteGameProvider.notifier).playNope('p1', card);

        final action = lastSentAction() as NopeAction;
        expect(action.nopeCard, card);
      });

      test('defuse manda DefuseBombAction', () {
        const card = CardModel(id: 'a', type: CardType.defuse);
        container.read(remoteGameProvider.notifier).defuse('p1', card, 3);

        final action = lastSentAction() as DefuseBombAction;
        expect(action.defuseCard, card);
        expect(action.insertAtPosition, 3);
      });
    });
  });
}
