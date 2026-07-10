import 'dart:async';

import 'package:exploding_kittens/core/errors/failures.dart';
import 'package:exploding_kittens/features/lobby/domain/i_lobby_repository.dart';
import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/network/websocket/websocket_client.dart';
import 'package:exploding_kittens/network/websocket/websocket_message.dart';
import 'package:exploding_kittens/network/websocket/websocket_server.dart';
import 'package:exploding_kittens/network/wifi/mdns_advertiser.dart';
import 'package:exploding_kittens/network/wifi/mdns_discoverer.dart';

// Implements ILobbyRepository by coordinating:
//   WsServer      — local TCP server (host only)
//   WsClient      — WebSocket client (all players, including host via 127.0.0.1)
//   MdnsAdvertiser — UDP broadcast beacon (host only)
//   MdnsDiscoverer — UDP beacon listener (joining players)
//
// TODO(improvement): split into HostLobbyRepository and ClientLobbyRepository
// to keep each class focused; the current unified class has two implicit modes
// (host / client) that share state awkwardly.
//
// TODO(improvement): persist playerId across sessions with shared_preferences
// so the same player can reconnect after a crash without appearing as a new user.
class LobbyRepository implements ILobbyRepository {
  WsServer? _server;
  WsClient? _client;
  MdnsAdvertiser? _advertiser;
  MdnsDiscoverer? _discoverer;
  StreamSubscription<LobbyRoom>? _playerCountSub;
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

      // 1. Start the WebSocket server.
      _server = await WsServer.start(hostId: playerId, hostName: playerName);
      final serverRoom = _server!.currentRoom!;

      // 2. Host connects to their own server via loopback.
      //    This allows the host to use the same WsClient path as any player.
      _client = await WsClient.connect(
        hostAddress: '127.0.0.1',
        playerId: playerId,
        playerName: playerName,
      );

      // 3. Start advertising the room on the local network.
      _advertiser = MdnsAdvertiser();
      await _advertiser!.start(
        roomId: serverRoom.id,
        hostName: playerName,
        playerCount: serverRoom.players.length,
        maxPlayers: serverRoom.maxPlayers,
      );

      // 4. Keep the beacon's player count in sync with room changes.
      //    TODO(improvement): cancel this subscription in leaveRoom to avoid
      //    calling updatePlayerCount after the advertiser has been stopped.
      _playerCountSub = _client!.roomStream.listen((room) {
        _advertiser?.updatePlayerCount(
          roomId: room.id,
          hostName: playerName,
          playerCount: room.players.length,
          maxPlayers: room.maxPlayers,
        );
      });

      // The server already holds the authoritative initial state; return it
      // directly to avoid waiting on the stream and hitting broadcast timing.
      return Success(serverRoom);
    } catch (e) {
      await _cleanup();
      return FailureResult(NetworkFailure('Failed to create room: $e'));
    }
  }

  // ── client ────────────────────────────────────────────────────────────────

  @override
  Stream<List<DiscoveredRoom>> discoverRooms() async* {
    await _discoverer?.stop();
    _discoverer = MdnsDiscoverer();
    await _discoverer!.start();
    yield* _discoverer!.rooms;
  }

  @override
  Future<Result<LobbyRoom>> joinRoom({
    required String hostAddress,
    required String playerName,
    required String playerId,
  }) async {
    try {
      _localPlayerId = playerId;

      // Stop discovery once the player has chosen a room.
      await _discoverer?.stop();
      _discoverer = null;

      _client = await WsClient.connect(
        hostAddress: hostAddress,
        playerId: playerId,
        playerName: playerName,
      );

      // Use the cached lastRoom if the RoomStateMessage arrived before we
      // could subscribe, otherwise wait for the next one.
      final room = _client!.lastRoom ??
          await _client!.roomStream.first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'Did not receive room state from server',
            ),
          );

      return Success(room);
    } catch (e) {
      await _cleanup();
      return FailureResult(NetworkFailure('Failed to join room: $e'));
    }
  }

  // ── shared ────────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> setReady({required bool ready}) async {
    if (_client == null || !_client!.isConnected) {
      return FailureResult(const NetworkFailure('Not connected to a room'));
    }
    _client!.send(SetReadyMessage(ready: ready));
    return const Success(null);
  }

  @override
  Future<Result<void>> startGame() async {
    if (_client == null || !_client!.isConnected) {
      return FailureResult(const NetworkFailure('Not connected to a room'));
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
    await _playerCountSub?.cancel();
    _playerCountSub = null;
    _advertiser?.stop();
    _advertiser = null;
    await _server?.close();
    _server = null;
    await _discoverer?.stop();
    _discoverer = null;
    _client = null;
    _localPlayerId = null;
  }
}
