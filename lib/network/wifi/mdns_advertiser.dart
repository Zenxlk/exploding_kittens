import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/core/errors/failures.dart';

import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';

// Announces a room on the local network via UDP broadcast.
//
// Every [interval] a JSON beacon is sent to 255.255.255.255:[discoveryPort]
// so that MdnsDiscoverer instances on the same subnet can find it.
//
// TODO(improvement): replace with the `nsd` package (pub.dev/packages/nsd)
// for proper mDNS / DNS-SD registration that shows up in system service
// browsers and works with Apple Bonjour.
//
// TODO(improvement): on Android 10+ receiving UDP broadcast requires
// acquiring a WifiManager.MulticastLock via a platform channel. Add this
// before shipping to the Play Store.
class MdnsAdvertiser {
  RawDatagramSocket? _socket;
  Timer? _timer;
  bool get isRunning => _socket != null;

  // Starts broadcasting the room beacon. Throws [NetworkFailure] if the
  // device is not connected to a WiFi network.
  Future<void> start({
    required String roomId,
    required String hostName,
    required int playerCount,
    required int maxPlayers,
    int port = AppConstants.localGamePort,
    Duration interval = const Duration(seconds: 3),
  }) async {
    final ip = await NetworkInfo().getWifiIP();
    if (ip == null) {
      throw const NetworkFailure('Could not determine WiFi IP address');
    }

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;

    final room = DiscoveredRoom(
      roomId: roomId,
      hostName: hostName,
      hostAddress: ip,
      port: port,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
    );

    _sendBeacon(room);
    _timer = Timer.periodic(interval, (_) => _sendBeacon(room));
  }

  // Call this whenever the player count changes so listeners see fresh data.
  // TODO(improvement): accept a full DiscoveredRoom instead of rebuilding
  // it here — avoids duplicating the roomId/hostName state in the caller.
  Future<void> updatePlayerCount({
    required String roomId,
    required String hostName,
    required int playerCount,
    required int maxPlayers,
    int port = AppConstants.localGamePort,
  }) async {
    final ip = await NetworkInfo().getWifiIP();
    if (ip == null || _socket == null) return;

    final room = DiscoveredRoom(
      roomId: roomId,
      hostName: hostName,
      hostAddress: ip,
      port: port,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
    );
    _sendBeacon(room);
  }

  void _sendBeacon(DiscoveredRoom room) {
    if (_socket == null) return;
    try {
      final payload = utf8.encode(jsonEncode(room.toJson()));
      _socket!.send(
        payload,
        InternetAddress('255.255.255.255'),
        AppConstants.discoveryPort,
      );
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _timer = null;
    _socket = null;
  }
}
