sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class GameException extends AppException {
  const GameException(super.message);
}

final class InvalidActionException extends GameException {
  const InvalidActionException(super.message);
}

final class NetworkException extends AppException {
  const NetworkException(super.message);
}

final class ConnectionLostException extends NetworkException {
  const ConnectionLostException(super.message);
}

final class RoomNotFoundException extends AppException {
  const RoomNotFoundException(super.message);
}

final class RoomFullException extends AppException {
  const RoomFullException(super.message);
}
