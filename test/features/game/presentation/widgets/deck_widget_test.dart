import 'package:exploding_kittens/features/game/presentation/widgets/deck_widget.dart';
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
  group('DeckWidget', () {
    testWidgets('muestra el contador de cartas restantes', (tester) async {
      await tester.pumpWidget(_wrap(const DeckWidget(drawPileCount: 42)));

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('invoca onTap al tocar el mazo', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          DeckWidget(drawPileCount: 10, onTap: () => taps++),
        ),
      );

      await tester.tap(find.byType(DeckWidget));
      expect(taps, 1);
    });

    testWidgets(
      'un bump de shuffleTrigger anima sin lanzar y termina en reposo',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const DeckWidget(drawPileCount: 10, shuffleTrigger: 0)),
        );

        await tester.pumpWidget(
          _wrap(const DeckWidget(drawPileCount: 10, shuffleTrigger: 1)),
        );
        // Pump a mitad de la animación de bamboleo antes de asentarla.
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('10'), findsOneWidget);
      },
    );
  });
}
