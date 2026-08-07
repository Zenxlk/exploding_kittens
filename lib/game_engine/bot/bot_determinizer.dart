import 'dart:math';

import '../models/card/card_model.dart';
import '../models/game/game_state.dart';

/// Genera una hipótesis internamente consistente de "dónde está cada carta
/// oculta": mismos conteos que `state` (mismo tamaño de mano por rival,
/// mismo largo de mazo), pero con las identidades concretas de la zona
/// oculta (mazo no revelado + manos rivales) re-sorteadas con `rng`.
///
/// Nunca deja pasar la identidad real de una carta rival concreta a
/// `GameStateEvaluator` — es lo que evita que el bot "haga trampa" leyendo
/// información que un jugador real no tendría. Importante: esto es
/// disciplina de **diseño de juego**, no una barrera de seguridad — en LAN
/// el bot corre en el mismo proceso confiable que ya ve `GameState`
/// completo sin restricciones (es el host). Ver `docs/ARCHITECTURE.md`,
/// sección "Motor de bots", para el detalle.
abstract final class Determinizer {
  static GameState sample(GameState state, String observerId, Random rng) {
    final knownIds =
        (state.seeTheFutureCards ?? const []).map((c) => c.id).toSet();

    // Mientras el tope del mazo siga coincidiendo, en orden, con lo que Ver
    // el Futuro reveló, se mantiene fijo (información legítima). En cuanto
    // aparece la primera carta no revelada, el resto es oculto — cubre el
    // caso de robar alguna de las reveladas a mitad de turno sin perder lo
    // que sigue siendo válido.
    var stillKnown = true;
    final visibleTop = <CardModel>[];
    final hiddenTail = <CardModel>[];
    for (final card in state.deck.drawPile) {
      if (stillKnown && knownIds.contains(card.id)) {
        visibleTop.add(card);
      } else {
        stillKnown = false;
        hiddenTail.add(card);
      }
    }

    final pool = <CardModel>[
      ...hiddenTail,
      for (final p in state.players)
        if (p.id != observerId) ...p.hand,
    ]..shuffle(rng);

    var cursor = 0;
    List<CardModel> take(int n) {
      final slice = pool.sublist(cursor, cursor + n);
      cursor += n;
      return slice;
    }

    final newDrawPile = [...visibleTop, ...take(hiddenTail.length)];
    final newPlayers = state.players.map((p) {
      if (p.id == observerId) return p;
      return p.copyWith(hand: take(p.hand.length));
    }).toList();

    return state.copyWith(
      deck: state.deck.copyWith(drawPile: newDrawPile),
      players: newPlayers,
    );
  }
}
