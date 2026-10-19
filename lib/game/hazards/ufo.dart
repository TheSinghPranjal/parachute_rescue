import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/services/audio_service.dart';
import '../../core/utils/doodle.dart';
import '../../domain/scoring.dart';
import '../../domain/spawn_plan.dart';
import 'hazard.dart';

enum BeamPhase { idle, warning, active }

/// Glides on a curved path and periodically fires a tractor beam. A dashed
/// cone telegraphs the beam first; a person who stays in the solid beam long
/// enough is abducted. The drawn beam and the hit test use the same path.
class Ufo extends Hazard {
  Ufo({
    required super.id,
    required bool fromLeft,
    required double y,
    required double worldWidth,
  }) : _dir = fromLeft ? 1 : -1,
       _baseY = y,
       super(
         kind: HazardKind.ufo,
         position: Vector2(fromLeft ? -80 : worldWidth + 80, y),
         size: Vector2(110, 56),
       );

  static const double beamLength = 250;
  static const double beamTopHalf = 22;
  static const double beamBottomHalf = 56;

  final double _dir;
  final double _baseY;
  double _clock = 0;
  int hits = 0;
  bool destroyed = false;
  double _destroyT = 0;
  BeamPhase beam = BeamPhase.idle;
  double _beamT = 0;

  int get hitsToDestroy => game.config.hazards.ufoHits;

  @override
  bool get isActive => !destroyed && isMounted;

  @override
  bool get attackable => !destroyed;

  @override
  Rect get tapRect => toAbsoluteRect().inflate(18);

  /// Beam trapezoid in world space — used for drawing and for collisions.
  Path beamPath() {
    final top = position.y + 14;
    final x = position.x;
    return Path()
      ..moveTo(x - beamTopHalf, top)
      ..lineTo(x + beamTopHalf, top)
      ..lineTo(x + beamBottomHalf, top + beamLength)
      ..lineTo(x - beamBottomHalf, top + beamLength)
      ..close();
  }

