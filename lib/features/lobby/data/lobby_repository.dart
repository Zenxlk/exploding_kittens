import 'dart:async';

import 'package:exploding_kittens/core/errors/failures.dart';
import 'package:exploding_kittens/features/lobby/data/client_room_discovery.dart';
import 'package:exploding_kittens/features/lobby/data/host_beacon_sync.dart';
import 'package:exploding_kittens/features/lobby/domain/i_lobby_repository.dart';
import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/network/websocket/websocket_client.dart';
import 'package:exploding_kittens/network/websocket/websocket_message.dart';
import 'package:exploding_kittens/network/websocket/websocket_server.dart';

// Implementa ILobbyRepository coordinando:
//   WsServer            — servidor TCP local (solo host)
//   WsClient             — cliente WebSocket (todos, incluido el host vía 127.0.0.1)
//   HostBeaconSync       — beacon UDP de MdnsAdvertiser (solo host)
//   ClientRoomDiscovery  — escucha de beacons de MdnsDiscoverer (solo cliente)
class LobbyRepository implements ILobbyRepository {
  WsServer? _server;
  WsClient? _client;
  final _hostBeacon = HostBeaconSync();
  final _clientDiscovery = ClientRoomDiscovery();
  String? _localPlayerId;

  @override
  Stream<LobbyRoom> get roomStream =>
      _client?.roomStream ?? const Stream.empty();

  @override
  WsClient? get wsClient => _client;

  @override
  WsServer? get wsServer => _server;

  // ── host ──────────────────────────────────────────────────────────────────

  @override
  Future<Result<LobbyRoom>> createRoom({
    required String playerName,
    required String playerId,
  }) async {
    try {
      _localPlayerId = playerId;

      // 1. Arranca el servidor WebSocket.
      _server = await WsServer.start(hostId: playerId, hostName: playerName);
      final serverRoom = _server!.currentRoom!;

      // 2. El host se conecta a su propio servidor vía loopback.
      //    Esto permite que el host use el mismo camino WsClient que cualquier jugador.
      _client = await WsClient.connect(
        hostAddress: '127.0.0.1',
        playerId: playerId,
        playerName: playerName,
      );

      // 3. Empieza a anunciar la sala en la red local, y mantiene el conteo
      //    de jugadores del beacon al día con cada cambio de sala.
      await _hostBeacon.start(
        roomId: serverRoom.id,
        hostName: playerName,
        playerCount: serverRoom.players.length,
        maxPlayers: serverRoom.maxPlayers,
        roomUpdates: _client!.roomStream,
      );

      // El servidor ya tiene el estado inicial autoritativo; se devuelve
      // directo para no esperar el stream y toparse con timing del broadcast.
      return Success(serverRoom);
    } catch (e) {
      await _cleanup();
      return FailureResult(NetworkFailure('No se pudo crear la sala: $e'));
    }
  }

  // ── client ────────────────────────────────────────────────────────────────

  @override
  Stream<List<DiscoveredRoom>> discoverRooms() => _clientDiscovery.discover();

  @override
  Future<Result<LobbyRoom>> joinRoom({
    required String hostAddress,
    required String playerName,
    required String playerId,
  }) async {
    try {
      _localPlayerId = playerId;

      // Detiene la búsqueda una vez que el jugador eligió una sala.
      await _clientDiscovery.stop();

      _client = await WsClient.connect(
        hostAddress: hostAddress,
        playerId: playerId,
        playerName: playerName,
      );

      // Usa el lastRoom en caché si el RoomStateMessage llegó antes de
      // poder suscribirse; si no, espera el próximo.
      final room = _client!.lastRoom ??
          await _client!.roomStream.first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'No llegó el estado de la sala desde el servidor',
            ),
          );

      return Success(room);
    } catch (e) {
      await _cleanup();
      return FailureResult(NetworkFailure('No se pudo unir a la sala: $e'));
    }
  }

  // ── shared ────────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> setReady({required bool ready}) async {
    if (_client == null || !_client!.isConnected) {
      return FailureResult(const NetworkFailure('No conectado a una sala'));
    }
    _client!.send(SetReadyMessage(ready: ready));
    return const Success(null);
  }

  @override
  Future<Result<void>> startGame() async {
    if (_client == null || !_client!.isConnected) {
      return FailureResult(const NetworkFailure('No conectado a una sala'));
    }
    _client!.send(const StartGameMessage());
    return const Success(null);
  }

  @override
  Future<void> leaveRoom() async {
    final playerId = _localPlayerId;
    if (playerId != null && _client != null) {
      await _client!.close(playerId: playerId);
    }
    await _cleanup();
  }

  // ── internals ─────────────────────────────────────────────────────────────

  Future<void> _cleanup() async {
    await _hostBeacon.stop();
    await _server?.close();
    _server = null;
    await _clientDiscovery.stop();
    _client = null;
    _localPlayerId = null;
  }
}
