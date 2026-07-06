import 'dart:math';

abstract final class RandomUtils {
  static final Random _rng = Random();

  static int nextInt(int max) => _rng.nextInt(max);

  // Devuelve un Random con semilla fija para partidas reproducibles (testing)
  static Random seeded(int seed) => Random(seed);
}
