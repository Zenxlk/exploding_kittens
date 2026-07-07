import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_player.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_status.dart';
import 'websocket_message.dart';

// The host device runs one WsServer instance per game session.
// All players — including the host — connect as WebSocket clients.
//
// Message flow:
//   client  →  server : JoinRoom, SetReady, LeaveRoom, StartGame, Ping
//   server  →  client : RoomState (broadcast), GameStarting (broadcast),
//                        PlayerKicked (targeted), WsError (targeted), Pong
class WsServer {
  WsServer._({required String hostId}) : _hostId = hostId;

  final String _hostId;
  HttpServer? _httpServer;

  // Connections whose JoinRoomMessage has not arrived yet.
  final _pending = <WebSocket>{};

  // playerId → WebSocket for fully identified players.
  final _clients = <String, WebSocket>{};

  LobbyRoom? _room;
  final _roomController = StreamController<LobbyRoom>.broadcast();

  Stream<LobbyRoom> get roomStream => _roomController.stream;
  LobbyRoom? get currentRoom => _room;
  bool get isRunning => _httpServer != null;

  // Starts the server and initialises the room with the host as first player.
  static Future<WsServer> start({
    required String hostId,
    required String hostName,
  }) async {
    final server = WsServer._(hostId: hostId);
    await server._bind(hostName: hostName);
    return server;
  }

  Future<void> _bind({required String hostName}) async {
    _room = LobbyRoom(
      id: const Uuid().v4(),
      hostId: _hostId,
      players: [
        LobbyPlayer(id: _hostId, name: hostName, isHost: true, isReady: true),
      ],
    );

    _httpServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      AppConstants.localGamePort,
    );

    _httpServer!.listen((req) => _upgradeRequest(req).catchError((_) {}));
    _roomController.add(_room!);
  }

  Future<void> _upgradeRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(request);
    _pending.add(ws);
    ws.listen(
      (data) => _onData(ws, data as String),
      onDone: () => _onDisconnect(ws),
      onError: (_) => _onDisconnect(ws),
      cancelOnError: true,
    );
  }

  // ── message dispatch ──────────────────────────────────────────────────────

  void _onData(WebSocket ws, String data) {
    try {
      final msg = WsMessage.fromJson(jsonDecode(data) as Map<String, dynamic>);
      _dispatch(ws, msg);
    } catch (e) {
      _send(ws, WsErrorMessage(message: 'Invalid message: $e'));
    }
  }

  void _dispatch(WebSocket ws, WsMessage msg) {
    switch (msg) {
      case JoinRoomMessage(:final playerId, :final name):
        _onJoin(ws, playerId, name);
      case SetReadyMessage(:final ready):
        _onSetReady(ws, ready);
      case LeaveRoomMessage(:final playerId):
        _onLeave(playerId);
      case StartGameMessage():
        _onStartGame(ws);
      case PingMessage():
        _send(ws, const PongMessage());
      default:
        break;
    }
  }

  // ── lobby handlers ────────────────────────────────────────────────────────

  void _onJoin(WebSocket ws, String playerId, String name) {
    _pending.remove(ws);
    final room = _room!;

    // Host or returning player — just update the socket reference.
    if (room.players.any((p) => p.id == playerId)) {
      _clients[playerId] = ws;
      _send(ws, RoomStateMessage(roomJson: room.toJson()));
      return;
    }

    if (room.isFull) {
      _send(ws, const WsErrorMessage(message: 'Room is full'));
      return;
    }
    if (room.status != LobbyStatus.waiting) {
      _send(ws, const WsErrorMessage(message: 'Game already started'));
      return;
    }

    _clients[playerId] = ws;
    _updateRoom(room.copyWith(
      players: [...room.players, LobbyPlayer(id: playerId, name: name)],
    ));
    _broadcastRoomState();
  }

  void _onSetReady(WebSocket ws, bool ready) {
    final playerId = _playerIdFor(ws);
    if (playerId == null) return;

    final room = _room!;
    _updateRoom(room.copyWith(
      players: room.players
          .map((p) => p.id == playerId ? p.copyWith(isReady: ready) : p)
          .toList(),
    ));
    _broadcastRoomState();
  }

  void _onLeave(String playerId) {
    _clients.remove(playerId);
    final room = _room!;

    if (playerId == _hostId) {
      _broadcast(const PlayerKickedMessage(reason: 'Host closed the room'));
      close();
      return;
    }

    _updateRoom(room.copyWith(
      players: room.players.where((p) => p.id != playerId).toList(),
    ));
    _broadcastRoomState();
  }

  void _onStartGame(WebSocket ws) {
    if (_playerIdFor(ws) != _hostId) {
      _send(ws, const WsErrorMessage(message: 'Only the host can start the game'));
      return;
    }
    final room = _room!;
    if (!room.canStart) {
      _send(ws, const WsErrorMessage(message: 'Not enough ready players'));
      return;
    }
    _updateRoom(room.copyWith(status: LobbyStatus.starting));
    _broadcast(const GameStartingMessage());
  }

  void _onDisconnect(WebSocket ws) {
    _pending.remove(ws);
    final playerId = _playerIdFor(ws);
    if (playerId != null) _onLeave(playerId);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String? _playerIdFor(WebSocket ws) =>
      _clients.entries.where((e) => e.value == ws).map((e) => e.key).firstOrNull;

  void _send(WebSocket ws, WsMessage msg) {
    try {
      ws.add(jsonEncode(msg.toJson()));
    } catch (_) {}
  }

  void _broadcast(WsMessage msg) {
    final encoded = jsonEncode(msg.toJson());
    for (final ws in _clients.values) {
      try {
        ws.add(encoded);
      } catch (_) {}
    }
  }

  void _broadcastRoomState() =>
      _broadcast(RoomStateMessage(roomJson: _room!.toJson()));

  void _updateRoom(LobbyRoom room) {
    _room = room;
    _roomController.add(room);
  }

  Future<void> close() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
    await _roomController.close();
    _clients.clear();
    _pending.clear();
  }
}
