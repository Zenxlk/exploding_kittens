import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:exploding_kittens/core/config/online_config.dart';
import 'package:exploding_kittens/core/errors/exceptions.dart';

/// Habla `POST /rooms` del backend online (`cards_game_service`) — el
/// único endpoint HTTP que necesita el modo online del lado cliente, ver
/// `internal/transport/server.go` en ese repo. El resto de la conversación
/// (unirse, jugar) es WebSocket puro vía `WsClient.connectToUri`.
class OnlineRoomsClient {
  OnlineRoomsClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Crea una sala y devuelve su código (`GET /ws/{code}` para conectarse).
  /// Lanza [NetworkException] si el servidor rechaza la request o no
  /// responde — mismo patrón que `LobbyRepository`, que envuelve
  /// excepciones en `Result` en vez de dejarlas propagar hasta la UI.
  Future<String> createRoom({
    required String gameType,
    required String hostId,
    required String hostName,
  }) async {
    final http.Response response;
    try {
      response = await _http.post(
        OnlineConfig.httpUri('/rooms'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gameType': gameType,
          'hostId': hostId,
          'hostName': hostName,
        }),
      );
    } catch (e) {
      throw NetworkException('No se pudo contactar al servidor online: $e');
    }

    if (response.statusCode != 200) {
      throw NetworkException(
        'El servidor online rechazó la sala (${response.statusCode}): '
        '${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['code'] as String;
  }

  void close() => _http.close();
}
