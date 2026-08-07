import 'dart:math';

import 'package:exploding_kittens/game_engine/bot/bot_config.dart';
import 'package:exploding_kittens/game_engine/bot/bot_player.dart';
import 'package:exploding_kittens/game_engine/engine/game_engine.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:exploding_kittens/game_engine/rules/game_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Espeja la lógica que usará `GameNotifier._scheduleBotDecisionIfNeeded`
/// (issue #47) para saber a quién le toca actuar: útil acá como el "motor
/// de turnos" de la simulación, sin depender de Flutter/Riverpod.
String? _nextActorId(GameState state) {
  return switch (state.turn.phase) {
    TurnPhase.playing || TurnPhase.resolving => state.turn.currentPlayerId,
    TurnPhase.nopeWindow => state.alivePlayers
        .where((p) => GameRules.legalActions(p.id, state).isNotEmpty)
        .firstOrNull
        ?.id,
    TurnPhase.awaitingCardChoice => switch (state.pendingAction) {
        PlayFavorAction(:final targetPlayerId) => targetPlayerId,
        PlayCatTrioAction(:final playerId) => playerId,
        _ => null,
      },
    TurnPhase.drawRequired || TurnPhase.ended => null,
  };
}

/// Juega una partida completa bot-vs-bot, devuelve el estado final. Nunca
/// debería lanzar (ninguna acción del bot puede ser inválida, ya que sale
/// de `GameRules.legalActions`) ni quedar trabada indefinidamente.
GameState _playFullGame({
  required int playerCount,
  required int seed,
  int maxSteps = 500,
}) {
  final players = List.generate(
    playerCount,
    (i) => PlayerModel(id: 'p$i', name: 'Bot $i', hand: const [], isBot: true),
  );
  final engine = GameEngine();
  var state = engine.startGame(
    players,
    GameConfig(playerCount: playerCount, seed: seed),
  );
  final rng = Random(seed);
  const config = BotConfig(weights: BotWeights.standard);

  var steps = 0;
  while (state.phase != GamePhase.finished) {
    steps++;
    if (steps > maxSteps) {
      fail('La partida (playerCount=$playerCount, seed=$seed) no terminó '
          'en $maxSteps pasos — posible loop infinito.');
    }

    final actorId = _nextActorId(state);
    if (actorId == null) {
      // Nadie tiene nada legal para hacer en la ventana de Nope: se resuelve
      // sola, igual que haría el timer real.
      state = engine.resolveNopeWindow();
      continue;
    }

    final action = BotPlayer.decide(state, actorId, config, rng);
    if (action == null) {
      state = engine.resolveNopeWindow();
      continue;
    }
    state = engine.apply(action);
  }
  return state;
}

void main() {
  group('Fuzz: partidas bot-vs-bot', () {
    for (final playerCount in [2, 3, 4, 5]) {
      for (final seed in [1, 2, 3, 4, 5]) {
        test(
            'playerCount=$playerCount seed=$seed termina sin excepciones '
            'y con un ganador', () {
          final finalState =
              _playFullGame(playerCount: playerCount, seed: seed);
          expect(finalState.phase, GamePhase.finished);
          expect(finalState.result, isNotNull);
          expect(finalState.result!.winnerId, isNotEmpty);
        });
      }
    }
  });
}
