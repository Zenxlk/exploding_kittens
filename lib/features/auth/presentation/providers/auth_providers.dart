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

  SupabaseAuthService _requireService() {
    final service = ref.read(authServiceProvider);
    if (service == null) {
      throw StateError('Supabase no está configurado');
    }
    return service;
  }

  // Si falla, no toca `state` — deja que la excepción llegue a la
  // pantalla para mostrar el error sin invalidar la sesión (anónima)
  // que ya estaba activa.
  Future<void> signUpAndLinkAnonymous({
    required String email,
    required String password,
  }) async {
    final session = await _requireService()
        .signUpAndLinkAnonymous(email: email, password: password);
    state = AsyncValue.data(session);
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final session = await _requireService()
        .signInWithPassword(email: email, password: password);
    state = AsyncValue.data(session);
  }

  Future<void> resetPasswordForEmail(String email) =>
      _requireService().resetPasswordForEmail(email);

  // Cerrar sesión siempre deja a la app en modo invitado (identidad
  // anónima nueva), nunca sin sesión — mismo criterio que build().
  Future<void> signOut() async {
    final service = _requireService();
    await service.signOut();
    state = AsyncValue.data(await service.signInAnonymously());
  }
}
