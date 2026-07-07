import 'package:equatable/equatable.dart';
import '../../../../core/constants/game_constants.dart';
import 'lobby_player.dart';
import 'lobby_status.dart';

class LobbyRoom extends Equatable {
  const LobbyRoom({
    required this.id,
    required this.hostId,
    required this.players,
    this.maxPlayers = GameConstants.maxPlayers,
    this.status = LobbyStatus.waiting,
  });

  final String id;
  final String hostId;
  final List<LobbyPlayer> players;
  final int maxPlayers;
  final LobbyStatus status;

  bool get isFull => players.length >= maxPlayers;
  bool get canStart =>
      players.length >= GameConstants.minPlayers &&
      players.every((p) => p.isReady || p.isHost);

  LobbyPlayer? get host =>
      players.where((p) => p.id == hostId).firstOrNull;

  LobbyRoom copyWith({
    List<LobbyPlayer>? players,
    LobbyStatus? status,
  }) {
    return LobbyRoom(
      id: id,
      hostId: hostId,
      players: players ?? this.players,
      maxPlayers: maxPlayers,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostId': hostId,
        'players': players.map((p) => p.toJson()).toList(),
        'maxPlayers': maxPlayers,
        'status': status.name,
      };

  factory LobbyRoom.fromJson(Map<String, dynamic> j) => LobbyRoom(
        id: j['id'] as String,
        hostId: j['hostId'] as String,
        players: (j['players'] as List)
            .map((p) => LobbyPlayer.fromJson(p as Map<String, dynamic>))
            .toList(),
        maxPlayers: j['maxPlayers'] as int,
        status: LobbyStatus.values.byName(j['status'] as String),
      );

  @override
  List<Object?> get props => [id, hostId, players, maxPlayers, status];
}
