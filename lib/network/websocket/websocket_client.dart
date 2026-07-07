import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocketStatus;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';

import 'websocket_message.dart';

enum WsConnectionStatus { connecting, connected, disconnected }

// Connects to a WsServer running on the host device.
// Uses web_socket_channel (Flutter-recommended) instead of dart:io directly,
// which handles platform differences on Android/iOS more reliably.
//
// All players — including the host — use this client to communicate.
//
// Typical lifecycle:
//   1. WsClient.connect(hostAddress, playerId, playerName)
//   2. Listen to [messages] or convenience streams (roomStream, etc.)
//   3. Call send() to dispatch actions
//   4. Call close() when leaving the room
//
// TODO(improvement): add automatic reconnection with exponential back-off
// before delegating to ReconnectionManager (Phase 5). Right now a disconnect
// emits WsConnectionStatus.disconnected and the UI must react.
class WsClient {
  WsClient._();

  WebSocketChannel? _channel;
  bool _connected = false;
  LobbyRoom? _lastRoom;
  final _messageController = StreamController<WsMessage>.broadcast();
  final _statusController = StreamController<WsConnectionStatus>.broadcast();
  Timer? _pingTimer;

  // Raw stream of every parsed WsMessage received from the server.
  Stream<WsMessage> get messages => _messageController.stream;

  // Connection status changes (connecting → connected → disconnected).
  Stream<WsConnectionStatus> get status => _statusController.stream;

  // Last room state received. Populated before the stream emits, so callers
  // that miss the first stream event can still read the current state.
  LobbyRoom? get lastRoom => _lastRoom;

  // Filtered view: emits a new LobbyRoom on every RoomStateMessage.
  Stream<LobbyRoom> get roomStream => messages
      .where((m) => m is RoomStateMessage)
      .map((m) => LobbyRoom.fromJson((m as RoomStateMessage).roomJson));

  bool get isConnected => _connected;

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

    _channel = IOWebSocketChannel.connect(uri);

    // Wait for the handshake to complete; throws if the server is unreachable.
    await _channel!.ready;

    _connected = true;
    _statusController.add(WsConnectionStatus.connected);

    _channel!.stream.listen(
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
      (_) { if (_connected) send(const PingMessage()); },
    );
  }

  // Serializes and sends any WsMessage to the server.
  void send(WsMessage msg) {
    if (!_connected) return;
    try {
      _channel!.sink.add(jsonEncode(msg.toJson()));
    } catch (_) {}
  }

  // ── incoming ──────────────────────────────────────────────────────────────

  void _onData(String data) {
    try {
      final msg = WsMessage.fromJson(jsonDecode(data) as Map<String, dynamic>);
      // Cache before emitting so lastRoom is always readable even if no
      // subscriber was attached when the first RoomStateMessage arrived.
      if (msg is RoomStateMessage) {
        _lastRoom = LobbyRoom.fromJson(msg.roomJson);
      }
      _messageController.add(msg);
    } catch (_) {}
  }

  void _onDisconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _connected = false;
    _channel = null;
    if (!_statusController.isClosed) {
      _statusController.add(WsConnectionStatus.disconnected);
    }
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  // Sends LeaveRoom, closes the channel and disposes streams.
  Future<void> close({required String playerId}) async {
    send(LeaveRoomMessage(playerId: playerId));
    _pingTimer?.cancel();
    _pingTimer = null;
    _connected = false;
    await _channel?.sink.close(WebSocketStatus.normalClosure);
    _channel = null;
    await _messageController.close();
    await _statusController.close();
  }
}
