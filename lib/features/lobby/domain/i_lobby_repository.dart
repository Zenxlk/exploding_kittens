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
  // authToken (Fase 7): JWT de Supabase de la sesión actual, si hay una
  // (ver features/auth) — null en modo invitado, sin cambio de comportamiento.
  Future<Result<LobbyRoom>> createRoom({
    required String playerName,
    required String playerId,
    String? authToken,
  });

  // Client: scan the local network for available rooms.
  Stream<List<DiscoveredRoom>> discoverRooms();

  // Client: connect to an existing room. hostAddress es una IP LAN para
  // LobbyRepository, pero OnlineLobbyRepository lo reinterpreta como el
  // código de sala devuelto por createRoom del host — mismo campo, distinto
  // significado según la implementación (ver esa clase para el detalle).
  Future<Result<LobbyRoom>> joinRoom({
    required String hostAddress,
    required String playerName,
    required String playerId,
    String? authToken,
  });

  // Toggle the local player's ready state.
  Future<Result<void>> setReady({required bool ready});

  // Host only: start the game (requires canStart == true).
  Future<Result<void>> startGame();

  // Leave the current room; stops the server + advertiser if local player is host.
  Future<void> leaveRoom();
}
