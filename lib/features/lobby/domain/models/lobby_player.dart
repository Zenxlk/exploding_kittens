import 'package:equatable/equatable.dart';

class LobbyPlayer extends Equatable {
  const LobbyPlayer({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isReady = false,
  });

  final String id;
  final String name;
  final bool isHost;
  final bool isReady;

  LobbyPlayer copyWith({
    bool? isHost,
    bool? isReady,
  }) {
    return LobbyPlayer(
      id: id,
      name: name,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isHost': isHost,
        'isReady': isReady,
      };

  factory LobbyPlayer.fromJson(Map<String, dynamic> j) => LobbyPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        isHost: j['isHost'] as bool,
        isReady: j['isReady'] as bool,
      );

  @override
  List<Object?> get props => [id, name, isHost, isReady];
}
