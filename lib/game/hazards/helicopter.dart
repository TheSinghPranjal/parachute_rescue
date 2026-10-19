import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/utils/doodle.dart';
import '../../domain/scoring.dart';
import '../../domain/spawn_plan.dart';
import 'hazard.dart';

/// Crosses the sky on a gentle sine path. Its body and rotor knock out any
/// person they touch. Tap it [hitsToDestroy] times to bring it down.
class Helicopter extends Hazard {
  Helicopter({
    required super.id,
    required bool fromLeft,
    required double y,
    required double worldWidth,
  }) : _dir = fromLeft ? 1 : -1,
       _baseY = y,
       super(
         kind: HazardKind.helicopter,
         position: Vector2(fromLeft ? -90 : worldWidth + 90, y),
         size: Vector2(130, 70),
       );

  final double _dir;
  final double _baseY;
  double _clock = 0;
  int hits = 0;
  bool destroyed = false;
  double _wobble = 0;
  double _fallVy = 0;

  int get hitsToDestroy => game.config.hazards.helicopterHits;

  @override
  bool get isActive => !destroyed && isMounted;

  @override
  bool get attackable => !destroyed;

  @override
  Rect get tapRect => toAbsoluteRect().inflate(18);

  /// Collision area: cabin plus rotor sweep, slightly inset to be fair.
  Rect get dangerRect => Rect.fromCenter(
    center: Offset(position.x, position.y - 4),
    width: 112,
    height: 50,
  );

  @override
  bool hit() {
    if (destroyed) return false;
    hits++;
    _wobble = 1;
    if (hits >= hitsToDestroy) {
      destroyed = true;
      return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;
    _clock += dt;
    _wobble = math.max(0, _wobble - dt * 2.5);

    if (destroyed) {
      _fallVy = math.min(_fallVy + 700 * dt, 600);
      position.y += _fallVy * dt;
      position.x += _dir * 40 * dt;
      angle += dt * 5 * _dir;
      if (position.y > game.config.world.groundY) {
        game.spawnExplosion(
          Vector2(position.x, game.config.world.groundY - 10),
        );
        removeFromParent();
      }
      return;
    }

    final speed = game.config.hazards.helicopterSpeed * speedMultiplier;
    // Damage slows it a little.
    position.x += _dir * speed * (1 - hits * 0.12) * dt;
    position.y = _baseY + math.sin(_clock * 1.4) * 34;

    final danger = dangerRect;
    for (final p in game.airbornePeople) {
      if (p.hurtRect.overlaps(danger)) p.markLost(LossCause.helicopter);
    }
    if (offField(position.x, 120)) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final pal = game.terrain.hazards;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(math.sin(_clock * 30) * 0.08 * _wobble);
    canvas.scale(_dir, 1);
    drawArt(
      canvas,
      _clock,
      pal.helicopter,
      pal.helicopterAccent,
      damage: hits / hitsToDestroy,
    );
    canvas.restore();
    if (!destroyed && hits > 0) {
      // Smoke puffs grow with damage.
      for (var i = 0; i < hits * 2; i++) {
        final t = (_clock * 1.5 + i * 0.37) % 1;
        canvas.drawCircle(
          Offset(size.x / 2 - _dir * (20 + t * 40), size.y / 2 - 10 - t * 30),
          4 + t * 8,
          Doodle.fill(Color.fromRGBO(70, 70, 70, 0.45 * (1 - t))),
        );
      }
    }
  }

  /// Draws a cartoon helicopter facing right, centred on (0, 0).
  static void drawArt(
    Canvas canvas,
    double t,
    Color body,
    Color accent, {
    double damage = 0,
  }) {
    // Tail boom and tail rotor.
    final boom = Doodle.line(
      [
        const Offset(-20, -4),
        const Offset(-62, -10),
        const Offset(-62, -2),
        const Offset(-20, 6),
      ],
      seed: 141,
      close: true,
    );
    Doodle.inked(canvas, boom, body, width: 2.6);
    final tr = math.sin(t * 50) * 9;
    canvas.drawLine(
      Offset(-62, -6 - tr),
      Offset(-62, -6 + tr),
      Doodle.stroke(Doodle.ink, 2.4),
    );
    // Cabin.
    final cabin = Doodle.blob(const Offset(4, 2), 30, 20, seed: 142);
    Doodle.inked(canvas, cabin, body);
    // Bubble window with a grumpy pilot.
    final glass = Path()
      ..moveTo(8, -14)
      ..quadraticBezierTo(34, -14, 34, 6)
      ..lineTo(10, 6)
      ..close();
    Doodle.inked(canvas, glass, const Color(0xFFBFE6FA), width: 2);
    canvas.drawCircle(
      const Offset(19, -2),
      6,
      Doodle.fill(const Color(0xFFFFFFFF)),
    );
    canvas.drawCircle(const Offset(19, -2), 6, Doodle.stroke(Doodle.ink, 1.6));
    canvas.drawLine(
      const Offset(15, -5),
      const Offset(19, -4),
      Doodle.stroke(Doodle.ink, 1.4),
    );
    canvas.drawLine(
      const Offset(23, -5),
      const Offset(20, -4),
      Doodle.stroke(Doodle.ink, 1.4),
    );
    // Stripe.
    canvas.drawLine(
      const Offset(-24, 10),
      const Offset(28, 10),
      Doodle.stroke(accent, 3),
    );
    // Skids.
    final skid = Doodle.stroke(Doodle.ink, 2.4);
    canvas.drawLine(const Offset(-12, 20), const Offset(-14, 28), skid);
    canvas.drawLine(const Offset(18, 20), const Offset(20, 28), skid);
    canvas.drawLine(const Offset(-26, 28), const Offset(32, 28), skid);
    // Main rotor (motion-blurred blade).
    canvas.drawLine(const Offset(2, -18), const Offset(2, -26), skid);
    final blade = 52 * (0.55 + 0.45 * math.cos(t * 38).abs());
    canvas.drawLine(
      Offset(2 - blade, -27),
      Offset(2 + blade, -27),
      Doodle.stroke(Doodle.ink, 3),
    );
    canvas.drawLine(
      const Offset(-50, -31),
      const Offset(-36, -31),
      Doodle.stroke(Doodle.ink.withValues(alpha: 0.4), 1.4),
    );
    canvas.drawLine(
      const Offset(40, -31),
      const Offset(54, -31),
      Doodle.stroke(Doodle.ink.withValues(alpha: 0.4), 1.4),
    );
    // Cracks show damage.
    if (damage > 0.3) {
      canvas.drawPath(
        Doodle.line([
          const Offset(-14, -8),
          const Offset(-6, 0),
          const Offset(-12, 6),
          const Offset(-4, 14),
        ], seed: 143),
        Doodle.stroke(Doodle.ink, 1.6),
      );
    }
  }
}
