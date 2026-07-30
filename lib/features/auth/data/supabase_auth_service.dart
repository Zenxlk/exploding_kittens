import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:exploding_kittens/features/auth/domain/auth_session.dart';

/// Envoltorio fino sobre `supabase_flutter` — nada propio de más, solo
/// traduce su modelo de sesión a [AuthSession]. Ver
/// `docs/ARCHITECTURE.md`, sección "Autenticación con Supabase (Fase 7)".
class SupabaseAuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  AuthSession? get currentSession {
    final session = _client.auth.currentSession;
    return session == null ? null : _toAuthSession(session);
  }

  Future<AuthSession> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();
    // signInAnonymously() solo lanza si falla; si vuelve sin lanzar, la API
    // de GoTrue garantiza session no nulo.
    return _toAuthSession(response.session!);
  }

  AuthSession _toAuthSession(Session session) => AuthSession(
        playerId: session.user.id,
        accessToken: session.accessToken,
        isAnonymous: session.user.isAnonymous,
      );
}
