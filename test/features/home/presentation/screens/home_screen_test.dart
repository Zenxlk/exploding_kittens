import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// HomeScreen navigates via go_router's context.push, so it needs a real
// GoRouter in the tree (not just a Navigator) for the button taps to work.
Widget _wrapWithRouter() {
  final router = GoRouter(
    initialLocation: RouteNames.home,
    routes: [
      GoRoute(path: RouteNames.home, builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: RouteNames.createRoom,
        builder: (_, __) => const Scaffold(body: Text('createRoom-screen')),
      ),
      GoRoute(
        path: RouteNames.joinRoom,
        builder: (_, __) => const Scaffold(body: Text('joinRoom-screen')),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (_, __) => const Scaffold(body: Text('settings-screen')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('HomeScreen', () {
    testWidgets('renders title, main actions and footer', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Crear sala'), findsOneWidget);
      expect(find.text('Unirse a sala'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
      expect(
        find.text('Proyecto de fans · Sin fines comerciales'),
        findsOneWidget,
      );
    });

    testWidgets('tapping "Crear sala" navigates to createRoom route',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear sala'));
      await tester.pumpAndSettle();

      expect(find.text('createRoom-screen'), findsOneWidget);
    });

    testWidgets('tapping "Unirse a sala" navigates to joinRoom route',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unirse a sala'));
      await tester.pumpAndSettle();

      expect(find.text('joinRoom-screen'), findsOneWidget);
    });

    testWidgets('tapping "Ajustes" navigates to settings route',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(find.text('settings-screen'), findsOneWidget);
    });
  });
}
