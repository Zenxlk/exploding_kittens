import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
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
  group('CardWidget', () {
    testWidgets('sin assetPath muestra el placeholder de CardVisuals', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CardWidget(type: CardType.skip)));

      expect(find.text('Skip'), findsOneWidget);
      expect(find.byIcon(Icons.fast_forward), findsOneWidget);
    });

    testWidgets('invoca onTap al tocar la carta', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          CardWidget(type: CardType.nope, onTap: () => taps++),
        ),
      );

      await tester.tap(find.byType(CardWidget));
      expect(taps, 1);
    });

    testWidgets('cambiar faceUp anima sin lanzar errores', (tester) async {
      await tester.pumpWidget(
        _wrap(const CardWidget(type: CardType.attack, faceUp: true)),
      );

      await tester.pumpWidget(
        _wrap(const CardWidget(type: CardType.attack, faceUp: false)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CardWidget), findsOneWidget);
    });

    testWidgets('justDrawn anima sin lanzar errores', (tester) async {
      await tester.pumpWidget(
        _wrap(const CardWidget(type: CardType.shuffle, justDrawn: false)),
      );

      await tester.pumpWidget(
        _wrap(const CardWidget(type: CardType.shuffle, justDrawn: true)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CardWidget), findsOneWidget);
    });

    testWidgets(
      'justDrawn e isPlayable juntas animan sin lanzar errores',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CardWidget(
              type: CardType.shuffle,
              justDrawn: false,
              isPlayable: false,
            ),
          ),
        );

        await tester.pumpWidget(
          _wrap(
            const CardWidget(
              type: CardType.shuffle,
              justDrawn: true,
              isPlayable: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CardWidget), findsOneWidget);
      },
    );
  });
}
