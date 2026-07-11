import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:exploding_kittens/network/wifi/mdns_discoverer.dart';
import 'package:flutter_test/flutter_test.dart';

// Integration tests: real UDP loopback, MdnsDiscoverer binds the real
// (fixed) AppConstants.discoveryPort — matches how it's actually used, the
// port can't be OS-assigned since every device on the network needs to know
// it in advance. staleAfter/pruneInterval are shortened so the pruning
// tests don't need to wait the real ~10s.
void main() {
  group('MdnsDiscoverer', () {
    late RawDatagramSocket sender;

    setUp(() async {
      sender = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    });

    tearDown(() {
      sender.close();
    });

    const room = DiscoveredRoom(
      roomId: 'room-1',
      hostName: 'Ana',
      hostAddress: '127.0.0.1',
      port: 8765,
      playerCount: 1,
      maxPlayers: 5,
    );

    void sendBeacon(DiscoveredRoom r) {
      final payload = utf8.encode(jsonEncode(r.toJson()));
      sender.send(
        payload,
        InternetAddress('127.0.0.1'),
        AppConstants.discoveryPort,
      );
    }

    test('un beacon nuevo aparece en rooms', () async {
      final discoverer = MdnsDiscoverer();
      await discoverer.start();
      addTearDown(discoverer.stop);

      final firstEmit = discoverer.rooms.first;
      sendBeacon(room);

      final rooms = await firstEmit.timeout(const Duration(seconds: 2));
      expect(rooms, [room]);
    });

    test(
      'una sala se elimina si no llega ningún beacon nuevo antes de '
      'staleAfter',
      () async {
        final discoverer = MdnsDiscoverer(
          staleAfter: const Duration(milliseconds: 150),
          pruneInterval: const Duration(milliseconds: 30),
        );
        await discoverer.start();
        addTearDown(discoverer.stop);

        final events = <List<DiscoveredRoom>>[];
        final sub = discoverer.rooms.listen(events.add);
        addTearDown(sub.cancel);

        sendBeacon(room);
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          return events.isEmpty;
        }).timeout(const Duration(seconds: 2));
        expect(events.last, [room]);

        // Sin más beacons, debería podarse tras staleAfter + un ciclo de
        // pruneInterval.
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 20));
          return events.last.isNotEmpty;
        }).timeout(const Duration(seconds: 2));
        expect(events.last, isEmpty);
      },
    );

    test(
      'una sala que sigue mandando beacons no se poda aunque pase '
      'staleAfter',
      () async {
        final discoverer = MdnsDiscoverer(
          staleAfter: const Duration(milliseconds: 150),
          pruneInterval: const Duration(milliseconds: 30),
        );
        await discoverer.start();
        addTearDown(discoverer.stop);

        final refresher = Timer.periodic(
          const Duration(milliseconds: 50),
          (_) => sendBeacon(room),
        );
        addTearDown(refresher.cancel);

        sendBeacon(room);
        await Future.delayed(const Duration(milliseconds: 400));

        final rooms =
            await discoverer.rooms.first.timeout(const Duration(seconds: 2));
        expect(rooms, [room]);
      },
    );
  });
}
