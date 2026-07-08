import '../models/game/game_state.dart';
import '../models/turn/turn_model.dart';
import '../rules/turn_rules.dart';

/// Gestiona el avance de turno y el encadenamiento de Attack.
abstract final class TurnManager {
  /// Avanza al siguiente jugador. Si Attack encadenó turnos, reduce actionsLeft.
  static GameState advance(GameState state) {
    final attacksLeft = TurnRules.attackTurnsLeft(state);

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
