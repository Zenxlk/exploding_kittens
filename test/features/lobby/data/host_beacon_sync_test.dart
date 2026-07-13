import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exploding_kittens/features/lobby/data/host_beacon_sync.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_player.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Test de integración: UDP real en loopback, puerto dedicado propio (evita
// chocar con otros archivos de test de red cuando flutter test corre todo
// en paralelo). NetworkInfo().getWifiIP() se mockea en su method channel
// porque MdnsAdvertiser (usado por HostBeaconSync) lo necesita para arrancar.
const _networkInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/network_info',
);
const _testDiscoveryPort = 18904;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_networkInfoChannel, (call) async {
      if (call.method == 'wifiIPAddress') return '127.0.0.1';
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_networkInfoChannel, null);
  });

  group('HostBeaconSync', () {
    late RawDatagramSocket receiver;
    late StreamController<Map<String, dynamic>> beacons;

    setUp(() async {
      receiver = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _testDiscoveryPort,
        reuseAddress: true,
      );
      beacons = StreamController.broadcast();
      receiver.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = receiver.receive();
        if (datagram != null) {
          beacons.add(
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>,
          );
        }
      });
    });

    tearDown(() async {
      receiver.close();
      await beacons.close();
    });

    const host = LobbyPlayer(id: 'h1', name: 'Ana', isHost: true);
    const p2 = LobbyPlayer(id: 'p2', name: 'Beto');

    test('start manda el beacon inicial con los datos de la sala', () async {
      final sync = HostBeaconSync();
      addTearDown(sync.stop);

      final first = beacons.stream.first;
      await sync.start(
        roomId: 'room-1',
        hostName: 'Ana',
        playerCount: 1,
        maxPlayers: 5,
        roomUpdates: const Stream.empty(),
        discoveryPort: _testDiscoveryPort,
      );

      final json = await first.timeout(const Duration(seconds: 2));
      expect(json['roomId'], 'room-1');
      expect(json['playerCount'], 1);
    });

    test(
      'reenvía cada cambio de sala como una actualización del conteo de '
      'jugadores del beacon',
      () async {
        final roomUpdates = StreamController<LobbyRoom>();
        final sync = HostBeaconSync();
        addTearDown(sync.stop);
        addTearDown(roomUpdates.close);

        final initial = beacons.stream.first;
        await sync.start(
          roomId: 'room-1',
          hostName: 'Ana',
          playerCount: 1,
          maxPlayers: 5,
          roomUpdates: roomUpdates.stream,
          discoveryPort: _testDiscoveryPort,
        );
        await initial.timeout(const Duration(seconds: 2));

        final updated = beacons.stream.first;
        roomUpdates.add(
          const LobbyRoom(id: 'room-1', hostId: 'h1', players: [host, p2]),
        );

        final json = await updated.timeout(const Duration(seconds: 2));
        expect(json['playerCount'], 2);
      },
    );

    test('stop() deja de reenviar cambios de sala', () async {
      final roomUpdates = StreamController<LobbyRoom>();
      final sync = HostBeaconSync();
      addTearDown(roomUpdates.close);

      final initial = beacons.stream.first;
      await sync.start(
        roomId: 'room-1',
        hostName: 'Ana',
        playerCount: 1,
        maxPlayers: 5,
        roomUpdates: roomUpdates.stream,
        discoveryPort: _testDiscoveryPort,
      );
      await initial.timeout(const Duration(seconds: 2));
      await sync.stop();

      final seen = <int>[];
      final sub = beacons.stream.listen(
        (json) => seen.add(json['playerCount'] as int),
      );
      addTearDown(sub.cancel);

      roomUpdates.add(
        const LobbyRoom(id: 'room-1', hostId: 'h1', players: [host, p2]),
      );
      await Future.delayed(const Duration(milliseconds: 200));
      expect(seen, isEmpty);
    });
  });
}
