import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  const AppSettings({
    this.playerName = 'Jugador',
    this.soundEnabled = true,
    this.volume = 0.8,
    this.musicEnabled = true,
  });

  final String playerName;
  final bool soundEnabled;
  final double volume;
  final bool musicEnabled;

  AppSettings copyWith({
    String? playerName,
    bool? soundEnabled,
    double? volume,
    bool? musicEnabled,
  }) {
    return AppSettings(
      playerName: playerName ?? this.playerName,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volume: volume ?? this.volume,
      musicEnabled: musicEnabled ?? this.musicEnabled,
    );
  }

  @override
  List<Object?> get props => [playerName, soundEnabled, volume, musicEnabled];
}