  @override
  bool hit() {
    if (destroyed) return false;
    hits++;
    if (hits >= hitsToDestroy) {
      destroyed = true;
      beam = BeamPhase.idle;
      return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;
    _clock += dt;
    final h = game.config.hazards;

    if (destroyed) {
      _destroyT += dt;
      if (_destroyT > 0.5) removeFromParent();
      return;
    }

    // Slow down while beaming so the threat is readable.
    final slow = beam == BeamPhase.idle ? 1.0 : 0.3;
    position.x += _dir * h.ufoSpeed * speedMultiplier * slow * dt;
    position.y = _baseY + math.sin(position.x / 110) * 40;

    _beamT += dt;
    switch (beam) {
      case BeamPhase.idle:
        // Only beam while fully over the field.
        if (_beamT >= h.ufoBeamCooldown &&
            position.x > 60 &&
            position.x < game.config.world.width - 60) {
          beam = BeamPhase.warning;
          _beamT = 0;
          game.audio.play(Sfx.beam);
        }
      case BeamPhase.warning:
        if (_beamT >= h.ufoBeamWarning) {
          beam = BeamPhase.active;
          _beamT = 0;
        }
      case BeamPhase.active:
        final path = beamPath();
        for (final p in game.airbornePeople) {
          if (path.contains(Offset(p.body.x, p.body.y))) {
            p.beamExposure += dt;
            if (p.beamExposure >= h.ufoAbductTime) p.markLost(LossCause.ufo);
          } else {
            p.beamExposure = 0;
          }
        }
        if (_beamT >= h.ufoBeamActive) {
          beam = BeamPhase.idle;
          _beamT = 0;
          for (final p in game.airbornePeople) {
            p.beamExposure = 0;
          }
        }
    }
    if (offField(position.x, 110)) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final pal = game.terrain.hazards;
    // Beam first (behind the saucer), in world space relative to this.
    if (beam != BeamPhase.idle) {
      canvas.save();
      canvas.translate(-position.x + size.x / 2, -position.y + size.y / 2);
      final path = beamPath();
      if (beam == BeamPhase.warning) {
        final blink = (math.sin(_clock * 18) + 1) / 2;
        canvas.drawPath(
          path,
          Doodle.fill(pal.ufoDome.withValues(alpha: 0.10 + blink * 0.1)),
        );
        _dashed(
          canvas,
          path,
          Doodle.stroke(pal.ufoDome.withValues(alpha: 0.9), 2.2),
        );
      } else {
        canvas.drawPath(path, Doodle.fill(pal.ufoDome.withValues(alpha: 0.38)));
        canvas.drawPath(
          path,
          Doodle.stroke(Doodle.ink.withValues(alpha: 0.6), 1.6),
        );
        // Rising sparkles.
        for (var i = 0; i < 6; i++) {
          final u = (_clock * 0.9 + i / 6) % 1;
          final y = position.y + 14 + beamLength * (1 - u);
          final x =
              position.x +
              math.sin(i * 2.1 + _clock * 3) *
                  (beamTopHalf + (beamBottomHalf - beamTopHalf) * (1 - u)) *
                  0.7;
          canvas.drawCircle(
            Offset(x, y),
            2.4,
            Doodle.fill(const Color(0xFFFFFFFF)),
          );
        }
      }
      canvas.restore();
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    if (destroyed) {
      final u = (_destroyT / 0.5).clamp(0.0, 1.0);
      Doodle.inked(
        canvas,
        Doodle.burst(Offset.zero, 30 + u * 40, seed: 151),
        const Color(0xFFFFD43B),
      );
      canvas.restore();
      return;
    }
    canvas.rotate(math.sin(_clock * 2.2) * 0.08);
    drawArt(canvas, _clock, pal.ufo, pal.ufoDome, damage: hits / hitsToDestroy);
    canvas.restore();
  }

  static void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 16) {
        canvas.drawPath(metric.extractPath(d, d + 9), paint);
      }
    }
  }

  /// Draws a cartoon saucer centred on (0, 0).
  static void drawArt(
    Canvas canvas,
    double t,
    Color hull,
    Color dome, {
    double damage = 0,
  }) {
    // Dome with a little alien.
    final domePath = Path()
      ..moveTo(-24, -4)
      ..quadraticBezierTo(-24, -32, 0, -32)
      ..quadraticBezierTo(24, -32, 24, -4)
      ..close();
    Doodle.inked(canvas, domePath, const Color(0xFFDDF3FA), width: 2.4);
    canvas.drawCircle(const Offset(0, -14), 9, Doodle.fill(dome));
    canvas.drawCircle(const Offset(0, -14), 9, Doodle.stroke(Doodle.ink, 1.8));
    canvas.drawCircle(const Offset(-3.5, -15), 2.2, Doodle.fill(Doodle.ink));
    canvas.drawCircle(const Offset(3.5, -15), 2.2, Doodle.fill(Doodle.ink));
    // Saucer.
    final disc = Doodle.blob(const Offset(0, 2), 52, 13, seed: 152);
    Doodle.inked(canvas, disc, hull);
    canvas.drawPath(
      Doodle.blob(const Offset(0, 9), 30, 6, seed: 153),
      Doodle.fill(const Color(0x33000000)),
    );
    // Running lights.
    for (var i = 0; i < 5; i++) {
      final on = ((t * 6).floor() + i) % 2 == 0;
      canvas.drawCircle(
        Offset(-32.0 + i * 16, 3),
        3.4,
        Doodle.fill(on ? const Color(0xFFFFD43B) : const Color(0xFFFFF6C8)),
      );
      canvas.drawCircle(
        Offset(-32.0 + i * 16, 3),
        3.4,
        Doodle.stroke(Doodle.ink, 1.2),
      );
    }
    if (damage > 0) {
      canvas.drawPath(
        Doodle.line([
          const Offset(-20, -2),
          const Offset(-12, 6),
          const Offset(-18, 12),
        ], seed: 154),
        Doodle.stroke(Doodle.ink, 1.8),
      );
    }
  }
}
