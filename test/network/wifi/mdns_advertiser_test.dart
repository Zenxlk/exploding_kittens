import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exploding_kittens/network/wifi/mdns_advertiser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Integration tests: real UDP loopback (verified that broadcast to
// 255.255.255.255 is deliverable to a listener on the same loopback
// namespace in this environment). NetworkInfo().getWifiIP() is mocked at
// its method channel since it needs a real platform to answer otherwise.
// Uses its own dedicated port rather than the real AppConstants.discoveryPort
// so it doesn't collide with mdns_discoverer_test.dart's receiver when
// flutter test runs both files in parallel (the default).
const _networkInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/network_info',
);
const _testDiscoveryPort = 18902;

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

  group('MdnsAdvertiser', () {
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

    test('start manda un beacon inicial con los datos de la sala', () async {
      final advertiser = MdnsAdvertiser();
      addTearDown(advertiser.stop);

      final first = beacons.stream.first;
      await advertiser.start(
        roomId: 'room-1',
        hostName: 'Ana',
        playerCount: 1,
        maxPlayers: 5,
        discoveryPort: _testDiscoveryPort,
        interval: const Duration(milliseconds: 500),
      );

      final json = await first.timeout(const Duration(seconds: 2));
      expect(json['roomId'], 'room-1');
      expect(json['hostName'], 'Ana');
      expect(json['playerCount'], 1);
      expect(json['maxPlayers'], 5);
    });

    test(
      'el timer periódico sigue mandando el playerCount actualizado, no '
      'el original',
      () async {
        final advertiser = MdnsAdvertiser();
        addTearDown(advertiser.stop);

        final initial = beacons.stream.first;
        await advertiser.start(
          roomId: 'room-1',
          hostName: 'Ana',
          playerCount: 1,
          maxPlayers: 5,
          discoveryPort: _testDiscoveryPort,
          interval: const Duration(milliseconds: 30),
        );
        // Drena el beacon inicial (playerCount: 1) antes de seguir, para
        // que no quede un datagrama en tránsito que se cuele más abajo.
        await initial.timeout(const Duration(seconds: 2));

        await advertiser.updatePlayerCount(playerCount: 3, maxPlayers: 5);
        // Deja que el propio beacon de updatePlayerCount llegue antes de
        // empezar a contar — lo que importa es que los ticks *siguientes*
        // del Timer.periodic no vuelvan a mandar el playerCount original.
        await Future.delayed(const Duration(milliseconds: 50));

        final seen = <int>[];
        final sub = beacons.stream.listen(
          (json) => seen.add(json['playerCount'] as int),
        );
        addTearDown(sub.cancel);

        await Future.delayed(const Duration(milliseconds: 200));

        expect(seen, isNotEmpty);
        expect(seen, everyElement(3));
      },
    );

    test('updatePlayerCount antes de start() no lanza ni manda nada', () async {
      final advertiser = MdnsAdvertiser();

      await expectLater(
        advertiser.updatePlayerCount(playerCount: 3, maxPlayers: 5),
        completes,
      );

      final seen = <int>[];
      final sub = beacons.stream.listen(
        (json) => seen.add(json['playerCount'] as int),
      );
      addTearDown(sub.cancel);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(seen, isEmpty);
    });
  });
}
