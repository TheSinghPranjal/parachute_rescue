import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/services/audio_service.dart';
import '../../core/utils/doodle.dart';
import '../../domain/scoring.dart';
import '../../domain/spawn_plan.dart';
import 'hazard.dart';

enum StormPhase { idle, warning, strike, cooldown }

/// Drifts across the sky and cycles warning → strike → cooldown. The strike
/// column [strikeRect] is used both for drawing and for hit-testing.
/// Clouds cannot be tapped — steer people out of the column with wind.
class Thundercloud extends Hazard {
  Thundercloud({
    required super.id,
    required bool fromLeft,
    required double y,
    required double worldWidth,
  }) : _dir = fromLeft ? 1 : -1,
       super(
         kind: HazardKind.thundercloud,
         position: Vector2(fromLeft ? -110 : worldWidth + 110, y),
         size: Vector2(180, 90),
         priority: 12,
       );

  final double _dir;
  double _clock = 0;
  StormPhase phase = StormPhase.idle;
  int strikes = 0;
  double _phaseT = 0;
  late final Path _cloudPath = Doodle.cloud(
    Offset(size.x / 2, size.y / 2),
    170,
    seed: 161,
  );

  @override
  bool get isActive => isMounted;

  @override
  bool get attackable => false;

  @override
  Rect get tapRect => Rect.zero;

  @override
  bool hit() => false;

  /// The lightning column, from the cloud base down to the ground.
  Rect get strikeRect {
    final w = game.config.hazards.lightningWidth;
    final top = position.y + size.y * 0.3;
    return Rect.fromLTRB(
      position.x - w / 2,
      top,
      position.x + w / 2,
      game.config.world.groundY,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;
    _clock += dt;
    final h = game.config.hazards;
    final moving = phase == StormPhase.idle || phase == StormPhase.cooldown;
    position.x +=
        _dir * h.cloudSpeed * speedMultiplier * (moving ? 1 : 0.15) * dt;

    _phaseT += dt;
    switch (phase) {
      case StormPhase.idle:
        if (_phaseT > 1.4 &&
            strikes < h.lightningMaxStrikes &&
            position.x > 80 &&
            position.x < game.config.world.width - 80) {
          _enter(StormPhase.warning);
        }
      case StormPhase.warning:
        if (_phaseT >= h.lightningWarning) {
          _enter(StormPhase.strike);
          strikes++;
          game.audio.play(Sfx.zap);
          game.haptics.heavy();
        }
      case StormPhase.strike:
        final column = strikeRect;
        for (final p in game.airbornePeople) {
          if (p.hurtRect.overlaps(column)) p.markLost(LossCause.lightning);
        }
        if (_phaseT >= h.lightningStrike) _enter(StormPhase.cooldown);
      case StormPhase.cooldown:
        if (_phaseT >= h.lightningCooldown) _enter(StormPhase.idle);
    }
    if (offField(position.x, 130)) removeFromParent();
  }

  void _enter(StormPhase next) {
    phase = next;
    _phaseT = 0;
  }

  @override
  void render(Canvas canvas) {
    final pal = game.terrain.hazards;
    if (phase == StormPhase.warning || phase == StormPhase.strike) {
      canvas.save();
      canvas.translate(-position.x + size.x / 2, -position.y + size.y / 2);
      final r = strikeRect;
      if (phase == StormPhase.warning) {
        final blink = (math.sin(_phaseT * 22) + 1) / 2;
        canvas.drawRect(
          r,
          Doodle.fill(pal.bolt.withValues(alpha: 0.08 + blink * 0.12)),
        );
        final edge = Doodle.stroke(pal.bolt.withValues(alpha: 0.9), 2);
        for (var y = r.top; y < r.bottom; y += 18) {
          canvas.drawLine(Offset(r.left, y), Offset(r.left, y + 9), edge);
          canvas.drawLine(Offset(r.right, y), Offset(r.right, y + 9), edge);
        }
      } else {
        canvas.drawRect(r, Doodle.fill(pal.bolt.withValues(alpha: 0.28)));
        _bolt(canvas, r, pal.bolt);
      }
      canvas.restore();
    }
    // The cloud itself, darker and jittering when about to strike.
    canvas.save();
    if (phase == StormPhase.warning) {
      canvas.translate(math.sin(_clock * 40) * 2, 0);
    }
    Doodle.inked(
      canvas,
      _cloudPath,
      phase == StormPhase.strike ? const Color(0xFF3E3F46) : pal.stormCloud,
    );
    // Grumpy face.
    final c = Offset(size.x / 2, size.y / 2 + 4);
    final face = Doodle.stroke(Doodle.ink, 2.2);
    canvas.drawLine(c.translate(-22, -10), c.translate(-10, -6), face);
    canvas.drawLine(c.translate(22, -10), c.translate(10, -6), face);
    canvas.drawCircle(c.translate(-15, -2), 2.6, Doodle.fill(Doodle.ink));
    canvas.drawCircle(c.translate(15, -2), 2.6, Doodle.fill(Doodle.ink));
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, 12), width: 16, height: 10),
      math.pi + 0.3,
      math.pi - 0.6,
      false,
      face,
    );
    // Rain dashes.
    final rain = Doodle.stroke(const Color(0xFF4F7FA8), 1.6);
    for (var i = 0; i < 6; i++) {
      final x = size.x * 0.2 + i * size.x * 0.12;
      final off = (_clock * 120 + i * 13) % 30;
      canvas.drawLine(
        Offset(x, size.y * 0.8 + off),
        Offset(x - 3, size.y * 0.8 + off + 8),
        rain,
      );
    }
    canvas.restore();
  }

  void _bolt(Canvas canvas, Rect r, Color color) {
    final pts = <Offset>[];
    var y = r.top;
    var i = 0;
    while (y < r.bottom) {
      pts.add(
        Offset(
          r.center.dx + Doodle.noise((_clock * 30).floor(), i) * r.width * 0.35,
          y,
        ),
      );
      y += 40;
      i++;
    }
    pts.add(Offset(r.center.dx, r.bottom));
    final path = Doodle.line(pts, jitter: 0);
    canvas.drawPath(path, Doodle.stroke(Doodle.ink, 9));
    canvas.drawPath(path, Doodle.stroke(color, 5));
  }
}
