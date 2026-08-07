import 'dart:async';
import 'game_event.dart';

/// Bus de eventos singleton. El engine publica; la UI y la red se suscriben.
class GameEventBus {
  GameEventBus._();
  static final GameEventBus instance = GameEventBus._();

  final StreamController<GameEvent> _controller =
      StreamController<GameEvent>.broadcast();

  Stream<GameEvent> get stream => _controller.stream;

  Stream<T> on<T extends GameEvent>() => stream.where((e) => e is T).cast<T>();

  bool _muted = false;

  void emit(GameEvent event) {
    if (_muted || _controller.isClosed) return;
    _controller.add(event);
  }

  /// Ejecuta `body` sin emitir al stream real — para simulaciones internas
  /// (bot) que aplican una `TurnAction` candidata solo para puntuar el
  /// estado resultante, sin que la UI/sonido lo perciba. `body` debe ser
  /// síncrono: Dart es de un solo hilo, no hay riesgo de reentrancia entre
  /// el mute y el unmute mientras no haya un `await` en el medio.
  T runMuted<T>(T Function() body) {
    final was = _muted;
    _muted = true;
    try {
      return body();
    } finally {
      _muted = was;
    }
  }

  void dispose() => _controller.close();
}
