import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';

import 'websocket_message.dart';

enum WsConnectionStatus { connecting, connected, disconnected }

// Connects to a WsServer running on the host device.
// All players — including the host — use this client to communicate.
//
// Typical lifecycle:
//   1. WsClient.connect(hostAddress, playerId, playerName)
//   2. Listen to [messages] or convenience streams (roomStream, etc.)
//   3. Call send() to dispatch actions
//   4. Call close() when leaving the room
class WsClient {
  WsClient._();

  WebSocket? _socket;
  final _messageController = StreamController<WsMessage>.broadcast();
  final _statusController = StreamController<WsConnectionStatus>.broadcast();
  Timer? _pingTimer;

  // Raw stream of every parsed WsMessage received from the server.
  Stream<WsMessage> get messages => _messageController.stream;

  // Connection status changes (connecting → connected → disconnected).
  Stream<WsConnectionStatus> get status => _statusController.stream;

  // Filtered view: emits a new LobbyRoom on every RoomStateMessage.
  Stream<LobbyRoom> get roomStream => messages
      .where((m) => m is RoomStateMessage)
      .map((m) => LobbyRoom.fromJson((m as RoomStateMessage).roomJson));

  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  // Connects to ws://<hostAddress>:<port> and immediately sends JoinRoom.
  static Future<WsClient> connect({
    required String hostAddress,
    required String playerId,
    required String playerName,
    int port = AppConstants.localGamePort,
  }) async {
    final client = WsClient._();
    await client._connect(
      uri: Uri.parse('ws://$hostAddress:$port'),
      playerId: playerId,
      playerName: playerName,
    );
    return client;
  }

  Future<void> _connect({
    required Uri uri,
    required String playerId,
    required String playerName,
  }) async {
    _statusController.add(WsConnectionStatus.connecting);
    _socket = await WebSocket.connect(uri.toString());
    _statusController.add(WsConnectionStatus.connected);

    _socket!.listen(
      (data) => _onData(data as String),
      onDone: _onDisconnect,
      onError: (_) => _onDisconnect(),
      cancelOnError: true,
    );

    // Announce presence to the server right after connecting.
    send(JoinRoomMessage(playerId: playerId, name: playerName));

    // Heartbeat — detects silent connection drops.
    _pingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (isConnected) send(const PingMessage()); },
    );
  }

  // Serializes and sends any WsMessage to the server.
  void send(WsMessage msg) {
    if (!isConnected) return;
    try {
      _socket!.add(jsonEncode(msg.toJson()));
    } catch (_) {}
  }

  // ── incoming ──────────────────────────────────────────────────────────────

  void _onData(String data) {
    try {
      final msg = WsMessage.fromJson(jsonDecode(data) as Map<String, dynamic>);
      _messageController.add(msg);
    } catch (_) {}
  }

  void _onDisconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _socket = null;
    if (!_statusController.isClosed) {
      _statusController.add(WsConnectionStatus.disconnected);
    }
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  // Sends LeaveRoom, closes the socket and disposes streams.
  Future<void> close({required String playerId}) async {
    send(LeaveRoomMessage(playerId: playerId));
    _pingTimer?.cancel();
    _pingTimer = null;
    await _socket?.close(WebSocketStatus.normalClosure);
    _socket = null;
    await _messageController.close();
    await _statusController.close();
  }
}
