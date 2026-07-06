sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class GameFailure extends Failure {
  const GameFailure(super.message);
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'Error desconocido']) : super(message);
}

// Resultado funcional — evita lanzar excepciones en lógica de negocio
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure_<T> extends Result<T> {
  const Failure_(this.failure);
  final Failure failure;
}
