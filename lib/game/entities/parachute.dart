import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/utils/doodle.dart';
import '../skins.dart';

enum CanopyState { packed, opening, open, collapsing, gone }

/// The canopy attached above a [Person]'s head. Purely visual: the physics
/// change from deploying lives in the person's FallBody.
///
/// Local origin is the attachment point (top of the person's head).
class Parachute extends PositionComponent {
  Parachute({required this.colors}) : super(priority: -1);

  static const double canopyWidth = 84;
  static const double canopyHeight = 42;
  static const double lineLength = 30;
  static const double openTime = 0.25;
  static const double collapseTime = 0.45;

  /// Gore colours, repeated across the canopy.
  final List<Color> colors;

  CanopyState state = CanopyState.packed;
  double _t = 0;
  double _clock = 0;

  /// Current descent speed, used to animate the canopy "breathing".
  double descent = 0;

  /// Picks canopy colours for a new person from the equipped skin.
  static List<Color> colorsFor(ChuteSkin skin, int seed) {
    if (skin.panels.isNotEmpty) return skin.panels;
    final pair = ChuteSkin.classicPairs[seed % ChuteSkin.classicPairs.length];
    return pair;
  }

  void open() {
    if (state != CanopyState.packed) return;
    state = CanopyState.opening;
    _t = 0;
  }

  void collapse() {
    if (state == CanopyState.packed || state == CanopyState.gone) {
      state = CanopyState.gone;
      return;
    }
    state = CanopyState.collapsing;
    _t = 0;
  }

  @override
  void update(double dt) {
    _clock += dt;
    _t += dt;
    if (state == CanopyState.opening && _t >= openTime) {
      state = CanopyState.open;
    } else if (state == CanopyState.collapsing && _t >= collapseTime) {
      state = CanopyState.gone;
    }
  }

  @override
  void render(Canvas canvas) {
    double inflate;
    double drop = 0;
    switch (state) {
      case CanopyState.packed:
      case CanopyState.gone:
        return;
      case CanopyState.opening:
        // Overshoot slightly for a snappy "pop".
        final u = (_t / openTime).clamp(0.0, 1.0);
        inflate = math.sin(u * math.pi * 0.62) / math.sin(math.pi * 0.62);
        inflate = inflate * 1.08 - (u > 0.9 ? (u - 0.9) * 0.8 : 0);
      case CanopyState.open:
        inflate = 1 + math.sin(_clock * 3.2) * 0.025;
      case CanopyState.collapsing:
        final u = (_t / collapseTime).clamp(0.0, 1.0);
        inflate = 1 - u * 0.85;
        drop = u * 26;
    }
    draw(
      canvas,
      colors,
      inflate: inflate,
      drop: drop,
      sway: math.sin(_clock * 1.7) * 0.04,
    );
  }

  /// Draws a canopy with its lines. Shared with menus and the tutorial.
  static void draw(
    Canvas canvas,
    List<Color> colors, {
    double inflate = 1,
    double drop = 0,
    double sway = 0,
    int seed = 4,
  }) {
    final w = canopyWidth * inflate.clamp(0.15, 1.2);
    final h = canopyHeight * (0.35 + 0.65 * inflate.clamp(0.0, 1.2));
    final bottomY = -lineLength + drop;
    final top = bottomY - h;

    canvas.save();
    canvas.rotate(sway);

    // Lines from hands to canopy rim.
    final lines = Doodle.stroke(Doodle.ink, 1.3);
    const lHand = Offset(-9, 7.5);
    const rHand = Offset(9, 7.5);
    for (var i = 0; i <= 4; i++) {
      final rimX = -w / 2 + w * i / 4;
      final hand = i < 2 ? lHand : (i > 2 ? rHand : const Offset(0, 6));
      canvas.drawLine(hand, Offset(rimX, bottomY), lines);
    }

    // Canopy dome: upper half-ellipse with a scalloped bottom edge.
    final dome = Path()
      ..moveTo(-w / 2, bottomY)
      ..cubicTo(-w / 2, top - h * 0.05, w / 2, top - h * 0.05, w / 2, bottomY);
    const gores = 5;
    for (var i = gores; i > 0; i--) {
      final x0 = -w / 2 + w * i / gores;
      final x1 = -w / 2 + w * (i - 1) / gores;
      dome.quadraticBezierTo((x0 + x1) / 2, bottomY - h * 0.18, x1, bottomY);
    }
    dome.close();

    canvas.save();
    canvas.clipPath(dome);
    for (var i = 0; i < gores; i++) {
      final x0 = -w / 2 + w * i / gores;
      canvas.drawRect(
        Rect.fromLTWH(x0, top - 4, w / gores + 0.5, h + 8),
        Doodle.fill(colors[i % colors.length]),
      );
    }
    // Soft shading on the right gores.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.12, top - 4, w * 0.4, h + 8),
      Doodle.fill(const Color(0x14000000)),
    );
    canvas.restore();

    // Gore seams and outline.
    final seam = Doodle.stroke(Doodle.ink, 1.6);
    for (var i = 1; i < gores; i++) {
      final x = -w / 2 + w * i / gores;
      final peakX = x * 0.55;
      canvas.drawLine(
        Offset(x, bottomY - h * 0.16),
        Offset(peakX, top + h * 0.08),
        seam,
      );
    }
    canvas.drawPath(dome, Doodle.stroke(Doodle.ink, 2.6));
    canvas.restore();
  }
}
