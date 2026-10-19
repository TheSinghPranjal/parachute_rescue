import '../core/config/game_config.dart';

/// A directional push of wind created by one swipe.
class Gust {
  Gust({required this.strength, required this.duration}) : remaining = duration;

  /// Signed horizontal acceleration in u/s² (negative = left).
  final double strength;
  final double duration;
  double remaining;

  bool get expired => remaining <= 0;

  /// Current acceleration with linear decay over the gust lifetime.
  double get acceleration =>
      expired ? 0 : strength * (remaining / duration).clamp(0.0, 1.0);

  void tick(double dt) => remaining -= dt;
}

/// Turns a completed drag into a gust, or null when it is not a valid swipe.
///
/// [dx]/[dy] are the world-space drag displacement and [seconds] its duration.
Gust? gustFromSwipe({
  required double dx,
  required double dy,
  required double seconds,
  required WindConfig cfg,
}) {
  if (dx.isNaN || dy.isNaN || seconds.isNaN) return null;
  final distanceSq = dx * dx + dy * dy;
  if (distanceSq < cfg.minSwipeDistance * cfg.minSwipeDistance) return null;
  // A purely vertical swipe carries no sideways wind.
  if (dx.abs() < cfg.minSwipeDistance * 0.5) return null;
  // Guard against zero/absurd durations producing infinite speed.
  final duration = seconds < 0.016 ? 0.016 : seconds;
  final speed = dx.abs() / duration;
  final magnitude = (speed * cfg.forceScale).clamp(
    cfg.minStrength,
    cfg.maxStrength,
  );
  return Gust(strength: dx.sign * magnitude, duration: cfg.gustDuration);
}

/// Owns the active gusts and sums their acceleration.
class WindField {
  WindField(this.cfg);

  final WindConfig cfg;
  final List<Gust> _gusts = [];

  List<Gust> get gusts => List.unmodifiable(_gusts);

  void add(Gust gust) {
    if (_gusts.length >= cfg.maxActiveGusts) _gusts.removeAt(0);
    _gusts.add(gust);
  }

  double get acceleration {
    var sum = 0.0;
    for (final g in _gusts) {
      sum += g.acceleration;
    }
    return sum.clamp(-cfg.maxStrength, cfg.maxStrength);
  }

  void tick(double dt) {
    for (final g in _gusts) {
      g.tick(dt);
    }
    _gusts.removeWhere((g) => g.expired);
  }

  void clear() => _gusts.clear();
}
