import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../core/config/game_config.dart';
import '../core/services/audio_service.dart';
import '../core/services/haptics_service.dart';
import '../core/utils/random_source.dart';
import '../domain/fall_physics.dart';
import '../domain/scoring.dart';
import '../domain/spawn_plan.dart';
import '../domain/swipe.dart';
import 'effects/effects.dart';
import 'entities/fish.dart';
import 'entities/landing_space.dart';
import 'entities/parachute.dart';
import 'entities/person.dart';
import 'entities/plane.dart';
import 'game_events.dart';
import 'hazards/hazard.dart';
import 'hazards/helicopter.dart';
import 'hazards/thundercloud.dart';
import 'hazards/ufo.dart';
import 'skins.dart';
import 'terrain/terrain.dart';
import 'terrain/terrain_backdrop.dart';

export '../core/services/audio_service.dart' show Sfx;

/// The Flame game: owns the world, camera, session state machine, spawning,
/// wind, scoring authority and the event bridge to Flutter.
///
/// Live simulation state stays here; Flutter only receives [events] and a few
/// low-frequency [ValueNotifier]s for the HUD.
class RescueGame extends FlameGame {
  RescueGame({
    this.config = const GameConfig(),
    this.terrain = TerrainTheme.ocean,
    this.skins = const SkinSet(),
    AudioService? audio,
    HapticsService? haptics,
    RandomSource? random,
    this.attractMode = false,
    this.autoStart = false,
  }) : audio = audio ?? SilentAudioService(),
       haptics = haptics ?? HapticsService(),
       random = random ?? RandomSource(),
       super(
         camera: CameraComponent.withFixedResolution(
           width: config.world.width,
           height: config.world.height,
         ),
       ) {
    scoreBook = ScoreBook(config.scoring);
    director = SpawnDirector(cfg: config, random: this.random);
    wind = WindField(config.wind);
  }

  final GameConfig config;
  final TerrainTheme terrain;
  final SkinSet skins;
  final AudioService audio;
  final HapticsService haptics;
  final RandomSource random;

  /// Menu background mode: no scoring, no hazards, a friendly autopilot.
  final bool attractMode;

  /// Begin playing as soon as the game has loaded.
  final bool autoStart;

  late final ScoreBook scoreBook;
  late final SpawnDirector director;
  late final WindField wind;
  late final DropPlane plane;
  late final Fish fish;

  final StreamController<GameEvent> _events = StreamController.broadcast();

  /// Typed events for the application layer.
  Stream<GameEvent> get events => _events.stream;

  // Low-frequency HUD values (change only on events).
  final ValueNotifier<SessionState> state = ValueNotifier(SessionState.ready);
  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> lives = ValueNotifier(0);
  final ValueNotifier<int> streak = ValueNotifier(0);
  final ValueNotifier<int> rescued = ValueNotifier(0);
  final ValueNotifier<int> dropped = ValueNotifier(0);

  final List<Person> _people = [];
  final List<LandingSpace> _decks = [];
  final List<Hazard> _hazards = [];

  /// Last finished result, if any.
  GameResult? lastResult;

  double _attractWindTimer = 0;

  bool get isPlaying => state.value == SessionState.playing;

  List<LandingSpace> get landingSpaces => _decks;

  Iterable<Person> get people => _people;

  Iterable<Person> get airbornePeople => _people.where((p) => p.isAirborne);

  Iterable<Hazard> get hazards => _hazards;

  int get activeHazardCount => _hazards.where((h) => h.isActive).length;

  Vector2 get worldSize => Vector2(config.world.width, config.world.height);

  @override
  Color backgroundColor() => terrain.sky.top;

  final Paint _letterboxPaint = Paint();

