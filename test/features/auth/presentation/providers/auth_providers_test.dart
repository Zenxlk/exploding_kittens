import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
