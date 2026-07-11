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
class MdnsDiscoverer {
  MdnsDiscoverer({
    Duration staleAfter = const Duration(seconds: 10),
    Duration pruneInterval = const Duration(seconds: 2),
  })  : _staleAfter = staleAfter,
        _pruneInterval = pruneInterval;

  final Duration _staleAfter;
  final Duration _pruneInterval;
  final _roomsController = StreamController<List<DiscoveredRoom>>.broadcast();
  final _rooms = <String, DiscoveredRoom>{}; // roomId → room
  final _lastSeen = <String, DateTime>{}; // roomId → last beacon time
  RawDatagramSocket? _socket;
  Timer? _pruneTimer;

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

    // The host stops sending beacons on close but never announces it's
    // gone, so without this a closed room stayed listed until the app
    // restarted. Whichever beacon is oldest by more than `_staleAfter`
    // (~3 missed beacons at the advertiser's default 3s interval) gets
    // dropped.
    _pruneTimer = Timer.periodic(_pruneInterval, (_) => _pruneStale());
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final json =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (json['type'] != 'room_beacon') return;

      // Trust the beacon's hostAddress; use datagram.address as a fallback
      // if the self-reported IP is missing or malformed.
      // TODO(improvement): validate hostAddress against datagram.address to
      // detect spoofed beacons (edge case in shared/VPN networks).
      final room = DiscoveredRoom.fromJson(json);
      _rooms[room.roomId] = room;
      _lastSeen[room.roomId] = DateTime.now();

      _emit();
    } catch (_) {
      // Ignore malformed or non-beacon datagrams.
    }
  }

  void _pruneStale() {
    final cutoff = DateTime.now().subtract(_staleAfter);
    final staleIds = _lastSeen.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    if (staleIds.isEmpty) return;

    for (final id in staleIds) {
      _rooms.remove(id);
      _lastSeen.remove(id);
    }
    _emit();
  }

  void _emit() {
    if (!_roomsController.isClosed) {
      _roomsController.add(List.unmodifiable(_rooms.values));
    }
  }

  Future<void> stop() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    _rooms.clear();
    _lastSeen.clear();
    await _roomsController.close();
  }
}
