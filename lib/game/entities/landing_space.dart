import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/utils/doodle.dart';
import '../../domain/landing.dart';
import '../rescue_game.dart';
import '../terrain/terrain.dart';

/// The moving rescue platform: a boat on water, an armoured truck on the
/// battlefield, a cart, sled or raft elsewhere. Every variant has the same
/// deck width, deck height and movement — only the art differs.
///
/// Position is the centre of the deck surface.
class LandingSpace extends PositionComponent with HasGameReference<RescueGame> {
  LandingSpace({
    required this.variant,
    required this.colors,
    required double x,
    required this.deckY,
    required this.halfWidth,
    required this.minX,
    required this.maxX,
    this.direction = 1,
    this.speed = 70,
  }) : _prevX = x,
       super(
         position: Vector2(x, deckY),
         size: Vector2(halfWidth * 2 + 30, 90),
         anchor: const Anchor(0.5, 0.42),
         priority: 20,
       );

  /// Deck top sits this far above the ground/waterline.
  static const double deckHeightAboveGround = 24;

  final LandingVariant variant;
  final LandingPalette colors;
  final double deckY;
  final double halfWidth;
  final double minX;
  final double maxX;

  /// +1 moving right, -1 moving left.
  double direction;

  /// Current speed (u/s); set by the difficulty director.
  double speed;

  double _prevX;
  double _clock = 0;
  double _turnSquash = 0;
  double _cheer = 0;

  /// Vertical bob offset applied to riders.
  double get bob => math.sin(_clock * 2.4) * 1.5;

  /// Deck span at the start and end of the current substep.
  DeckSweep get sweep => DeckSweep(
    deckY: deckY,
    prevCenterX: _prevX,
    centerX: position.x,
    halfWidth: halfWidth,
  );

  void celebrate() => _cheer = 0.6;

  @override
  void update(double dt) {
    _prevX = position.x;
    if (dt <= 0) return;
    _clock += dt;
    _turnSquash = math.max(0, _turnSquash - dt * 3);
    _cheer = math.max(0, _cheer - dt);
    position.x += direction * speed * dt;
    if (position.x > maxX) {
      position.x = maxX;
      direction = -1;
      _turnSquash = 1;
    } else if (position.x < minX) {
      position.x = minX;
      direction = 1;
      _turnSquash = 1;
    }
  }

  @override
  void render(Canvas canvas) {
    // Local frame: deck centre at (cx, deckLocalY).
    final cx = size.x / 2;
    final dy = size.y * 0.42;
    canvas.save();
    canvas.translate(cx, dy + bob - _cheer * 4 * math.sin(_cheer * 20).abs());
    // Face the travel direction, with a brief squash when turning.
    canvas.scale(direction >= 0 ? 1 : -1, 1);
    canvas.scale(1 + _turnSquash * 0.06, 1 - _turnSquash * 0.06);
    drawVariant(canvas, variant, colors, halfWidth, _clock);
    canvas.restore();
  }

  /// Draws a landing space with its deck surface on y = 0, centred on x = 0.
  /// Shared with the menu and the tutorial.
  static void drawVariant(
    Canvas canvas,
    LandingVariant variant,
    LandingPalette c,
    double hw,
    double t,
  ) {
    switch (variant) {
      case LandingVariant.boat:
        _boat(canvas, c, hw);
      case LandingVariant.armoredTruck:
        _truck(canvas, c, hw, t);
      case LandingVariant.camelCart:
        _cart(canvas, c, hw, t);
      case LandingVariant.iceSled:
        _sled(canvas, c, hw);
      case LandingVariant.raft:
        _raft(canvas, c, hw);
    }
  }

  static void _deckPlanks(Canvas canvas, double hw, Color deck) {
    final r = Rect.fromLTRB(-hw, -5, hw, 4);
    Doodle.inked(canvas, Doodle.box(r, radius: 3, seed: 21), deck, width: 2.4);
    final seam = Doodle.stroke(Doodle.ink, 1.1);
    for (var x = -hw + 22; x < hw; x += 22) {
      canvas.drawLine(Offset(x, -4), Offset(x, 3), seam);
    }
  }

  static void _flag(Canvas canvas, Offset base, Color color) {
    canvas.drawLine(
      base,
      base.translate(0, -34),
      Doodle.stroke(Doodle.ink, 2.4),
    );
    final flag = Doodle.line(
      [base.translate(0, -34), base.translate(18, -29), base.translate(0, -23)],
      seed: 9,
      close: true,
    );
    Doodle.inked(canvas, flag, color, width: 2);
  }

