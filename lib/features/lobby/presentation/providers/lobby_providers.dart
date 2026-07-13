import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:exploding_kittens/features/lobby/data/lobby_repository.dart';
import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/settings/presentation/providers/settings_providers.dart';
import 'package:exploding_kittens/core/errors/failures.dart';
import 'package:exploding_kittens/network/websocket/websocket_client.dart';
import 'package:exploding_kittens/network/websocket/websocket_server.dart';

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
  const LobbyInRoom({required this.room, required this.localPlayerId});
  final LobbyRoom room;
  final String localPlayerId;

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

final playerIdProvider = FutureProvider<String>((ref) async {
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
  final _repo = LobbyRepository();
  StreamSubscription<LobbyRoom>? _roomSub;
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

  // ── host ────────────────────────────────────────────────────────────────

  Future<void> createRoom() async {
    final settings = await ref.read(settingsProvider.future);
    final playerId = await ref.read(playerIdProvider.future);
    _localPlayerId = playerId;

    state = const LobbyConnecting();

    final result = await _repo.createRoom(
      playerName: settings.playerName,
      playerId: playerId,
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

  Future<void> joinRoom(String hostAddress) async {
    final settings = await ref.read(settingsProvider.future);
    final playerId = await ref.read(playerIdProvider.future);
    _localPlayerId = playerId;

    await _discoverySub?.cancel();
    _discoverySub = null;

    state = const LobbyConnecting();

    final result = await _repo.joinRoom(
      hostAddress: hostAddress,
      playerName: settings.playerName,
      playerId: playerId,
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
      if (id != null) state = LobbyInRoom(room: room, localPlayerId: id);
    });
  }

  void _disposeAll() {
    _roomSub?.cancel();
    _discoverySub?.cancel();
    _repo.leaveRoom();
  }
}
