import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_player.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── LobbyPlayer ────────────────────────────────────────────────────────────
  group('LobbyPlayer', () {
    const player = LobbyPlayer(
      id: 'p1',
      name: 'Alice',
      isHost: false,
      isReady: false,
      isBot: true,
    );

    test('toJson / fromJson round-trip conserva todos los campos', () {
      final restored = LobbyPlayer.fromJson(player.toJson());
      expect(restored, equals(player));
    });

    test('fromJson tolera JSON sin isBot (compatibilidad hacia atrás)', () {
      final json = player.toJson()..remove('isBot');
      final restored = LobbyPlayer.fromJson(json);
      expect(restored.isBot, isFalse);
    });

    test('copyWith cambia solo los campos indicados', () {
      final ready = player.copyWith(isReady: true);
      expect(ready.isReady, isTrue);
      expect(ready.id, equals(player.id));
      expect(ready.name, equals(player.name));
      expect(ready.isBot, equals(player.isBot));
    });
  });

  // ── LobbyRoom ─────────────────────────────────────────────────────────────
  group('LobbyRoom', () {
    LobbyPlayer host() =>
        const LobbyPlayer(id: 'h1', name: 'Host', isHost: true, isReady: true);
    LobbyPlayer ready(String id) =>
        LobbyPlayer(id: id, name: id, isReady: true);
    LobbyPlayer notReady(String id) => LobbyPlayer(id: id, name: id);

    LobbyRoom makeRoom(List<LobbyPlayer> players, {int max = 5}) => LobbyRoom(
          id: 'room1',
          hostId: 'h1',
          players: players,
          maxPlayers: max,
        );

    test('toJson / fromJson round-trip conserva todos los campos', () {
      final room = makeRoom([host(), ready('p1')]);
      final restored = LobbyRoom.fromJson(room.toJson());
      expect(restored, equals(room));
    });

    test('fromJson maneja LobbyStatus correctamente', () {
      final starting =
          makeRoom([host()]).copyWith(status: LobbyStatus.starting);
      final restored = LobbyRoom.fromJson(starting.toJson());
      expect(restored.status, equals(LobbyStatus.starting));
    });

    test('isFull es true cuando players.length == maxPlayers', () {
      final room = makeRoom([host(), notReady('p1')], max: 2);
      expect(room.isFull, isTrue);
    });

    test('isFull es false cuando hay espacio', () {
      final room = makeRoom([host()], max: 5);
      expect(room.isFull, isFalse);
    });

    test('canStart requiere mínimo 2 jugadores', () {
      expect(makeRoom([host()]).canStart, isFalse);
    });

    test('canStart requiere que todos los no-host estén listos', () {
      expect(makeRoom([host(), notReady('p1')]).canStart, isFalse);
      expect(makeRoom([host(), ready('p1')]).canStart, isTrue);
    });

    test('canStart es true con múltiples no-host todos listos', () {
      final room = makeRoom([host(), ready('p1'), ready('p2'), ready('p3')]);
      expect(room.canStart, isTrue);
    });

    test('host getter devuelve el jugador correcto', () {
      final room = makeRoom([host(), ready('p1')]);
      expect(room.host?.id, equals('h1'));
    });
  });

  // ── DiscoveredRoom ─────────────────────────────────────────────────────────
  group('DiscoveredRoom', () {
    const room = DiscoveredRoom(
      roomId: 'r1',
      hostName: 'Host',
      hostAddress: '192.168.1.5',
      port: 8765,
      playerCount: 2,
      maxPlayers: 5,
    );

    test('toJson / fromJson round-trip', () {
      final restored = DiscoveredRoom.fromJson(room.toJson());
      expect(restored, equals(room));
    });

    test('isFull cuando playerCount == maxPlayers', () {
      const full = DiscoveredRoom(
        roomId: 'r2',
        hostName: 'H',
        hostAddress: '1.2.3.4',
        port: 8765,
        playerCount: 5,
        maxPlayers: 5,
      );
      expect(full.isFull, isTrue);
      expect(room.isFull, isFalse);
    });
  });
}
