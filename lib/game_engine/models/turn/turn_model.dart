import 'package:equatable/equatable.dart';

enum TurnPhase {
  playing,      // el jugador activo puede jugar cartas
  nopeWindow,   // ventana abierta para que otros jueguen Nope
  drawRequired, // el jugador debe robar para terminar turno
  resolving,    // se está aplicando el efecto de una carta
  ended,        // turno terminado, pasa al siguiente
}

class TurnModel extends Equatable {
  const TurnModel({
    required this.currentPlayerId,
    required this.phase,
    this.actionsLeft = 1,   // Attack puede dejarlo en 2
    this.nopeChainCount = 0,
  });

  final String currentPlayerId;
  final TurnPhase phase;
  final int actionsLeft;    // veces que el jugador debe robar (Attack chains)
  final int nopeChainCount; // número de Nopes en cadena (par = cancelado)

  bool get isNoped => nopeChainCount.isOdd;

  TurnModel copyWith({
    String? currentPlayerId,
    TurnPhase? phase,
    int? actionsLeft,
    int? nopeChainCount,
  }) {
    return TurnModel(
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      phase: phase ?? this.phase,
      actionsLeft: actionsLeft ?? this.actionsLeft,
      nopeChainCount: nopeChainCount ?? this.nopeChainCount,
    );
  }

  @override
  List<Object?> get props => [currentPlayerId, phase, actionsLeft, nopeChainCount];
}
