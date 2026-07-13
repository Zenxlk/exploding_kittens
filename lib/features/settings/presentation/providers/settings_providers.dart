import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/app_settings.dart';

// ── Claves SharedPreferences ────────────────────────────────────────────────
abstract final class _Keys {
  static const playerName = 'settings_player_name';
  static const soundEnabled = 'settings_sound_enabled';
  static const volume = 'settings_volume';
  static const musicEnabled = 'settings_music_enabled';
}

// ── Notifier ────────────────────────────────────────────────────────────────
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      playerName: prefs.getString(_Keys.playerName) ?? 'Jugador',
      soundEnabled: prefs.getBool(_Keys.soundEnabled) ?? true,
      volume: prefs.getDouble(_Keys.volume) ?? 0.8,
      musicEnabled: prefs.getBool(_Keys.musicEnabled) ?? true,
    );
  }

  Future<void> setPlayerName(String name) => _update(
        (s) => s.copyWith(
            playerName: name.trim().isEmpty ? 'Jugador' : name.trim()),
        save: (prefs, s) => prefs.setString(_Keys.playerName, s.playerName),
      );

  Future<void> setSoundEnabled(bool value) => _update(
        (s) => s.copyWith(soundEnabled: value),
        save: (prefs, s) => prefs.setBool(_Keys.soundEnabled, s.soundEnabled),
      );

  Future<void> setVolume(double value) => _update(
        (s) => s.copyWith(volume: value),
        save: (prefs, s) => prefs.setDouble(_Keys.volume, s.volume),
      );

  Future<void> setMusicEnabled(bool value) => _update(
        (s) => s.copyWith(musicEnabled: value),
        save: (prefs, s) => prefs.setBool(_Keys.musicEnabled, s.musicEnabled),
      );

  Future<void> _update(
    AppSettings Function(AppSettings) transform, {
    required Future<bool> Function(SharedPreferences, AppSettings) save,
  }) async {
    final current = state.asData?.value ?? const AppSettings();
    final next = transform(current);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await save(prefs, next);
  }
}

// ── Provider público ────────────────────────────────────────────────────────
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// Versión real de la app (de pubspec.yaml, vía los metadatos nativos del
// build) — reemplaza el string hardcodeado que había que sincronizar a
// mano en cada commit chore(version).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
