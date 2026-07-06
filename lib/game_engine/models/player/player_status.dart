enum PlayerStatus {
  active,       // jugando normalmente
  eliminated,   // explotó sin defuse
  winner,       // último superviviente
  disconnected, // perdió conexión (grace period activo)
}
