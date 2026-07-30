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
// A disconnect that wasn't triggered by close() (network drop, host
// momentarily unreachable) schedules an automatic reconnect attempt with
// exponential back-off (1s, 2s, 4s, ... capped at 16s, reset on success).
// messages/status/roomStream keep working across a reconnect — callers never
// need to re-subscribe. This is the client-side half of Phase 5 reconnection;
// WsServer.onPlayerDisconnected + ReconnectionManager is the host-side half.
class WsClient {
  WsClient._();

  WebSocketChannel? _channel;
  bool _connected = false;
  bool _explicitClose = false;
  LobbyRoom? _lastRoom;
  GameStateMessage? _lastGameState;
  final _messageController = StreamController<WsMessage>.broadcast();
  final _statusController = StreamController<WsConnectionStatus>.broadcast();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Duration _reconnectBackoff = _initialBackoff;

  static const _initialBackoff = Duration(seconds: 1);
  static const _maxBackoff = Duration(seconds: 16);

  Uri? _uri;
  String? _playerId;
  String? _playerName;

  // JWT de Supabase (features/auth), si el jugador está autenticado —
  // seteado en _connect() igual que _playerId/_playerName, así que
  // _attemptReconnect() lo reenvía solo por reutilizar esos mismos campos.
  // Null en modo invitado, sin cambio de comportamiento.
  String? _authToken;

  // Emitido por el servidor en el primer join_room de este playerId en la
  // sala actual (SessionTokenMessage). Se reenvía en cada join_room
  // posterior para que una reconexión tras una caída de red pueda probar
  // que es el mismo jugador — ver cards_game_service/docs/TOKENS.md para
  // el contrato del lado servidor.
  //
  // TODO(sesión persistida): esto vive solo en memoria, a diferencia de
  // playerId (persistido vía playerIdProvider/shared_preferences, ver
  // lobby_providers.dart). Un crash/reinicio de la app conserva el mismo
  // playerId pero pierde este token, así que el backend online
  // (OnlineLobbyRepository, ya conectado desde Fase 7) rechazaría la
  // reconexión como un playerId ya reclamado sin poder probarlo. Falta
  // darle su propio almacenamiento persistido — ver ROADMAP.md, sección
  // "Modo online".
  String? _sessionToken;

  // Raw stream of every parsed WsMessage received from the server.
  Stream<WsMessage> get messages => _messageController.stream;

  // Connection status changes (connecting → connected → disconnected).
  Stream<WsConnectionStatus> get status => _statusController.stream;

  // Last room state received. Populated before the stream emits, so callers
  // that miss the first stream event can still read the current state.
  LobbyRoom? get lastRoom => _lastRoom;

  // Último GameState recibido. Mismo motivo que _lastRoom: el host arranca
  // el motor y transmite el primer GameState casi al instante (todo local,
  // vía loopback — ver gameNetworkBridgeProvider), mientras que en un
  // cliente remoto GameScreen recién se suscribe a `messages` (broadcast
  // stream, sin replay) después de navegar y montar la pantalla — un viaje
  // de red real que en modo online (Internet, no LAN) puede tardar más que
  // ese primer broadcast. Sin este caché, ese primer GameState se pierde
  // para siempre y el jugador queda trabado en "Repartiendo cartas…".
  GameStateMessage? get lastGameState => _lastGameState;

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
    String? authToken,
  }) async {
    final client = WsClient._();
    await client._connect(
      uri: Uri.parse('ws://$hostAddress:$port'),
      playerId: playerId,
      playerName: playerName,
      authToken: authToken,
    );
    return client;
  }

  // Conecta directo a una Uri completa en vez de armar ws://host:port —
  // para el modo online (Fase 7), donde el backend expone wss://.../ws/{code}
  // en vez de una IP LAN con puerto fijo (ver OnlineConfig.wsUri()).
  // _connect()/_attemptReconnect() ya son genéricos en Uri, así que esto
  // reutiliza toda la misma máquina de ping/reconexión sin duplicarla.
  static Future<WsClient> connectToUri({
    required Uri uri,
    required String playerId,
    required String playerName,
    String? authToken,
  }) async {
    final client = WsClient._();
    await client._connect(
      uri: uri,
      playerId: playerId,
      playerName: playerName,
      authToken: authToken,
    );
    return client;
  }

  Future<void> _connect({
    required Uri uri,
    required String playerId,
    required String playerName,
    String? authToken,
  }) async {
    _uri = uri;
    _playerId = playerId;
    _playerName = playerName;
    _authToken = authToken;

    _statusController.add(WsConnectionStatus.connecting);

    _channel = IOWebSocketChannel.connect(uri);

    // Wait for the handshake to complete; throws if the server is unreachable.
    await _channel!.ready;

    _connected = true;
    _reconnectBackoff = _initialBackoff;
    _statusController.add(WsConnectionStatus.connected);

    _channel!.stream.listen(
      (data) => _onData(data as String),
      onDone: _onDisconnect,
      onError: (_) => _onDisconnect(),
      cancelOnError: true,
    );

    // Announce presence to the server right after connecting. token is
    // null on a fresh join; on a reconnect it's whatever this playerId was
    // issued earlier in this room, proving it's the same player.
    send(JoinRoomMessage(
      playerId: playerId,
      name: playerName,
      token: _sessionToken,
      authToken: _authToken,
    ));

    // Heartbeat — detects silent connection drops.
    _pingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_connected) send(const PingMessage());
      },
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
      if (msg is GameStateMessage) {
        _lastGameState = msg;
      }
      if (msg is SessionTokenMessage) {
        _sessionToken = msg.token;
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
    if (!_explicitClose) _scheduleReconnect();
  }

  // ── reconexión (Fase 5) ──────────────────────────────────────────────────

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectBackoff, _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    if (_explicitClose) return;
    final uri = _uri;
    final playerId = _playerId;
    final playerName = _playerName;
    // Capturado antes de _connect(): reasigna _authToken a partir de este
    // mismo parámetro, así que sin capturarlo antes se perdería en el
    // segundo intento de reconexión en adelante (quedaría null).
    final authToken = _authToken;
    if (uri == null || playerId == null || playerName == null) return;

    try {
      await _connect(
        uri: uri,
        playerId: playerId,
        playerName: playerName,
        authToken: authToken,
      );
    } catch (_) {
      _reconnectBackoff = _reconnectBackoff * 2;
      if (_reconnectBackoff > _maxBackoff) _reconnectBackoff = _maxBackoff;
      _scheduleReconnect();
    }
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  // Sends LeaveRoom, closes the channel and disposes streams.
  Future<void> close({required String playerId}) async {
    _explicitClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    send(LeaveRoomMessage(playerId: playerId));
    _sessionToken = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _connected = false;
    await _channel?.sink.close(WebSocketStatus.normalClosure);
    _channel = null;
    await _messageController.close();
    await _statusController.close();
  }
}
