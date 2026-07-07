import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exploding_kittens/core/constants/app_constants.dart';

import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';

// Discovers rooms on the local network by listening for UDP beacons
// sent by MdnsAdvertiser.
//
// Usage:
//   final discoverer = MdnsDiscoverer();
//   discoverer.rooms.listen((rooms) => setState(() => _rooms = rooms));
//   await discoverer.start();
//   // ... show UI
//   await discoverer.stop();
//
// TODO(improvement): also query mDNS PTR records for AppConstants.mdnsServiceType
// using the `multicast_dns` package once proper mDNS advertising is in place
// (see MdnsAdvertiser). Combine both sources with rx_dart merge or a plain
// StreamGroup so either mechanism works.
//
// TODO(improvement): prune stale rooms — remove any entry whose last beacon
// arrived more than ~10 s ago (e.g. the host stopped without sending a
// LeaveRoom broadcast). A simple Timer.periodic cleanup pass is enough.
class MdnsDiscoverer {
  final _roomsController =
      StreamController<List<DiscoveredRoom>>.broadcast();
  final _rooms = <String, DiscoveredRoom>{}; // roomId → room
  RawDatagramSocket? _socket;

  // Emits the current list every time a new beacon arrives or a room is pruned.
  Stream<List<DiscoveredRoom>> get rooms => _roomsController.stream;

  // Binds to discoveryPort and starts collecting beacons.
  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      AppConstants.discoveryPort,
      reuseAddress: true,
    );

    _socket!.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket!.receive();
        if (datagram != null) _handleDatagram(datagram);
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final json = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (json['type'] != 'room_beacon') return;

      // Trust the beacon's hostAddress; use datagram.address as a fallback
      // if the self-reported IP is missing or malformed.
      // TODO(improvement): validate hostAddress against datagram.address to
      // detect spoofed beacons (edge case in shared/VPN networks).
      final room = DiscoveredRoom.fromJson(json);
      _rooms[room.roomId] = room;

      if (!_roomsController.isClosed) {
        _roomsController.add(List.unmodifiable(_rooms.values));
      }
    } catch (_) {
      // Ignore malformed or non-beacon datagrams.
    }
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    _rooms.clear();
    await _roomsController.close();
  }
}
