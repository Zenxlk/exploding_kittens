import 'dart:async';

import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/core/constants/asset_paths.dart';
import 'package:exploding_kittens/features/game/presentation/audio/game_sound_controller.dart';
import 'package:exploding_kittens/features/settings/domain/app_settings.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAudioService implements IAudioService {
  final List<(String, double)> effectsPlayed = [];

  @override
  Future<void> playEffect(String assetPath, {required double volume}) async {
    effectsPlayed.add((assetPath, volume));
  }

  @override
  Future<void> playMusic(
    String assetPath, {
    required bool enabled,
    required double volume,
  }) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> dispose() async {}
}

final _now = DateTime(2026);

void main() {
  group('soundAssetFor', () {
    test('mapea cada evento a su efecto, o null si no le corresponde ninguno',
        () {
      expect(
        soundAssetFor(CardDrawnEvent(timestamp: _now, playerId: 'p1')),
        AssetPaths.soundCardDraw,
      );
      expect(
        soundAssetFor(
          CardPlayedEvent(
            timestamp: _now,
            playerId: 'p1',
            card: const CardModel(id: 'a', type: CardType.skip),
          ),
        ),
        AssetPaths.soundCardPlay,
      );
      expect(
        soundAssetFor(
          CardPlayedEvent(
            timestamp: _now,
            playerId: 'p1',
            card: const CardModel(id: 'a', type: CardType.attack),
          ),
        ),
        AssetPaths.soundCardAttack,
      );
      expect(
        soundAssetFor(BombTriggeredEvent(timestamp: _now, playerId: 'p1')),
        AssetPaths.soundExplosion,
      );
      expect(
        soundAssetFor(
          BombDefusedEvent(
            timestamp: _now,
            playerId: 'p1',
            insertedAtPosition: 0,
          ),
        ),
        AssetPaths.soundDefuse,
      );
      expect(
        soundAssetFor(
            NopedEvent(timestamp: _now, playerId: 'p1', chainCount: 1)),
        AssetPaths.soundNope,
      );
      expect(
        soundAssetFor(DeckShuffledEvent(timestamp: _now)),
        AssetPaths.soundCardShuffle,
      );
      expect(
        soundAssetFor(
          GameOverEvent(timestamp: _now, winnerId: 'p1', winnerName: 'Ana'),
        ),
        AssetPaths.soundWin,
      );
      // No suena aparte: comparte el momento con BombTriggeredEvent, que ya
      // reprodujo la explosión.
      expect(
        soundAssetFor(
          PlayerEliminatedEvent(
            timestamp: _now,
            playerId: 'p1',
            playerName: 'Ana',
          ),
        ),
        isNull,
      );
      expect(
        soundAssetFor(
          TurnChangedEvent(timestamp: _now, nextPlayerId: 'p2', turnCount: 1),
        ),
        isNull,
      );
      expect(
        soundAssetFor(
          SeeTheFutureEvent(
              timestamp: _now, playerId: 'p1', topCards: const []),
        ),
        isNull,
      );
    });
  });

  group('GameSoundController', () {
    test('reproduce el efecto correspondiente respetando soundEnabled/volume',
        () async {
      final controller = StreamController<GameEvent>();
      final audio = _RecordingAudioService();
      const settings = AppSettings(soundEnabled: true, volume: 0.5);

      final sound = GameSoundController(
        events: controller.stream,
        audioService: audio,
        settings: () => settings,
      );

      controller
          .add(NopedEvent(timestamp: _now, playerId: 'p1', chainCount: 1));
      await Future<void>.delayed(Duration.zero);

      expect(audio.effectsPlayed, [(AssetPaths.soundNope, 0.5)]);

      sound.dispose();
      await controller.close();
    });

    test('no reproduce nada si soundEnabled es falso', () async {
      final controller = StreamController<GameEvent>();
      final audio = _RecordingAudioService();
      const settings = AppSettings(soundEnabled: false);

      final sound = GameSoundController(
        events: controller.stream,
        audioService: audio,
        settings: () => settings,
      );

      controller
          .add(NopedEvent(timestamp: _now, playerId: 'p1', chainCount: 1));
      await Future<void>.delayed(Duration.zero);

      expect(audio.effectsPlayed, isEmpty);

      sound.dispose();
      await controller.close();
    });

    test('ignora eventos sin efecto mapeado', () async {
      final controller = StreamController<GameEvent>();
      final audio = _RecordingAudioService();

      final sound = GameSoundController(
        events: controller.stream,
        audioService: audio,
        settings: () => const AppSettings(),
      );

      controller.add(
        TurnChangedEvent(timestamp: _now, nextPlayerId: 'p2', turnCount: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(audio.effectsPlayed, isEmpty);

      sound.dispose();
      await controller.close();
    });

    test('dispose cancela la suscripción: eventos posteriores no suenan',
        () async {
      final controller = StreamController<GameEvent>();
      final audio = _RecordingAudioService();

      final sound = GameSoundController(
        events: controller.stream,
        audioService: audio,
        settings: () => const AppSettings(),
      );
      sound.dispose();

      controller
          .add(NopedEvent(timestamp: _now, playerId: 'p1', chainCount: 1));
      await Future<void>.delayed(Duration.zero);

      expect(audio.effectsPlayed, isEmpty);
      await controller.close();
    });
  });
}
