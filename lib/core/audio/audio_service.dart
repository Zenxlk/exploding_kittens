import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:exploding_kittens/core/utils/logger.dart';
import 'i_audio_service.dart';

/// Implementación real de [IAudioService] sobre `audioplayers`. Usa dos
/// reproductores separados (efectos vs. música) porque son independientes:
/// un efecto no debe cortar la música de fondo ni viceversa.
class AudioService implements IAudioService {
  AudioService({AudioPlayer? sfxPlayer, AudioPlayer? musicPlayer})
      : _sfxPlayer = sfxPlayer ?? AudioPlayer(),
        _musicPlayer = musicPlayer ?? AudioPlayer() {
    unawaited(_musicPlayer.setReleaseMode(ReleaseMode.loop));
  }

  final AudioPlayer _sfxPlayer;
  final AudioPlayer _musicPlayer;
  String? _currentMusicAsset;

  @override
  Future<void> playEffect(String assetPath, {required double volume}) async {
    try {
      await _sfxPlayer.play(AssetSource(assetPath), volume: volume);
    } catch (e, stack) {
      AppLogger.warning(
        'No se pudo reproducir el efecto $assetPath',
        tag: 'AudioService',
      );
      AppLogger.error('playEffect falló', error: e, stack: stack);
    }
  }

  @override
  Future<void> playMusic(
    String assetPath, {
    required bool enabled,
    required double volume,
  }) async {
    if (!enabled) {
      await stopMusic();
      return;
    }
    try {
      if (_currentMusicAsset == assetPath) {
        await _musicPlayer.setVolume(volume);
        return;
      }
      _currentMusicAsset = assetPath;
      await _musicPlayer.play(AssetSource(assetPath), volume: volume);
    } catch (e, stack) {
      AppLogger.warning(
        'No se pudo reproducir la música $assetPath',
        tag: 'AudioService',
      );
      AppLogger.error('playMusic falló', error: e, stack: stack);
    }
  }

  @override
  Future<void> stopMusic() async {
    _currentMusicAsset = null;
    try {
      await _musicPlayer.stop();
    } catch (_) {
      // Detener música que ya falló al iniciar no es un error a reportar.
    }
  }

  @override
  Future<void> pauseMusic() async {
    try {
      await _musicPlayer.pause();
    } catch (_) {
      // Pausar música que ya falló al iniciar no es un error a reportar.
    }
  }

  @override
  Future<void> resumeMusic() async {
    if (_currentMusicAsset == null) return;
    try {
      await _musicPlayer.resume();
    } catch (_) {
      // Reanudar música que ya falló al iniciar no es un error a reportar.
    }
  }

  @override
  Future<void> dispose() async {
    await _sfxPlayer.dispose();
    await _musicPlayer.dispose();
  }
}

/// Servicio de audio compartido por toda la app: un solo par de
/// reproductores (efectos + música) durante toda la sesión.
final audioServiceProvider = Provider<IAudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
