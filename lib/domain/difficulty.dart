import '../core/config/game_config.dart';

/// Difficulty values at a moment of the run. All values are within the
/// range spanned by the configured phases.
class DifficultySnapshot {
  const DifficultySnapshot({
    required this.spawnInterval,
    required this.maxActivePeople,
    required this.landingSpeed,
    required this.landingCount,
    required this.hazardInterval,
    required this.maxHazards,
    required this.hazardSpeedMultiplier,
  });

  final double spawnInterval;
  final int maxActivePeople;
  final double landingSpeed;
  final int landingCount;
  final double hazardInterval;
  final int maxHazards;
  final double hazardSpeedMultiplier;
}

/// Smoothly interpolates between configured phase anchors by survival time.
class DifficultyCurve {
  DifficultyCurve(this.cfg) : assert(cfg.phases.isNotEmpty);

  final DifficultyConfig cfg;

  DifficultySnapshot at(double seconds) {
    final phases = cfg.phases;
    final t = seconds.isNaN || seconds < 0 ? 0.0 : seconds;
    if (t <= phases.first.time) return _snap(phases.first, phases.first, 0);
    for (var i = 0; i < phases.length - 1; i++) {
      final a = phases[i];
      final b = phases[i + 1];
      if (t < b.time) {
        final u = (t - a.time) / (b.time - a.time);
        // Smoothstep eases into and out of each phase.
        return _snap(a, b, u * u * (3 - 2 * u));
      }
    }
    return _snap(phases.last, phases.last, 0);
  }

  static double _lerp(double a, double b, double u) => a + (b - a) * u;

  DifficultySnapshot _snap(DifficultyPhase a, DifficultyPhase b, double u) {
    // Integer limits step up only once the phase is mostly reached.
    int step(int x, int y) => u >= 0.5 ? y : x;
    return DifficultySnapshot(
      spawnInterval: _lerp(a.spawnInterval, b.spawnInterval, u),
      maxActivePeople: step(a.maxActivePeople, b.maxActivePeople),
      landingSpeed: _lerp(a.landingSpeed, b.landingSpeed, u),
      landingCount: step(a.landingCount, b.landingCount),
      hazardInterval: _lerp(a.hazardInterval, b.hazardInterval, u),
      maxHazards: step(a.maxHazards, b.maxHazards),
      hazardSpeedMultiplier: _lerp(
        a.hazardSpeedMultiplier,
        b.hazardSpeedMultiplier,
        u,
      ),
    );
  }
}
