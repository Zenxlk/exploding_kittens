import 'package:exploding_kittens/features/auth/data/supabase_auth_service.dart';
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

  group('SupabaseAuthService', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late SupabaseAuthService service;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      when(() => client.auth).thenReturn(auth);
      service = SupabaseAuthService(client);
    });

    test('currentSession es null sin sesión activa en GoTrue', () {
      when(() => auth.currentSession).thenReturn(null);

      expect(service.currentSession, isNull);
    });

    test('currentSession traduce la Session de GoTrue a AuthSession', () {
      final user = _user(id: 'user-1');
      when(() => auth.currentSession)
          .thenReturn(_session(accessToken: 'tok-abc', user: user));

      final result = service.currentSession;

      expect(result?.playerId, 'user-1');
      expect(result?.accessToken, 'tok-abc');
      expect(result?.isAnonymous, isTrue);
    });

    test('signInAnonymously traduce la sesión de la respuesta', () async {
      final user = _user(id: 'user-2');
      final session = _session(accessToken: 'tok-new', user: user);
      when(() => auth.signInAnonymously())
          .thenAnswer((_) async => AuthResponse(session: session));

      final result = await service.signInAnonymously();

      expect(result.playerId, 'user-2');
      expect(result.accessToken, 'tok-new');
      expect(result.isAnonymous, isTrue);
    });

    test(
        'signUpAndLinkAnonymous llama updateUser y traduce la sesión '
        'actualizada (misma identidad, ya no anónima)', () async {
      final linkedUser =
          _user(id: 'user-1', isAnonymous: false, email: 'ana@example.com');
      when(() => auth.updateUser(any())).thenAnswer(
        (_) async => UserResponse.fromJson(linkedUser.toJson()),
      );
      when(() => auth.currentSession).thenReturn(
        _session(accessToken: 'tok-abc', user: linkedUser),
      );

      final result = await service.signUpAndLinkAnonymous(
        email: 'ana@example.com',
        password: 'hunter22',
      );

      final captured = verify(() => auth.updateUser(captureAny()))
          .captured
          .single as UserAttributes;
      expect(captured.email, 'ana@example.com');
      expect(captured.password, 'hunter22');
      expect(result.playerId, 'user-1');
      expect(result.isAnonymous, isFalse);
      expect(result.email, 'ana@example.com');
    });

    test('signInWithPassword traduce la sesión de la cuenta existente',
        () async {
      final user =
          _user(id: 'user-3', isAnonymous: false, email: 'beto@example.com');
      final session = _session(accessToken: 'tok-existing', user: user);
      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => AuthResponse(session: session));

      final result = await service.signInWithPassword(
        email: 'beto@example.com',
        password: 'contraseña123',
      );

      expect(result.playerId, 'user-3');
      expect(result.isAnonymous, isFalse);
      expect(result.email, 'beto@example.com');
    });

    test('signOut delega en GoTrue', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      await service.signOut();

      verify(() => auth.signOut()).called(1);
    });

    test('resetPasswordForEmail delega en GoTrue', () async {
      when(() => auth.resetPasswordForEmail(any())).thenAnswer((_) async {});

      await service.resetPasswordForEmail('ana@example.com');

      verify(() => auth.resetPasswordForEmail('ana@example.com')).called(1);
    });
  });
}
