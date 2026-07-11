import 'dart:convert';
import 'dart:io';

import 'package:exploding_kittens/features/lobby/domain/models/lobby_status.dart';
import 'package:exploding_kittens/network/websocket/websocket_client.dart';
import 'package:exploding_kittens/network/websocket/websocket_message.dart';
import 'package:exploding_kittens/network/websocket/websocket_server.dart';
import 'package:flutter_test/flutter_test.dart';

// Integration tests: real WsServer + WsClient on loopback.
// Each test binds on port 0 (OS-assigned) to avoid collisions.
void main() {
  // Helpers
  Future<WsServer> startServer(
          {String hostId = 'h1', String hostName = 'Host'}) =>
      WsServer.start(hostId: hostId, hostName: hostName, port: 0);

  Future<WsClient> connectClient({
    required int port,
    String playerId = 'p1',
    String playerName = 'Alice',
  }) =>
      WsClient.connect(
        hostAddress: '127.0.0.1',
        playerId: playerId,
        playerName: playerName,
        port: port,
      );

  // ── conexión básica ──────────────────────────────────────────────────────
  group('WsServer — conexión', () {
    test('el servidor arranca y expone el puerto asignado', () async {
      final server = await startServer();
      expect(server.port, isNonZero);
      expect(server.isRunning, isTrue);
      await server.close();
    });

    test('el host aparece en la sala inicial', () async {
      final server = await startServer();
      expect(server.currentRoom!.players, hasLength(1));
      expect(server.currentRoom!.players.first.isHost, isTrue);
      await server.close();
    });
  });

  // ── join / leave ─────────────────────────────────────────────────────────
  group('WsServer — join / leave', () {
    test('un cliente que se une aparece en la sala', () async {
      final server = await startServer();

      // Suscribirse antes de conectar para no perder el evento
      final roomUpdate = server.roomStream.first;
      final client = await connectClient(port: server.port);

      final room = await roomUpdate.timeout(const Duration(seconds: 3));
      expect(room.players, hasLength(2));
      expect(room.players.any((p) => p.id == 'p1'), isTrue);

      await client.close(playerId: 'p1');
      await server.close();
    });

    test('un cliente que se va se elimina de la sala', () async {
      final server = await startServer();
      final client = await connectClient(port: server.port);

      // Esperar join
      await server.roomStream
          .firstWhere((r) => r.players.length == 2)
          .timeout(const Duration(seconds: 3));

      // Leave
      final afterLeave = server.roomStream
          .firstWhere((r) => r.players.length == 1)
          .timeout(const Duration(seconds: 3));

      await client.close(playerId: 'p1');
      final room = await afterLeave;
      expect(room.players, hasLength(1));

      await server.close();
    });
  });

  // ── ready / start ────────────────────────────────────────────────────────
  group('WsServer — ready y start', () {
    test('SetReady actualiza el estado del jugador en la sala', () async {
      final server = await startServer();
      final client = await connectClient(port: server.port);

      // Esperar a que el join se procese
      await server.roomStream
          .firstWhere((r) => r.players.length == 2)
          .timeout(const Duration(seconds: 3));

      final readyUpdate = server.roomStream
          .firstWhere((r) => r.players.any((p) => p.id == 'p1' && p.isReady))
          .timeout(const Duration(seconds: 3));

      client.send(const SetReadyMessage(ready: true));
      final room = await readyUpdate;
      expect(room.players.firstWhere((p) => p.id == 'p1').isReady, isTrue);

      await client.close(playerId: 'p1');
      await server.close();
    });

    test('startGame cambia el status a starting cuando canStart es true',
        () async {
      final server = await startServer();

      // Host se conecta a su propio servidor
      final hostClient = await connectClient(
        port: server.port,
        playerId: 'h1',
        playerName: 'Host',
      );

      // Un segundo jugador se une y se pone listo
      final guest = await connectClient(
        port: server.port,
        playerId: 'p2',
        playerName: 'Bob',
      );

      await server.roomStream
          .firstWhere((r) => r.players.length == 2)
          .timeout(const Duration(seconds: 3));

      guest.send(const SetReadyMessage(ready: true));

      await server.roomStream
          .firstWhere((r) => r.canStart)
          .timeout(const Duration(seconds: 3));

      final startingRoom = server.roomStream
          .firstWhere((r) => r.status == LobbyStatus.starting)
          .timeout(const Duration(seconds: 3));

      hostClient.send(const StartGameMessage());
      final room = await startingRoom;
      expect(room.status, equals(LobbyStatus.starting));

      await hostClient.close(playerId: 'h1');
      await guest.close(playerId: 'p2');
      await server.close();
    });

    test('startGame con canStart false no cambia el status', () async {
      final server = await startServer();
      final hostClient = await connectClient(
        port: server.port,
        playerId: 'h1',
        playerName: 'Host',
      );

      // Solo el host — canStart == false
      hostClient.send(const StartGameMessage());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(server.currentRoom!.status, equals(LobbyStatus.waiting));

      await hostClient.close(playerId: 'h1');
      await server.close();
    });
  });

  // ── in-game (Fase 5) ─────────────────────────────────────────────────────
  group('WsServer — mensajes en partida', () {
    test('actionMessages emite el ActionMessage con el playerId del remitente',
        () async {
      final server = await startServer();
      final client = await connectClient(port: server.port);

      await server.roomStream
          .firstWhere((r) => r.players.length == 2)
          .timeout(const Duration(seconds: 3));

      final received = server.actionMessages.first.timeout(
        const Duration(seconds: 3),
      );
      client.send(const ActionMessage(actionJson: {'type': 'draw_card'}));

      final entry = await received;
      expect(entry.playerId, 'p1');
      expect(entry.actionJson, equals({'type': 'draw_card'}));

      await client.close(playerId: 'p1');
      await server.close();
    });

    test('broadcast envía el mensaje a todos los clientes conectados',
        () async {
      final server = await startServer();
      final client = await connectClient(port: server.port);

      await server.roomStream
          .firstWhere((r) => r.players.length == 2)
          .timeout(const Duration(seconds: 3));

      final received = client.messages
          .firstWhere((m) => m is GameStateMessage)
          .timeout(const Duration(seconds: 3));
      server.broadcast(const GameStateMessage(stateJson: {'turnCount': 1}));

      final msg = await received as GameStateMessage;
      expect(msg.stateJson, equals({'turnCount': 1}));

      await client.close(playerId: 'p1');
      await server.close();
    });

    test('sendToPlayer solo llega al jugador indicado', () async {
      final server = await startServer();
      final client1 = await connectClient(port: server.port, playerId: 'p1');
      final client2 = await connectClient(
        port: server.port,
        playerId: 'p2',
        playerName: 'Bob',
      );

      await server.roomStream
          .firstWhere((r) => r.players.length == 3)
          .timeout(const Duration(seconds: 3));

      final rejectedForP1 = client1.messages
          .firstWhere((m) => m is ActionRejectedMessage)
          .timeout(const Duration(seconds: 3));
      // client2 no debería recibirlo: si llegara, esta futura completaría
      // antes de que termine el test y el `expect` de abajo lo detectaría.
      var p2Received = false;
      final p2Sub =
          client2.messages.where((m) => m is ActionRejectedMessage).listen(
                (_) => p2Received = true,
              );

      server.sendToPlayer(
        'p1',
        const ActionRejectedMessage(message: 'no es tu turno'),
      );

      final msg = await rejectedForP1 as ActionRejectedMessage;
      expect(msg.message, 'no es tu turno');
      expect(p2Received, isFalse);

      await p2Sub.cancel();
      await client1.close(playerId: 'p1');
      await client2.close(playerId: 'p2');
      await server.close();
    });

    // `WsClient.close()` sends a `LeaveRoomMessage` before dropping the
    // socket — a graceful, intentional leave that should keep removing the
    // player immediately regardless of `_gameStarted`. To simulate a real
    // drop (crash, network loss) these two tests connect a bare `dart:io`
    // `WebSocket` instead, so no `LeaveRoomMessage` precedes the socket close.
    Future<WebSocket> rawConnect(int port, String playerId) async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port');
      ws.add(jsonEncode(
        JoinRoomMessage(playerId: playerId, name: 'Raw').toJson(),
      ));
      return ws;
    }

    test(
      'tras markGameStarted, la desconexión de un no-host dispara '
      'onPlayerDisconnected en vez de sacarlo de la sala',
      () async {
        final server = await startServer();
        final raw = await rawConnect(server.port, 'p1');

        await server.roomStream
            .firstWhere((r) => r.players.length == 2)
            .timeout(const Duration(seconds: 3));

        server.markGameStarted();

        String? disconnectedId;
        server.onPlayerDisconnected = (id) => disconnectedId = id;

        await raw.close();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(disconnectedId, 'p1');
        // El jugador sigue en la sala (no se ejecutó _onLeave).
        expect(server.currentRoom!.players.any((p) => p.id == 'p1'), isTrue);

        await server.close();
      },
    );

    test(
      'reconectar con el mismo playerId dispara onPlayerReconnected',
      () async {
        final server = await startServer();
        final raw = await rawConnect(server.port, 'p1');

        await server.roomStream
            .firstWhere((r) => r.players.length == 2)
            .timeout(const Duration(seconds: 3));

        server.markGameStarted();
        String? reconnectedId;
        server.onPlayerReconnected = (id) => reconnectedId = id;

        await raw.close();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final rejoined = await connectClient(port: server.port, playerId: 'p1');
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(reconnectedId, 'p1');

        await rejoined.close(playerId: 'p1');
        await server.close();
      },
    );
  });

  // ── WsClient ─────────────────────────────────────────────────────────────
  group('WsClient', () {
    test('lastRoom se cachea tras el primer RoomStateMessage', () async {
      final server = await startServer();
      final client = await connectClient(port: server.port);

      // Esperar que llegue el RoomStateMessage al cliente
      await client.roomStream.first.timeout(const Duration(seconds: 3));

      expect(client.lastRoom, isNotNull);
      expect(client.lastRoom!.players, isNotEmpty);

      await client.close(playerId: 'p1');
      await server.close();
    });

    test('isConnected es false después de close()', () async {
      final server = await startServer();
      final client = await connectClient(port: server.port);
      expect(client.isConnected, isTrue);

      await client.close(playerId: 'p1');
      expect(client.isConnected, isFalse);

      await server.close();
    });
  });

  // ── reconexión automática ────────────────────────────────────────────────
  group('WsClient — reconexión automática', () {
    test(
      'una caída no explícita (no close()) reconecta sola con back-off '
      'cuando el servidor vuelve a estar disponible',
      () async {
        final firstServer = await startServer();
        final port = firstServer.port;
        final client = await connectClient(port: port);
        await client.roomStream.first.timeout(const Duration(seconds: 3));

        // Caída no solicitada por el cliente (se apaga el servidor, no un
        // close() del propio cliente) -> debe reconectar sola, no quedarse
        // en disconnected para siempre.
        final disconnected = client.status
            .firstWhere((s) => s == WsConnectionStatus.disconnected)
            .timeout(const Duration(seconds: 3));
        await firstServer.close();
        await disconnected;
        expect(client.isConnected, isFalse);

        // El servidor "vuelve" en el mismo puerto; el back-off inicial es de
        // 1s, así que debería reconectar sin que el test tenga que forzar
        // nada más.
        final secondServer = await WsServer.start(
          hostId: 'h1',
          hostName: 'Host',
          port: port,
        );

        await client.status
            .firstWhere((s) => s == WsConnectionStatus.connected)
            .timeout(const Duration(seconds: 5));
        expect(client.isConnected, isTrue);

        await client.close(playerId: 'p1');
        await secondServer.close();
      },
    );

    test('close() explícito no dispara una reconexión automática', () async {
      final server = await startServer();
      final client = await connectClient(port: server.port);
      await client.roomStream.first.timeout(const Duration(seconds: 3));

      await client.close(playerId: 'p1');
      await server.close();

      // Si close() disparara una reconexión, esto fallaría por escribir en
      // un stream ya cerrado; simplemente confirmamos que sigue desconectado
      // tras esperar más que el back-off inicial.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(client.isConnected, isFalse);
    });
  });
}
