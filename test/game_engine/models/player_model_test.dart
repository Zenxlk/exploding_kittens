import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerModel', () {
    test('toJson / fromJson round-trip conserva todos los campos', () {
      const player = PlayerModel(
        id: 'p1',
        name: 'Alice',
        hand: [
          CardModel(id: 'nope_1', type: CardType.nope),
          CardModel(id: 'defuse_1', type: CardType.defuse),
        ],
        status: PlayerStatus.disconnected,
        isHost: true,
        isBot: true,
      );

      final restored = PlayerModel.fromJson(player.toJson());
      expect(restored, equals(player));
    });

    test('fromJson maneja mano vacía y valores por defecto', () {
      const player = PlayerModel(id: 'p2', name: 'Bob', hand: []);
      final restored = PlayerModel.fromJson(player.toJson());
      expect(restored, equals(player));
      expect(restored.status, PlayerStatus.active);
      expect(restored.isHost, isFalse);
      expect(restored.isBot, isFalse);
    });

    test('fromJson tolera JSON sin isBot (compatibilidad hacia atrás)', () {
      const player = PlayerModel(id: 'p3', name: 'Carol', hand: []);
      final json = player.toJson()..remove('isBot');
      final restored = PlayerModel.fromJson(json);
      expect(restored.isBot, isFalse);
    });

    test('copyWith actualiza isBot de forma independiente', () {
      const player = PlayerModel(id: 'p4', name: 'Dave', hand: []);
      final bot = player.copyWith(isBot: true);
      expect(bot.isBot, isTrue);
      expect(bot.id, player.id);
      expect(bot.name, player.name);
    });
  });
}
