import 'package:exploding_kittens/features/game/presentation/widgets/turn_timer_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../support/localization_test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: testLocale,
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(body: child),
    );

LinearProgressIndicator _progress(WidgetTester tester) =>
    tester.widget(find.byType(LinearProgressIndicator));

void main() {
  group('TurnTimerBar', () {
    testWidgets('muestra el nombre del jugador y arranca en el máximo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TurnTimerBar(
            currentPlayerId: 'p1',
            currentPlayerName: 'Ana',
            duration: Duration(seconds: 10),
          ),
        ),
      );

      expect(find.textContaining('Ana'), findsOneWidget);
      // Arranca llena (todo el tiempo disponible) y se vacía a medida que
      // pasa el turno.
      expect(_progress(tester).value, 1);

      await tester.pumpAndSettle();
    });

    testWidgets('la barra avanza con el tiempo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TurnTimerBar(
            currentPlayerId: 'p1',
            currentPlayerName: 'Ana',
            duration: Duration(seconds: 10),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 5));

      expect(_progress(tester).value, closeTo(0.5, 0.01));

      await tester.pumpAndSettle();
    });

    testWidgets(
      'cambiar de jugador reinicia la cuenta regresiva',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const TurnTimerBar(
              currentPlayerId: 'p1',
              currentPlayerName: 'Ana',
              duration: Duration(seconds: 10),
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 8));
        expect(_progress(tester).value, closeTo(0.2, 0.01));

        await tester.pumpWidget(
          _wrap(
            const TurnTimerBar(
              currentPlayerId: 'p2',
              currentPlayerName: 'Beto',
              duration: Duration(seconds: 10),
            ),
          ),
        );
        // Un pump inmediato tras el rebuild ya debería reflejar el reinicio
        // (barra llena de nuevo), no la continuación del 20% previo.
        await tester.pump();

        expect(_progress(tester).value, greaterThan(0.9));
        expect(find.textContaining('Beto'), findsOneWidget);

        await tester.pumpAndSettle();
      },
    );
  });
}