  static void _boat(Canvas canvas, LandingPalette c, double hw) {
    // Hull.
    final hull = Doodle.line(
      [
        Offset(-hw - 14, -2),
        Offset(hw + 18, -2),
        Offset(hw - 6, 36),
        Offset(-hw + 8, 36),
      ],
      seed: 31,
      close: true,
    );
    Doodle.inked(canvas, hull, c.hull);
    canvas.drawPath(
      Doodle.line([Offset(-hw - 8, 10), Offset(hw + 12, 10)], seed: 32),
      Doodle.stroke(c.trim, 4),
    );
    _deckPlanks(canvas, hw, c.deck);
    // Small wheelhouse at the stern (kept low so it never blocks landings).
    final cabin = Doodle.box(
      Rect.fromLTRB(-hw + 6, -26, -hw + 44, -5),
      radius: 4,
      seed: 33,
    );
    Doodle.inked(canvas, cabin, c.cabin, width: 2.4);
    canvas.drawRect(
      Rect.fromLTRB(-hw + 12, -21, -hw + 24, -12),
      Doodle.fill(const Color(0xFF7CC4F0)),
    );
    canvas.drawRect(
      Rect.fromLTRB(-hw + 12, -21, -hw + 24, -12),
      Doodle.stroke(Doodle.ink, 1.6),
    );
    // Life ring.
    canvas.drawCircle(
      Offset(hw - 22, 20),
      9,
      Doodle.stroke(const Color(0xFFFFFFFF), 6),
    );
    canvas.drawCircle(Offset(hw - 22, 20), 9, Doodle.stroke(c.flag, 2.2));
    canvas.drawCircle(Offset(hw - 22, 20), 12, Doodle.stroke(Doodle.ink, 1.4));
    _flag(canvas, Offset(-hw + 34, -26), c.flag);
  }

