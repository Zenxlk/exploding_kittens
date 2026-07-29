import 'package:exploding_kittens/core/errors/exceptions.dart';
import 'package:exploding_kittens/core/errors/failures.dart';
import 'package:exploding_kittens/features/lobby/data/online_lobby_repository.dart';
import 'package:exploding_kittens/network/http/online_rooms_client.dart';
import 'package:exploding_kittens/network/websocket/websocket_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOnlineRoomsClient extends Mock implements OnlineRoomsClient {}

// WsServer no valida el path del request al hacer upgrade — sirve como
// doble de "backend online" acá: lo que se está probando es el lado
// cliente (OnlineLobbyRepository) hablando el mismo protocolo WsMessage
// que cards_game_service ya implementa (ver internal/transport/protocol.go
// en ese repo, verificado carácter por carácter contra este cliente).
Future<WsServer> _startFakeBackend() =>
    WsServer.start(hostId: 'h1', hostName: 'Host', port: 0);

void main() {
  setUp(() {
    registerFallbackValue('exploding_kittens');
  });

  tearDown(dotenv.clean);

  void configureOnlineUrl(int port) {
    dotenv.loadFromString(
      envString: 'ONLINE_SERVER_URL=http://127.0.0.1:$port',
    );
  }

  group('OnlineLobbyRepository.createRoom', () {
    test('conecta al code devuelto por OnlineRoomsClient y trae la sala',
        () async {
      final backend = await _startFakeBackend();
      configureOnlineUrl(backend.port);
      final rooms = MockOnlineRoomsClient();
      when(() => rooms.createRoom(
            gameType: any(named: 'gameType'),
            hostId: any(named: 'hostId'),
            hostName: any(named: 'hostName'),
          )).thenAnswer((_) async => 'AB12CD');

      final repo = OnlineLobbyRepository(roomsClient: rooms);
      final result = await repo.createRoom(playerName: 'Ana', playerId: 'p1');

      expect(result, isA<Success<dynamic>>());
      expect(repo.wsClient?.isConnected, isTrue);
      expect(repo.wsServer, isNull);

      await repo.leaveRoom();
      await backend.close();
    });

    test('devuelve FailureResult si OnlineRoomsClient falla', () async {
      final rooms = MockOnlineRoomsClient();
      when(() => rooms.createRoom(
            gameType: any(named: 'gameType'),
            hostId: any(named: 'hostId'),
            hostName: any(named: 'hostName'),
          )).thenThrow(const NetworkException('sin conexión'));

      final repo = OnlineLobbyRepository(roomsClient: rooms);
      final result = await repo.createRoom(playerName: 'Ana', playerId: 'p1');

      expect(result, isA<FailureResult<dynamic>>());
    });
  });

  group('OnlineLobbyRepository.joinRoom', () {
    test('conecta directo al código de sala (sin HTTP)', () async {
      final backend = await _startFakeBackend();
      configureOnlineUrl(backend.port);

      final repo = OnlineLobbyRepository(roomsClient: MockOnlineRoomsClient());
      final result = await repo.joinRoom(
        hostAddress: 'AB12CD',
        playerName: 'Beto',
        playerId: 'p2',
      );

      expect(result, isA<Success<dynamic>>());
      expect(repo.wsClient?.isConnected, isTrue);

      await repo.leaveRoom();
      await backend.close();
    });
  });

  test('discoverRooms es un stream vacío (sin mDNS online)', () async {
    final repo = OnlineLobbyRepository(roomsClient: MockOnlineRoomsClient());
    expect(await repo.discoverRooms().toList(), isEmpty);
  });

  group('OnlineLobbyRepository — sin conexión activa', () {
    test('setReady falla si no hay sala conectada', () async {
      final repo = OnlineLobbyRepository(roomsClient: MockOnlineRoomsClient());
      final result = await repo.setReady(ready: true);
      expect(result, isA<FailureResult<void>>());
    });

    test('startGame falla si no hay sala conectada', () async {
      final repo = OnlineLobbyRepository(roomsClient: MockOnlineRoomsClient());
      final result = await repo.startGame();
      expect(result, isA<FailureResult<void>>());
    });
  });
}
