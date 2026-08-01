import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:exploding_kittens/features/auth/presentation/providers/auth_providers.dart';
import 'package:exploding_kittens/features/lobby/data/lobby_repository.dart';
import 'package:exploding_kittens/features/lobby/data/online_lobby_repository.dart';
import 'package:exploding_kittens/features/lobby/domain/i_lobby_repository.dart';
import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/settings/presentation/providers/settings_providers.dart';
import 'package:exploding_kittens/core/errors/failures.dart';
import 'package:exploding_kittens/network/websocket/websocket_client.dart';
import 'package:exploding_kittens/network/websocket/websocket_server.dart';

// LAN (mDNS + WsServer local) u online (cards_game_service por Internet,
// Fase 7) — el jugador lo elige explícitamente en la UI antes de crear/unirse
// a una sala; no se decide solo según si hay sesión de Supabase activa, para
// no forzar a jugadores de la misma red WiFi a pasar por Internet solo
// porque el build tenga un backend online configurado (ver ROADMAP.md).
enum LobbyMode { lan, online }

// ── State ─────────────────────────────────────────────────────────────────────

sealed class LobbyState {
  const LobbyState();
}

class LobbyIdle extends LobbyState {
  const LobbyIdle();
}

class LobbyConnecting extends LobbyState {
  const LobbyConnecting();
}

class LobbyDiscovering extends LobbyState {
  const LobbyDiscovering({this.rooms = const []});
  final List<DiscoveredRoom> rooms;
}

class LobbyInRoom extends LobbyState {
  const LobbyInRoom(
      {required this.room, required this.localPlayerId, this.error});
  final LobbyRoom room;
  final String localPlayerId;

  // Último WsErrorMessage del servidor (ej. "Faltan jugadores listos" al
  // rechazar un start_game) — transitorio, mismo patrón que
  // GameRunning.error en game_providers.dart: se limpia solo en cuanto
  // llega el próximo room_state legítimo (ver _subscribeToRoom), no hace
  // falta un método explícito para descartarlo.
  final String? error;

  bool get isHost => room.hostId == localPlayerId;

  bool get isLocalPlayerReady =>
      room.players
          .where((p) => p.id == localPlayerId)
          .map((p) => p.isReady)
          .firstOrNull ??
      false;
}

class LobbyError extends LobbyState {
  const LobbyError(this.message);
  final String message;
}

// ── Utility providers ─────────────────────────────────────────────────────────

// Identidad de red del jugador local. Se persiste para que sobreviva a un
// reinicio/crash de la app — sin esto, reconectar tras un crash (grace
// period de Fase 5) siempre parecería un jugador nuevo entrando, ya que el
// host empareja las reconexiones por playerId.
const _playerIdPrefsKey = 'lobby_player_id';

// Prefiere el "sub" de la sesión de Supabase (Fase 7) por sobre el UUID de
// invitado generado acá — mismo criterio que usa cards_game_service al
// validar el authToken, así que el playerId que ve el servidor y el que
// arma el cliente terminan siendo el mismo id. Sin Supabase configurado,
// authSessionProvider resuelve a null y este provider se comporta exacto
// igual que antes de Fase 7.
//
// Importante: si el jugador ya tenía un UUID de invitado guardado y
// después se autentica, el playerId efectivo cambia (el UUID viejo queda
// en SharedPreferences pero deja de usarse) — no hay migración automática
// de estado local ligado a ese UUID viejo, ver docs/ARCHITECTURE.md.
final playerIdProvider = FutureProvider<String>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session != null) return session.playerId;

  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_playerIdPrefsKey);
  if (existing != null) return existing;

  final generated = const Uuid().v4();
  await prefs.setString(_playerIdPrefsKey, generated);
  return generated;
});

// Current WiFi IP — shown to the host so others can join manually.
final wifiIpProvider = FutureProvider<String?>(
  (_) => NetworkInfo().getWifiIP(),
);

// ── Notifier ──────────────────────────────────────────────────────────────────

final lobbyProvider =
    NotifierProvider<LobbyNotifier, LobbyState>(LobbyNotifier.new);

