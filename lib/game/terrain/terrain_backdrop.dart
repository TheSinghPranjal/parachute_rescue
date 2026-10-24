import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/utils/doodle.dart';
import 'terrain.dart';

/// Sky, paper texture, sun, drifting clouds and the terrain's horizon props.
/// Static parts are recorded once into a [Picture] and replayed each frame.
class TerrainBackdrop extends PositionComponent {
  TerrainBackdrop({
    required this.theme,
    required this.worldSize,
    required this.groundY,
  }) : super(size: worldSize, priority: 0);

  final TerrainTheme theme;
  final Vector2 worldSize;
  final double groundY;

  late final Picture _static = _recordStatic();
  late final List<Path> _clouds = [
    for (var i = 0; i < 4; i++)
      Doodle.cloud(Offset.zero, 110 + i * 18.0, seed: 200 + i * 5),
  ];
  double _clock = 0;

  @override
  void update(double dt) => _clock += dt;

  @override
  void onRemove() {
    _static.dispose();
    super.onRemove();
  }

  Picture _recordStatic() {
    final rec = PictureRecorder();
    final canvas = Canvas(rec);
    final w = worldSize.x;
    final full = Rect.fromLTWH(0, 0, w, groundY + 4);
    canvas.drawRect(
      full,
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, groundY), [
          theme.sky.top,
          theme.sky.bottom,
        ]),
    );
    final grain = Doodle.paperGrain(
      Size(w, groundY),
      const Color(0x00000000),
      theme.sky.grain,
    );
    canvas.drawPicture(grain);
    grain.dispose();

    // Sun with doodled rays.
    final sun = Offset(w - 92, 250);
    final ray = Doodle.stroke(theme.sky.sun, 3);
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2;
      canvas.drawLine(
        sun + Offset(math.cos(a), math.sin(a)) * 40,
        sun + Offset(math.cos(a), math.sin(a)) * 54,
        ray,
      );
    }
    Doodle.inked(
      canvas,
      Doodle.blob(sun, 32, 32, seed: 210),
      theme.sky.sun,
      width: 2.6,
    );

    _props(canvas, w);
    return rec.endRecording();
  }

  void _props(Canvas canvas, double w) {
    final g = groundY;
    switch (theme.props) {
      case BackdropProps.island:
        // Island with lighthouse on the left, palm islet on the right.
        Doodle.inked(
          canvas,
          Doodle.blob(Offset(70, g + 4), 110, 46, seed: 220),
          theme.propSecondary,
        );
        Doodle.inked(
          canvas,
          Doodle.blob(Offset(60, g - 22), 80, 26, seed: 221),
          theme.propPrimary,
        );
        final tower = Doodle.line(
          [
            Offset(52, g - 40),
            Offset(58, g - 150),
            Offset(82, g - 150),
            Offset(88, g - 40),
          ],
          seed: 222,
          close: true,
        );
        Doodle.inked(canvas, tower, const Color(0xFFFFFFFF));
        for (var i = 0; i < 3; i++) {
          final y = g - 60 - i * 32.0;
          canvas.drawRect(
            Rect.fromLTRB(56 + i * 1.5, y - 12, 84 - i * 1.5, y),
            Doodle.fill(const Color(0xFFE8504F)),
          );
        }
        canvas.drawPath(tower, Doodle.stroke());
        Doodle.inked(
          canvas,
          Doodle.box(
            Rect.fromLTRB(54, g - 172, 86, g - 150),
            radius: 4,
            seed: 223,
          ),
          const Color(0xFFFFE066),
        );
        Doodle.inked(
          canvas,
          Doodle.line(
            [Offset(50, g - 172), Offset(70, g - 190), Offset(90, g - 172)],
            seed: 224,
            close: true,
          ),
          const Color(0xFFE8504F),
        );
        Doodle.inked(
          canvas,
          Doodle.blob(Offset(w - 40, g + 6), 90, 34, seed: 225),
          theme.propSecondary,
        );
        _palm(canvas, Offset(w - 52, g - 18));
      case BackdropProps.battlefield:
        // Bunker, sandbags, barbed wire and a wrecked tank silhouette.
        final bunker = Path()
          ..moveTo(10, g)
          ..quadraticBezierTo(80, g - 110, 150, g)
          ..close();
        Doodle.inked(canvas, bunker, const Color(0xFF8E8A78));
        canvas.drawRect(
          Rect.fromLTRB(52, g - 50, 108, g - 38),
          Doodle.fill(Doodle.ink),
        );
        for (var row = 0; row < 2; row++) {
          for (var i = 0; i < 5 - row; i++) {
            Doodle.inked(
              canvas,
              Doodle.blob(
                Offset(w - 150 + i * 26 + row * 13, g - 10 - row * 16),
                14,
                9,
                seed: 230 + i + row * 7,
              ),
              theme.propPrimary,
              width: 2.2,
            );
          }
        }
        final wire = Doodle.stroke(Doodle.ink, 1.6);
        for (var x = 160.0; x < w - 160; x += 44) {
          canvas.drawLine(
            Offset(x, g - 26),
            Offset(x, g),
            Doodle.stroke(const Color(0xFF6B4626), 3),
          );
        }
        for (var x = 160.0; x < w - 160; x += 11) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, g - 18), radius: 7),
            0,
            math.pi * 2,
            false,
            wire,
          );
        }
        // Distant wrecked tank.
        canvas.drawPath(
          Doodle.box(
            Rect.fromLTRB(w - 170, g - 76, w - 90, g - 56),
            radius: 6,
            seed: 238,
          ),
          Doodle.fill(theme.propSecondary.withValues(alpha: 0.6)),
        );
        canvas.drawLine(
          Offset(w - 120, g - 72),
          Offset(w - 60, g - 90),
          Doodle.stroke(theme.propSecondary.withValues(alpha: 0.6), 6),
        );
      case BackdropProps.desert:
        Doodle.inked(
          canvas,
          Doodle.blob(Offset(110, g + 10), 170, 56, seed: 240),
          theme.propSecondary,
        );
        Doodle.inked(
          canvas,
          Doodle.blob(Offset(w - 80, g + 14), 150, 44, seed: 241),
          theme.propSecondary,
        );
        final pyramid = Doodle.line(
          [
            Offset(w - 210, g - 30),
            Offset(w - 140, g - 140),
            Offset(w - 70, g - 30),
          ],
          seed: 242,
          close: true,
        );
        Doodle.inked(canvas, pyramid, const Color(0xFFE9B96E));
        Doodle.hatch(
          canvas,
          Rect.fromLTRB(w - 140, g - 110, w - 85, g - 40),
          const Color(0x55A8743A),
        );
        _cactus(canvas, Offset(70, g - 30));
        _cactus(canvas, Offset(w - 40, g - 20));
      case BackdropProps.arctic:
        Doodle.inked(
          canvas,
          Doodle.blob(Offset(90, g - 30), 160, 60, seed: 250),
          const Color(0xFFFFFFFF),
        );
        Doodle.inked(
          canvas,
          Doodle.blob(Offset(w - 60, g - 22), 120, 50, seed: 251),
          const Color(0xFFF3F9FD),
        );
        for (final x in [40.0, 80.0, w - 70]) {
          _pine(canvas, Offset(x, g - 40));
        }
        final igloo = Path()
          ..moveTo(w - 160, g - 30)
          ..quadraticBezierTo(w - 120, g - 110, w - 80, g - 30)
          ..close();
        Doodle.inked(canvas, igloo, const Color(0xFFFFFFFF));
        final brick = Doodle.stroke(const Color(0xFF8FB8D8), 1.4);
        canvas.drawLine(Offset(w - 150, g - 52), Offset(w - 90, g - 52), brick);
        canvas.drawLine(
          Offset(w - 140, g - 72),
          Offset(w - 100, g - 72),
          brick,
        );
        canvas.drawPath(
          Path()..addArc(
            Rect.fromLTRB(w - 132, g - 56, w - 108, g - 30),
            math.pi,
            math.pi,
          ),
          Doodle.fill(Doodle.ink),
        );
      case BackdropProps.swamp:
        for (final x in [30.0, 110.0, w - 50]) {
          _mangrove(canvas, Offset(x, g));
        }
        for (var i = 0; i <= (w - 360) ~/ 90; i++) {
          Doodle.inked(
            canvas,
            Doodle.blob(Offset(170.0 + i * 90, g - 4), 22, 6, seed: 260 + i),
            const Color(0xFF8CBF5A),
            width: 2,
          );
        }
    }
  }

  void _palm(Canvas canvas, Offset base) {
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          base.dx + 6,
          base.dy - 50,
          base.dx - 6,
          base.dy - 96,
        ),
      Doodle.stroke(const Color(0xFF8A5A2B), 7),
    );
    final top = base.translate(-6, -96);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi + i * math.pi / 4;
      final leaf = Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          top.dx + math.cos(a) * 30,
          top.dy + math.sin(a) * 30 - 10,
          top.dx + math.cos(a) * 50,
          top.dy + math.sin(a) * 26 + 14,
        );
      canvas.drawPath(leaf, Doodle.stroke(Doodle.ink, 9));
      canvas.drawPath(leaf, Doodle.stroke(theme.propPrimary, 6));
    }
  }

  void _cactus(Canvas canvas, Offset b) {
    final c = theme.propPrimary;
    Doodle.inked(
      canvas,
      Doodle.box(
        Rect.fromLTRB(b.dx - 9, b.dy - 70, b.dx + 9, b.dy + 10),
        radius: 9,
        seed: 270,
      ),
      c,
    );
    Doodle.inked(
      canvas,
      Doodle.box(
        Rect.fromLTRB(b.dx - 30, b.dy - 46, b.dx - 18, b.dy - 18),
        radius: 6,
        seed: 271,
      ),
      c,
      width: 2.4,
    );
    Doodle.inked(
      canvas,
      Doodle.box(
        Rect.fromLTRB(b.dx + 18, b.dy - 56, b.dx + 30, b.dy - 30),
        radius: 6,
        seed: 272,
      ),
      c,
      width: 2.4,
    );
  }

  void _pine(Canvas canvas, Offset b) {
    canvas.drawRect(
      Rect.fromLTRB(b.dx - 4, b.dy - 10, b.dx + 4, b.dy + 10),
      Doodle.fill(const Color(0xFF6B4626)),
    );
    for (var i = 0; i < 3; i++) {
      final y = b.dy - 10 - i * 22.0;
      final tri = Doodle.line(
        [
          Offset(b.dx - 26 + i * 6, y),
          Offset(b.dx, y - 36),
          Offset(b.dx + 26 - i * 6, y),
        ],
        seed: 280 + i,
        close: true,
      );
      Doodle.inked(canvas, tri, theme.propPrimary, width: 2.4);
      canvas.drawPath(
        Doodle.wave(
          b.dx - 14 + i * 4,
          b.dx + 14 - i * 4,
          y - 26,
          amplitude: 2,
          wavelength: 10,
        ),
        Doodle.stroke(const Color(0xFFFFFFFF), 3),
      );
    }
  }

  void _mangrove(Canvas canvas, Offset b) {
    final trunk = Doodle.stroke(theme.propSecondary, 6);
    for (final dx in [-14.0, 0.0, 14.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(b.dx + dx * 1.6, b.dy)
          ..quadraticBezierTo(b.dx + dx, b.dy - 30, b.dx, b.dy - 70),
        trunk,
      );
    }
    Doodle.inked(
      canvas,
      Doodle.cloud(Offset(b.dx, b.dy - 92), 110, seed: 290),
      theme.propPrimary,
    );
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPicture(_static);
    final w = worldSize.x;
    // Drifting clouds in the upper sky.
    for (var i = 0; i < _clouds.length; i++) {
      final speed = 8.0 + i * 3;
      final span = w + 300;
      final x = (i * 260 + _clock * speed) % span - 150;
      final y = 260.0 + i * 150 + math.sin(_clock * 0.3 + i) * 6;
      canvas.save();
      canvas.translate(x, y);
      Doodle.inked(canvas, _clouds[i], theme.sky.cloud, width: 2.4);
      canvas.restore();
    }
    _animatedProps(canvas, w);
  }

  void _animatedProps(Canvas canvas, double w) {
    switch (theme.props) {
      case BackdropProps.battlefield:
        // Smoke plumes rising from the field.
        for (final base in [
          Offset(80, groundY - 90),
          Offset(w - 110, groundY - 80),
        ]) {
          for (var i = 0; i < 5; i++) {
            final u = (_clock * 0.25 + i / 5) % 1;
            final p = base.translate(
              math.sin(u * 4 + i) * 10 + u * 20,
              -u * 220,
            );
            canvas.drawPath(
              Doodle.blob(p, 14 + u * 22, 12 + u * 18, seed: 300 + i),
              Doodle.fill(Color.fromRGBO(90, 88, 84, 0.35 * (1 - u))),
            );
          }
        }
      case BackdropProps.arctic:
        final flake = Doodle.fill(const Color(0xCCFFFFFF));
        for (var i = 0; i < 24; i++) {
          final x = (i * 97.0 + math.sin(_clock + i) * 20) % w;
          final y = (i * 53.0 + _clock * (30 + i % 5 * 6)) % groundY;
          canvas.drawCircle(Offset(x, y), 2.4, flake);
        }
      case BackdropProps.swamp:
        for (var i = 0; i < 10; i++) {
          final glow = (math.sin(_clock * 3 + i * 1.7) + 1) / 2;
          final p = Offset(
            (i * 131.0) % w,
            groundY - 60 - (i * 37.0) % 160 + math.sin(_clock + i) * 10,
          );
          canvas.drawCircle(
            p,
            3,
            Doodle.fill(Color.fromRGBO(255, 240, 120, glow)),
          );
        }
      case BackdropProps.island:
      case BackdropProps.desert:
        break;
    }
  }
}

