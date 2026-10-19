import 'dart:math';

/// Injectable randomness so spawning is reproducible in tests.
class RandomSource {
  RandomSource([int? seed]) : _random = Random(seed);

  final Random _random;

  double nextDouble() => _random.nextDouble();

  int nextInt(int max) => _random.nextInt(max);

  bool nextBool() => _random.nextBool();

  double range(double min, double max) => min + (max - min) * nextDouble();

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Picks an index with probability proportional to [weights].
  int weighted(List<double> weights) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    var roll = nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return weights.length - 1;
  }
}
