abstract final class GameConstants {
  static const int minPlayers = 2;
  static const int maxPlayers = 5;

  static const int initialHandSize = 7;
  static const int defuseCardsPerPlayer = 1;

  // Composición del mazo base (sin Defuse ni Exploding Kittens)
  static const int nopeCount = 5;
  static const int attackCount = 4;
  static const int skipCount = 4;
  static const int favorCount = 4;
  static const int shuffleCount = 4;
  static const int seeTheFutureCount = 5;

  // Cartas gatito (cada tipo)
  static const int catCardCount = 4;

  // Tiempo de ventana para jugar Nope (ms)
  static const int nopeWindowMs = 3000;

  // Segundos para reconexión antes de eliminar al jugador
  static const int reconnectTimeoutSeconds = 60;

  // Segundos por turno antes de robar una carta automáticamente
  static const int turnTimeoutSeconds = 30;

  // Pausa antes de que un bot aplique la acción que decidió (issue #47) —
  // sin esto la jugada se siente instantánea y no da tiempo a que la
  // animación de la jugada anterior termine.
  static const int botThinkDelayMs = 700;
}