/// The ground or water body below the landing line (behind decks/people).
class GroundLayer extends PositionComponent {
  GroundLayer({
    required this.theme,
    required this.worldSize,
    required this.groundY,
  }) : super(priority: 15);

  final TerrainTheme theme;
  final Vector2 worldSize;
  final double groundY;
  double _clock = 0;

  @override
  void update(double dt) => _clock += dt;

  @override
  void render(Canvas canvas) {
    final w = worldSize.x;
    final body = Rect.fromLTRB(0, groundY, w, worldSize.y);
    canvas.drawRect(
      body,
      Paint()
        ..shader = Gradient.linear(Offset(0, groundY), Offset(0, worldSize.y), [
          theme.groundFill,
          theme.groundDeep,
        ]),
    );
    final accent = Doodle.stroke(theme.groundAccent, 2.4);
    switch (theme.ground) {
      case GroundStyle.water:
      case GroundStyle.swamp:
        for (var row = 0; row < 5; row++) {
          final y = groundY + 40 + row * 36.0;
          for (var i = 0; i < ((w + 80) / 140).ceil(); i++) {
            final x =
                (i * 140.0 + row * 60 + _clock * (row.isEven ? 14 : -10)) %
                    (w + 80) -
                40;
            canvas.drawPath(
              Doodle.wave(
                x,
                x + 40,
                y,
                amplitude: 3,
                wavelength: 20,
                phase: _clock * 2,
              ),
              accent,
            );
          }
        }
        if (theme.ground == GroundStyle.swamp) {
          for (var i = 0; i < ((w - 60) / 120).ceil(); i++) {
            Doodle.inked(
              canvas,
              Doodle.blob(
                Offset(60.0 + i * 120, groundY + 70 + (i % 2) * 70),
                22,
                7,
                seed: 310 + i,
              ),
              const Color(0xFF8CBF5A),
              width: 2,
            );
          }
        }
      case GroundStyle.dirt:
        // Craters and rocks.
        for (var i = 0; i < ((w - 80) / 140).ceil(); i++) {
          final c = Offset(80.0 + i * 140, groundY + 60 + (i % 2) * 70);
          canvas.drawOval(
            Rect.fromCenter(center: c, width: 70, height: 18),
            Doodle.fill(theme.groundDeep),
          );
          canvas.drawOval(
            Rect.fromCenter(center: c, width: 70, height: 18),
            Doodle.stroke(Doodle.ink, 2),
          );
        }
        Doodle.hatch(
          canvas,
          Rect.fromLTRB(0, groundY + 20, w, worldSize.y - 10),
          theme.groundAccent,
          gap: 22,
        );
      case GroundStyle.sand:
        for (var row = 0; row < 4; row++) {
          canvas.drawPath(
            Doodle.wave(
              0,
              w,
              groundY + 50 + row * 45,
              amplitude: 6,
              wavelength: 140,
              phase: row.toDouble(),
            ),
            accent,
          );
        }
      case GroundStyle.snow:
        for (var i = 0; i < ((w - 110) / 170).ceil(); i++) {
          final c = Offset(110.0 + i * 170, groundY + 80 + (i % 2) * 60);
          canvas.drawOval(
            Rect.fromCenter(center: c, width: 90, height: 24),
            Doodle.fill(const Color(0xFF3F6E9A)),
          );
          canvas.drawOval(
            Rect.fromCenter(center: c, width: 90, height: 24),
            Doodle.stroke(Doodle.ink, 2),
          );
        }
    }
  }
}

