import 'package:exploding_kittens/features/auth/data/supabase_auth_service.dart';
import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

User _user({required String id, bool isAnonymous = true, String? email}) =>
    User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      isAnonymous: isAnonymous,
      email: email,
    );

Session _session({required String accessToken, required User user}) =>
    Session(accessToken: accessToken, tokenType: 'bearer', user: user);

void main() {
  setUpAll(() {
    registerFallbackValue(UserAttributes());
  });

  group('authServiceProvider / authSessionProvider', () {
    // Sin .env cargado (flutter test nunca corre main.dart),
    // SupabaseConfig.isConfigured da false — mismo estado que un build sin
    // credenciales reales, no hace falta mockear nada más.
    test('authServiceProvider es null sin Supabase configurado', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(authServiceProvider), isNull);
    });

    test(
        'authSessionProvider resuelve a null (modo invitado) sin Supabase '
        'configurado', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = await container.read(authSessionProvider.future);

      expect(session, isNull);
    });
  });

  group('AuthSessionNotifier — con Supabase configurado (mocktail)', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late ProviderContainer container;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      when(() => client.auth).thenReturn(auth);

      // build() arranca sin sesión activa: currentSession null la primera
      // vez, luego signInAnonymously() la crea — mismo camino que
      // SupabaseAuthService en producción.
      when(() => auth.currentSession).thenReturn(null);
      when(() => auth.signInAnonymously()).thenAnswer(
        (_) async => AuthResponse(
          session: _session(
            accessToken: 'tok-anon',
            user: _user(id: 'anon-1'),
          ),
        ),
      );

      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(SupabaseAuthService(client)),
        ],
      );
      addTearDown(container.dispose);
    });

    test('signUpAndLinkAnonymous actualiza el state con la cuenta vinculada',
        () async {
      await container.read(authSessionProvider.future); // sesión anónima

      final linkedUser =
          _user(id: 'anon-1', isAnonymous: false, email: 'ana@example.com');
      when(() => auth.updateUser(any()))
          .thenAnswer((_) async => UserResponse.fromJson(linkedUser.toJson()));
      when(() => auth.currentSession).thenReturn(
        _session(accessToken: 'tok-anon', user: linkedUser),
      );

      await container.read(authSessionProvider.notifier).signUpAndLinkAnonymous(
            email: 'ana@example.com',
            password: 'hunter22',
          );

      final session = container.read(authSessionProvider).value;
      expect(session?.playerId, 'anon-1');
      expect(session?.isAnonymous, isFalse);
      expect(session?.email, 'ana@example.com');
    });

    test('signInWithPassword reemplaza la sesión anónima por la de la cuenta',
        () async {
      await container.read(authSessionProvider.future); // sesión anónima

      final existingUser =
          _user(id: 'user-existing', isAnonymous: false, email: 'beto@x.com');
      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async => AuthResponse(
          session: _session(accessToken: 'tok-existing', user: existingUser),
        ),
      );

      await container.read(authSessionProvider.notifier).signInWithPassword(
            email: 'beto@x.com',
            password: 'contraseña123',
          );

      final session = container.read(authSessionProvider).value;
      expect(session?.playerId, 'user-existing');
      expect(session?.email, 'beto@x.com');
    });

    test('signOut vuelve a modo invitado con una identidad anónima nueva',
        () async {
      await container.read(authSessionProvider.future); // sesión anónima

      when(() => auth.signOut()).thenAnswer((_) async {});
      when(() => auth.signInAnonymously()).thenAnswer(
        (_) async => AuthResponse(
          session: _session(
            accessToken: 'tok-anon-2',
            user: _user(id: 'anon-2'),
          ),
        ),
      );

      await container.read(authSessionProvider.notifier).signOut();

      final session = container.read(authSessionProvider).value;
      verify(() => auth.signOut()).called(1);
      expect(session?.playerId, 'anon-2');
      expect(session?.isAnonymous, isTrue);
    });

    test('si signInWithPassword falla, el state conserva la sesión previa',
        () async {
      await container.read(authSessionProvider.future); // sesión anónima
      final before = container.read(authSessionProvider).value;

      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(
        const AuthException('Invalid login credentials'),
      );

      await expectLater(
        container.read(authSessionProvider.notifier).signInWithPassword(
              email: 'beto@x.com',
              password: 'incorrecta',
            ),
        throwsA(isA<AuthException>()),
      );

      expect(container.read(authSessionProvider).value, before);
    });
  });
}
