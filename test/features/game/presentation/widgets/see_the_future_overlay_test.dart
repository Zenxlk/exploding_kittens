import 'package:exploding_kittens/features/game/presentation/widgets/see_the_future_overlay.dart';
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
  group('SeeTheFutureOverlay', () {
    testWidgets('muestra las 3 cartas recibidas', (tester) async {
      const cards = [
        CardModel(id: 'a', type: CardType.skip),
        CardModel(id: 'b', type: CardType.attack),
        CardModel(id: 'c', type: CardType.nope),
      ];

      await tester.pumpWidget(
        _wrap(SeeTheFutureOverlay(topCards: cards, onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Attack'), findsOneWidget);
      expect(find.text('Nope'), findsOneWidget);
    });

    testWidgets('invoca onDismiss al tocar Continuar', (tester) async {
      const cards = [CardModel(id: 'a', type: CardType.skip)];
      var dismissed = false;

      await tester.pumpWidget(
        _wrap(
          SeeTheFutureOverlay(
            topCards: cards,
            onDismiss: () => dismissed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuar'));
      expect(dismissed, isTrue);
    });
  });
}
