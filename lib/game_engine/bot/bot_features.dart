import 'dart:math';

import '../models/card/card_model.dart';
import '../models/card/card_type.dart';
import '../models/game/game_state.dart';

/// Señales numéricas simples extraídas de un `GameState` ya "resuelto" (post
/// determinización), para que `GameStateEvaluator` las combine con
/// `BotWeights`. A propósito solo `double`/`int`/`bool` — nada de tipos Dart
/// específicos — para que la misma tabla de features sea re-describible en
/// el futuro puerto a Go (ver `docs/ARCHITECTURE.md`, sección "Motor de
/// bots").
abstract final class BotFeatures {
  /// Probabilidad de que la próxima carta robada sea un Exploding Kitten,
  /// asumiendo distribución uniforme sobre lo que queda del mazo.
  static double explosionProbability(GameState state) {
    final pile = state.deck.drawPile;
    if (pile.isEmpty) return 0;
    final kittens =
        pile.where((c) => c.type == CardType.explodingKitten).length;
    return kittens / pile.length;
  }

  static int defuseCount(GameState state, String playerId) =>
      _handOf(state, playerId).where((c) => c.type == CardType.defuse).length;

  static int escapeCardCount(GameState state, String playerId) => _handOf(
        state,
        playerId,
      )
          .where((c) => c.type == CardType.skip || c.type == CardType.attack)
          .length;

  /// true si Ver el Futuro reveló que el tope inmediato del mazo NO es una
  /// bomba — información puntual, más allá de la probabilidad genérica.
  static bool hasSafeKnownDraw(GameState state) {
    final known = state.seeTheFutureCards;
    if (known == null || known.isEmpty) return false;
    return known.first.type != CardType.explodingKitten;
  }

  /// Tamaño de mano del rival vivo con menos cartas — proxy de "está más
  /// cerca de quedarse sin recursos para defenderse".
  static int weakestOpponentHandSize(GameState state, String playerId) {
    final rivals = state.alivePlayers.where((p) => p.id != playerId);
    if (rivals.isEmpty) return 0;
    return rivals.map((p) => p.cardCount).reduce(min);
  }

  static List<CardModel> _handOf(GameState state, String playerId) =>
      state.playerById(playerId)?.hand ?? const [];
}
