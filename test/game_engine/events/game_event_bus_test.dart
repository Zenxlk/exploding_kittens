import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/events/game_event_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameEventBus.runMuted', () {
    test('no emite eventos al stream mientras está silenciado', () async {
      final bus = GameEventBus.instance;
      final received = <GameEvent>[];
      final sub = bus.stream.listen(received.add);

      final result = bus.runMuted(() {
        bus.emit(DeckShuffledEvent(timestamp: DateTime.utc(2026)));
        return 42;
      });

      expect(result, 42);
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
      await sub.cancel();
    });

    test('vuelve a emitir normalmente después de runMuted', () async {
      final bus = GameEventBus.instance;
      final received = <GameEvent>[];
      final sub = bus.stream.listen(received.add);

      bus.runMuted(() {});
      bus.emit(DeckShuffledEvent(timestamp: DateTime.utc(2026)));

      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      await sub.cancel();
    });

    test('restaura el estado previo si runMuted anida (silenciado dentro de silenciado)',
        () async {
      final bus = GameEventBus.instance;
      final received = <GameEvent>[];
      final sub = bus.stream.listen(received.add);

      bus.runMuted(() {
        bus.runMuted(() {});
        // Todavía dentro del runMuted externo: sigue silenciado.
        bus.emit(DeckShuffledEvent(timestamp: DateTime.utc(2026)));
      });

      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
      await sub.cancel();
    });

    test('propaga excepciones y restaura el estado igual', () async {
      final bus = GameEventBus.instance;
      expect(() => bus.runMuted(() => throw StateError('boom')),
          throwsStateError);

      final received = <GameEvent>[];
      final sub = bus.stream.listen(received.add);
      bus.emit(DeckShuffledEvent(timestamp: DateTime.utc(2026)));
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      await sub.cancel();
    });
  });
}
