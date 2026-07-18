import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/player_hand_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PlayerHandWidget', () {
    testWidgets('mano vacía no renderiza ninguna carta', (tester) async {
      await tester.pumpWidget(_wrap(const PlayerHandWidget(hand: [])));

      expect(find.byType(CardWidget), findsNothing);
    });

    testWidgets('renderiza una carta por cada carta de la mano', (
      tester,
    ) async {
      const hand = [
        CardModel(id: 'a', type: CardType.skip),
        CardModel(id: 'b', type: CardType.attack),
        CardModel(id: 'c', type: CardType.nope),
      ];

      await tester.pumpWidget(_wrap(const PlayerHandWidget(hand: hand)));

      expect(find.byType(CardWidget), findsNWidgets(3));
    });

    testWidgets('onCardTap recibe la carta tocada', (tester) async {
      const hand = [
        CardModel(id: 'a', type: CardType.skip),
        CardModel(id: 'b', type: CardType.attack),
      ];
      CardModel? tapped;

      await tester.pumpWidget(
        _wrap(
          PlayerHandWidget(hand: hand, onCardTap: (card) => tapped = card),
        ),
      );

      // La última carta del abanico queda completamente encima y visible.
      await tester.tap(find.byType(CardWidget).last);

      expect(tapped, hand.last);
    });

    testWidgets(
      'al quitar una carta del medio, las que quedan conservan su identidad por id',
      (tester) async {
        const hand = [
          CardModel(id: 'a', type: CardType.skip),
          CardModel(id: 'b', type: CardType.attack),
          CardModel(id: 'c', type: CardType.nope),
        ];
        await tester.pumpWidget(_wrap(const PlayerHandWidget(hand: hand)));

        // Se juega/descarta la carta del medio ('b'): sin key por id,
        // Flutter reutilizaría por índice el State (y su animación de flip
        // en curso) de 'b' para 'c', que pasa a ocupar ese mismo índice.
        const handSinB = [
          CardModel(id: 'a', type: CardType.skip),
          CardModel(id: 'c', type: CardType.nope),
        ];
        await tester.pumpWidget(_wrap(const PlayerHandWidget(hand: handSinB)));

        expect(find.byKey(const ValueKey('a')), findsOneWidget);
        expect(find.byKey(const ValueKey('c')), findsOneWidget);
        expect(find.byKey(const ValueKey('b')), findsNothing);
      },
    );

    testWidgets(
      'arrastrar una carta y soltarla sin un DragTarget que la acepte la '
      'selecciona, igual que un tap',
      (tester) async {
        const hand = [CardModel(id: 'a', type: CardType.skip)];
        CardModel? tapped;

        await tester.pumpWidget(
          _wrap(
            PlayerHandWidget(hand: hand, onCardTap: (card) => tapped = card),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CardWidget)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, -80));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tapped, hand.first);
      },
    );

    testWidgets(
      'soltar una carta sobre un DragTarget que la acepta no dispara '
      'onCardTap',
      (tester) async {
        const hand = [CardModel(id: 'a', type: CardType.skip)];
        CardModel? tapped;
        CardModel? accepted;

        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                PlayerHandWidget(
                    hand: hand, onCardTap: (card) => tapped = card),
                DragTarget<CardModel>(
                  onAcceptWithDetails: (details) => accepted = details.data,
                  builder: (context, candidateData, rejectedData) =>
                      const SizedBox(width: 100, height: 100),
                ),
              ],
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CardWidget)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await gesture
            .moveTo(tester.getCenter(find.byType(DragTarget<CardModel>)));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(accepted, hand.first);
        expect(tapped, isNull);
      },
    );
  });
}
