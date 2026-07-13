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
  DiscoveredRoom? _room;
  int _discoveryPort = AppConstants.discoveryPort;
  bool get isRunning => _socket != null;

  // Starts broadcasting the room beacon. Throws [NetworkFailure] if the
  // device is not connected to a WiFi network. [discoveryPort] is the UDP
  // port beacons are sent to — overridable so tests can use their own port
  // and avoid colliding with other test files exercising the real one.
  Future<void> start({
    required String roomId,
    required String hostName,
    required int playerCount,
    required int maxPlayers,
    int port = AppConstants.localGamePort,
    int discoveryPort = AppConstants.discoveryPort,
    Duration interval = const Duration(seconds: 3),
  }) async {
    final ip = await NetworkInfo().getWifiIP();
    if (ip == null) {
      throw const NetworkFailure('Could not determine WiFi IP address');
    }

    _discoveryPort = discoveryPort;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;

    _room = DiscoveredRoom(
      roomId: roomId,
      hostName: hostName,
      hostAddress: ip,
      port: port,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
    );

    _sendBeacon(_room!);
    // Reads _room fresh on every tick (not a value captured once here) so
    // that updatePlayerCount's changes stick — otherwise this kept
    // re-announcing the player count the room started with, overwriting
    // updatePlayerCount's beacon every `interval`.
    _timer = Timer.periodic(interval, (_) {
      final room = _room;
      if (room != null) _sendBeacon(room);
    });
  }

  // Call this whenever the player count changes so listeners see fresh data.
  Future<void> updatePlayerCount({
    required int playerCount,
    required int maxPlayers,
  }) async {
    final current = _room;
    if (current == null || _socket == null) return;

    final ip = await NetworkInfo().getWifiIP() ?? current.hostAddress;
    _room = DiscoveredRoom(
      roomId: current.roomId,
      hostName: current.hostName,
      hostAddress: ip,
      port: current.port,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
    );
    _sendBeacon(_room!);
  }

  void _sendBeacon(DiscoveredRoom room) {
    if (_socket == null) return;
    try {
      final payload = utf8.encode(jsonEncode(room.toJson()));
      _socket!.send(
        payload,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _timer = null;
    _socket = null;
    _room = null;
  }
}
