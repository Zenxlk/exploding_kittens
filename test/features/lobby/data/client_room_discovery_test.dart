import 'dart:convert';
import 'dart:io';

import 'package:exploding_kittens/features/lobby/data/client_room_discovery.dart';
import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:flutter_test/flutter_test.dart';

// Test de integración: UDP real en loopback, puerto dedicado propio (evita
// chocar con otros archivos de test de red cuando flutter test corre todo
// en paralelo, el comportamiento por defecto).
const _testDiscoveryPort = 18903;

void main() {
  group('ClientRoomDiscovery', () {
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
      sender.send(payload, InternetAddress('127.0.0.1'), _testDiscoveryPort);
    }

    test('discover() expone las salas que van llegando', () async {
      final discovery = ClientRoomDiscovery();
      addTearDown(discovery.stop);

      final events = <List<DiscoveredRoom>>[];
      final sub = discovery.discover(port: _testDiscoveryPort).listen(
            events.add,
          );
      addTearDown(sub.cancel);

      // discover() es un generador async* que recién se pone en marcha
      // (y arranca el socket) cuando alguien se suscribe — esta espera le
      // da tiempo a llegar al start() antes de mandar el beacon.
      await Future.delayed(const Duration(milliseconds: 100));
      sendBeacon(room);

      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return events.isEmpty;
      }).timeout(const Duration(seconds: 2));
      expect(events.last, [room]);
    });

    test(
      'llamar discover() de nuevo reinicia la búsqueda en vez de acumular '
      'el estado anterior',
      () async {
        final discovery = ClientRoomDiscovery();
        addTearDown(discovery.stop);

        final firstEvents = <List<DiscoveredRoom>>[];
        final firstSub = discovery.discover(port: _testDiscoveryPort).listen(
              firstEvents.add,
            );
        await Future.delayed(const Duration(milliseconds: 100));
        sendBeacon(room);
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          return firstEvents.isEmpty;
        }).timeout(const Duration(seconds: 2));
        await firstSub.cancel();

        // Un segundo discover() no debería seguir viendo la sala anterior
        // sin un beacon nuevo — el estado se descarta al reiniciar.
        final events = <List<DiscoveredRoom>>[];
        final sub = discovery.discover(port: _testDiscoveryPort).listen(
              events.add,
            );
        addTearDown(sub.cancel);

        await Future.delayed(const Duration(milliseconds: 200));
        expect(events, isEmpty);

        const room2 = DiscoveredRoom(
          roomId: 'room-2',
          hostName: 'Beto',
          hostAddress: '127.0.0.1',
          port: 8765,
          playerCount: 1,
          maxPlayers: 5,
        );
        sendBeacon(room2);
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          return events.isEmpty;
        }).timeout(const Duration(seconds: 2));
        expect(events.last, [room2]);
      },
    );
  });
}
