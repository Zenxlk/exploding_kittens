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

  // Vincula correo/contraseña a la sesión anónima activa en vez de crear
  // una cuenta nueva — mismo playerId/accessToken de antes, updateUser()
  // solo agrega credenciales a esa identidad (ver gotrue_client.dart:
  // actualiza _currentSession in-place). Distinto de signUp(), que crearía
  // un usuario aparte y perdería el historial ya asociado al anónimo.
  Future<AuthSession> signUpAndLinkAnonymous({
    required String email,
    required String password,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
    return _toAuthSession(_client.auth.currentSession!);
  }

  // A diferencia de signUpAndLinkAnonymous, esto reemplaza la sesión
  // anónima por la de una cuenta ya existente (recupera su historial).
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response =
        await _client.auth.signInWithPassword(email: email, password: password);
    return _toAuthSession(response.session!);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPasswordForEmail(String email) =>
      _client.auth.resetPasswordForEmail(email);

  AuthSession _toAuthSession(Session session) => AuthSession(
        playerId: session.user.id,
        accessToken: session.accessToken,
        isAnonymous: session.user.isAnonymous,
        email: session.user.email,
      );
}
