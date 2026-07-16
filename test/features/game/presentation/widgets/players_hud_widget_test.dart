import 'package:exploding_kittens/features/game/presentation/widgets/players_hud_widget.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PlayersHudWidget', () {
    testWidgets('muestra nombre y cantidad de cartas de cada jugador', (
      tester,
    ) async {
      const players = [
        PlayerModel(
          id: 'p1',
          name: 'Ana',
          hand: [],
        ),
        PlayerModel(
          id: 'p2',
          name: 'Beto',
          hand: [],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          const PlayersHudWidget(players: players, currentPlayerId: 'p1'),
        ),
      );

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
    });

    testWidgets('atenúa a los jugadores eliminados', (tester) async {
      const players = [
        PlayerModel(
          id: 'p1',
          name: 'Ana',
          hand: [],
          status: PlayerStatus.eliminated,
        ),
        PlayerModel(id: 'p2', name: 'Beto', hand: []),
      ];

      await tester.pumpWidget(
        _wrap(
          const PlayersHudWidget(players: players, currentPlayerId: 'p2'),
        ),
      );

      final anaOpacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('Ana'), matching: find.byType(Opacity)),
      );
      final betoOpacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('Beto'), matching: find.byType(Opacity)),
      );
      expect(anaOpacity.opacity, lessThan(1.0));
      expect(betoOpacity.opacity, 1.0);
    });

    testWidgets(
      'muestra "Reconectando…" y el icono de wifi apagado para un jugador '
      'desconectado',
      (tester) async {
        const players = [
          PlayerModel(
            id: 'p1',
            name: 'Ana',
            hand: [],
            status: PlayerStatus.disconnected,
          ),
          PlayerModel(id: 'p2', name: 'Beto', hand: []),
        ];

        await tester.pumpWidget(
          _wrap(
            const PlayersHudWidget(players: players, currentPlayerId: 'p2'),
          ),
        );

        expect(find.text('Reconectando…'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
        // Ana (desconectada) no muestra el contador de cartas, solo el
        // mensaje de reconexión; Beto (activo) sí lo muestra -> un solo
        // icono de carta en total, no dos.
        expect(find.byIcon(Icons.style), findsOneWidget);
      },
    );

    testWidgets(
      'el anillo de turno transiciona con AnimatedContainer al cambiar de jugador',
      (tester) async {
        const players = [
          PlayerModel(id: 'p1', name: 'Ana', hand: []),
          PlayerModel(id: 'p2', name: 'Beto', hand: []),
        ];

        await tester.pumpWidget(
          _wrap(
            const PlayersHudWidget(players: players, currentPlayerId: 'p1'),
          ),
        );

        // CircleAvatar también usa un AnimatedContainer internamente (sin
        // padding); el anillo de turno es el único que fija `padding`.
        List<BoxDecoration> ringDecorations() => tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .where((c) => c.padding != null)
            .map((c) => c.decoration as BoxDecoration)
            .toList();

        expect(ringDecorations()[0].border, isNotNull); // Ana tiene el turno
        expect(ringDecorations()[1].border, isNull); // Beto no

        await tester.pumpWidget(
          _wrap(
            const PlayersHudWidget(players: players, currentPlayerId: 'p2'),
          ),
        );
        // Pump a mitad de la transición (no pumpAndSettle todavía) para
        // confirmar que no lanza mientras el AnimatedContainer interpola.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(ringDecorations()[0].border, isNull); // Ana ya no
        expect(ringDecorations()[1].border, isNotNull); // Beto ahora sí
      },
    );
  });
}