/// Thin surface strip drawn in front of decks, so boats sit *in* the water
/// and wheels sit *on* the ground.
class GroundSurface extends PositionComponent {
  GroundSurface({
    required this.theme,
    required this.worldSize,
    required this.groundY,
  }) : super(priority: 42);

  final TerrainTheme theme;
  final Vector2 worldSize;
  final double groundY;
  double _clock = 0;

  @override
  void update(double dt) => _clock += dt;

  @override
  void render(Canvas canvas) {
    final w = worldSize.x;
    if (theme.isLiquid) {
      final surface =
          Doodle.wave(
              -10,
              w + 10,
              groundY + 10,
              amplitude: 4,
              wavelength: 46,
              phase: _clock * 2.2,
            )
            ..lineTo(w + 10, groundY + 26)
            ..lineTo(-10, groundY + 26)
            ..close();
      canvas.drawPath(
        surface,
        Doodle.fill(theme.groundFill.withValues(alpha: 0.92)),
      );
      canvas.drawPath(
        Doodle.wave(
          -10,
          w + 10,
          groundY + 10,
          amplitude: 4,
          wavelength: 46,
          phase: _clock * 2.2,
        ),
        Doodle.stroke(Doodle.ink, 2.6),
      );
    } else {
      canvas.drawPath(
        Doodle.wave(-10, w + 10, groundY + 2, amplitude: 1.5, wavelength: 90),
        Doodle.stroke(Doodle.ink, 3),
      );
      // Tufts / pebbles along the surface.
      final tuft = Doodle.stroke(
        theme.ground == GroundStyle.snow
            ? const Color(0xFF8FB8D8)
            : theme.groundDeep,
        2,
      );
      for (var x = 12.0; x < w; x += 37) {
        canvas.drawLine(
          Offset(x, groundY + 2),
          Offset(x - 4, groundY - 6),
          tuft,
        );
        canvas.drawLine(
          Offset(x + 4, groundY + 2),
          Offset(x + 6, groundY - 7),
          tuft,
        );
      }
    }
  }
}
