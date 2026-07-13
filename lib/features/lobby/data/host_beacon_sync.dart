import 'dart:async';

import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/network/wifi/mdns_advertiser.dart';

/// Encapsula el ciclo de vida del `MdnsAdvertiser` del host: lo arranca con
/// los datos iniciales de la sala y mantiene el conteo de jugadores del
/// beacon al día escuchando [roomUpdates]. Extraído de `LobbyRepository`
/// para que la parte "solo host" no viva mezclada con la parte "solo
/// cliente" (`ClientRoomDiscovery`) en la misma clase.
class HostBeaconSync {
  MdnsAdvertiser? _advertiser;
  StreamSubscription<LobbyRoom>? _sub;

  // [discoveryPort] es sobreescribible para que los tests usen su propio
  // puerto en vez del AppConstants.discoveryPort real.
  Future<void> start({
    required String roomId,
    required String hostName,
    required int playerCount,
    required int maxPlayers,
    required Stream<LobbyRoom> roomUpdates,
    int discoveryPort = AppConstants.discoveryPort,
  }) async {
    _advertiser = MdnsAdvertiser();
    await _advertiser!.start(
      roomId: roomId,
      hostName: hostName,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
      discoveryPort: discoveryPort,
    );

    _sub = roomUpdates.listen((room) {
      _advertiser?.updatePlayerCount(
        playerCount: room.players.length,
        maxPlayers: room.maxPlayers,
      );
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _advertiser?.stop();
    _advertiser = null;
  }
}
