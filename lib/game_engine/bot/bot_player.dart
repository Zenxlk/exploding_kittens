import 'dart:math';

import 'bot_config.dart';
import 'bot_determinizer.dart';
import 'bot_evaluator.dart';
import '../engine/action_processor.dart';
import '../events/game_event_bus.dart';
import '../models/game/game_state.dart';
import '../models/turn/turn_action.dart';
import '../models/turn/turn_model.dart';
import '../rules/game_rules.dart';

/// Decide qué `TurnAction` juega un bot: para cada candidata legal
/// (`GameRules.legalActions`), promedia su score sobre `config
/// .determinizations` hipótesis de la información oculta (`Determinizer`),
/// y elige con un softmax de temperatura `config.temperature` sobre los
/// scores (0 = siempre la de mayor puntaje; más alto = más aleatorio).
///
/// Devuelve `null` cuando el bot decide legítimamente no hacer nada — el
/// único caso real es una ventana de Nope: tener un Nope en mano es
/// "legal" pero no jugarlo es una decisión válida y distinta (a diferencia
/// de las demás fases, que siempre fuerzan progreso: hasta el candidato más
/// pasivo, robar, está disponible). También devuelve `null` si
/// `GameRules.legalActions` ya viene vacío. El llamador no debe tratar
/// `null` como error: significa "dejar que el timer de la ventana lo
/// resuelva solo", igual que si un jugador humano no reacciona a tiempo.
abstract final class BotPlayer {
  static TurnAction? decide(
    GameState state,
    String playerId,
    BotConfig config,
    Random rng,
  ) {
    final candidates = GameRules.legalActions(playerId, state);
    if (candidates.isEmpty) return null;

    // Trío de gatos a ciegas: el actor no ve la mano del objetivo. Puntuar
    // esto con evaluate() sería trampa real (usaría la identidad concreta
    // de una carta rival), aunque nadie lo vea en pantalla — se elige
    // uniforme al azar, igual que haría un jugador real.
    if (_isBlindCardChoice(state, playerId)) {
      return candidates[rng.nextInt(candidates.length)];
    }

    final options = <TurnAction?>[...candidates];
    if (state.turn.phase == TurnPhase.nopeWindow) {
      options.add(null); // "no nopear" — ver doc de arriba.
    }

    final scored = options.map((action) {
      if (action == null) {
        return (
          action: action,
          score: GameStateEvaluator.evaluate(state, playerId, config.weights),
        );
      }
      var total = 0.0;
      for (var i = 0; i < config.determinizations; i++) {
        final world = Determinizer.sample(state, playerId, rng);
        final resulting = GameEventBus.instance.runMuted(
          () => ActionProcessor.process(action, world),
        );
        total +=
            GameStateEvaluator.evaluate(resulting, playerId, config.weights);
      }
      return (action: action, score: total / config.determinizations);
    }).toList();

    return _pickWithTemperature(scored, config.temperature, rng);
  }

  static bool _isBlindCardChoice(GameState state, String playerId) =>
      switch (state.pendingAction) {
        PlayCatTrioAction(playerId: final actorId) => actorId == playerId,
        _ => false,
      };

  static TurnAction? _pickWithTemperature(
    List<({TurnAction? action, double score})> scored,
    double temperature,
    Random rng,
  ) {
    if (temperature <= 0) {
      return scored.reduce((a, b) => b.score > a.score ? b : a).action;
    }
    final maxScore = scored.map((s) => s.score).reduce(max);
    final weights =
        scored.map((s) => exp((s.score - maxScore) / temperature)).toList();
    final total = weights.reduce((a, b) => a + b);
    var target = rng.nextDouble() * total;
    for (var i = 0; i < scored.length; i++) {
      target -= weights[i];
      if (target <= 0) return scored[i].action;
    }
    return scored.last.action;
  }
}
