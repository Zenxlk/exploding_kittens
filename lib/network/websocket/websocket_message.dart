/// Mensajes que viajan por WebSocket entre host y clientes.
sealed class WsMessage {
  const WsMessage();
  Map<String, dynamic> toJson();
}

final class GameStateMessage extends WsMessage {
  const GameStateMessage({required this.stateJson});
  final Map<String, dynamic> stateJson;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'game_state', 'payload': stateJson};
}

final class ActionMessage extends WsMessage {
  const ActionMessage({required this.actionJson});
  final Map<String, dynamic> actionJson;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'action', 'payload': actionJson};
}

final class PlayerJoinedMessage extends WsMessage {
  const PlayerJoinedMessage({required this.playerId, required this.name});
  final String playerId;
  final String name;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'player_joined', 'playerId': playerId, 'name': name};
}

final class PlayerReconnectedMessage extends WsMessage {
  const PlayerReconnectedMessage({required this.playerId});
  final String playerId;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'player_reconnected', 'playerId': playerId};
}

final class PingMessage extends WsMessage {
  const PingMessage();

  @override
  Map<String, dynamic> toJson() => {'type': 'ping'};
}
