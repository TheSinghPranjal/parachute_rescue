import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/spawn_plan.dart';
import '../rescue_game.dart';

/// Shared contract for sky hazards. Each hazard owns its own movement,
/// timers and collision checks; the game only spawns, taps and counts them.
abstract class Hazard extends PositionComponent
    with HasGameReference<RescueGame> {
  Hazard({
    required this.id,
    required this.kind,
    super.position,
    super.size,
    super.anchor = Anchor.center,
    super.priority = 35,
  });

  final int id;
  final HazardKind kind;

  /// Seconds since this hazard last took a hit (for tap cooldown).
  double sinceHit = 99;

  /// False once destroyed or leaving; it no longer counts or collides.
  bool get isActive;

  /// Whether taps can damage this hazard.
  bool get attackable;

  /// World-space tap target.
  Rect get tapRect;

  /// Applies one tap. Returns true if this hit destroyed the hazard.
  bool hit();

  /// Speed multiplier from difficulty, fixed at spawn.
  double speedMultiplier = 1;

  @override
  void update(double dt) {
    sinceHit += dt;
  }

  @override
  void onRemove() {
    game.unregister(this);
    super.onRemove();
  }

  /// True when [x] is beyond either side edge by [margin].
  bool offField(double x, double margin) =>
      x < -margin || x > game.config.world.width + margin;
}
