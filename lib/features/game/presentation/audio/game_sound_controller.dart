import 'dart:async';

import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/core/constants/asset_paths.dart';
import 'package:exploding_kittens/features/settings/domain/app_settings.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';

/// Efecto de sonido para un [GameEvent], o `null` si no le corresponde
/// ninguno todavía. Función pura, testeable sin widgets ni audio real.
///
/// `PlayerEliminatedEvent` no suena aparte: comparte el mismo clip que
/// `BombTriggeredEvent` (`AssetPaths.soundExplosion`/`soundEliminated`
/// apuntan al mismo archivo, ver asset_paths.dart) y ambos eventos se
/// emiten juntos al eliminar a un jugador — sonarían duplicados si los dos
/// dispararan reproducción.
String? soundAssetFor(GameEvent event) => switch (event) {
      CardDrawnEvent() => AssetPaths.soundCardDraw,
      CardPlayedEvent(:final card) when card.type == CardType.attack =>
        AssetPaths.soundCardAttack,
      CardPlayedEvent() => AssetPaths.soundCardPlay,
      BombTriggeredEvent() => AssetPaths.soundExplosion,
      BombDefusedEvent() => AssetPaths.soundDefuse,
      NopedEvent() => AssetPaths.soundNope,
      DeckShuffledEvent() => AssetPaths.soundCardShuffle,
      GameOverEvent() => AssetPaths.soundWin,
      PlayerEliminatedEvent() ||
      TurnChangedEvent() ||
      SeeTheFutureEvent() =>
        null,
    };

/// Escucha el `Stream<GameEvent>` del motor mientras dura la partida y
/// reproduce el efecto correspondiente a cada evento, respetando
/// `AppSettings.soundEnabled`/`volume` en el momento de sonar (no al
/// suscribirse), para reaccionar a cambios hechos en Ajustes sin tener que
/// recrear la suscripción.
class GameSoundController {
  GameSoundController({
    required Stream<GameEvent> events,
    required IAudioService audioService,
    required AppSettings Function() settings,
  })  : _audioService = audioService,
        _settings = settings {
    _subscription = events.listen(_onEvent);
  }

  final IAudioService _audioService;
  final AppSettings Function() _settings;
  late final StreamSubscription<GameEvent> _subscription;

  void _onEvent(GameEvent event) {
    final assetPath = soundAssetFor(event);
    if (assetPath == null) return;

    final settings = _settings();
    if (!settings.soundEnabled) return;
    _audioService.playEffect(assetPath, volume: settings.volume);
  }

  void dispose() => _subscription.cancel();
}
