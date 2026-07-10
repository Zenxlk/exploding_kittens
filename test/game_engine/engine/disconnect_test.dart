import 'package:exploding_kittens/game_engine/engine/action_processor.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _baseState({
  required List<PlayerModel> players,
  String? currentPlayerId,
}) {
  return GameState(
    id: 'game-1',
    config: const GameConfig(playerCount: 2),
    players: players,
    deck: const DeckModel(drawPile: [], discardPile: []),
    turn: TurnModel(
      currentPlayerId: currentPlayerId ?? players.first.id,
      phase: TurnPhase.playing,
    ),
    phase: GamePhase.playing,
  );
}

void main() {
  group('ActionProcessor — desconexión (Fase 5)', () {
    test('markDisconnected marca a un jugador activo como disconnected', () {
      final p1 = PlayerModel(id: 'p1', name: 'A', hand: const []);
      final p2 = PlayerModel(id: 'p2', name: 'B', hand: const []);
      final state = _baseState(players: [p1, p2]);

      final next = ActionProcessor.markDisconnected('p1', state);

      expect(next.playerById('p1')!.status, PlayerStatus.disconnected);
      expect(next.playerById('p2')!.status, PlayerStatus.active);
    });

    test('markDisconnected es no-op sobre un jugador ya eliminado', () {
      final p1 = PlayerModel(
        id: 'p1',
        name: 'A',
        hand: const [],
        status: PlayerStatus.eliminated,
      );
      final p2 = PlayerModel(id: 'p2', name: 'B', hand: const []);
      final state = _baseState(players: [p1, p2]);

      final next = ActionProcessor.markDisconnected('p1', state);

      expect(next.playerById('p1')!.status, PlayerStatus.eliminated);
    });

    test('markReconnected devuelve a un desconectado a active', () {
      final p1 = PlayerModel(
        id: 'p1',
        name: 'A',
        hand: const [],
        status: PlayerStatus.disconnected,
      );
      final p2 = PlayerModel(id: 'p2', name: 'B', hand: const []);
      final state = _baseState(players: [p1, p2]);

      final next = ActionProcessor.markReconnected('p1', state);

      expect(next.playerById('p1')!.status, PlayerStatus.active);
    });

    test('markReconnected es no-op si el jugador no estaba disconnected', () {
      final p1 = PlayerModel(id: 'p1', name: 'A', hand: const []);
      final p2 = PlayerModel(id: 'p2', name: 'B', hand: const []);
      final state = _baseState(players: [p1, p2]);

      final next = ActionProcessor.markReconnected('p1', state);

      expect(next.playerById('p1')!.status, PlayerStatus.active);
    });

    test(
      'eliminateForDisconnect elimina al jugador y registra eliminationOrder',
      () {
        final p1 = PlayerModel(
          id: 'p1',
          name: 'A',
          hand: const [],
          status: PlayerStatus.disconnected,
        );
        final p2 = PlayerModel(id: 'p2', name: 'B', hand: const []);
        final p3 = PlayerModel(id: 'p3', name: 'C', hand: const []);
        final state = _baseState(
          players: [p1, p2, p3],
          currentPlayerId: 'p2',
        );

        final next = ActionProcessor.eliminateForDisconnect('p1', state);

        expect(next.playerById('p1')!.status, PlayerStatus.eliminated);
        expect(next.eliminationOrder, ['p1']);
        // No tenía el turno -> el turno en curso no se ve afectado.
        expect(next.turn.currentPlayerId, 'p2');
        expect(next.phase, GamePhase.playing);
      },
    );

    test(
      'eliminateForDisconnect pasa el turno si el desconectado era el '
      'jugador activo',
      () {
        // 3 jugadores: al eliminar a p1 sigue habiendo más de un jugador
        // vivo, así que el turno avanza en vez de terminar la partida.
        final p1 = PlayerModel(id: 'p1', name: 'A', hand: const []);
        final p2 = PlayerModel(id: 'p2', name: 'B', hand: const []);
        final p3 = PlayerModel(id: 'p3', name: 'C', hand: const []);
        final state = _baseState(
          players: [p1, p2, p3],
          currentPlayerId: 'p1',
        );

        final next = ActionProcessor.eliminateForDisconnect('p1', state);

        expect(next.turn.currentPlayerId, 'p2');
        expect(next.phase, GamePhase.playing);
      },
    );

    test(
      'eliminateForDisconnect dispara WinCondition si solo queda un jugador '
      'activo',
      () {
        final p1 = PlayerModel(id: 'p1', name: 'A', hand: const []);
        final p2 = PlayerModel(id: 'p2', name: 'B', hand: const []);
        final state = _baseState(players: [p1, p2], currentPlayerId: 'p2');

        final next = ActionProcessor.eliminateForDisconnect('p1', state);

        expect(next.phase, GamePhase.finished);
        expect(next.result, isNotNull);
        expect(next.result!.winnerId, 'p2');
      },
    );

    test('eliminateForDisconnect es no-op sobre un jugador ya eliminado', () {
      final p1 = PlayerModel(
        id: 'p1',
        name: 'A',
        hand: const [],
        status: PlayerStatus.eliminated,
      );
      final p2 = PlayerModel(id: 'p2', name: 'B', hand: const []);
      final state = _baseState(players: [p1, p2]);

      final next = ActionProcessor.eliminateForDisconnect('p1', state);

      expect(next.eliminationOrder, isEmpty);
    });
  });
}
