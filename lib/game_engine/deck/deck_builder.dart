import 'dart:math';
import '../../core/constants/game_constants.dart';
import '../models/card/card_model.dart';
import '../models/card/card_type.dart';
import '../models/deck/deck_model.dart';
import '../models/game/game_config.dart';
import '../models/player/player_model.dart';

/// Construye y reparte el mazo según la configuración oficial.
abstract final class DeckBuilder {
  static ({DeckModel deck, List<PlayerModel> players}) build({
    required List<PlayerModel> players,
    required GameConfig config,
    Random? random,
  }) {
    final rng = config.seed != null ? Random(config.seed) : (random ?? Random());
    final n = players.length;

    // 1. Cartas base sin Defuse ni Exploding Kittens
    final cards = <CardModel>[
      ..._repeat(CardType.nope, GameConstants.nopeCount),
      ..._repeat(CardType.attack, GameConstants.attackCount),
      ..._repeat(CardType.skip, GameConstants.skipCount),
      ..._repeat(CardType.favor, GameConstants.favorCount),
      ..._repeat(CardType.shuffle, GameConstants.shuffleCount),
      ..._repeat(CardType.seeTheFuture, GameConstants.seeTheFutureCount),
      ..._repeat(CardType.tacocat, GameConstants.catCardCount),
      ..._repeat(CardType.rainbowRalphingCat, GameConstants.catCardCount),
      ..._repeat(CardType.beardedDragon, GameConstants.catCardCount),
      ..._repeat(CardType.cattermelon, GameConstants.catCardCount),
      ..._repeat(CardType.hairyPotatoCat, GameConstants.catCardCount),
    ]..shuffle(rng);

    // 2. Repartir mano inicial (sin Defuse)
    final updatedPlayers = <PlayerModel>[];
    var remaining = List<CardModel>.from(cards);

    for (final player in players) {
      final hand = remaining.take(GameConstants.initialHandSize).toList();
      remaining = remaining.skip(GameConstants.initialHandSize).toList();

      // Cada jugador recibe 1 Defuse en mano
      final defuse = _makeCard(CardType.defuse);
      updatedPlayers.add(player.copyWith(hand: [...hand, defuse]));
    }

    // 3. Añadir Exploding Kittens al mazo (n-1)
    final bombs = _repeatList(CardType.explodingKitten, n - 1);

    // 4. Añadir Defuses extra al mazo (según reglas oficiales: 2 extra + los que
    //    no se repartieron del pool original)
    final extraDefuses = _repeatList(CardType.defuse, 2);

    final drawPile = [...remaining, ...bombs, ...extraDefuses]..shuffle(rng);

    return (
      deck: DeckModel(drawPile: drawPile, discardPile: const []),
      players: updatedPlayers,
    );
  }

  static List<CardModel> _repeat(CardType type, int count) =>
      List.generate(count, (_) => _makeCard(type));

  static List<CardModel> _repeatList(CardType type, int count) =>
      List.generate(count, (_) => _makeCard(type));

  static int _counter = 0;
  static CardModel _makeCard(CardType type) =>
      CardModel(id: '${type.name}_${_counter++}', type: type);
}
