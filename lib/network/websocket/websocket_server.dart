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

  // Forwarded ActionMessages, tagged with the sender's playerId — the server
  // doesn't know anything about GameState/TurnAction, it just routes bytes;
  // the game feature layer decodes and applies them.
  final _actionController = StreamController<
      ({String playerId, Map<String, dynamic> actionJson})>.broadcast();

  // True once the host has started the actual game (not just the lobby).
  // While false, a socket drop is a lobby departure (_onLeave, as before);
  // once true, it's a mid-game disconnect that goes through the grace-period
  // hooks below instead of immediately removing the player.
  bool _gameStarted = false;

  // Wired by the game feature layer (ReconnectionManager) once the game
  // starts; network/ deliberately knows nothing about GameState/PlayerStatus.
  void Function(String playerId)? onPlayerDisconnected;
  void Function(String playerId)? onPlayerReconnected;

  Stream<LobbyRoom> get roomStream => _roomController.stream;
  Stream<({String playerId, Map<String, dynamic> actionJson})>
      get actionMessages => _actionController.stream;
  LobbyRoom? get currentRoom => _room;
  bool get isRunning => _httpServer != null;

  void markGameStarted() => _gameStarted = true;

  // Starts the server and initialises the room with the host as first player.
  // port: pass 0 to let the OS assign a free port (useful in tests).
  static Future<WsServer> start({
    required String hostId,
    required String hostName,
    int port = AppConstants.localGamePort,
  }) async {
    final server = WsServer._(hostId: hostId);
    await server._bind(hostName: hostName, port: port);
    return server;
  }

  // Actual bound port — may differ from the requested port when 0 was passed.
  int get port => _httpServer?.port ?? AppConstants.localGamePort;

  Future<void> _bind({required String hostName, required int port}) async {
    _room = LobbyRoom(
      id: const Uuid().v4(),
      hostId: _hostId,
      players: [
        LobbyPlayer(id: _hostId, name: hostName, isHost: true, isReady: true),
      ],
    );

    _httpServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
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
      case ActionMessage(:final actionJson):
        _onAction(ws, actionJson);
      case PlayerReconnectedMessage(:final playerId):
        onPlayerReconnected?.call(playerId);
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
      onPlayerReconnected?.call(playerId);
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
      _send(ws,
          const WsErrorMessage(message: 'Only the host can start the game'));
      return;
    }
    final room = _room!;
    if (!room.canStart) {
      _send(ws, const WsErrorMessage(message: 'Not enough ready players'));
      return;
    }
    markGameStarted();
    _updateRoom(room.copyWith(status: LobbyStatus.starting));
    _broadcast(const GameStartingMessage());
    // Send updated room so clients see status:starting via roomStream and
    // can react without needing to listen to the raw messages stream.
    _broadcastRoomState();
  }

  void _onDisconnect(WebSocket ws) {
    _pending.remove(ws);
    final playerId = _playerIdFor(ws);
    if (playerId == null) return;

    // Mid-game, non-host disconnect: keep the player in the room (they may
    // reconnect within the grace period) instead of removing them outright.
    if (_gameStarted && playerId != _hostId) {
      _clients.remove(playerId);
      onPlayerDisconnected?.call(playerId);
      return;
    }

    _onLeave(playerId);
  }

  void _onAction(WebSocket ws, Map<String, dynamic> actionJson) {
    final playerId = _playerIdFor(ws);
    if (playerId == null) return;
    _actionController.add((playerId: playerId, actionJson: actionJson));
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String? _playerIdFor(WebSocket ws) => _clients.entries
      .where((e) => e.value == ws)
      .map((e) => e.key)
      .firstOrNull;

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

  // Public wrappers used by the game feature layer (network/ itself stays
  // agnostic of GameState/GameEvent — it only knows about WsMessage).
  void broadcast(WsMessage msg) => _broadcast(msg);

  void sendToPlayer(String playerId, WsMessage msg) {
    final ws = _clients[playerId];
    if (ws != null) _send(ws, msg);
  }

  void _broadcastRoomState() =>
      _broadcast(RoomStateMessage(roomJson: _room!.toJson()));

  void _updateRoom(LobbyRoom room) {
    _room = room;
    _roomController.add(room);
  }

  Future<void> close() async {
    // HttpServer.close(force: true) does NOT close sockets that already
    // completed the WebSocket upgrade (they're detached from HttpServer's own
    // connection tracking) — without this, connected clients would never see
    // a disconnect and their sockets would just leak until the OS reaps them.
    for (final ws in {..._clients.values, ..._pending}) {
      unawaited(ws.close().catchError((_) {}));
    }
    await _httpServer?.close(force: true);
    _httpServer = null;
    await _roomController.close();
    await _actionController.close();
    _clients.clear();
    _pending.clear();
  }
}
