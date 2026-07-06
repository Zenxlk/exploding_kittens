import 'dart:math';

extension ListShuffleX<T> on List<T> {
  List<T> shuffled([Random? random]) {
    final copy = List<T>.from(this);
    copy.shuffle(random ?? Random());
    return copy;
  }

  T pickRandom([Random? random]) {
    assert(isNotEmpty, 'No se puede elegir de lista vacía');
    final rng = random ?? Random();
    return this[rng.nextInt(length)];
  }

  List<T> pickN(int n, [Random? random]) {
    assert(n <= length, 'No hay suficientes elementos');
    return shuffled(random).take(n).toList();
  }
}

extension ListNullableX<T> on List<T>? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
