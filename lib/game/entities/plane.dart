import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/utils/doodle.dart';
import '../terrain/terrain.dart';

/// The dropper plane. It sweeps back and forth along the top lane; the spawn
/// director releases people from its current position.
class DropPlane extends PositionComponent {
  DropPlane({
    required this.variant,
    required this.colors,
    required double y,
    required this.worldWidth,
    this.speed = 150,
    this.turnPause = 0.8,
  }) : super(
         position: Vector2(-120, y),
         size: Vector2(170, 64),
         anchor: Anchor.center,
         priority: 25,
       );

  final PlaneVariant variant;
  final PlanePalette colors;
  final double worldWidth;
  final double speed;

  /// Seconds spent off-screen before the next pass.
  final double turnPause;

  double direction = 1;
  double _offscreenTimer = 0;
  double _clock = 0;
  double _dropFlash = 0;

  /// Margin outside the field at which the plane turns around.
  static const double _outside = 120;

  /// True while the plane is over a part of the field where a drop is safe.
  bool get canDrop =>
      _offscreenTimer <= 0 && position.x > 50 && position.x < worldWidth - 50;

  /// Plays the hatch "release" animation.
  void release() => _dropFlash = 0.35;

  @override
  void update(double dt) {
    if (dt <= 0) return;
    _clock += dt;
    _dropFlash = math.max(0, _dropFlash - dt);
    if (_offscreenTimer > 0) {
      _offscreenTimer -= dt;
      return;
    }
    position.x += direction * speed * dt;
    position.y += math.sin(_clock * 1.6) * 6 * dt;
    if (direction > 0 && position.x > worldWidth + _outside) {
      direction = -1;
      _offscreenTimer = turnPause;
    } else if (direction < 0 && position.x < -_outside) {
      direction = 1;
      _offscreenTimer = turnPause;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(direction >= 0 ? 1 : -1, 1);
    drawVariant(canvas, variant, colors, _clock, hatchOpen: _dropFlash > 0);
    canvas.restore();
  }

  /// Draws the plane facing right, centred on (0, 0).
  static void drawVariant(
    Canvas canvas,
    PlaneVariant variant,
    PlanePalette c,
    double t, {
    bool hatchOpen = false,
  }) {
    // Speed lines behind.
    final speed = Doodle.stroke(Doodle.ink.withValues(alpha: 0.5), 1.6);
    for (var i = 0; i < 3; i++) {
      final y = -6.0 + i * 8;
      final off = (t * 90 + i * 17) % 24;
      canvas.drawLine(Offset(-96 - off, y), Offset(-84 - off, y), speed);
    }
    switch (variant) {
      case PlaneVariant.airliner:
        _airliner(canvas, c, hatchOpen);
      case PlaneVariant.cargo:
        _cargo(canvas, c, t, hatchOpen);
    }
  }

  static void _airliner(Canvas canvas, PlanePalette c, bool hatchOpen) {
    // Tail fin.
    final tail = Doodle.line(
      [
        const Offset(-70, -2),
        const Offset(-82, -30),
        const Offset(-62, -30),
        const Offset(-44, -4),
      ],
      seed: 111,
      close: true,
    );
    Doodle.inked(canvas, tail, c.stripe);
    // Fuselage.
    final body = Path()
      ..moveTo(-74, -4)
      ..quadraticBezierTo(-60, -16, 20, -14)
      ..quadraticBezierTo(70, -14, 78, 2)
      ..quadraticBezierTo(70, 14, 20, 14)
      ..lineTo(-60, 10)
      ..close();
    Doodle.inked(canvas, body, c.body);
    canvas.drawPath(
      Doodle.line([const Offset(-66, 4), const Offset(74, 4)], seed: 112),
      Doodle.stroke(c.stripe, 3.4),
    );
    // Windows.
    final win = Doodle.fill(c.window);
    for (var x = -40.0; x < 50; x += 11) {
      canvas.drawCircle(Offset(x, -4), 2.6, win);
    }
    // Cockpit.
    canvas.drawPath(
      Path()
        ..moveTo(60, -8)
        ..quadraticBezierTo(70, -8, 74, -1)
        ..lineTo(62, -1)
        ..close(),
      Doodle.fill(c.window),
    );
    // Wing (below, toward viewer).
    final wing = Doodle.line(
      [
        const Offset(-6, 6),
        const Offset(-30, 30),
        const Offset(-16, 30),
        const Offset(22, 6),
      ],
      seed: 113,
      close: true,
    );
    Doodle.inked(canvas, wing, c.body, width: 2.6);
    canvas.drawLine(
      const Offset(-26, 28),
      const Offset(-16, 28),
      Doodle.stroke(c.stripe, 3),
    );
    // Engine.
    Doodle.inked(
      canvas,
      Doodle.box(const Rect.fromLTRB(-10, 15, 8, 23), radius: 4, seed: 114),
      const Color(0xFFB8C0CC),
      width: 2,
    );
    _hatch(canvas, hatchOpen);
  }

  static void _cargo(Canvas canvas, PlanePalette c, double t, bool hatchOpen) {
    final tail = Doodle.line(
      [
        const Offset(-64, -4),
        const Offset(-80, -34),
        const Offset(-60, -34),
        const Offset(-40, -8),
      ],
      seed: 121,
      close: true,
    );
    Doodle.inked(canvas, tail, c.body);
    final body = Path()
      ..moveTo(-72, -2)
      ..quadraticBezierTo(-50, -18, 20, -18)
      ..quadraticBezierTo(66, -18, 74, 0)
      ..quadraticBezierTo(68, 16, 20, 16)
      ..lineTo(-56, 12)
      ..close();
    Doodle.inked(canvas, body, c.body);
    canvas.drawPath(
      Doodle.line([const Offset(-60, 2), const Offset(68, 2)], seed: 122),
      Doodle.stroke(c.stripe, 3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(54, -12)
        ..quadraticBezierTo(66, -12, 70, -4)
        ..lineTo(56, -4)
        ..close(),
      Doodle.fill(c.window),
    );
    // High wing on top with two spinning propellers.
    final wing = Doodle.box(
      const Rect.fromLTRB(-30, -24, 40, -16),
      radius: 4,
      seed: 123,
    );
    Doodle.inked(canvas, wing, c.stripe, width: 2.4);
    for (final x in [-12.0, 26.0]) {
      Doodle.inked(
        canvas,
        Doodle.blob(Offset(x, -12), 8, 5, seed: 124),
        c.stripe,
        width: 2,
      );
      final blade = math.sin(t * 40) * 10;
      canvas.drawLine(
        Offset(x + 9, -12 - blade),
        Offset(x + 9, -12 + blade),
        Doodle.stroke(Doodle.ink, 2.2),
      );
    }
    _hatch(canvas, hatchOpen);
  }

  static void _hatch(Canvas canvas, bool open) {
    if (!open) {
      canvas.drawLine(
        const Offset(-30, 12),
        const Offset(-14, 12),
        Doodle.stroke(Doodle.ink, 1.6),
      );
      return;
    }
    canvas.drawPath(
      Doodle.line([
        const Offset(-30, 12),
        const Offset(-36, 24),
        const Offset(-14, 12),
      ], seed: 131),
      Doodle.stroke(Doodle.ink, 2.2),
    );
    Doodle.inked(
      canvas,
      Doodle.burst(const Offset(-22, 20), 7, points: 6, seed: 132),
      const Color(0xFFFFF3B0),
      width: 1.6,
    );
  }
}
