import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/utils/doodle.dart';
import '../rescue_game.dart';
import '../terrain/terrain.dart';

enum FishMode { patrol, dash, bite }

/// The predator below the landing line: shark, mini tank, sandworm, orca or
/// crocodile depending on the terrain. All variants share size and behaviour.
///
/// It only reacts to people who are already lost — it never takes a life by
/// itself, so it can never "steal" a rescuable person.
class Fish extends PositionComponent with HasGameReference<RescueGame> {
  Fish({
    required this.variant,
    required this.colors,
    required double x,
    required double y,
  }) : super(
         position: Vector2(x, y),
         size: Vector2(140, 60),
         anchor: Anchor.center,
         priority: 45,
       );

  final FishVariant variant;
  final FishPalette colors;

  FishMode mode = FishMode.patrol;
  double direction = 1;
  double _target = 0;
  double _clock = 0;
  double _biteT = 0;

  /// Number of bites performed (used by tests and feedback).
  int bites = 0;

  late final double _baseY = position.y;

  /// Sends the fish toward a splash at [x].
  void attack(double x) {
    _target = x;
    mode = FishMode.dash;
    direction = x >= position.x ? 1 : -1;
  }

  @override
  void update(double dt) {
    if (dt <= 0) return;
    _clock += dt;
    final cfg = game.config;
    final w = cfg.world.width;
    switch (mode) {
      case FishMode.patrol:
        position.x += direction * cfg.hazards.fishPatrolSpeed * dt;
        if (position.x > w - 60) direction = -1;
        if (position.x < 60) direction = 1;
        position.y = _baseY + math.sin(_clock * 2) * 4;
      case FishMode.dash:
        final dx = _target - position.x;
        final step = cfg.hazards.fishDashSpeed * dt;
        if (dx.abs() <= step) {
          position.x = _target;
          mode = FishMode.bite;
          _biteT = 0;
          bites++;
        } else {
          position.x += dx.sign * step;
          direction = dx.sign;
        }
      case FishMode.bite:
        _biteT += dt;
        // Leap up and drop back.
        position.y =
            _baseY - math.sin((_biteT / 0.7).clamp(0, 1) * math.pi) * 46;
        if (_biteT >= 0.7) {
          mode = FishMode.patrol;
          position.y = _baseY;
        }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(direction >= 0 ? 1 : -1, 1);
    final jaw = mode == FishMode.bite
        ? math.sin((_biteT / 0.7).clamp(0, 1) * math.pi)
        : (mode == FishMode.dash
              ? 0.4
              : 0.1 + math.sin(_clock * 3).abs() * 0.1);
    drawVariant(canvas, variant, colors, _clock, jaw);
    canvas.restore();
  }

  /// Draws the predator facing right, centred on (0, 0), inside 140×60.
  static void drawVariant(
    Canvas canvas,
    FishVariant variant,
    FishPalette c,
    double t,
    double jaw,
  ) {
    switch (variant) {
      case FishVariant.shark:
        _shark(canvas, c, t, jaw, orca: false);
      case FishVariant.orca:
        _shark(canvas, c, t, jaw, orca: true);
      case FishVariant.tank:
        _tank(canvas, c, t, jaw);
      case FishVariant.sandworm:
        _worm(canvas, c, t, jaw);
      case FishVariant.crocodile:
        _croc(canvas, c, t, jaw);
    }
  }

  static void _shark(
    Canvas canvas,
    FishPalette c,
    double t,
    double jaw, {
    required bool orca,
  }) {
    final tail = math.sin(t * 7) * 6;
    final body = Path()
      ..moveTo(-58, tail * 0.3)
      ..quadraticBezierTo(-20, -26, 40, -10)
      ..quadraticBezierTo(62, -4, 64, 2)
      ..lineTo(40, 4 + jaw * 10)
      ..quadraticBezierTo(0, 22, -58, tail * 0.3)
      ..close();
    // Tail fin.
    final tailFin = Doodle.line(
      [
        Offset(-52, tail * 0.3),
        Offset(-70, -18 + tail),
        Offset(-64, tail * 0.3),
        Offset(-70, 16 + tail),
      ],
      seed: 81,
      close: true,
    );
    Doodle.inked(canvas, tailFin, c.body);
    // Dorsal fin.
    final dorsal = Doodle.line(
      [const Offset(-12, -16), const Offset(2, -42), const Offset(14, -14)],
      seed: 82,
      close: true,
    );
    Doodle.inked(canvas, dorsal, c.body);
    Doodle.inked(canvas, body, c.body);
    // Belly.
    final belly = Path()
      ..moveTo(-40, 6)
      ..quadraticBezierTo(0, 20, 38, 6 + jaw * 8)
      ..quadraticBezierTo(0, 10, -40, 6)
      ..close();
    canvas.drawPath(belly, Doodle.fill(c.belly));
    if (orca) {
      canvas.drawPath(
        Doodle.blob(const Offset(28, -8), 8, 4, seed: 83),
        Doodle.fill(c.belly),
      );
    }
    // Teeth when the mouth opens.
    if (jaw > 0.2) {
      final mouth = Path()
        ..moveTo(38, 2)
        ..lineTo(62, 2)
        ..lineTo(40, 4 + jaw * 10)
        ..close();
      canvas.drawPath(mouth, Doodle.fill(const Color(0xFF8C2A2A)));
      final tooth = Doodle.fill(const Color(0xFFFFFFFF));
      for (var i = 0; i < 4; i++) {
        final x = 42.0 + i * 5;
        canvas.drawPath(
          Path()
            ..moveTo(x, 2)
            ..lineTo(x + 2.5, 6)
            ..lineTo(x + 5, 2)
            ..close(),
          tooth,
        );
      }
    }
    // Eye with an angry brow.
    canvas.drawCircle(
      const Offset(36, -6),
      3.2,
      Doodle.fill(const Color(0xFFFFFFFF)),
    );
    canvas.drawCircle(const Offset(37, -6), 1.7, Doodle.fill(Doodle.ink));
    canvas.drawLine(
      const Offset(30, -12),
      const Offset(41, -9),
      Doodle.stroke(Doodle.ink, 2),
    );
    // Gills.
    final gill = Doodle.stroke(Doodle.ink, 1.4);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(18.0 - i * 5, 0), width: 6, height: 12),
        -1.2,
        2.4,
        false,
        gill,
      );
    }
  }

  static void _tank(Canvas canvas, FishPalette c, double t, double jaw) {
    // Treads.
    final tread = Doodle.box(
      const Rect.fromLTRB(-56, 4, 56, 26),
      radius: 11,
      seed: 91,
    );
    Doodle.inked(canvas, tread, const Color(0xFF3A3D42));
    final wheel = Doodle.fill(const Color(0xFF8D9299));
    for (var i = 0; i < 6; i++) {
      final cx = -44.0 + i * 17.6;
      canvas.drawCircle(Offset(cx, 15), 6, wheel);
      canvas.drawCircle(Offset(cx, 15), 6, Doodle.stroke(Doodle.ink, 1.4));
      final a = t * 5;
      canvas.drawLine(
        Offset(cx, 15),
        Offset(cx + math.cos(a) * 5, 15 + math.sin(a) * 5),
        Doodle.stroke(Doodle.ink, 1.2),
      );
    }
    // Hull and turret.
    final hull = Doodle.line(
      [
        const Offset(-58, 6),
        const Offset(-48, -10),
        const Offset(50, -10),
        const Offset(60, 6),
      ],
      seed: 92,
      close: true,
    );
    Doodle.inked(canvas, hull, c.body);
    final turret = Doodle.blob(const Offset(-4, -18), 26, 12, seed: 93);
    Doodle.inked(canvas, turret, c.body);
    // Barrel recoils on a "bite".
    final recoil = jaw * 10;
    final barrel = Doodle.box(
      Rect.fromLTRB(18 - recoil, -23, 68 - recoil, -15),
      radius: 3,
      seed: 94,
    );
    Doodle.inked(canvas, barrel, c.belly, width: 2.4);
    if (jaw > 0.35) {
      Doodle.inked(
        canvas,
        Doodle.burst(Offset(74 - recoil, -19), 10 + jaw * 6, seed: 95),
        c.accent,
        width: 2,
      );
    }
    // Hatch + a star.
    canvas.drawCircle(const Offset(-8, -30), 6, Doodle.fill(c.belly));
    canvas.drawCircle(const Offset(-8, -30), 6, Doodle.stroke(Doodle.ink, 2));
    final star = Doodle.burst(const Offset(-30, -2), 5, points: 5, seed: 96);
    canvas.drawPath(star, Doodle.fill(c.accent));
  }

  static void _worm(Canvas canvas, FishPalette c, double t, double jaw) {
    // Segmented arcs poking up from the sand.
    for (var i = 4; i >= 0; i--) {
      final x = -50.0 + i * 22;
      final y = math.sin(t * 5 + i * 0.9) * 6 - (i == 4 ? jaw * 14 : 0);
      final seg = Doodle.blob(Offset(x, y), 15 - i * 0.6, 13, seed: 100 + i);
      Doodle.inked(canvas, seg, i.isEven ? c.body : c.belly);
    }
    final head = Offset(38, math.sin(t * 5 + 3.6) * 6 - jaw * 14);
    // Mouth ring.
    canvas.drawCircle(
      head.translate(10, 0),
      6 + jaw * 4,
      Doodle.fill(c.accent),
    );
    canvas.drawCircle(
      head.translate(10, 0),
      6 + jaw * 4,
      Doodle.stroke(Doodle.ink, 2),
    );
    canvas.drawCircle(head.translate(-2, -6), 2.4, Doodle.fill(Doodle.ink));
  }

  static void _croc(Canvas canvas, FishPalette c, double t, double jaw) {
    final tail = math.sin(t * 5) * 5;
    final body = Path()
      ..moveTo(-66, tail)
      ..quadraticBezierTo(-30, -16, 10, -12)
      ..lineTo(64, -6 - jaw * 14)
      ..lineTo(64, -2)
      ..lineTo(14, 0)
      ..lineTo(64, 2)
      ..lineTo(60, 8)
      ..quadraticBezierTo(-20, 18, -66, tail)
      ..close();
    Doodle.inked(canvas, body, c.body);
    canvas.drawPath(
      Path()
        ..moveTo(-40, 8)
        ..quadraticBezierTo(0, 15, 56, 7),
      Doodle.stroke(c.belly, 4),
    );
    // Back ridges.
    final ridge = Doodle.fill(c.belly.withValues(alpha: 0.7));
    for (var i = 0; i < 6; i++) {
      final x = -50.0 + i * 11;
      canvas.drawPath(
        Path()
          ..moveTo(x, -10 + tail * (1 - i / 6) * 0.4)
          ..lineTo(x + 4, -17)
          ..lineTo(x + 8, -10)
          ..close(),
        ridge,
      );
    }
    // Teeth.
    final tooth = Doodle.fill(const Color(0xFFFFFFFF));
    for (var i = 0; i < 5; i++) {
      final x = 24.0 + i * 8;
      canvas.drawPath(
        Path()
          ..moveTo(x, 1.5)
          ..lineTo(x + 3, 6)
          ..lineTo(x + 6, 1.5)
          ..close(),
        tooth,
      );
    }
    canvas.drawCircle(const Offset(6, -16), 5, Doodle.fill(c.accent));
    canvas.drawCircle(const Offset(6, -16), 5, Doodle.stroke(Doodle.ink, 1.8));
    canvas.drawLine(
      const Offset(6, -19),
      const Offset(6, -13),
      Doodle.stroke(Doodle.ink, 2),
    );
  }
}
