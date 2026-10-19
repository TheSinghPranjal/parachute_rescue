import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/utils/doodle.dart';
import '../../domain/fall_physics.dart';
import '../../domain/landing.dart';
import '../../domain/scoring.dart';
import '../rescue_game.dart';
import 'landing_space.dart';
import 'parachute.dart';

/// The one and only person size. Terrains, skins and difficulty never change
/// it — every stick figure in the game is exactly this big.
final Vector2 kPersonSize = Vector2(34, 56);

/// Half the person's height: distance from centre to feet.
const double kPersonHalfHeight = 28;

/// Taps within this multiple of the body rect count as hitting the person.
const double kTouchInflate = 1.6;

enum PersonFate { airborne, rescued, lost }

/// A falling stick figure: physics body, state machine, art and hit areas.
class Person extends PositionComponent with HasGameReference<RescueGame> {
  Person({
    required this.id,
    required double x,
    required double y,
    required List<Color> canopyColors,
    Color? shirt,
    double initialVx = 0,
  }) : body = FallBody(x: x, y: y, vx: initialVx, vy: 40),
       _shirt = shirt,
       super(
         position: Vector2(x, y),
         size: kPersonSize,
         anchor: Anchor.center,
         priority: 30,
       ) {
    parachute = Parachute(colors: canopyColors);
  }

  final int id;
  final FallBody body;
  final Color? _shirt;
  late final Parachute parachute;

  PersonFate fate = PersonFate.airborne;
  LossCause? lossCause;
  double _age = 0;
  double _fateTime = 0;
  double _fade = 1;

  // Rescue ride.
  LandingSpace? _deck;
  double _deckOffset = 0;

  /// Seconds a person stays in an active UFO beam (reset when out).
  double beamExposure = 0;

  bool get isAirborne => fate == PersonFate.airborne;
  bool get chuteDeployed => body.chuteDeployed;
  double get feetY => body.y + kPersonHalfHeight;

  /// Body rect in world space.
  Rect get bodyRect => Rect.fromCenter(
    center: Offset(body.x, body.y),
    width: kPersonSize.x,
    height: kPersonSize.y,
  );

  /// Generous rect for taps so a moving target is easy to hit.
  Rect get touchRect => Rect.fromCenter(
    center: Offset(body.x, body.y),
    width: kPersonSize.x * kTouchInflate,
    height: kPersonSize.y * kTouchInflate,
  );

  /// Area that hazards can hit: body, plus the canopy while it is open.
  Rect get hurtRect {
    final b = bodyRect;
    if (!chuteDeployed) return b;
    return b.expandToInclude(
      Rect.fromLTWH(
        body.x - Parachute.canopyWidth / 2,
        b.top - Parachute.canopyHeight - Parachute.lineLength * 0.4,
        Parachute.canopyWidth,
        Parachute.canopyHeight,
      ),
    );
  }

  @override
  void onLoad() {
    parachute.position = Vector2(size.x / 2, 2);
    add(parachute);
  }

  @override
  void onRemove() {
    game.unregister(this);
    super.onRemove();
  }

  /// Opens the chute. Returns false if it could not be opened.
  bool deploy() {
    if (!isAirborne) return false;
    if (!body.deploy()) return false;
    parachute.open();
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    switch (fate) {
      case PersonFate.airborne:
        _simulate(dt);
      case PersonFate.rescued:
        _ride(dt);
      case PersonFate.lost:
        _afterLoss(dt);
    }
    position.setValues(body.x, body.y);
  }

  void _simulate(double dt) {
    final cfg = game.config;
    final prevFeet = feetY;
    var prevX = body.x;
    body.step(dt, game.wind.acceleration, cfg.physics);
    if (body.applyEdges(cfg.world.width, size.x / 2, cfg.physics.edgeRule)) {
      // Don't sweep a deck test across the whole screen after a wrap.
      prevX = body.x;
    }
    parachute.descent = body.vy;

    for (final deck in game.landingSpaces) {
      final hit = sweptDeckHit(
        prevFeetY: prevFeet,
        feetY: feetY,
        prevX: prevX,
        x: body.x,
        footprintHalfWidth: cfg.landing.footprintHalfWidth,
        deck: deck.sweep,
      );
      if (hit == null) continue;
      if (chuteDeployed || !cfg.landing.requireChuteToLand) {
        _land(deck);
      } else {
        // Free-falling onto a deck is a crash.
        body.y = deck.deckY - kPersonHalfHeight;
        markLost(LossCause.crash);
      }
      return;
    }

    if (crossedGround(
      prevFeetY: prevFeet,
      feetY: feetY,
      groundY: cfg.world.groundY,
    )) {
      body.y = cfg.world.groundY - kPersonHalfHeight + 4;
      markLost(LossCause.water);
    }
  }

