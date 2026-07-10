import '../../../core/errors/failures.dart';
import '../../../network/websocket/websocket_client.dart';
import '../../../network/websocket/websocket_server.dart';
import 'models/discovered_room.dart';
import 'models/lobby_room.dart';

abstract interface class ILobbyRepository {
  // Live room state — emits on every change while inside a room.
  Stream<LobbyRoom> get roomStream;

  // The WebSocket connection every player (including the host, via
  // 127.0.0.1) already has open — Fase 5 reuses it for in-game messages
  // instead of opening a second connection. Null before joining/creating.
  WsClient? get wsClient;

  // Only non-null on the host device — the server the game feature relays
  // ActionMessage/GameStateMessage through once the game starts.
  WsServer? get wsServer;

  // Host: create a new room and start advertising it on the local network.
  Future<Result<LobbyRoom>> createRoom({
    required String playerName,
    required String playerId,
  });

  // Client: scan the local network for available rooms.
  Stream<List<DiscoveredRoom>> discoverRooms();

  // Client: connect to an existing room by host address.
  Future<Result<LobbyRoom>> joinRoom({
    required String hostAddress,
    required String playerName,
    required String playerId,
  });

  // Toggle the local player's ready state.
  Future<Result<void>> setReady({required bool ready});

  // Host only: start the game (requires canStart == true).
  Future<Result<void>> startGame();

  // Leave the current room; stops the server + advertiser if local player is host.
  Future<void> leaveRoom();
}
