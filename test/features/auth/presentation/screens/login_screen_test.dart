import 'package:exploding_kittens/features/auth/domain/auth_session.dart';
import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:exploding_kittens/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  final calls = <String>[];
  Object? failWith;

  @override
  Future<AuthSession?> build() async => const AuthSession(
        playerId: 'anon-1',
        accessToken: 'tok',
        isAnonymous: true,
      );

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    calls.add('signInWithPassword:$email:$password');
    if (failWith != null) throw failWith!;
    state = AsyncValue.data(
      AuthSession(
        playerId: 'user-existing',
        accessToken: 'tok2',
        isAnonymous: false,
        email: email,
      ),
    );
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    calls.add('resetPasswordForEmail:$email');
  }
}

Widget _wrapPushed(_FakeAuthSessionNotifier notifier) {
  return ProviderScope(
    overrides: [authSessionProvider.overrideWith(() => notifier)],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('iniciar sesión con éxito vuelve a la pantalla anterior',
      (tester) async {
    final notifier = _FakeAuthSessionNotifier();
    await tester.pumpWidget(_wrapPushed(notifier));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Correo'), 'beto@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), 'contraseña123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(
        notifier.calls, ['signInWithPassword:beto@example.com:contraseña123']);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('credenciales inválidas muestran el error inline y no navegan',
      (tester) async {
    final notifier = _FakeAuthSessionNotifier()
      ..failWith = const AuthException('Invalid login credentials');
    await tester.pumpWidget(_wrapPushed(notifier));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Correo'), 'beto@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), 'mala');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });

  testWidgets(
      '¿Olvidaste tu contraseña? pide un correo y llama a '
      'resetPasswordForEmail', (tester) async {
    final notifier = _FakeAuthSessionNotifier();
    await tester.pumpWidget(_wrapPushed(notifier));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar contraseña'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'ana@example.com');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(notifier.calls, ['resetPasswordForEmail:ana@example.com']);
    expect(
      find.textContaining('Si el correo existe'),
      findsOneWidget,
    );
  });
}
