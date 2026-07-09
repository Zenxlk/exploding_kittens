import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/deck_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/game_table_view.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _state({
  required List<PlayerModel> players,
  required String currentPlayerId,
  TurnPhase phase = TurnPhase.playing,
  int nopeChainCount = 0,
  List<CardModel>? seeTheFutureCards,
  Object? pendingAction,
}) {
  return GameState(
    id: 'g1',
    config: const GameConfig(playerCount: 2),
    players: players,
    deck: const DeckModel(drawPile: [], discardPile: []),
    turn: TurnModel(
      currentPlayerId: currentPlayerId,
      phase: phase,
      nopeChainCount: nopeChainCount,
    ),
    phase: GamePhase.playing,
    seeTheFutureCards: seeTheFutureCards,
    pendingAction: pendingAction,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('GameTableView', () {
    testWidgets(
        'muestra la mano del jugador local, no la de quien tiene el '
        'turno', (tester) async {
      const me = PlayerModel(
        id: 'me',
        name: 'Ana',
        hand: [CardModel(id: 'a', type: CardType.skip)],
      );
      const other = PlayerModel(
        id: 'other',
        name: 'Beto',
        hand: [CardModel(id: 'b', type: CardType.attack)],
      );

      await tester.pumpWidget(
        _wrap(
          GameTableView(
            gameState: _state(
              players: const [me, other],
              currentPlayerId: 'other',
            ),
            localPlayerId: 'me',
            onDraw: () {},
            onPlaySimpleCard: (_) {},
            onPlayFavor: (_, __) {},
            onPlayCatPair: (_, __) {},
            onPlayNope: (_) {},
          ),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Attack'), findsNothing);
      expect(find.textContaining('Turno de Beto'), findsOneWidget);
    });

    testWidgets('el mazo no responde al tap si no es mi turno', (
      tester,
    ) async {
      const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
      const other = PlayerModel(id: 'other', name: 'Beto', hand: []);
      var draws = 0;

      await tester.pumpWidget(
        _wrap(
          GameTableView(
            gameState: _state(
              players: const [me, other],
              currentPlayerId: 'other',
            ),
            localPlayerId: 'me',
            onDraw: () => draws++,
            onPlaySimpleCard: (_) {},
            onPlayFavor: (_, __) {},
            onPlayCatPair: (_, __) {},
            onPlayNope: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(DeckWidget));
      expect(draws, 0);
    });

    testWidgets(
      'seleccionar una carta jugable y confirmar invoca onPlaySimpleCard',
      (tester) async {
        const skip = CardModel(id: 'a', type: CardType.skip);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: [skip]);
        CardModel? played;

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(players: const [me], currentPlayerId: 'me'),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (card) => played = card,
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pump();

        expect(find.text('Jugar'), findsOneWidget);
        await tester.tap(find.text('Jugar'));
        await tester.pump();

        expect(played, skip);
        expect(find.text('Jugar'), findsNothing);
      },
    );

    testWidgets(
      'una carta sin soporte todavía deja el botón Jugar deshabilitado',
      (tester) async {
        const nope = CardModel(id: 'a', type: CardType.nope);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: [nope]);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(players: const [me], currentPlayerId: 'me'),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pump();

        expect(
          find.text('Esta carta se juega en otro momento'),
          findsOneWidget,
        );
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'una sola carta de gato pide otra igual para formar el par',
      (tester) async {
        const taco = CardModel(id: 'a', type: CardType.tacocat);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: [taco]);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(players: const [me], currentPlayerId: 'me'),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pump();

        expect(
          find.text('Toca otra carta del mismo tipo para formar un par'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'seleccionar Favor y un objetivo invoca onPlayFavor',
      (tester) async {
        const favor = CardModel(id: 'a', type: CardType.favor);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: [favor]);
        const rival = PlayerModel(id: 'rival', name: 'Beto', hand: []);
        CardModel? playedCard;
        String? targetId;

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [me, rival],
                currentPlayerId: 'me',
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (card, target) {
                playedCard = card;
                targetId = target;
              },
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pump();
        expect(find.text('Elegir objetivo'), findsOneWidget);

        await tester.tap(find.text('Elegir objetivo'));
        await tester.pump();
        final targetButton = find.widgetWithText(OutlinedButton, 'Beto');
        expect(targetButton, findsOneWidget);

        await tester.tap(targetButton);
        await tester.pump();

        expect(playedCard, favor);
        expect(targetId, 'rival');
        expect(find.text('Elegir objetivo'), findsNothing);
      },
    );

    testWidgets(
      'seleccionar un par de gatos y un objetivo invoca onPlayCatPair',
      (tester) async {
        const tacoA = CardModel(id: 'a', type: CardType.tacocat);
        const tacoB = CardModel(id: 'b', type: CardType.tacocat);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: [tacoA, tacoB]);
        const rival = PlayerModel(id: 'rival', name: 'Beto', hand: []);
        List<CardModel>? playedCards;
        String? targetId;

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [me, rival],
                currentPlayerId: 'me',
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (cards, target) {
                playedCards = cards;
                targetId = target;
              },
              onPlayNope: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget).first);
        await tester.pump();
        await tester.tap(find.byType(CardWidget).last);
        await tester.pump();

        expect(find.text('Elegir objetivo'), findsOneWidget);
        await tester.tap(find.text('Elegir objetivo'));
        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Beto'));
        await tester.pump();

        expect(playedCards, [tacoA, tacoB]);
        expect(targetId, 'rival');
      },
    );

    testWidgets(
      'cancelar en el selector de objetivo limpia la selección',
      (tester) async {
        const favor = CardModel(id: 'a', type: CardType.favor);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: [favor]);
        const rival = PlayerModel(id: 'rival', name: 'Beto', hand: []);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [me, rival],
                currentPlayerId: 'me',
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pump();
        await tester.tap(find.text('Elegir objetivo'));
        await tester.pump();
        expect(find.widgetWithText(OutlinedButton, 'Beto'), findsOneWidget);

        await tester.tap(find.text('Cancelar').last);
        await tester.pump();

        expect(find.widgetWithText(OutlinedButton, 'Beto'), findsNothing);
        expect(find.text('Elegir objetivo'), findsNothing);
      },
    );

    testWidgets(
      'muestra el overlay de See the Future cuando el estado lo trae',
      (tester) async {
        const me = PlayerModel(id: 'me', name: 'Ana', hand: []);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [me],
                currentPlayerId: 'me',
                seeTheFutureCards: const [
                  CardModel(id: 'a', type: CardType.skip),
                  CardModel(id: 'b', type: CardType.attack),
                  CardModel(id: 'c', type: CardType.nope),
                ],
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
            ),
          ),
        );

        expect(find.text('Ves las próximas 3 cartas'), findsOneWidget);
        expect(find.text('Continuar'), findsOneWidget);
      },
    );

    testWidgets(
      'descartar el overlay lo oculta hasta la próxima revelación',
      (tester) async {
        const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
        const reveal = [CardModel(id: 'a', type: CardType.skip)];

        Widget build(List<CardModel>? cards) => _wrap(
              GameTableView(
                gameState: _state(
                  players: const [me],
                  currentPlayerId: 'me',
                  seeTheFutureCards: cards,
                ),
                localPlayerId: 'me',
                onDraw: () {},
                onPlaySimpleCard: (_) {},
                onPlayFavor: (_, __) {},
                onPlayCatPair: (_, __) {},
                onPlayNope: (_) {},
              ),
            );

        await tester.pumpWidget(build(reveal));
        expect(find.text('Continuar'), findsOneWidget);

        await tester.tap(find.text('Continuar'));
        await tester.pump();
        expect(find.text('Continuar'), findsNothing);

        // La misma revelación (sin pasar por null) sigue descartada.
        await tester.pumpWidget(build(reveal));
        expect(find.text('Continuar'), findsNothing);

        // Una revelación nueva (null → no-null) vuelve a mostrarse.
        await tester.pumpWidget(build(null));
        await tester.pumpWidget(build(reveal));
        expect(find.text('Continuar'), findsOneWidget);
      },
    );

    testWidgets(
      'muestra el overlay de Nope y jugar la carta invoca onPlayNope',
      (tester) async {
        const nope = CardModel(id: 'a', type: CardType.nope);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: [nope]);
        const other = PlayerModel(id: 'other', name: 'Beto', hand: []);
        CardModel? played;

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [me, other],
                currentPlayerId: 'other',
                phase: TurnPhase.nopeWindow,
                pendingAction: const Object(),
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (card) => played = card,
            ),
          ),
        );

        expect(find.text('Ventana de Nope'), findsOneWidget);
        await tester.tap(find.text('¡Nope!'));
        expect(played, nope);
      },
    );

    testWidgets(
      'el botón de Nope está deshabilitado si no tengo un Nope en mano',
      (tester) async {
        const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
        const other = PlayerModel(id: 'other', name: 'Beto', hand: []);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [me, other],
                currentPlayerId: 'other',
                phase: TurnPhase.nopeWindow,
                pendingAction: const Object(),
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
            ),
          ),
        );

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '¡Nope!'),
        );
        expect(button.onPressed, isNull);
      },
    );
  });
}
