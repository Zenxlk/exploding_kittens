import 'package:equatable/equatable.dart';

class GameConfig extends Equatable {
  const GameConfig({
    required this.playerCount,
    this.includeExpansion = false,
    this.botCount = 0,
    this.seed,
  });

  final int playerCount;
  final bool includeExpansion;
  final int botCount;
  final int? seed; // null = aleatorio; valor fijo = partida reproducible

  @override
  List<Object?> get props => [playerCount, includeExpansion, botCount, seed];
}