  void _land(LandingSpace deck) {
    fate = PersonFate.rescued;
    _fateTime = 0;
    _deck = deck;
    final half = deck.sweep.halfWidth - 10;
    _deckOffset = (body.x - deck.position.x).clamp(-half, half);
    body
      ..vx = 0
      ..vy = 0
      ..y = deck.deckY - kPersonHalfHeight;
    parachute.collapse();
    final risky =
        (body.deployedAtY ?? -1e9) >
        deck.deckY - game.config.landing.riskWindow;
    game.onPersonRescued(this, deck, risky: risky);
  }

  /// Ends this person's flight. Safe to call more than once; only the first
  /// call has any effect, so one incident can only cost one life.
  void markLost(LossCause cause) {
    if (fate != PersonFate.airborne) return;
    fate = PersonFate.lost;
    lossCause = cause;
    _fateTime = 0;
    parachute.collapse();
    if (cause == LossCause.helicopter || cause == LossCause.crash) {
      // Knocked away: a little hop, then a tumble into the ground.
      body.vy = cause == LossCause.crash ? -260 : -160;
      body.vx = (body.vx >= 0 ? 1 : -1) * 120;
    }
    game.onPersonLost(this, cause);
  }

  void _ride(double dt) {
    _fateTime += dt;
    final deck = _deck;
    if (deck != null && deck.isMounted) {
      body.x = deck.position.x + _deckOffset;
      body.y = deck.deckY - kPersonHalfHeight + deck.bob;
    }
    // Cheer, then hop below deck.
    if (_fateTime > 1.6) _fade = (1 - (_fateTime - 1.6) / 0.4).clamp(0, 1);
    if (_fateTime > 2.0) removeFromParent();
  }

  void _afterLoss(double dt) {
    _fateTime += dt;
    final groundY = game.config.world.groundY;
    switch (lossCause!) {
      case LossCause.water:
        // Sink below the surface (clipped in render), then disappear.
        body.y += 45 * dt;
        if (_fateTime > 1.2) removeFromParent();
      case LossCause.crash:
      case LossCause.helicopter:
      case LossCause.lightning:
        // Tumble down; vanish on reaching the ground (no further penalty).
        body.vy = math.min(body.vy + 900 * dt, 520);
        body.x += body.vx * dt;
        body.y += body.vy * dt;
        if (feetY > groundY + 30 || _fateTime > 3) removeFromParent();
      case LossCause.ufo:
        // Drawn up the beam, fading out.
        body.y -= 140 * dt;
        _fade = (1 - _fateTime / 0.9).clamp(0, 1);
        if (_fateTime > 0.9) removeFromParent();
    }
  }

  // ---------------------------------------------------------------- render --

  static const _limb = 3.4;

  @override
  void render(Canvas canvas) {
    final sinking = fate == PersonFate.lost && lossCause == LossCause.water;
    if (sinking) {
      canvas.save();
      final localGround =
          game.config.world.groundY - (body.y - kPersonHalfHeight);
      canvas.clipRect(Rect.fromLTWH(-80, -120, 200, 120 + localGround));
    }
    final tumbling =
        fate == PersonFate.lost &&
        (lossCause == LossCause.helicopter || lossCause == LossCause.crash);
    if (tumbling) {
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      canvas.rotate(_fateTime * 9);
      canvas.translate(-size.x / 2, -size.y / 2);
    }

    // The canopy (child) renders after this; the figure is drawn here.
    drawFigure(canvas, _pose(), _age, id, shirt: _shirt);

    if (tumbling) canvas.restore();
    if (sinking) canvas.restore();
  }

  final Paint _fadePaint = Paint();

  @override
  void renderTree(Canvas canvas) {
    // Fade the figure and its canopy together.
    if (_fade >= 1) {
      super.renderTree(canvas);
      return;
    }
    if (_fade <= 0) return;
    _fadePaint.color = Color.fromRGBO(0, 0, 0, _fade);
    canvas.saveLayer(null, _fadePaint);
    super.renderTree(canvas);
    canvas.restore();
  }

  FigurePose _pose() {
    switch (fate) {
      case PersonFate.airborne:
        return chuteDeployed ? FigurePose.hanging : FigurePose.falling;
      case PersonFate.rescued:
        return FigurePose.cheering;
      case PersonFate.lost:
        return lossCause == LossCause.lightning
            ? FigurePose.zapped
            : FigurePose.panicking;
    }
  }

