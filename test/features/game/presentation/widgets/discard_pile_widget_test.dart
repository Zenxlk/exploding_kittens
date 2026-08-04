import 'package:exploding_kittens/features/game/presentation/widgets/discard_pile_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../support/localization_test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: testLocale,
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('DiscardPileWidget', () {
    testWidgets('sin carta descartada muestra un hueco vacío', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const DiscardPileWidget(topCard: null)));

      expect(find.byType(DottedCardSlot), findsOneWidget);
    });

    testWidgets('con carta descartada la muestra boca arriba', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DiscardPileWidget(
            topCard: CardModel(id: 'a', type: CardType.shuffle),
          ),
        ),
      );

      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.byType(DottedCardSlot), findsNothing);
    });

    testWidgets(
      'al cambiar la carta de arriba, transiciona con AnimatedSwitcher',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const DiscardPileWidget(
              topCard: CardModel(id: 'a', type: CardType.shuffle),
            ),
          ),
        );
        expect(find.text('Shuffle'), findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            const DiscardPileWidget(
              topCard: CardModel(id: 'b', type: CardType.skip),
            ),
          ),
        );
        // Pump a mitad de la transición: ambas cartas pueden coexistir un
        // instante (fade-out de la vieja, fade-in de la nueva).
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Shuffle'), findsNothing);
      },
    );
  });
}
