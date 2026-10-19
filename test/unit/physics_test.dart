import 'package:flutter_test/flutter_test.dart';
import 'package:parachute_rescue/core/config/game_config.dart';
import 'package:parachute_rescue/domain/fall_physics.dart';
import 'package:parachute_rescue/domain/swipe.dart';

void main() {
  const cfg = PhysicsConfig();
  const wind = WindConfig();

  void run(
    FallBody b,
    double seconds, {
    double windAccel = 0,
    double dt = 1 / 120,
  }) {
    for (var t = 0.0; t < seconds; t += dt) {
      b.step(dt, windAccel, cfg);
    }
  }

  group('falling', () {
    test('free fall descends faster than an open parachute', () {
      final free = FallBody(x: 0, y: 0);
      final chute = FallBody(x: 0, y: 0)..deploy();
      run(free, 2);
      run(chute, 2);
      expect(free.y, greaterThan(chute.y * 2));
      expect(free.vy, closeTo(cfg.freeFallTerminal, 1));
      expect(chute.vy, closeTo(cfg.chuteDescent, 5));
    });

    test('deploy only works once', () {
      final b = FallBody(x: 0, y: 100);
      expect(b.deploy(), isTrue);
      expect(b.deploy(), isFalse);
      expect(b.deployedAtY, 100);
    });

    test('opening transitions to open after the configured time', () {
      final b = FallBody(x: 0, y: 0)..deploy();
      expect(b.chute, ChuteState.opening);
      run(b, cfg.openingDuration + 0.02);
      expect(b.chute, ChuteState.open);
    });

    test('result is independent of frame rate', () {
      final a = FallBody(x: 0, y: 0, vx: 100)..deploy();
      final b = FallBody(x: 0, y: 0, vx: 100)..deploy();
      run(a, 1, dt: 1 / 120, windAccel: 300);
      run(b, 1, dt: 1 / 30, windAccel: 300);
      expect(a.y, closeTo(b.y, 4));
      expect(a.x, closeTo(b.x, 4));
    });
  });

  group('wind', () {
    test('a gust pushes in the swipe direction', () {
      final right = gustFromSwipe(dx: 200, dy: 10, seconds: 0.2, cfg: wind)!;
      final left = gustFromSwipe(dx: -200, dy: 0, seconds: 0.2, cfg: wind)!;
      final a = FallBody(x: 0, y: 0)..deploy();
      final b = FallBody(x: 0, y: 0)..deploy();
      run(a, 0.5, windAccel: right.acceleration);
      run(b, 0.5, windAccel: left.acceleration);
      expect(a.vx, greaterThan(0));
      expect(a.x, greaterThan(0));
      expect(b.vx, lessThan(0));
    });

    test('damping never reverses horizontal movement', () {
      final b = FallBody(x: 0, y: 0, vx: 200)..deploy();
      for (var i = 0; i < 2000; i++) {
        b.step(1 / 60, 0, cfg);
        expect(b.vx, greaterThanOrEqualTo(0));
      }
      expect(b.vx, lessThan(1));
    });

    test('horizontal speed is clamped', () {
      final b = FallBody(x: 0, y: 0)..deploy();
      run(b, 3, windAccel: 1e6);
      expect(b.vx.abs(), lessThanOrEqualTo(cfg.maxHorizontalSpeed));
    });

    test('taps, zero-length and vertical swipes create no wind', () {
      expect(gustFromSwipe(dx: 0, dy: 0, seconds: 0.1, cfg: wind), isNull);
      expect(gustFromSwipe(dx: 5, dy: 3, seconds: 0, cfg: wind), isNull);
      expect(gustFromSwipe(dx: 2, dy: 200, seconds: 0.2, cfg: wind), isNull);
      expect(
        gustFromSwipe(dx: double.nan, dy: 0, seconds: 0.1, cfg: wind),
        isNull,
      );
    });

    test('gust strength is bounded even for instant swipes', () {
      final g = gustFromSwipe(dx: 500, dy: 0, seconds: 0, cfg: wind)!;
      expect(g.strength, lessThanOrEqualTo(wind.maxStrength));
      final slow = gustFromSwipe(dx: 40, dy: 0, seconds: 5, cfg: wind)!;
      expect(slow.strength, greaterThanOrEqualTo(wind.minStrength));
    });

    test('gusts decay and expire', () {
      final field = WindField(wind)..add(Gust(strength: 500, duration: 0.5));
      final start = field.acceleration;
      field.tick(0.25);
      expect(field.acceleration, lessThan(start));
      field.tick(0.3);
      expect(field.acceleration, 0);
      expect(field.gusts, isEmpty);
    });
  });

  group('edges and steps', () {
    test('wrap moves a body to the other side exactly once', () {
      final b = FallBody(x: 721, y: 0);
      expect(b.applyEdges(720, 17, EdgeRule.wrap), isTrue);
      expect(b.x, inInclusiveRange(0, 720));
      expect(b.applyEdges(720, 17, EdgeRule.wrap), isFalse);
      final c = FallBody(x: -3, y: 0);
      c.applyEdges(720, 17, EdgeRule.wrap);
      expect(c.x, closeTo(717, 1e-9));
    });

    test('clamp keeps the body inside and stops outward motion', () {
      final b = FallBody(x: 800, y: 0, vx: 50);
      b.applyEdges(720, 17, EdgeRule.clamp);
      expect(b.x, 703);
      expect(b.vx, 0);
    });

    test('long frames are clamped and split into substeps', () {
      final s = substeps(2.0, cfg);
      expect(s.count * s.dt, closeTo(cfg.maxFrameDt, 1e-9));
      expect(s.dt, lessThanOrEqualTo(cfg.maxSubstep + 1e-9));
      expect(substeps(0, cfg).count, 0);
      expect(substeps(-1, cfg).count, 0);
    });
  });
}
