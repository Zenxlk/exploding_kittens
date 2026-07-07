import '../../../core/errors/failures.dart';
import 'models/discovered_room.dart';
import 'models/lobby_room.dart';

abstract interface class ILobbyRepository {
  // Live room state — emits on every change while inside a room.
  Stream<LobbyRoom> get roomStream;

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
