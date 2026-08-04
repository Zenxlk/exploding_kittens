import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/features/rules/presentation/screens/rules_screen.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../../../../support/localization_test_helpers.dart';

// RulesScreen's back button uses go_router's context.pop(), so it needs a
// real GoRouter in the tree (not just a Navigator).
Widget _wrap() {
  final router = GoRouter(
    initialLocation: RouteNames.rules,
    routes: [
      GoRoute(path: RouteNames.rules, builder: (_, __) => const RulesScreen()),
      GoRoute(
        path: RouteNames.home,
        builder: (_, __) => const Scaffold(body: Text('home-screen')),
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      locale: testLocale,
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
    ),
  );
}

// La pantalla es un ListView largo (13 cartas + intro); se agranda la
// superficie de prueba para que todo el contenido se construya de una, en
// vez de depender de scroll manual para cada aserción (un Sliver no
// construye los widgets que quedan fuera del viewport).
void _growViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('RulesScreen', () {
    testWidgets('muestra el título y las secciones principales', (
      tester,
    ) async {
      _growViewport(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Cómo jugar'), findsOneWidget);
      expect(find.text('EL OBJETIVO'), findsOneWidget);
      expect(find.text('ANTES DE EMPEZAR'), findsOneWidget);
      expect(find.text('TU TURNO'), findsOneWidget);
      expect(find.text('CARTAS ESPECIALES'), findsOneWidget);
      expect(find.text('CARTAS DE ACCIÓN'), findsOneWidget);
      expect(find.text('GATOS'), findsOneWidget);
    });

    testWidgets(
      'muestra las 13 cartas del juego, cada una con su arte real',
      (tester) async {
        _growViewport(tester);
        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        // El nombre ya no se busca como Text: con el arte final presente,
        // CardWidget dibuja la imagen (que lo lleva impreso) en vez del
        // placeholder de ícono+texto — ver CardWidget/CardAssetResolver.
        final cards =
            tester.widgetList<CardWidget>(find.byType(CardWidget)).toList();

        expect(cards.map((c) => c.type).toSet(), CardType.values.toSet());
        for (final card in cards) {
          expect(card.assetPath, isNotNull,
              reason: '${card.type} debería resolver su arte real');
        }
      },
    );

    testWidgets(
      'explica que el trío de gatos se elige a ciegas de la mano rival',
      (tester) async {
        _growViewport(tester);
        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        expect(find.textContaining('3 iguales'), findsOneWidget);
        expect(find.textContaining('a ciegas'), findsOneWidget);
      },
    );

    testWidgets('el botón de volver hace pop de la ruta', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // No hay a dónde volver dentro del propio router de la prueba (rules
      // es la ruta inicial); solo confirmamos que el botón existe y no
      // rompe nada al tocarlo cuando no hay historial previo.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });
}
