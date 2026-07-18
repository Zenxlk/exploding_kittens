import 'dart:async';

import 'package:exploding_kittens/core/constants/layout_constants.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/deck_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/discard_pile_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/game_table_view.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/player_hand_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/players_hud_widget.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
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
  CardModel? pendingBomb,
  int drawPileCount = 0,
}) {
  return GameState(
    id: 'g1',
    config: const GameConfig(playerCount: 2),
    players: players,
    deck: DeckModel(
      drawPile: List.generate(
        drawPileCount,
        (i) => CardModel(id: 'draw$i', type: CardType.skip),
      ),
      discardPile: const [],
    ),
    turn: TurnModel(
      currentPlayerId: currentPlayerId,
      phase: phase,
      nopeChainCount: nopeChainCount,
    ),
    phase: GamePhase.playing,
    seeTheFutureCards: seeTheFutureCards,
    pendingAction: pendingAction,
    pendingBomb: pendingBomb,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// El surface de test por defecto (800×600) es más ancho que alto, así que
// MediaQuery.orientationOf ya lo lee como landscape: sin este fixture los
// tests existentes, escritos para el árbol portrait de GameTableView,
// pasarían a ejercitar la composición landscape en cuanto _buildTable
// bifurca por context.isLandscape.
void _pinPortrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _pinLandscape(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('GameTableView', () {
    testWidgets(
        'muestra la mano del jugador local, no la de quien tiene el '
        'turno', (tester) async {
      _pinPortrait(tester);
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
            onDefuseBomb: (_, __) {},
            onPlayCatTrio: (_, __) {},
            onChooseCard: (_) {},
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
      _pinPortrait(tester);
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
            onDefuseBomb: (_, __) {},
            onPlayCatTrio: (_, __) {},
            onChooseCard: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(DeckWidget));
      expect(draws, 0);
    });

    testWidgets(
      'seleccionar una carta jugable y confirmar invoca onPlaySimpleCard',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pumpAndSettle();

        expect(find.text('Jugar'), findsOneWidget);
        await tester.tap(find.text('Jugar'));
        await tester.pumpAndSettle();

        expect(played, skip);
        expect(find.text('Jugar'), findsNothing);
      },
    );

    testWidgets(
      'una carta sin soporte todavía deja el botón Jugar deshabilitado',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Esta carta no se juega así — toca el mazo para robar y pasar '
            'el turno',
          ),
          findsOneWidget,
        );
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'una sola carta de gato pide otra igual para formar el par',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Un gato solo no se puede jugar: toca otra carta igual para '
            'formar un par, o toca el mazo para robar y pasar el turno',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'seleccionar Favor y un objetivo invoca onPlayFavor',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pumpAndSettle();
        expect(find.text('Elegir objetivo'), findsOneWidget);

        await tester.tap(find.text('Elegir objetivo'));
        await tester.pumpAndSettle();
        final targetButton = find.widgetWithText(OutlinedButton, 'Beto');
        expect(targetButton, findsOneWidget);

        await tester.tap(targetButton);
        await tester.pumpAndSettle();

        expect(playedCard, favor);
        expect(targetId, 'rival');
        expect(find.text('Elegir objetivo'), findsNothing);
      },
    );

    testWidgets(
      'seleccionar un par de gatos y un objetivo invoca onPlayCatPair',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CardWidget).last);
        await tester.pumpAndSettle();

        expect(find.text('Elegir objetivo'), findsOneWidget);
        await tester.tap(find.text('Elegir objetivo'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Beto'));
        await tester.pumpAndSettle();

        expect(playedCards, [tacoA, tacoB]);
        expect(targetId, 'rival');
      },
    );

    testWidgets(
      'al objetivo de un Favor pendiente le aparece el selector de carta '
      'para elegir cuál entregar',
      (tester) async {
        _pinPortrait(tester);
        const cardA = CardModel(id: 'a', type: CardType.skip);
        const cardB = CardModel(id: 'b', type: CardType.attack);
        const target = PlayerModel(
          id: 'me',
          name: 'Ana',
          hand: [cardA, cardB],
        );
        const asker = PlayerModel(id: 'asker', name: 'Beto', hand: []);
        String? chosenId;

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [asker, target],
                currentPlayerId: 'asker',
                phase: TurnPhase.awaitingCardChoice,
                pendingAction: const PlayFavorAction(
                  playerId: 'asker',
                  card: CardModel(id: 'favor-1', type: CardType.favor),
                  targetPlayerId: 'me',
                ),
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (id) => chosenId = id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elegí una carta para darle a Beto'), findsOneWidget);

        await tester.tap(find.byType(CardWidget).last);
        await tester.pumpAndSettle();

        expect(chosenId, 'b');
      },
    );

    testWidgets(
      'a quien no es el objetivo de un Favor pendiente no le aparece el '
      'selector de carta',
      (tester) async {
        _pinPortrait(tester);
        const target = PlayerModel(id: 'other', name: 'Ana', hand: []);
        const asker = PlayerModel(id: 'me', name: 'Beto', hand: []);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [asker, target],
                currentPlayerId: 'me',
                phase: TurnPhase.awaitingCardChoice,
                pendingAction: const PlayFavorAction(
                  playerId: 'me',
                  card: CardModel(id: 'favor-1', type: CardType.favor),
                  targetPlayerId: 'other',
                ),
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Elegí una carta'), findsNothing);
        expect(
          find.textContaining('Esperando a que Ana elija una carta'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'seleccionar un trío de gatos y un objetivo invoca onPlayCatTrio',
      (tester) async {
        _pinPortrait(tester);
        const tacoA = CardModel(id: 'a', type: CardType.tacocat);
        const tacoB = CardModel(id: 'b', type: CardType.tacocat);
        const tacoC = CardModel(id: 'c', type: CardType.tacocat);
        const me = PlayerModel(
          id: 'me',
          name: 'Ana',
          hand: [tacoA, tacoB, tacoC],
        );
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
              onPlayCatPair: (_, __) {},
              onPlayCatTrio: (cards, target) {
                playedCards = cards;
                targetId = target;
              },
              onPlayNope: (_) {},
              onDefuseBomb: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget).at(0));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CardWidget).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CardWidget).at(2));
        await tester.pumpAndSettle();

        expect(find.text('Trío de gatos listo'), findsOneWidget);
        expect(find.text('Elegir objetivo'), findsOneWidget);
        await tester.tap(find.text('Elegir objetivo'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Beto'));
        await tester.pumpAndSettle();

        expect(playedCards, [tacoA, tacoB, tacoC]);
        expect(targetId, 'rival');
      },
    );

    testWidgets(
      'al actor de un trío pendiente le aparece la mano rival boca abajo '
      'para elegir a ciegas',
      (tester) async {
        _pinPortrait(tester);
        const rivalCard = CardModel(id: 'r1', type: CardType.skip);
        const actor = PlayerModel(id: 'me', name: 'Ana', hand: []);
        const rival = PlayerModel(
          id: 'rival',
          name: 'Beto',
          hand: [rivalCard],
        );
        String? chosenId;

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [actor, rival],
                currentPlayerId: 'me',
                phase: TurnPhase.awaitingCardChoice,
                pendingAction: const PlayCatTrioAction(
                  playerId: 'me',
                  cards: [
                    CardModel(id: 't1', type: CardType.tacocat),
                    CardModel(id: 't2', type: CardType.tacocat),
                    CardModel(id: 't3', type: CardType.tacocat),
                  ],
                  targetPlayerId: 'rival',
                ),
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onPlayNope: (_) {},
              onDefuseBomb: (_, __) {},
              onChooseCard: (id) => chosenId = id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Elegí a ciegas una carta de la mano de Beto'),
          findsOneWidget,
        );
        // Boca abajo: el tipo real de la carta (Skip) no debería verse.
        expect(find.text('Skip'), findsNothing);

        await tester.tap(find.byType(CardWidget).last);
        await tester.pumpAndSettle();

        expect(chosenId, 'r1');
      },
    );

    testWidgets(
      'a quien no es el actor de un trío pendiente no le aparece el '
      'selector a ciegas',
      (tester) async {
        _pinPortrait(tester);
        const actor = PlayerModel(id: 'other', name: 'Ana', hand: []);
        const rival = PlayerModel(id: 'me', name: 'Beto', hand: []);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [actor, rival],
                currentPlayerId: 'other',
                phase: TurnPhase.awaitingCardChoice,
                pendingAction: const PlayCatTrioAction(
                  playerId: 'other',
                  cards: [
                    CardModel(id: 't1', type: CardType.tacocat),
                    CardModel(id: 't2', type: CardType.tacocat),
                    CardModel(id: 't3', type: CardType.tacocat),
                  ],
                  targetPlayerId: 'me',
                ),
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onPlayNope: (_) {},
              onDefuseBomb: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Elegí a ciegas'), findsNothing);
        expect(
          find.textContaining('Esperando a que Ana elija una carta'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'cancelar en el selector de objetivo limpia la selección',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );

        await tester.tap(find.byType(CardWidget));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elegir objetivo'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(OutlinedButton, 'Beto'), findsOneWidget);

        await tester.tap(find.text('Cancelar').last);
        await tester.pumpAndSettle();

        expect(find.widgetWithText(OutlinedButton, 'Beto'), findsNothing);
        expect(find.text('Elegir objetivo'), findsNothing);
      },
    );

    testWidgets(
      'muestra el overlay de See the Future cuando el estado lo trae',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ves las próximas 3 cartas'), findsOneWidget);
        expect(find.text('Continuar'), findsOneWidget);
      },
    );

    testWidgets(
      'descartar el overlay lo oculta hasta la próxima revelación',
      (tester) async {
        _pinPortrait(tester);
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
                onDefuseBomb: (_, __) {},
                onPlayCatTrio: (_, __) {},
                onChooseCard: (_) {},
              ),
            );

        await tester.pumpWidget(build(reveal));
        expect(find.text('Continuar'), findsOneWidget);

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.text('Continuar'), findsNothing);

        // La misma revelación (sin pasar por null) sigue descartada.
        await tester.pumpWidget(build(reveal));
        expect(find.text('Continuar'), findsNothing);

        // Una revelación nueva (null → no-null) vuelve a mostrarse.
        await tester.pumpWidget(build(null));
        await tester.pumpWidget(build(reveal));
        await tester.pumpAndSettle();
        expect(find.text('Continuar'), findsOneWidget);
      },
    );

    testWidgets(
      'no muestra el overlay de See the Future a quien no jugó la carta',
      (tester) async {
        _pinPortrait(tester);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
        const other = PlayerModel(id: 'other', name: 'Beto', hand: []);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              // GameState.seeTheFutureCards viaja compartido en la red; el
              // turno es de "other" (quien la jugó), no de "me" — el
              // overlay no debería verse en este dispositivo.
              gameState: _state(
                players: const [me, other],
                currentPlayerId: 'other',
                seeTheFutureCards: const [
                  CardModel(id: 'a', type: CardType.skip),
                ],
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ves las próximas 3 cartas'), findsNothing);
      },
    );

    testWidgets(
      'muestra el overlay de Nope y jugar la carta invoca onPlayNope',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ventana de Nope'), findsOneWidget);
        await tester.tap(find.text('¡Nope!'));
        expect(played, nope);
      },
    );

    testWidgets(
      'el botón de Nope está deshabilitado si no tengo un Nope en mano',
      (tester) async {
        _pinPortrait(tester);
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
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '¡Nope!'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'muestra el overlay de esconder bomba y confirmar invoca onDefuseBomb',
      (tester) async {
        _pinPortrait(tester);
        const defuse = CardModel(id: 'a', type: CardType.defuse);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: [defuse]);
        CardModel? defusedCard;
        int? position;

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [me],
                currentPlayerId: 'me',
                phase: TurnPhase.resolving,
                pendingBomb: const CardModel(
                  id: 'bomb',
                  type: CardType.explodingKitten,
                ),
                drawPileCount: 4,
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
              onDefuseBomb: (card, pos) {
                defusedCard = card;
                position = pos;
              },
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('¿Dónde escondes la bomba?'), findsOneWidget);
        expect(find.text('Abajo del todo'), findsOneWidget);

        await tester.tap(find.text('Esconder bomba'));
        expect(defusedCard, defuse);
        expect(position, 4);
      },
    );

    testWidgets(
      'no soy yo quien resuelve la bomba: no muestro el overlay',
      (tester) async {
        _pinPortrait(tester);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
        const other = PlayerModel(id: 'other', name: 'Beto', hand: []);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState: _state(
                players: const [me, other],
                currentPlayerId: 'other',
                phase: TurnPhase.resolving,
                pendingBomb: const CardModel(
                  id: 'bomb',
                  type: CardType.explodingKitten,
                ),
              ),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
            ),
          ),
        );

        expect(find.text('¿Dónde escondes la bomba?'), findsNothing);
        expect(find.textContaining('esconda la bomba'), findsOneWidget);
      },
    );

    testWidgets(
      'un jugador recién eliminado muestra el overlay de explosión',
      (tester) async {
        _pinPortrait(tester);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
        const otherAlive = PlayerModel(id: 'other', name: 'Beto', hand: []);
        final otherEliminated =
            otherAlive.copyWith(status: PlayerStatus.eliminated);

        Widget build(PlayerModel other) => _wrap(
              GameTableView(
                gameState: _state(players: [me, other], currentPlayerId: 'me'),
                localPlayerId: 'me',
                onDraw: () {},
                onPlaySimpleCard: (_) {},
                onPlayFavor: (_, __) {},
                onPlayCatPair: (_, __) {},
                onPlayNope: (_) {},
                onDefuseBomb: (_, __) {},
                onPlayCatTrio: (_, __) {},
                onChooseCard: (_) {},
              ),
            );

        await tester.pumpWidget(build(otherAlive));
        expect(find.text('¡BOOM!'), findsNothing);

        await tester.pumpWidget(build(otherEliminated));
        await tester.pump();

        expect(find.text('¡BOOM!'), findsOneWidget);
        expect(find.text('Beto explotó'), findsOneWidget);

        // Deja que la animación termine para no dejar un Timer pendiente.
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'el overlay de explosión se cierra solo al terminar la animación',
      (tester) async {
        _pinPortrait(tester);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
        const otherAlive = PlayerModel(id: 'other', name: 'Beto', hand: []);
        final otherEliminated =
            otherAlive.copyWith(status: PlayerStatus.eliminated);

        Widget build(PlayerModel other) => _wrap(
              GameTableView(
                gameState: _state(players: [me, other], currentPlayerId: 'me'),
                localPlayerId: 'me',
                onDraw: () {},
                onPlaySimpleCard: (_) {},
                onPlayFavor: (_, __) {},
                onPlayCatPair: (_, __) {},
                onPlayNope: (_) {},
                onDefuseBomb: (_, __) {},
                onPlayCatTrio: (_, __) {},
                onChooseCard: (_) {},
              ),
            );

        await tester.pumpWidget(build(otherAlive));
        await tester.pumpWidget(build(otherEliminated));
        await tester.pump();
        expect(find.text('¡BOOM!'), findsOneWidget);

        await tester.pumpAndSettle();

        expect(find.text('¡BOOM!'), findsNothing);
      },
    );

    testWidgets(
      'un DeckShuffledEvent por el stream de eventos anima el mazo',
      (tester) async {
        _pinPortrait(tester);
        const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
        const other = PlayerModel(id: 'other', name: 'Beto', hand: []);
        final controller = StreamController<GameEvent>.broadcast();
        addTearDown(controller.close);

        await tester.pumpWidget(
          _wrap(
            GameTableView(
              gameState:
                  _state(players: const [me, other], currentPlayerId: 'me'),
              localPlayerId: 'me',
              onDraw: () {},
              onPlaySimpleCard: (_) {},
              onPlayFavor: (_, __) {},
              onPlayCatPair: (_, __) {},
              onPlayNope: (_) {},
              onDefuseBomb: (_, __) {},
              onPlayCatTrio: (_, __) {},
              onChooseCard: (_) {},
              events: controller.stream,
            ),
          ),
        );

        expect(
          tester.widget<DeckWidget>(find.byType(DeckWidget)).shuffleTrigger,
          0,
        );

        controller.add(DeckShuffledEvent(timestamp: DateTime.now()));
        // La entrega de un StreamController es asíncrona aunque no haya
        // ningún await explícito en el productor: hace falta un pump para
        // que el setState() del listener aterrice antes de inspeccionar.
        await tester.pump();

        expect(
          tester.widget<DeckWidget>(find.byType(DeckWidget)).shuffleTrigger,
          1,
        );

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'un CardDrawnEvent propio marca justDrawn en la carta nueva de la '
      'mano local, no en las que ya tenía',
      (tester) async {
        _pinPortrait(tester);
        const other = PlayerModel(id: 'other', name: 'Beto', hand: []);
        final controller = StreamController<GameEvent>.broadcast();
        addTearDown(controller.close);

        Widget build(List<CardModel> hand) => _wrap(
              GameTableView(
                gameState: _state(
                  players: [
                    PlayerModel(id: 'me', name: 'Ana', hand: hand),
                    other,
                  ],
                  currentPlayerId: 'me',
                ),
                localPlayerId: 'me',
                onDraw: () {},
                onPlaySimpleCard: (_) {},
                onPlayFavor: (_, __) {},
                onPlayCatPair: (_, __) {},
                onPlayNope: (_) {},
                onDefuseBomb: (_, __) {},
                onPlayCatTrio: (_, __) {},
                onChooseCard: (_) {},
                events: controller.stream,
              ),
            );

        const cardA = CardModel(id: 'a', type: CardType.shuffle);
        const cardB = CardModel(id: 'b', type: CardType.skip);

        await tester.pumpWidget(build([cardA]));

        controller
            .add(CardDrawnEvent(playerId: 'me', timestamp: DateTime.now()));
        await tester.pump();

        // La mano recién crece en el siguiente rebuild, no en el evento.
        await tester.pumpWidget(build([cardA, cardB]));

        expect(
          tester.widget<CardWidget>(find.byKey(const ValueKey('a'))).justDrawn,
          isFalse,
        );
        expect(
          tester.widget<CardWidget>(find.byKey(const ValueKey('b'))).justDrawn,
          isTrue,
        );

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'un CardDrawnEvent de otro jugador no marca nada en la mano local',
      (tester) async {
        _pinPortrait(tester);
        final controller = StreamController<GameEvent>.broadcast();
        addTearDown(controller.close);

        Widget build(List<CardModel> hand) => _wrap(
              GameTableView(
                gameState: _state(
                  players: [
                    PlayerModel(id: 'me', name: 'Ana', hand: hand),
                    const PlayerModel(id: 'other', name: 'Beto', hand: []),
                  ],
                  currentPlayerId: 'other',
                ),
                localPlayerId: 'me',
                onDraw: () {},
                onPlaySimpleCard: (_) {},
                onPlayFavor: (_, __) {},
                onPlayCatPair: (_, __) {},
                onPlayNope: (_) {},
                onDefuseBomb: (_, __) {},
                onPlayCatTrio: (_, __) {},
                onChooseCard: (_) {},
                events: controller.stream,
              ),
            );

        const cardA = CardModel(id: 'a', type: CardType.shuffle);
        const cardB = CardModel(id: 'b', type: CardType.skip);

        await tester.pumpWidget(build([cardA]));

        controller
            .add(CardDrawnEvent(playerId: 'other', timestamp: DateTime.now()));
        await tester.pump();

        // Favor/pareja/trío también hacen crecer la mano local sin que sea
        // un robo propio: sin el evento de CardDrawnEvent para 'me', nada
        // debería marcarse como justDrawn.
        await tester.pumpWidget(build([cardA, cardB]));

        expect(
          tester.widget<CardWidget>(find.byKey(const ValueKey('b'))).justDrawn,
          isFalse,
        );
      },
    );
  });

  group('GameTableView — landscape', () {
    testWidgets('sigue mostrando mazo, descarte, HUD y mano sin overflow',
        (tester) async {
      _pinLandscape(tester);
      const skip = CardModel(id: 'a', type: CardType.skip);
      const me = PlayerModel(id: 'me', name: 'Ana', hand: [skip]);
      const other = PlayerModel(id: 'other', name: 'Beto', hand: []);

      await tester.pumpWidget(
        _wrap(
          GameTableView(
            gameState: _state(
              players: const [me, other],
              currentPlayerId: 'me',
              drawPileCount: 5,
            ),
            localPlayerId: 'me',
            onDraw: () {},
            onPlaySimpleCard: (_) {},
            onPlayFavor: (_, __) {},
            onPlayCatPair: (_, __) {},
            onPlayNope: (_) {},
            onDefuseBomb: (_, __) {},
            onPlayCatTrio: (_, __) {},
            onChooseCard: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PlayersHudWidget), findsOneWidget);
      expect(find.byType(DeckWidget), findsOneWidget);
      expect(find.byType(DiscardPileWidget), findsOneWidget);
      expect(find.byType(PlayerHandWidget), findsOneWidget);
    });

    testWidgets(
        'tocar una carta jugable y confirmar sigue invocando '
        'onPlaySimpleCard', (tester) async {
      _pinLandscape(tester);
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
            onDefuseBomb: (_, __) {},
            onPlayCatTrio: (_, __) {},
            onChooseCard: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(CardWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jugar'));
      await tester.pumpAndSettle();

      expect(played, skip);
    });

    testWidgets('tocar el mazo sigue invocando onDraw', (tester) async {
      _pinLandscape(tester);
      const me = PlayerModel(id: 'me', name: 'Ana', hand: []);
      var draws = 0;

      await tester.pumpWidget(
        _wrap(
          GameTableView(
            gameState: _state(players: const [me], currentPlayerId: 'me'),
            localPlayerId: 'me',
            onDraw: () => draws++,
            onPlaySimpleCard: (_) {},
            onPlayFavor: (_, __) {},
            onPlayCatPair: (_, __) {},
            onPlayNope: (_) {},
            onDefuseBomb: (_, __) {},
            onPlayCatTrio: (_, __) {},
            onChooseCard: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DeckWidget));
      expect(draws, 1);
    });

    testWidgets('el ancho de carta de la mano usa el valor de landscape',
        (tester) async {
      _pinLandscape(tester);
      const skip = CardModel(id: 'a', type: CardType.skip);
      const me = PlayerModel(id: 'me', name: 'Ana', hand: [skip]);

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
            onDefuseBomb: (_, __) {},
            onPlayCatTrio: (_, __) {},
            onChooseCard: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<CardWidget>(find.byType(CardWidget)).width,
        LayoutConstants.handCardWidthLandscapePhone,
      );
    });
  });
}