  /// Draws a stick figure inside a [kPersonSize] box. Shared with menus and
  /// the tutorial so the character always looks (and measures) the same.
  static void drawFigure(
    Canvas canvas,
    FigurePose pose,
    double t,
    int seed, {
    Color? shirt,
  }) {
    final w = kPersonSize.x;
    final cx = w / 2;
    const headY = 10.0;
    const headR = 8.5;
    const neckY = headY + headR;
    const hipY = 37.0;
    final ink = pose == FigurePose.zapped
        ? const Color(0xFF111111)
        : Doodle.ink;
    final limb = Doodle.stroke(ink, _limb);

    // Arms.
    final shoulder = Offset(cx, neckY + 5);
    late Offset lHand, rHand;
    switch (pose) {
      case FigurePose.falling:
        final f = math.sin(t * 18 + seed) * 5;
        lHand = Offset(cx - 15, neckY - 6 + f);
        rHand = Offset(cx + 15, neckY - 6 - f);
      case FigurePose.hanging:
        lHand = Offset(cx - 9, neckY - 9);
        rHand = Offset(cx + 9, neckY - 9);
      case FigurePose.cheering:
        final f = math.sin(t * 10) * 4;
        lHand = Offset(cx - 13, neckY - 12 + f);
        rHand = Offset(cx + 13, neckY - 12 - f);
      case FigurePose.panicking:
        final f = math.sin(t * 22) * 6;
        lHand = Offset(cx - 14 + f, neckY - 10);
        rHand = Offset(cx + 14 - f, neckY - 10);
      case FigurePose.zapped:
        lHand = Offset(cx - 15, neckY + 2);
        rHand = Offset(cx + 15, neckY + 2);
    }
    canvas.drawPath(
      Doodle.line(
        [lHand, shoulder.translate(-2, 2), shoulder],
        seed: seed,
        jitter: 0.6,
      ),
      limb,
    );
    canvas.drawPath(
      Doodle.line(
        [rHand, shoulder.translate(2, 2), shoulder],
        seed: seed + 1,
        jitter: 0.6,
      ),
      limb,
    );

    // Torso (with optional shirt).
    if (shirt != null) {
      final torso = Doodle.box(
        Rect.fromLTRB(cx - 6, neckY + 2, cx + 6, hipY + 1),
        radius: 4,
        seed: seed,
      );
      Doodle.inked(canvas, torso, shirt, width: 2.2);
    } else {
      canvas.drawLine(Offset(cx, neckY), Offset(cx, hipY), limb);
    }

    // Legs.
    final swing = switch (pose) {
      FigurePose.falling => math.sin(t * 14 + seed) * 4,
      FigurePose.hanging => math.sin(t * 2.5 + seed) * 3,
      FigurePose.cheering => 0.0,
      FigurePose.panicking => math.sin(t * 20) * 5,
      FigurePose.zapped => 0.0,
    };
    final hip = Offset(cx, hipY);
    canvas.drawPath(
      Doodle.line(
        [hip, Offset(cx - 6 + swing, 46), Offset(cx - 9 + swing, 55)],
        seed: seed + 2,
        jitter: 0.6,
      ),
      limb,
    );
    canvas.drawPath(
      Doodle.line(
        [hip, Offset(cx + 6 - swing, 46), Offset(cx + 9 - swing, 55)],
        seed: seed + 3,
        jitter: 0.6,
      ),
      limb,
    );

    // Head.
    final head = Doodle.blob(
      Offset(cx, headY),
      headR,
      headR,
      seed: seed,
      wobble: 0.04,
    );
    Doodle.inked(
      canvas,
      head,
      pose == FigurePose.zapped
          ? const Color(0xFF55585E)
          : const Color(0xFFFFFFFF),
      width: 2.6,
    );
    _face(canvas, Offset(cx, headY), pose, ink);
  }

  static void _face(Canvas canvas, Offset c, FigurePose pose, Color ink) {
    final eye = Doodle.fill(ink);
    final line = Doodle.stroke(ink, 1.8);
    switch (pose) {
      case FigurePose.zapped:
        for (final dx in [-3.2, 3.2]) {
          final e = c.translate(dx, -1.5);
          canvas.drawLine(
            e.translate(-1.6, -1.6),
            e.translate(1.6, 1.6),
            Doodle.stroke(const Color(0xFFFFFFFF), 1.6),
          );
          canvas.drawLine(
            e.translate(-1.6, 1.6),
            e.translate(1.6, -1.6),
            Doodle.stroke(const Color(0xFFFFFFFF), 1.6),
          );
        }
      case FigurePose.falling:
      case FigurePose.panicking:
        canvas.drawCircle(c.translate(-3.2, -2), 1.6, eye);
        canvas.drawCircle(c.translate(3.2, -2), 1.6, eye);
        canvas.drawOval(
          Rect.fromCenter(center: c.translate(0, 3.6), width: 4, height: 4.6),
          line,
        );
      case FigurePose.hanging:
      case FigurePose.cheering:
        canvas.drawCircle(c.translate(-3.2, -2), 1.4, eye);
        canvas.drawCircle(c.translate(3.2, -2), 1.4, eye);
        canvas.drawArc(
          Rect.fromCenter(center: c.translate(0, 1.2), width: 8, height: 6.5),
          0.25,
          math.pi - 0.5,
          false,
          line,
        );
    }
  }
}

enum FigurePose { falling, hanging, cheering, panicking, zapped }
