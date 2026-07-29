import 'package:exploding_kittens/features/auth/domain/auth_session.dart';
import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedAuthSessionNotifier extends AuthSessionNotifier {
  _FixedAuthSessionNotifier(this._session);
  final AuthSession? _session;

  @override
  Future<AuthSession?> build() async => _session;
}

void main() {
  group('playerIdProvider', () {
    test('genera un id nuevo y lo persiste la primera vez', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final id = await container.read(playerIdProvider.future);
      expect(id, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lobby_player_id'), id);
    });

    test('reutiliza el id ya guardado en vez de generar uno nuevo', () async {
      SharedPreferences.setMockInitialValues({
        'lobby_player_id': 'existing-id',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final id = await container.read(playerIdProvider.future);
      expect(id, 'existing-id');
    });

    test('el mismo id se devuelve entre lecturas dentro de la misma sesión',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = await container.read(playerIdProvider.future);
      final second = await container.read(playerIdProvider.future);
      expect(second, first);
    });

    test(
      'sin sesión autenticada (authSessionProvider en null) cae al UUID '
      'de invitado, comportamiento sin cambios',
      () async {
        SharedPreferences.setMockInitialValues({
          'lobby_player_id': 'guest-id',
        });
        final container = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(
              () => _FixedAuthSessionNotifier(null),
            ),
          ],
        );
        addTearDown(container.dispose);

        final id = await container.read(playerIdProvider.future);
        expect(id, 'guest-id');
      },
    );

    test(
      'con sesión autenticada, prefiere su playerId por sobre el UUID de '
      'invitado guardado',
      () async {
        SharedPreferences.setMockInitialValues({
          'lobby_player_id': 'guest-id',
        });
        const session = AuthSession(
          playerId: 'supabase-user-1',
          accessToken: 'jwt-abc',
          isAnonymous: true,
        );
        final container = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(
              () => _FixedAuthSessionNotifier(session),
            ),
          ],
        );
        addTearDown(container.dispose);

        final id = await container.read(playerIdProvider.future);
        expect(id, 'supabase-user-1');
      },
    );
  });
}