class LobbyNotifier extends Notifier<LobbyState> {
  // LAN por defecto: cualquier código existente que no pase `mode` (los
  // tests actuales, por ejemplo) se sigue comportando exactamente igual
  // que antes de la Fase 7 de modo online.
  ILobbyRepository _repo = LobbyRepository();
  StreamSubscription<LobbyRoom>? _roomSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<List<DiscoveredRoom>>? _discoverySub;
  String? _localPlayerId;

  @override
  LobbyState build() {
    ref.onDispose(_disposeAll);
    return const LobbyIdle();
  }

  // Exposed so the game feature (Fase 5) can relay in-game messages through
  // the same live connection the lobby already opened, instead of a second
  // one — matches the project's "switching WebSocket URL is the only online
  // migration" design intent.
  WsClient? get wsClient => _repo.wsClient;
  WsServer? get wsServer => _repo.wsServer;
  bool get isOnline => _repo.isOnline;

  // ── host ────────────────────────────────────────────────────────────────

  Future<void> createRoom({LobbyMode mode = LobbyMode.lan}) async {
    _repo =
        mode == LobbyMode.online ? OnlineLobbyRepository() : LobbyRepository();

    final settings = await ref.read(settingsProvider.future);
    final playerId = await ref.read(playerIdProvider.future);
    final session = await ref.read(authSessionProvider.future);
    _localPlayerId = playerId;

    state = const LobbyConnecting();

    final result = await _repo.createRoom(
      playerName: settings.playerName,
      playerId: playerId,
      authToken: session?.accessToken,
    );

    switch (result) {
      case Success(:final value):
        _subscribeToRoom();
        state = LobbyInRoom(room: value, localPlayerId: playerId);
      case FailureResult(:final failure):
        state = LobbyError(failure.message);
    }
  }

  // ── client ───────────────────────────────────────────────────────────────

  void startDiscovery() {
    state = const LobbyDiscovering();
    _discoverySub?.cancel();
    _discoverySub = _repo.discoverRooms().listen((rooms) {
      if (state is LobbyDiscovering) {
        state = LobbyDiscovering(rooms: rooms);
      }
    });
  }

  // [target] es una IP LAN para LobbyMode.lan, o un código de sala para
  // LobbyMode.online — ver el doc de ILobbyRepository.joinRoom.
  Future<void> joinRoom(String target, {LobbyMode mode = LobbyMode.lan}) async {
    _repo =
        mode == LobbyMode.online ? OnlineLobbyRepository() : LobbyRepository();

    final settings = await ref.read(settingsProvider.future);
    final playerId = await ref.read(playerIdProvider.future);
    final session = await ref.read(authSessionProvider.future);
    _localPlayerId = playerId;

    await _discoverySub?.cancel();
    _discoverySub = null;

    state = const LobbyConnecting();

    final result = await _repo.joinRoom(
      hostAddress: target,
      playerName: settings.playerName,
      playerId: playerId,
      authToken: session?.accessToken,
    );

    switch (result) {
      case Success(:final value):
        _subscribeToRoom();
        state = LobbyInRoom(room: value, localPlayerId: playerId);
      case FailureResult(:final failure):
        state = LobbyError(failure.message);
    }
  }

  // ── shared ───────────────────────────────────────────────────────────────

  Future<void> setReady({required bool ready}) async {
    await _repo.setReady(ready: ready);
  }

  Future<void> startGame() async {
    await _repo.startGame();
  }

  Future<void> leaveRoom() async {
    await _repo.leaveRoom();
    state = const LobbyIdle();
  }

  // ── internals ────────────────────────────────────────────────────────────

  void _subscribeToRoom() {
    _roomSub?.cancel();
    _roomSub = _repo.roomStream.listen((room) {
      final id = _localPlayerId;
      // Se reconstruye entero (sin error) a propósito: un room_state
      // legítimo es la señal de que lo que haya pasado ya se resolvió, así
      // que de paso limpia cualquier error transitorio previo.
      if (id != null) state = LobbyInRoom(room: room, localPlayerId: id);
    });

    _errorSub?.cancel();
    _errorSub = _repo.errorStream.listen((message) {
      final current = state;
      if (current is LobbyInRoom) {
        state = LobbyInRoom(
          room: current.room,
          localPlayerId: current.localPlayerId,
          error: message,
        );
      }
    });
  }

  void _disposeAll() {
    _roomSub?.cancel();
    _errorSub?.cancel();
    _discoverySub?.cancel();
    _repo.leaveRoom();
  }
}
