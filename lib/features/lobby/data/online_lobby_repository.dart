import 'dart:async';

import 'package:exploding_kittens/core/config/online_config.dart';
import 'package:exploding_kittens/core/errors/failures.dart';
import 'package:exploding_kittens/features/lobby/domain/i_lobby_repository.dart';
import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/network/http/online_rooms_client.dart';
import 'package:exploding_kittens/network/websocket/websocket_client.dart';
import 'package:exploding_kittens/network/websocket/websocket_message.dart';
import 'package:exploding_kittens/network/websocket/websocket_server.dart';

// Nombre de juego que espera cards_game_service en POST /rooms — ver
// games/explodingkittens/engine.go (GameTypeName) en ese repo.
const _gameType = 'exploding_kittens';

// Implementa ILobbyRepository contra el backend online (cards_game_service)
// en vez de LAN: sin WsServer local, sin mDNS — el servidor remoto es quien
// arma el código de sala y orquesta la partida. [hostAddress] en joinRoom
// se reinterpreta como el código de sala (no una IP), ver el doc del
// método — misma interfaz que LobbyRepository (LAN) para que LobbyNotifier
// pueda elegir cuál instanciar sin ramas especiales en el resto del código.
class OnlineLobbyRepository implements ILobbyRepository {
  OnlineLobbyRepository({OnlineRoomsClient? roomsClient})
      : _rooms = roomsClient ?? OnlineRoomsClient();

  final OnlineRoomsClient _rooms;
  WsClient? _client;
  String? _localPlayerId;

  @override
  Stream<LobbyRoom> get roomStream =>
      _client?.roomStream ?? const Stream.empty();

  @override
  WsClient? get wsClient => _client;

  // El modo online no levanta ningún WsServer local — la sala vive en el
  // proceso del backend, no en este dispositivo.
  @override
  WsServer? get wsServer => null;

  // ── host ──────────────────────────────────────────────────────────────────

  @override
  Future<Result<LobbyRoom>> createRoom({
    required String playerName,
    required String playerId,
    String? authToken,
  }) async {
    try {
      _localPlayerId = playerId;

      final code = await _rooms.createRoom(
        gameType: _gameType,
        hostId: playerId,
        hostName: playerName,
      );

      _client = await WsClient.connectToUri(
        uri: OnlineConfig.wsUri('/ws/$code'),
        playerId: playerId,
        playerName: playerName,
        authToken: authToken,
      );

      final room = await _waitForRoom();
      return Success(room);
    } catch (e) {
      await _cleanup();
      return FailureResult(NetworkFailure('No se pudo crear la sala: $e'));
    }
  }

  // ── client ────────────────────────────────────────────────────────────────

  // Sin mDNS/descubrimiento en modo online — el jugador necesita que le
  // pasen el código de sala por fuera (ver UI de LobbyScreen).
  @override
  Stream<List<DiscoveredRoom>> discoverRooms() => const Stream.empty();

  @override
  Future<Result<LobbyRoom>> joinRoom({
    // Reinterpretado como el código de sala (p. ej. "AB12CD") devuelto por
    // createRoom del host — no una IP LAN, a pesar del nombre del campo
    // (mismo campo que LobbyRepository, para no bifurcar la interfaz).
    required String hostAddress,
    required String playerName,
    required String playerId,
    String? authToken,
  }) async {
    try {
      _localPlayerId = playerId;

      _client = await WsClient.connectToUri(
        uri: OnlineConfig.wsUri('/ws/$hostAddress'),
        playerId: playerId,
        playerName: playerName,
        authToken: authToken,
      );

      final room = await _waitForRoom();
      return Success(room);
    } catch (e) {
      await _cleanup();
      return FailureResult(NetworkFailure('No se pudo unir a la sala: $e'));
    }
  }

  // ── shared ────────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> setReady({required bool ready}) async {
    if (_client == null || !_client!.isConnected) {
      return FailureResult(const NetworkFailure('No conectado a una sala'));
    }
    _client!.send(SetReadyMessage(ready: ready));
    return const Success(null);
  }

  @override
  Future<Result<void>> startGame() async {
    if (_client == null || !_client!.isConnected) {
      return FailureResult(const NetworkFailure('No conectado a una sala'));
    }
    _client!.send(const StartGameMessage());
    return const Success(null);
  }

  @override
  Future<void> leaveRoom() async {
    final playerId = _localPlayerId;
    if (playerId != null && _client != null) {
      await _client!.close(playerId: playerId);
    }
    await _cleanup();
  }

  // ── internals ─────────────────────────────────────────────────────────────

  // Usa el lastRoom en caché si el RoomStateMessage llegó antes de poder
  // suscribirse; si no, espera el próximo — mismo patrón que
  // LobbyRepository.joinRoom (acá aplica también a createRoom porque, a
  // diferencia de WsServer local, el estado inicial no está disponible
  // sincrónicamente: solo el backend remoto lo tiene).
  Future<LobbyRoom> _waitForRoom() async {
    return _client!.lastRoom ??
        await _client!.roomStream.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException(
            'No llegó el estado de la sala desde el servidor',
          ),
        );
  }

  Future<void> _cleanup() async {
    _client = null;
    _localPlayerId = null;
  }
}
