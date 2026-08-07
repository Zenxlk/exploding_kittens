import 'bot_config.dart';
import 'bot_features.dart';
import '../models/game/game_state.dart';

/// Heurística ponderada, sin RNG: puntúa qué tan bueno es `state` para
/// `playerId`, combinando `BotFeatures` con `BotWeights`. El muestreo sobre
/// información oculta ya pasó por `Determinizer` antes de llegar acá — este
/// evaluador solo mira el `GameState` concreto que le dan.
abstract final class GameStateEvaluator {
  static double evaluate(
    GameState state,
    String playerId,
    BotWeights weights,
  ) {
    final player = state.playerById(playerId);
    if (player == null || !player.isAlive) return double.negativeInfinity;

    return weights.survivalWeight * BotFeatures.explosionProbability(state) +
        weights.defuseWeight * BotFeatures.defuseCount(state, playerId) +
        weights.escapeCardWeight *
            BotFeatures.escapeCardCount(state, playerId) +
        weights.infoWeight * (BotFeatures.hasSafeKnownDraw(state) ? 1 : 0) +
        weights.opponentPressureWeight *
            BotFeatures.weakestOpponentHandSize(state, playerId);
  }
}
