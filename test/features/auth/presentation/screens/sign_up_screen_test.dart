import 'package:exploding_kittens/features/auth/domain/auth_session.dart';
import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:exploding_kittens/features/auth/presentation/screens/sign_up_screen.dart';
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
  Future<void> signUpAndLinkAnonymous({
    required String email,
    required String password,
  }) async {
    calls.add('signUpAndLinkAnonymous:$email:$password');
    if (failWith != null) throw failWith!;
    state = AsyncValue.data(
      AuthSession(
        playerId: 'anon-1',
        accessToken: 'tok',
        isAnonymous: false,
        email: email,
      ),
    );
  }
}

// SignUpScreen navega con Navigator.pop (no go_router) — se la empuja
// sobre una pantalla marcador para poder comprobar que "Crear cuenta" con
// éxito vuelve atrás.
Widget _wrapPushed(_FakeAuthSessionNotifier notifier) {
  return ProviderScope(
    overrides: [authSessionProvider.overrideWith(() => notifier)],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SignUpScreen(),
                ),
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
  testWidgets(
      'completar y enviar el formulario vincula la cuenta y vuelve '
      'atrás', (tester) async {
    final notifier = _FakeAuthSessionNotifier();
    await tester.pumpWidget(_wrapPushed(notifier));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Correo'), 'ana@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), 'hunter22');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirmar contraseña'), 'hunter22');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(notifier.calls, ['signUpAndLinkAnonymous:ana@example.com:hunter22']);
    // Volvió a la pantalla marcadora tras el éxito.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('contraseñas que no coinciden no llaman al notifier',
      (tester) async {
    final notifier = _FakeAuthSessionNotifier();
    await tester.pumpWidget(_wrapPushed(notifier));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Correo'), 'ana@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), 'hunter22');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirmar contraseña'), 'otra');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pump();

    expect(notifier.calls, isEmpty);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('un AuthException del backend se muestra inline', (tester) async {
    final notifier = _FakeAuthSessionNotifier()
      ..failWith = const AuthException('El correo ya está registrado');
    await tester.pumpWidget(_wrapPushed(notifier));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Correo'), 'ana@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), 'hunter22');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirmar contraseña'), 'hunter22');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('El correo ya está registrado'), findsOneWidget);
    // Se queda en la pantalla de registro, no vuelve atrás.
    expect(find.text('open'), findsNothing);
  });
}
