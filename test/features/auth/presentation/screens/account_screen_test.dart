import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/features/auth/domain/auth_session.dart';
import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:exploding_kittens/features/auth/presentation/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Fake AuthSessionNotifier — mismo patrón que _RecordingLobbyNotifier en
// lobby_screen_test.dart: build() fija el estado inicial, signOut()
// simula lo que el notifier real hace (vuelve a modo invitado) sin tocar
// Supabase de verdad.
class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initial);
  final AuthSession? _initial;
  final calls = <String>[];

  @override
  Future<AuthSession?> build() async => _initial;

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    state = const AsyncValue.data(
      AuthSession(playerId: 'anon-2', accessToken: 'tok2', isAnonymous: true),
    );
  }
}

Widget _wrap(_FakeAuthSessionNotifier notifier) {
  final router = GoRouter(
    initialLocation: RouteNames.account,
    routes: [
      GoRoute(
        path: RouteNames.account,
        builder: (_, __) => const AccountScreen(),
      ),
      GoRoute(
        path: RouteNames.accountSignUp,
        builder: (_, __) => const Scaffold(body: Text('sign-up-screen')),
      ),
      GoRoute(
        path: RouteNames.accountLogin,
        builder: (_, __) => const Scaffold(body: Text('login-screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authSessionProvider.overrideWith(() => notifier)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('AccountScreen — invitado', () {
    testWidgets('muestra las opciones de crear cuenta / iniciar sesión',
        (tester) async {
      final notifier = _FakeAuthSessionNotifier(
        const AuthSession(
          playerId: 'anon-1',
          accessToken: 'tok',
          isAnonymous: true,
        ),
      );
      await tester.pumpWidget(_wrap(notifier));
      await tester.pumpAndSettle();

      expect(find.textContaining('invitado'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('Ya tengo cuenta'), findsOneWidget);
    });

    testWidgets('tocar "Crear cuenta" navega a la pantalla de registro',
        (tester) async {
      final notifier = _FakeAuthSessionNotifier(
        const AuthSession(
          playerId: 'anon-1',
          accessToken: 'tok',
          isAnonymous: true,
        ),
      );
      await tester.pumpWidget(_wrap(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('sign-up-screen'), findsOneWidget);
    });

    testWidgets('tocar "Ya tengo cuenta" navega a la pantalla de login',
        (tester) async {
      final notifier = _FakeAuthSessionNotifier(
        const AuthSession(
          playerId: 'anon-1',
          accessToken: 'tok',
          isAnonymous: true,
        ),
      );
      await tester.pumpWidget(_wrap(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ya tengo cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('login-screen'), findsOneWidget);
    });
  });

  group('AccountScreen — con cuenta vinculada', () {
    testWidgets('muestra el correo y permite cerrar sesión', (tester) async {
      final notifier = _FakeAuthSessionNotifier(
        const AuthSession(
          playerId: 'user-1',
          accessToken: 'tok',
          isAnonymous: false,
          email: 'ana@example.com',
        ),
      );
      await tester.pumpWidget(_wrap(notifier));
      await tester.pumpAndSettle();

      expect(find.text('ana@example.com'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(notifier.calls, ['signOut']);
      // Tras cerrar sesión, vuelve a la vista de invitado con el estado
      // anónimo nuevo que devuelve el fake signOut().
      expect(find.text('Crear cuenta'), findsOneWidget);
    });
  });
}