  @override
  void render(Canvas canvas) {
    // Tall screens letterbox the fixed playfield; fill the lower band with
    // the ground colour so the scene looks continuous.
    _letterboxPaint.color = terrain.groundDeep;
    canvas.drawRect(
      Rect.fromLTRB(0, size.y / 2, size.x, size.y),
      _letterboxPaint,
    );
    super.render(canvas);
  }

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    final w = config.world;
    await world.addAll([
      TerrainBackdrop(theme: terrain, worldSize: worldSize, groundY: w.groundY),
      GroundLayer(theme: terrain, worldSize: worldSize, groundY: w.groundY),
      GroundSurface(theme: terrain, worldSize: worldSize, groundY: w.groundY),
    ]);
    plane = DropPlane(
      variant: terrain.plane,
      colors: terrain.planeColors,
      y: w.planeLaneY,
      worldWidth: w.width,
    );
    fish = Fish(
      variant: terrain.fish,
      colors: terrain.fishColors,
      x: w.width * 0.3,
      y: w.groundY + 105,
    );
    await world.addAll([plane, fish]);
    _resetSession();
    if (attractMode) {
      state.value = SessionState.playing;
    } else if (autoStart) {
      start();
    }
  }

  // ------------------------------------------------------------ lifecycle --

  /// Starts a fresh run.
  void start() {
    if (attractMode) return;
    _resetSession();
    _setState(SessionState.playing);
    audio.startMusic();
  }

  void pause() {
    if (state.value != SessionState.playing || attractMode) return;
    _setState(SessionState.paused);
    audio.pauseMusic();
  }

  void resume() {
    if (state.value != SessionState.paused) return;
    _setState(SessionState.playing);
    audio.startMusic();
  }

  /// Clears the current run and starts again with no leftovers.
  void restart() => start();

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (state != AppLifecycleState.resumed) pause();
  }

  void _setState(SessionState next) {
    if (state.value == next) return;
    state.value = next;
    _emit(SessionStateChanged(next));
  }

  void _emit(GameEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _resetSession() {
    for (final p in List.of(_people)) {
      p.removeFromParent();
    }
    _people.clear();
    for (final h in List.of(_hazards)) {
      h.removeFromParent();
    }
    _hazards.clear();
    for (final d in List.of(_decks)) {
      d.removeFromParent();
    }
    _decks.clear();
    for (final e in world.children.whereType<TimedEffect>().toList()) {
      e.removeFromParent();
    }
    scoreBook.reset();
    director.reset();
    wind.clear();
    lastResult = null;
    _addDeck(x: config.world.width / 2, direction: 1);
    score.value = scoreBook.score;
    lives.value = scoreBook.lives;
    streak.value = 0;
    rescued.value = 0;
    dropped.value = 0;
  }

  void _addDeck({required double x, required double direction}) {
    final l = config.landing;
    final deck = LandingSpace(
      variant: terrain.landing,
      colors: terrain.landingColors,
      x: x,
      deckY: config.world.groundY - LandingSpace.deckHeightAboveGround,
      halfWidth: l.deckWidth / 2,
      minX: l.edgeMargin + l.deckWidth / 2,
      maxX: config.world.width - l.edgeMargin - l.deckWidth / 2,
      direction: direction,
      speed: l.baseSpeed,
    );
    _decks.add(deck);
    world.add(deck);
  }

  // --------------------------------------------------------------- update --

  @override
  void update(double dt) {
    if (!isPlaying) {
      // Frozen: process component lifecycle only, advance no simulation time.
      super.update(0);
      return;
    }
    final steps = substeps(dt, config.physics);
    if (steps.count == 0) {
      super.update(0);
      return;
    }
    for (var i = 0; i < steps.count && isPlaying; i++) {
      _step(steps.dt);
    }
  }

  void _step(double dt) {
    wind.tick(dt);
    final orders = director.tick(
      dt,
      activePeople: _people.where((p) => p.isAirborne).length,
      activeHazards: attractMode ? 99 : activeHazardCount,
      planeX: plane.position.x,
      planeReady: plane.canDrop,
    );
    for (final order in orders) {
      switch (order) {
        case SpawnPerson():
          _spawnPerson(order);
        case SpawnHazard():
          _spawnHazard(order);
      }
    }
    _applyDifficulty();
    if (attractMode) _autopilot(dt);
    super.update(dt);
  }

  void _applyDifficulty() {
    final d = director.difficulty;
    for (final deck in _decks) {
      deck.speed = d.landingSpeed;
    }
    final wanted = attractMode ? 1 : d.landingCount;
    if (_decks.length < wanted) {
      // A second deck joins on the side away from the first.
      final first = _decks.first;
      final w = config.world.width;
      final x = first.position.x < w / 2 ? w * 0.78 : w * 0.22;
      _addDeck(x: x, direction: -first.direction);
    }
  }

  void _spawnPerson(SpawnPerson order) {
    plane.release();
    final colors = Parachute.colorsFor(skins.chute, order.id);
    final person = Person(
      id: order.id,
      x: order.releaseX,
      y: plane.position.y + 26,
      canopyColors: colors,
      shirt: skins.shirt.color,
      initialVx: plane.direction * 30,
    );
    _people.add(person);
    world.add(person);
    if (!attractMode) {
      dropped.value++;
      audio.play(Sfx.release, volume: 0.5);
    }
  }

  void _spawnHazard(SpawnHazard order) {
    if (attractMode) return;
    final w = config.world;
    final Hazard hazard;
    switch (order.kind) {
      case HazardKind.helicopter:
        hazard = Helicopter(
          id: order.id,
          fromLeft: order.fromLeft,
          y: order.y.clamp(w.skyTop + 200, w.skyBottom - 300),
          worldWidth: w.width,
        );
      case HazardKind.ufo:
        hazard = Ufo(
          id: order.id,
          fromLeft: order.fromLeft,
          y: order.y.clamp(w.skyTop + 110, w.skyTop + 330),
          worldWidth: w.width,
        );
      case HazardKind.thundercloud:
        hazard = Thundercloud(
          id: order.id,
          fromLeft: order.fromLeft,
          y: w.skyTop + 40 + random.nextDouble() * 90,
          worldWidth: w.width,
        );
    }
    hazard.speedMultiplier = director.difficulty.hazardSpeedMultiplier;
    _hazards.add(hazard);
    world.add(hazard);
  }

  /// Called by components when they leave the world.
  void unregister(Component c) {
    if (c is Person) _people.remove(c);
    if (c is Hazard) _hazards.remove(c);
  }

  /// Menu autopilot: open chutes and nudge people toward the boat.
  void _autopilot(double dt) {
    for (final p in _people) {
      if (p.isAirborne && !p.chuteDeployed && p.body.y > 330) p.deploy();
    }
    _attractWindTimer -= dt;
    if (_attractWindTimer > 0 || _decks.isEmpty) return;
    _attractWindTimer = 0.9;
    final deck = _decks.first;
    for (final p in _people.where((p) => p.isAirborne)) {
      final dx = deck.position.x - p.body.x;
      if (dx.abs() > 30) {
        wind.add(Gust(strength: dx.sign * 380, duration: 0.5, target: p));
        break;
      }
    }
  }

  // ---------------------------------------------------------------- input --

  /// Routes a tap in world coordinates. Priority: free-falling person
  /// (deploy) → attackable hazard (hit). Returns what was hit.
  Object? handleTap(Vector2 point) {
    if (!isPlaying || attractMode) return null;
    final o = Offset(point.x, point.y);

    Person? best;
    var bestDist = double.infinity;
    for (final p in _people) {
      if (!p.isAirborne || p.chuteDeployed) continue;
      if (!p.touchRect.contains(o)) continue;
      final d = (Offset(p.body.x, p.body.y) - o).distanceSquared;
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    if (best != null && best.deploy()) {
      audio.play(Sfx.chute);
      haptics.light();
      return best;
    }

    for (final h in _hazards.reversed) {
      if (!h.attackable || !h.isActive || !h.tapRect.contains(o)) continue;
      if (h.sinceHit < config.hazards.tapCooldown) return h;
      h.sinceHit = 0;
      world.add(HitSpark(at: point.clone()));
      final destroyed = h.hit();
      audio.play(destroyed ? Sfx.explosion : Sfx.heliHit);
      haptics.light();
      if (destroyed) _hazardDestroyed(h);
      return h;
    }
    return null;
  }

  /// Converts a finished swipe (world coordinates) into a gust aimed at the
  /// airborne person nearest the swipe path. Returns null when the drag is
  /// not a swipe or nobody is within reach of it.
  Gust? handleSwipe(Vector2 start, Vector2 end, double seconds) {
    if (!isPlaying || attractMode) return null;
    final d = end - start;
    final target = _nearestToSwipe(start, end);
    final gust = gustFromSwipe(
      dx: d.x,
      dy: d.y,
      seconds: seconds,
      cfg: config.wind,
      target: target,
    );
    if (gust == null || target == null) return null;
    wind.add(gust);
    world.add(
      WindLines(
        start: start.clone(),
        end: end.clone(),
        direction: gust.strength.sign,
      ),
    );
    audio.play(Sfx.wind, volume: 0.6);
    return gust;
  }

  /// The airborne person whose hurt area is closest to the segment
  /// [start]→[end], or null if none is within [WindConfig.reach].
  Person? _nearestToSwipe(Vector2 start, Vector2 end) {
    Person? best;
    var bestDist = config.wind.reach;
    for (final p in _people) {
      if (!p.isAirborne) continue;
      final dist = _segmentToRectDistance(start, end, p.hurtRect);
      if (dist <= bestDist) {
        bestDist = dist;
        best = p;
      }
    }
    return best;
  }

  static double _segmentToRectDistance(Vector2 a, Vector2 b, Rect r) {
    // Sampling is plenty precise at swipe scale and keeps this simple.
    const samples = 24;
    var min = double.infinity;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final x = a.x + (b.x - a.x) * t;
      final y = a.y + (b.y - a.y) * t;
      final dx = x < r.left ? r.left - x : (x > r.right ? x - r.right : 0.0);
      final dy = y < r.top ? r.top - y : (y > r.bottom ? y - r.bottom : 0.0);
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < min) min = dist;
    }
    return min;
  }

  /// Converts a point on the game widget into world coordinates.
  Vector2 screenToWorld(Offset local) =>
      camera.globalToLocal(Vector2(local.dx, local.dy));

  // ------------------------------------------------------------- outcomes --

  void _hazardDestroyed(Hazard h) {
    final bonus = switch (h.kind) {
      HazardKind.helicopter => config.hazards.helicopterBonus,
      HazardKind.ufo => config.hazards.ufoBonus,
      HazardKind.thundercloud => 0,
    };
    final awarded = scoreBook.destroyHazard(h.id, bonus);
    world.add(Explosion(at: h.position.clone()));
    if (awarded == null) return;
    world.add(
      ScorePopup(
        at: h.position.clone(),
        text: '+$awarded',
        color: const Color(0xFFFF9F43),
      ),
    );
    score.value = scoreBook.score;
    _emit(HazardDestroyed(kind: h.kind, bonus: awarded));
  }

  void onPersonRescued(Person p, LandingSpace deck, {required bool risky}) {
    deck.celebrate();
    if (attractMode) return;
    final award = scoreBook.rescue(
      p.id,
      risky: risky,
      riskMultiplier: config.landing.riskMultiplier,
    );
    if (award == null) return;
    final at = Vector2(p.body.x, deck.deckY - 70);
    world.add(ScorePopup(at: at, text: '+${award.points}'));
    if (award.risky) {
      world.add(
        ScorePopup(
          at: at + Vector2(0, -38),
          text: 'DARING! x${config.landing.riskMultiplier}',
          color: const Color(0xFFE8504F),
          fontSize: 22,
        ),
      );
    } else if (award.streak >= 3) {
      world.add(
        ScorePopup(
          at: at + Vector2(0, -38),
          text: 'STREAK x${award.streak}',
          color: const Color(0xFF3FA7D6),
          fontSize: 22,
        ),
      );
    }
    if (award.extraLife) {
      world.add(
        ScorePopup(
          at: at + Vector2(0, -74),
          text: '+1 LIFE',
          color: const Color(0xFFE8504F),
          fontSize: 24,
        ),
      );
      lives.value = scoreBook.lives;
      _emit(LifeCountChanged(scoreBook.lives));
    }
    audio.play(Sfx.rescue);
    haptics.light();
    score.value = scoreBook.score;
    streak.value = scoreBook.streak;
    rescued.value = scoreBook.rescued;
    _emit(
      CharacterRescued(
        points: award.points,
        currentStreak: award.streak,
        totalScore: scoreBook.score,
        risky: award.risky,
      ),
    );
  }

  void onPersonLost(Person p, LossCause cause) {
    final groundY = config.world.groundY;
    switch (cause) {
      case LossCause.water:
        world.add(
          ImpactSplash(
            at: Vector2(p.body.x, groundY + 6),
            liquid: terrain.isLiquid,
            tint: terrain.isLiquid
                ? const Color(0xFFFFFFFF)
                : terrain.groundAccent,
          ),
        );
        fish.attack(p.body.x.clamp(60, config.world.width - 60));
        audio.play(terrain.isLiquid ? Sfx.splash : Sfx.thud);
      case LossCause.crash:
        world.add(Explosion(at: Vector2(p.body.x, p.feetY)));
        audio.play(Sfx.thud);
      case LossCause.helicopter:
        world.add(HitSpark(at: Vector2(p.body.x, p.body.y)));
        audio.play(Sfx.heliHit);
      case LossCause.ufo:
        audio.play(Sfx.beam);
      case LossCause.lightning:
        break;
    }
    if (attractMode) return;
    final ended = scoreBook.lose(p.id);
    _emit(CharacterLost(cause));
    audio.play(Sfx.lifeLost, volume: 0.6);
    haptics.medium();
    lives.value = scoreBook.lives;
    streak.value = 0;
    _emit(LifeCountChanged(scoreBook.lives));
    if (ended) _endGame();
  }

  void _endGame() {
    final result = scoreBook.result(
      seconds: director.elapsed,
      terrainId: terrain.id,
    );
    lastResult = result;
    _setState(SessionState.gameOver);
    audio.stopMusic();
    audio.play(Sfx.gameOver);
    haptics.heavy();
    _emit(GameOver(result));
  }

  void spawnExplosion(Vector2 at) {
    world.add(Explosion(at: at));
    audio.play(Sfx.explosion);
  }

  // ---------------------------------------------------------------- debug --

  /// Spawns a person at an exact spot (tests and tutorial).
  @visibleForTesting
  Person debugSpawnPerson(double x, double y, {bool deployed = false}) {
    final p = Person(
      id: director.nextId(),
      x: x,
      y: y,
      canopyColors: Parachute.colorsFor(skins.chute, 0),
    );
    _people.add(p);
    world.add(p);
    if (deployed) {
      p.body.deploy();
      p.body.chute = ChuteState.open;
      p.body.vy = config.physics.chuteDescent;
      p.parachute.state = CanopyState.open;
    }
    return p;
  }

  /// Spawns a hazard immediately (tests).
  @visibleForTesting
  Hazard debugSpawnHazard(
    HazardKind kind, {
    double y = 500,
    bool fromLeft = true,
  }) {
    _spawnHazard(
      SpawnHazard(id: director.nextId(), kind: kind, fromLeft: fromLeft, y: y),
    );
    return _hazards.last;
  }

  @override
  void onRemove() {
    unawaited(_events.close());
    audio.stopMusic();
    super.onRemove();
  }
}
