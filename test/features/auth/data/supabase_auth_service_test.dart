import 'package:exploding_kittens/features/auth/data/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

User _user({required String id, bool isAnonymous = true}) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      isAnonymous: isAnonymous,
    );

Session _session({required String accessToken, required User user}) =>
    Session(accessToken: accessToken, tokenType: 'bearer', user: user);

void main() {
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
  });
}
