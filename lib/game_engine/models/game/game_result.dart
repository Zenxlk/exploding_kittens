import 'package:equatable/equatable.dart';

class GameResult extends Equatable {
  const GameResult({
    required this.winnerId,
    required this.winnerName,
    required this.totalTurns,
    required this.eliminationOrder,
  });

  final String winnerId;
  final String winnerName;
  final int totalTurns;
  final List<String> eliminationOrder; // ids en orden de eliminación

  @override
  List<Object?> get props => [winnerId, totalTurns, eliminationOrder];
}
