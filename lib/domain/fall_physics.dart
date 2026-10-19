import 'dart:math' as math;

import '../core/config/game_config.dart';

enum ChuteState { freeFall, opening, open }

/// Pure kinematic state of one falling person. Units: world units and seconds.
///
/// Kept free of Flame so the rules can be unit-tested directly.
class FallBody {
  FallBody({required this.x, required this.y, this.vx = 0, this.vy = 0});

  double x;
  double y;
  double vx;
  double vy;
  ChuteState chute = ChuteState.freeFall;
  double openingElapsed = 0;

  /// Y at which the chute was deployed (for the risk bonus).
  double? deployedAtY;

  bool get chuteDeployed => chute != ChuteState.freeFall;

  /// Starts opening the canopy. Returns false if it was already deployed.
  bool deploy() {
    if (chute != ChuteState.freeFall) return false;
    chute = ChuteState.opening;
    openingElapsed = 0;
    deployedAtY = y;
    return true;
  }

  /// Advances one substep. [windAccel] is the summed gust acceleration
  /// (u/s²) before the chute-state wind factor is applied.
  void step(double dt, double windAccel, PhysicsConfig cfg) {
    if (dt <= 0) return;

    // Vertical.
    switch (chute) {
      case ChuteState.freeFall:
        vy = math.min(vy + cfg.gravity * dt, cfg.freeFallTerminal);
      case ChuteState.opening:
      case ChuteState.open:
        // Exponential relaxation toward the canopy descent speed. Using exp
        // keeps it identical regardless of how dt is split.
        final k = 1 - math.exp(-cfg.chuteRelaxRate * dt);
        vy += (cfg.chuteDescent - vy) * k;
        if (chute == ChuteState.opening) {
          openingElapsed += dt;
          if (openingElapsed >= cfg.openingDuration) chute = ChuteState.open;
        }
    }

    // Horizontal: accelerate, damp exponentially (never flips sign), clamp.
    final open = chute != ChuteState.freeFall;
    final windFactor = open ? cfg.chuteWindFactor : cfg.freeFallWindFactor;
    final drag = open ? cfg.chuteDrag : cfg.freeFallDrag;
    vx += windAccel * windFactor * dt;
    vx *= math.exp(-drag * dt);
    vx = vx.clamp(-cfg.maxHorizontalSpeed, cfg.maxHorizontalSpeed);

    x += vx * dt;
    y += vy * dt;
  }

  /// Applies the configured side-edge rule. Returns true if the body wrapped.
  bool applyEdges(double worldWidth, double halfWidth, EdgeRule rule) {
    switch (rule) {
      case EdgeRule.clamp:
        if (x < halfWidth) {
          x = halfWidth;
          if (vx < 0) vx = 0;
        } else if (x > worldWidth - halfWidth) {
          x = worldWidth - halfWidth;
          if (vx > 0) vx = 0;
        }
        return false;
      case EdgeRule.wrap:
        // Wrap once the body's centre leaves the field; the result is always
        // inside [0, worldWidth) so it can never wrap repeatedly.
        if (x < 0 || x >= worldWidth) {
          x = x % worldWidth;
          if (x < 0) x += worldWidth;
          return true;
        }
        return false;
    }
  }
}

/// Splits a frame delta into clamped, equal substeps.
({int count, double dt}) substeps(double frameDt, PhysicsConfig cfg) {
  if (frameDt <= 0 || frameDt.isNaN) return (count: 0, dt: 0);
  final clamped = math.min(frameDt, cfg.maxFrameDt);
  final count = math.max(1, (clamped / cfg.maxSubstep).ceil());
  return (count: count, dt: clamped / count);
}
