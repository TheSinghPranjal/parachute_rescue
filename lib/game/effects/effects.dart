import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../core/utils/doodle.dart';

/// Base for short-lived visual effects: counts its own lifetime and removes
/// itself when done. Effects freeze with the rest of the game while paused.
abstract class TimedEffect extends PositionComponent {
  TimedEffect({required this.lifetime, super.position, super.priority = 50});

  final double lifetime;
  double age = 0;

  double get progress => (age / lifetime).clamp(0.0, 1.0);

  @override
  void update(double dt) {
    age += dt;
    if (age >= lifetime) removeFromParent();
  }
}

/// Wind streaks along the swipe path, drifting in the gust direction.
class WindLines extends TimedEffect {
  WindLines({required this.start, required this.end, required this.direction})
    : super(lifetime: 0.7, priority: 55);

  final Vector2 start;
  final Vector2 end;
  final double direction;

  @override
  void render(Canvas canvas) {
    final u = progress;
    final alpha = (1 - u) * 0.85;
    final paint = Doodle.stroke(Doodle.ink.withValues(alpha: alpha), 2.4);
    final drift = direction * u * 120;
    for (var i = 0; i < 5; i++) {
      final f = i / 4;
      final x = start.x + (end.x - start.x) * f + drift;
      final y = start.y + (end.y - start.y) * f + (i.isEven ? -14 : 14);
      final len = 46.0 - (i - 2).abs() * 8;
      final path = Doodle.wave(
        x - len / 2,
        x + len / 2,
        y,
        amplitude: 3,
        wavelength: 26,
        phase: u * 8 + i,
      );
      canvas.drawPath(path, paint);
      // Curl at the leading end.
      final tip = Offset(x + direction * len / 2, y);
      canvas.drawArc(
        Rect.fromCircle(center: tip.translate(0, -5), radius: 5),
        direction > 0 ? -1.4 : 1.4 - math.pi,
        math.pi * 1.1,
        false,
        paint,
      );
    }
  }
}

/// Water splash (droplets + ring) or dust puff (land), at the ground line.
class ImpactSplash extends TimedEffect {
  ImpactSplash({required Vector2 at, required this.liquid, required this.tint})
    : super(lifetime: 0.8, position: at);

  final bool liquid;
  final Color tint;

  @override
  void render(Canvas canvas) {
    final u = progress;
    final fade = 1 - u;
    if (liquid) {
      final drop = Doodle.fill(tint.withValues(alpha: fade));
      final edge = Doodle.stroke(Doodle.ink.withValues(alpha: fade), 1.4);
      for (var i = 0; i < 7; i++) {
        final a = -math.pi * (0.15 + 0.7 * i / 6);
        final r = 10 + u * 42;
        final p = Offset(math.cos(a) * r, math.sin(a) * r * 1.3 + u * u * 40);
        canvas.drawCircle(p, 5 * fade + 1, drop);
        canvas.drawCircle(p, 5 * fade + 1, edge);
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 30 + u * 70,
          height: 8 + u * 10,
        ),
        Doodle.stroke(Doodle.ink.withValues(alpha: fade), 2),
      );
    } else {
      for (var i = 0; i < 6; i++) {
        final a = -math.pi * (0.1 + 0.8 * i / 5);
        final r = 8 + u * 36;
        final p = Offset(math.cos(a) * r, math.sin(a) * r * 0.6 - u * 10);
        final puff = Doodle.blob(p, 9 + u * 10, 7 + u * 8, seed: 170 + i);
        canvas.drawPath(puff, Doodle.fill(tint.withValues(alpha: 0.85 * fade)));
        canvas.drawPath(
          puff,
          Doodle.stroke(Doodle.ink.withValues(alpha: 0.6 * fade), 1.6),
        );
      }
    }
  }
}

/// Comic explosion for destroyed hazards.
class Explosion extends TimedEffect {
  Explosion({required Vector2 at})
    : super(lifetime: 0.55, position: at, priority: 58);

  @override
  void render(Canvas canvas) {
    final u = progress;
    final r = 18 + u * 46;
    final fade = 1 - u;
    canvas.drawPath(
      Doodle.burst(Offset.zero, r, seed: 181),
      Doodle.fill(const Color(0xFFFF9F43).withValues(alpha: fade)),
    );
    canvas.drawPath(
      Doodle.burst(Offset.zero, r * 0.6, seed: 182),
      Doodle.fill(const Color(0xFFFFE066).withValues(alpha: fade)),
    );
    canvas.drawPath(
      Doodle.burst(Offset.zero, r, seed: 181),
      Doodle.stroke(Doodle.ink.withValues(alpha: fade), 2.6),
    );
  }
}

/// Floating "+100" style text.
class ScorePopup extends TimedEffect {
  ScorePopup({
    required Vector2 at,
    required String text,
    Color color = const Color(0xFF2F9E44),
    double fontSize = 30,
  }) : _painter = TextPainter(
         text: TextSpan(
           text: text,
           style: TextStyle(
             fontSize: fontSize,
             fontFamily: 'Lilita',
             color: color,
             shadows: const [
               Shadow(offset: Offset(2, 2), color: Doodle.ink),
               Shadow(offset: Offset(-1.5, -1.5), color: Color(0xFFFFFFFF)),
             ],
           ),
         ),
         textDirection: TextDirection.ltr,
       )..layout(),
       super(lifetime: 1.1, position: at, priority: 60);

  final TextPainter _painter;

  @override
  void render(Canvas canvas) {
    final u = progress;
    final pop = u < 0.15 ? 0.6 + u / 0.15 * 0.5 : 1.1 - (u - 0.15) * 0.12;
    canvas.save();
    canvas.translate(0, -u * 70);
    canvas.scale(pop);
    if (u > 0.7) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, 1 - (u - 0.7) / 0.3),
      );
    }
    _painter.paint(canvas, Offset(-_painter.width / 2, -_painter.height / 2));
    if (u > 0.7) canvas.restore();
    canvas.restore();
  }
}

/// A quick "tap" ring where a hazard was hit.
class HitSpark extends TimedEffect {
  HitSpark({required Vector2 at})
    : super(lifetime: 0.25, position: at, priority: 58);

  @override
  void render(Canvas canvas) {
    final u = progress;
    Doodle.inked(
      canvas,
      Doodle.burst(Offset.zero, 10 + u * 14, points: 7, seed: 191),
      const Color(0xFFFFFFFF).withValues(alpha: 1 - u),
      width: 2,
    );
  }
}
