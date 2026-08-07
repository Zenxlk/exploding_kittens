import 'package:exploding_kittens/game_engine/bot/bot_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BotWeights', () {
    test('toJson / fromJson round-trip', () {
      const weights = BotWeights(
        survivalWeight: -6,
        defuseWeight: 1.5,
        escapeCardWeight: 0.8,
        infoWeight: 0.5,
        opponentPressureWeight: -0.3,
      );
      final restored = BotWeights.fromJson(weights.toJson());
      expect(restored, weights);
    });
  });

  group('BotConfig', () {
    test('toJson / fromJson round-trip', () {
      const config = BotConfig(
        weights: BotWeights.standard,
        determinizations: 12,
        temperature: 0.3,
      );
      final restored = BotConfig.fromJson(config.toJson());
      expect(restored, config);
    });

    test(
        'presets easy/normal/hard difieren en determinizations y '
        'temperature, mismos pesos', () {
      expect(BotConfig.easy.weights, BotConfig.hard.weights);
      expect(
        BotConfig.easy.determinizations,
        lessThan(BotConfig.normal.determinizations),
      );
      expect(
        BotConfig.normal.determinizations,
        lessThan(BotConfig.hard.determinizations),
      );
      expect(
        BotConfig.easy.temperature,
        greaterThan(BotConfig.normal.temperature),
      );
      expect(
        BotConfig.normal.temperature,
        greaterThan(BotConfig.hard.temperature),
      );
    });

    test('lookaheadDepth distinto de 1 dispara el assert', () {
      expect(
        () => BotConfig(weights: BotWeights.standard, lookaheadDepth: 2),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
