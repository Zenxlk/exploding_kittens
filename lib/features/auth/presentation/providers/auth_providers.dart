import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:exploding_kittens/core/config/supabase_config.dart';
import 'package:exploding_kittens/features/auth/data/supabase_auth_service.dart';
import 'package:exploding_kittens/features/auth/domain/auth_session.dart';

// null si no hay Supabase configurado (sin .env) — igual que el backend, la
// ausencia de configuración apaga la feature entera sin ramas especiales
// en el resto del código (lobby_providers.dart cae directo al UUID de
// invitado cuando esto es null).
final authServiceProvider = Provider<SupabaseAuthService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return SupabaseAuthService(Supabase.instance.client);
});

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
        AuthSessionNotifier.new);

class AuthSessionNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final service = ref.watch(authServiceProvider);
    if (service == null) return null; // modo invitado, sin cambios
    return service.currentSession ?? await service.signInAnonymously();
  }
}
