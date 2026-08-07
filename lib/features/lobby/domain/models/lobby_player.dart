import 'package:equatable/equatable.dart';

class LobbyPlayer extends Equatable {
  const LobbyPlayer({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isReady = false,
    this.isBot = false,
  });

  final String id;
  final String name;
  final bool isHost;
  final bool isReady;
  final bool isBot;

  LobbyPlayer copyWith({
    bool? isHost,
    bool? isReady,
    bool? isBot,
  }) {
    return LobbyPlayer(
      id: id,
      name: name,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      isBot: isBot ?? this.isBot,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isHost': isHost,
        'isReady': isReady,
        'isBot': isBot,
      };

  factory LobbyPlayer.fromJson(Map<String, dynamic> j) => LobbyPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        isHost: j['isHost'] as bool,
        isReady: j['isReady'] as bool,
        isBot: j['isBot'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, name, isHost, isReady, isBot];
}
