/// Sesión autenticada del jugador local, ya traducida del modelo de
/// `supabase_flutter` al vocabulario del resto de la app — nada en
/// `features/lobby`/`network/` necesita conocer tipos de Supabase.
class AuthSession {
  const AuthSession({
    required this.playerId,
    required this.accessToken,
    required this.isAnonymous,
  });

  // "sub" del JWT — mismo valor que espera cards_game_service como
  // playerId al validar el authToken (ver docs/ARCHITECTURE.md).
  final String playerId;
  final String accessToken;
  final bool isAnonymous;
}