  static void _wheel(Canvas canvas, Offset center, double r, double t) {
    canvas.drawCircle(center, r, Doodle.fill(const Color(0xFF2E3138)));
    canvas.drawCircle(center, r, Doodle.stroke(Doodle.ink, 2.4));
    canvas.drawCircle(center, r * 0.42, Doodle.fill(const Color(0xFF9AA0A8)));
    final spoke = Doodle.stroke(const Color(0xFF9AA0A8), 1.6);
    for (var i = 0; i < 3; i++) {
      final a = t * 6 + i * math.pi * 2 / 3;
      canvas.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * r * 0.8,
        spoke,
      );
    }
  }

  static void _truck(Canvas canvas, LandingPalette c, double hw, double t) {
    // Armoured body under the flatbed.
    final body = Doodle.line(
      [
        Offset(-hw - 4, 0),
        Offset(hw + 26, 0),
        Offset(hw + 30, 22),
        Offset(-hw - 8, 22),
      ],
      seed: 41,
      close: true,
    );
    Doodle.inked(canvas, body, c.hull);
    // Camo blotches.
    for (var i = 0; i < 5; i++) {
      canvas.drawPath(
        Doodle.blob(Offset(-hw + 18 + i * hw * 0.42, 11), 9, 5, seed: 42 + i),
        Doodle.fill(c.trim),
      );
    }
    // Cab ahead of the deck.
    final cab = Doodle.line(
      [
        Offset(hw + 2, 0),
        Offset(hw + 2, -26),
        Offset(hw + 20, -26),
        Offset(hw + 30, -8),
        Offset(hw + 30, 0),
      ],
      seed: 43,
      close: true,
    );
    Doodle.inked(canvas, cab, c.cabin, width: 2.6);
    canvas.drawRect(
      Rect.fromLTRB(hw + 8, -21, hw + 19, -11),
      Doodle.fill(const Color(0xFF2E3A44)),
    );
    _deckPlanks(canvas, hw, c.deck);
    // Rivets along the side.
    final rivet = Doodle.fill(Doodle.ink);
    for (var x = -hw + 6; x < hw + 20; x += 18) {
      canvas.drawCircle(Offset(x, 5), 1.4, rivet);
    }
    _wheel(canvas, Offset(-hw + 22, 26), 11, t);
    _wheel(canvas, const Offset(0, 26), 11, t);
    _wheel(canvas, Offset(hw + 12, 26), 11, t);
    // Red-cross medic panel so it reads as "rescue".
    final panel = Rect.fromCenter(
      center: Offset(-hw * 0.45, 11),
      width: 18,
      height: 14,
    );
    canvas.drawRect(panel, Doodle.fill(const Color(0xFFFFFFFF)));
    canvas.drawRect(panel, Doodle.stroke(Doodle.ink, 1.4));
    canvas.drawRect(
      Rect.fromCenter(center: panel.center, width: 4, height: 10),
      Doodle.fill(c.flag),
    );
    canvas.drawRect(
      Rect.fromCenter(center: panel.center, width: 10, height: 4),
      Doodle.fill(c.flag),
    );
    _flag(canvas, Offset(-hw + 6, -4), c.flag);
  }

  static void _cart(Canvas canvas, LandingPalette c, double hw, double t) {
    final bed = Doodle.box(Rect.fromLTRB(-hw, 0, hw, 18), radius: 3, seed: 51);
    Doodle.inked(canvas, bed, c.hull);
    final slat = Doodle.stroke(c.trim, 2);
    for (var x = -hw + 14; x < hw; x += 16) {
      canvas.drawLine(Offset(x, 3), Offset(x, 15), slat);
    }
    _deckPlanks(canvas, hw, c.deck);
    _wheel(canvas, Offset(-hw * 0.55, 24), 13, t);
    _wheel(canvas, Offset(hw * 0.55, 24), 13, t);
    // Camel pulling at the front.
    canvas.drawLine(
      Offset(hw, 6),
      Offset(hw + 18, 2),
      Doodle.stroke(Doodle.ink, 2),
    );
    final leg = Doodle.stroke(Doodle.ink, 3);
    final step = math.sin(t * 8) * 4;
    for (final (x, s) in [
      (hw + 26, step),
      (hw + 34, -step),
      (hw + 50, -step),
      (hw + 58, step),
    ]) {
      canvas.drawLine(Offset(x, -2), Offset(x + s, 26), leg);
    }
    final camel = Path.combine(
      PathOperation.union,
      Doodle.blob(Offset(hw + 42, -8), 24, 12, seed: 52),
      Doodle.blob(Offset(hw + 40, -20), 12, 10, seed: 53),
    );
    Doodle.inked(canvas, camel, c.cabin, width: 2.4);
    final neck = Doodle.line([
      Offset(hw + 62, -10),
      Offset(hw + 72, -30),
    ], seed: 54);
    canvas.drawPath(neck, Doodle.stroke(Doodle.ink, 9));
    canvas.drawPath(neck, Doodle.stroke(c.cabin, 5));
    final head = Doodle.blob(Offset(hw + 78, -32), 10, 6, seed: 55);
    Doodle.inked(canvas, head, c.cabin, width: 2.2);
    canvas.drawCircle(Offset(hw + 80, -34), 1.6, Doodle.fill(Doodle.ink));
    _flag(canvas, Offset(-hw + 6, -4), c.flag);
  }

  static void _sled(Canvas canvas, LandingPalette c, double hw) {
    final body = Doodle.box(Rect.fromLTRB(-hw, 0, hw, 16), radius: 4, seed: 61);
    Doodle.inked(canvas, body, c.hull);
    canvas.drawPath(
      Doodle.line([
        Offset(-hw - 6, 26),
        Offset(hw + 4, 26),
        Offset(hw + 18, 14),
      ], seed: 62),
      Doodle.stroke(Doodle.ink, 4),
    );
    canvas.drawPath(
      Doodle.line([
        Offset(-hw - 6, 26),
        Offset(hw + 4, 26),
        Offset(hw + 18, 14),
      ], seed: 62),
      Doodle.stroke(c.trim, 2),
    );
    final strut = Doodle.stroke(Doodle.ink, 2.2);
    canvas.drawLine(Offset(-hw * 0.6, 16), Offset(-hw * 0.6, 26), strut);
    canvas.drawLine(Offset(hw * 0.6, 16), Offset(hw * 0.6, 26), strut);
    _deckPlanks(canvas, hw, c.deck);
    _flag(canvas, Offset(-hw + 6, -4), c.flag);
  }

  static void _raft(Canvas canvas, LandingPalette c, double hw) {
    for (var i = 0; i < 2; i++) {
      final log = Doodle.box(
        Rect.fromLTRB(-hw - 6, 2 + i * 12.0, hw + 6, 13 + i * 12.0),
        radius: 6,
        seed: 71 + i,
      );
      Doodle.inked(canvas, log, c.hull, width: 2.4);
      canvas.drawCircle(
        Offset(hw + 1, 7.5 + i * 12),
        3,
        Doodle.stroke(c.trim, 1.4),
      );
    }
    _deckPlanks(canvas, hw, c.deck);
    // Rope lashings.
    final rope = Doodle.stroke(c.cabin, 2.4);
    for (final x in [-hw * 0.6, 0.0, hw * 0.6]) {
      canvas.drawLine(Offset(x - 3, -5), Offset(x + 3, 26), rope);
    }
    _flag(canvas, Offset(-hw + 6, -4), c.flag);
  }
}
