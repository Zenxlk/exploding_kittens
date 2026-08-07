import '../models/game/game_state.dart';
import '../models/turn/turn_model.dart';
import '../rules/turn_rules.dart';

/// Gestiona el avance de turno y el encadenamiento de Attack.
abstract final class TurnManager {
  /// Avanza al siguiente jugador. Si Attack encadenó turnos, reduce actionsLeft.
  static GameState advance(GameState state) {
    // Un jugador eliminado no puede "deber" más turnos de Attack: si moría
    // en el primer robo de una cadena de 2+, `attackTurnsLeft` seguía dando
    // >0 y esta función lo dejaba como currentPlayerId para siempre (nadie
    // vivo puede actuar en su nombre, ni hay otro disparador que vuelva a
    // llamar advance) — softlock real, no solo un problema de bots.
    final currentPlayer = state.playerById(state.turn.currentPlayerId);
    final attacksLeft = (currentPlayer?.isAlive ?? false)
        ? TurnRules.attackTurnsLeft(state)
        : 0;

    if (attacksLeft > 0) {
      // El mismo jugador aún tiene turnos por el Attack
      return state.copyWith(
        turn: state.turn.copyWith(
          phase: TurnPhase.playing,
          actionsLeft: attacksLeft,
          nopeChainCount: 0,
        ),
        turnCount: state.turnCount + 1,
        clearPendingAction: true,
        clearSeeTheFuture: true,
      );
    }

    final nextId = TurnRules.nextPlayerId(state);
    return state.copyWith(
      turn: TurnModel(
        currentPlayerId: nextId,
        phase: TurnPhase.playing,
        actionsLeft: 1,
        nopeChainCount: 0,
      ),
      turnCount: state.turnCount + 1,
      clearPendingAction: true,
      clearSeeTheFuture: true,
    );
  }

  /// Abre la ventana de Nope tras jugar una carta.
  static GameState openNopeWindow(GameState state, Object pendingAction) {
    return state.copyWith(
      turn: state.turn.copyWith(phase: TurnPhase.nopeWindow),
      pendingAction: pendingAction,
    );
  }
}
