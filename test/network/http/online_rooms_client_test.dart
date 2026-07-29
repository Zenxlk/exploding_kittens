import 'dart:convert';

import 'package:exploding_kittens/core/errors/exceptions.dart';
import 'package:exploding_kittens/network/http/online_rooms_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'ONLINE_SERVER_URL=https://example.run.app',
    );
  });
  tearDown(dotenv.clean);

  group('OnlineRoomsClient.createRoom', () {
    test('devuelve el code de una respuesta 200 exitosa', () async {
      http.Request? captured;
      final client = OnlineRoomsClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'code': 'AB12CD'}),
            200,
          );
        }),
      );

      final code = await client.createRoom(
        gameType: 'exploding_kittens',
        hostId: 'p1',
        hostName: 'Ana',
      );

      expect(code, 'AB12CD');
      expect(captured!.url.toString(), 'https://example.run.app/rooms');
      expect(captured!.method, 'POST');
      expect(
        jsonDecode(captured!.body),
        equals({
          'gameType': 'exploding_kittens',
          'hostId': 'p1',
          'hostName': 'Ana',
        }),
      );
    });

    test('lanza NetworkException si el servidor responde con error', () async {
      final client = OnlineRoomsClient(
        httpClient: MockClient(
          (request) async => http.Response('gameType inválido', 400),
        ),
      );

      expect(
        () => client.createRoom(
          gameType: 'bad',
          hostId: 'p1',
          hostName: 'Ana',
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('lanza NetworkException si la request falla (sin conexión)', () async {
      final client = OnlineRoomsClient(
        httpClient: MockClient((request) async => throw Exception('sin red')),
      );

      expect(
        () => client.createRoom(
          gameType: 'exploding_kittens',
          hostId: 'p1',
          hostName: 'Ana',
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
