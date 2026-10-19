import 'package:flutter_test/flutter_test.dart';
import 'package:parachute_rescue/core/config/game_config.dart';
import 'package:parachute_rescue/core/utils/random_source.dart';
import 'package:parachute_rescue/domain/difficulty.dart';
import 'package:parachute_rescue/domain/spawn_plan.dart';

void main() {
  const cfg = DifficultyConfig();
  final curve = DifficultyCurve(cfg);
  final first = cfg.phases.first;
  final last = cfg.phases.last;

  test('difficulty stays within configured limits at any time', () {
    for (var t = -10.0; t < 5000; t += 3.7) {
      final d = curve.at(t);
      expect(
        d.spawnInterval,
        inInclusiveRange(last.spawnInterval, first.spawnInterval),
      );
      expect(d.spawnInterval, greaterThan(0));
      expect(
        d.maxActivePeople,
        inInclusiveRange(first.maxActivePeople, last.maxActivePeople),
      );
      expect(
        d.landingSpeed,
        inInclusiveRange(first.landingSpeed, last.landingSpeed),
      );
      expect(
        d.hazardInterval,
        inInclusiveRange(last.hazardInterval, first.hazardInterval),
      );
      expect(d.maxHazards, inInclusiveRange(first.maxHazards, last.maxHazards));
      expect(
        d.hazardSpeedMultiplier,
        inInclusiveRange(1, last.hazardSpeedMultiplier),
      );
    }
    expect(curve.at(double.nan).spawnInterval, first.spawnInterval);
  });

  test('difficulty ramps monotonically', () {
    var prev = curve.at(0);
    for (var t = 1.0; t < 400; t += 1) {
      final d = curve.at(t);
      expect(d.spawnInterval, lessThanOrEqualTo(prev.spawnInterval + 1e-9));
      expect(d.landingSpeed, greaterThanOrEqualTo(prev.landingSpeed - 1e-9));
      expect(d.maxActivePeople, greaterThanOrEqualTo(prev.maxActivePeople));
      prev = d;
    }
  });

  List<String> runDirector(int seed) {
    final d = SpawnDirector(
      cfg: const GameConfig(),
      random: RandomSource(seed),
    );
    final log = <String>[];
    for (var i = 0; i < 60 * 240; i++) {
      for (final o in d.tick(
        1 / 60,
        activePeople: 0,
        activeHazards: 0,
        planeX: 360,
      )) {
        log.add(switch (o) {
          SpawnPerson(:final id, :final releaseX) =>
            'P$id@${releaseX.toStringAsFixed(1)}@${i ~/ 6}',
          SpawnHazard(:final id, :final kind, :final y) =>
            'H$id:${kind.name}@${y.toStringAsFixed(1)}@${i ~/ 6}',
        });
      }
    }
    return log;
  }

  test('the same seed reproduces the same spawn sequence', () {
    final a = runDirector(1234);
    final b = runDirector(1234);
    final c = runDirector(99);
    expect(a, isNotEmpty);
    expect(a, b);
    expect(a, isNot(c));
  });

  test('no hazards in the opening seconds; caps are respected', () {
    final d = SpawnDirector(cfg: const GameConfig(), random: RandomSource(5));
    var t = 0.0;
    while (t < const HazardConfig().hazardFreeTime - 0.1) {
      final orders = d.tick(
        1 / 60,
        activePeople: 0,
        activeHazards: 0,
        planeX: 360,
      );
      expect(orders.whereType<SpawnHazard>(), isEmpty);
      t += 1 / 60;
    }
    // When at the people cap, nobody new is spawned.
    final capped = SpawnDirector(
      cfg: const GameConfig(),
      random: RandomSource(5),
    );
    for (var i = 0; i < 600; i++) {
      expect(
        capped.tick(1 / 60, activePeople: 99, activeHazards: 99, planeX: 360),
        isEmpty,
      );
    }
  });

  test('release points are always inside the playfield', () {
    final d = SpawnDirector(cfg: const GameConfig(), random: RandomSource(3));
    expect(d.clampRelease(-500), greaterThan(0));
    expect(d.clampRelease(5000), lessThan(720));
  });
}
