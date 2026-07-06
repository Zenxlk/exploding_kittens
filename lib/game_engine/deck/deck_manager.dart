import 'dart:math';
import '../models/card/card_model.dart';
import '../models/deck/deck_model.dart';

/// Operaciones puras sobre el mazo — no mutan, devuelven un nuevo DeckModel.
abstract final class DeckManager {
  /// Roba la carta de arriba. Lanza StateError si el mazo está vacío.
  static ({DeckModel deck, CardModel drawn}) drawTop(DeckModel deck) {
    if (deck.drawPile.isEmpty) throw StateError('El mazo está vacío');
    final drawn = deck.drawPile.first;
    return (
      deck: deck.copyWith(drawPile: deck.drawPile.skip(1).toList()),
      drawn: drawn,
    );
  }

  /// Inserta una carta en una posición concreta (Defuse → Exploding Kitten).
  static DeckModel insertAt(DeckModel deck, CardModel card, int position) {
    final pile = List<CardModel>.from(deck.drawPile);
    final clamped = position.clamp(0, pile.length);
    pile.insert(clamped, card);
    return deck.copyWith(drawPile: pile);
  }

  /// Descarta la carta en la pila de descarte.
  static DeckModel discard(DeckModel deck, CardModel card) {
    return deck.copyWith(discardPile: [...deck.discardPile, card]);
  }

  /// Baraja el mazo de robo (Shuffle card).
  static DeckModel shuffle(DeckModel deck, [Random? rng]) {
    final pile = List<CardModel>.from(deck.drawPile)..shuffle(rng ?? Random());
    return deck.copyWith(drawPile: pile);
  }

  /// Devuelve las top N cartas sin extraerlas (See the Future).
  static List<CardModel> peekTop(DeckModel deck, int n) =>
      deck.drawPile.take(n).toList();
}
