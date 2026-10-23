import 'package:flutter_test/flutter_test.dart';
import 'package:parachute_rescue/core/config/game_config.dart';
import 'package:parachute_rescue/domain/scoring.dart';

void main() {
  const cfg = ScoringConfig();
  late ScoreBook book;

  setUp(() => book = ScoreBook(cfg));

  test('a rescue awards points exactly once per person', () {
    final first = book.rescue(1);
    final again = book.rescue(1);
    expect(first!.points, cfg.rescuePoints);
    expect(again, isNull);
    expect(book.score, cfg.rescuePoints);
    expect(book.rescued, 1);
  });

  test('consecutive rescues build a streak bonus', () {
    final a = book.rescue(1)!;
    final b = book.rescue(2)!;
    final c = book.rescue(3)!;
    expect([a.streak, b.streak, c.streak], [1, 2, 3]);
    expect(b.points, cfg.rescuePoints + cfg.streakBonus);
    expect(c.points, cfg.rescuePoints + cfg.streakBonus * 2);
    expect(book.longestStreak, 3);
  });

  test('a loss resets the streak but not the longest streak', () {
    book
      ..rescue(1)
      ..rescue(2)
      ..lose(3);
    expect(book.streak, 0);
    expect(book.longestStreak, 2);
    expect(book.rescue(4)!.streak, 1);
  });

  test('streak bonus is capped', () {
    for (var i = 0; i < 40; i++) {
      book.rescue(i);
    }
    final next = book.rescueValue(streakAfter: 999, risky: false);
    expect(next, cfg.rescuePoints + cfg.streakBonus * cfg.maxStreakBonusSteps);
  });

  test('risky landing multiplies points', () {
    expect(book.rescue(1, risky: true)!.points, cfg.rescuePoints * 2);
  });

  test('one failed rescue removes at most one life', () {
    book.lose(7);
    book.lose(7);
    book.lose(7);
    expect(book.lives, cfg.initialLives - 1);
    expect(book.lost, 1);
  });

  test('a person already rescued cannot also be lost', () {
    book.rescue(5);
    book.lose(5);
    expect(book.lives, cfg.initialLives);
  });

  test('lives never go negative and game over fires once', () {
    var overs = 0;
    for (var i = 0; i < 10; i++) {
      if (book.lose(i)) overs++;
    }
    expect(book.lives, 0);
    expect(overs, 1);
    expect(book.isGameOver, isTrue);
    expect(book.rescue(100), isNull, reason: 'no scoring after game over');
  });

  test('extra life at the threshold, capped at max lives', () {
    final small = ScoreBook(
      const ScoringConfig(extraLifeEvery: 200, maxLives: 4),
    );
    small.rescue(1);
    final award = small.rescue(2)!; // 100 + 125 = 225 ≥ 200
    expect(award.extraLife, isTrue);
    expect(small.lives, 4);
    for (var i = 3; i < 20; i++) {
      small.rescue(i);
    }
    expect(small.lives, 4);
  });

  test('hazard bonus can earn an extra life', () {
    final small = ScoreBook(const ScoringConfig(extraLifeEvery: 200));
    small.destroyHazard(1, 250);
    expect(small.lives, small.cfg.initialLives + 1);
  });

  test('each run gets its own token on its result', () {
    final first = book.result(seconds: 0, terrainId: 'ocean').run;
    expect(book.result(seconds: 1, terrainId: 'ocean').run, same(first));
    book.reset();
    expect(book.result(seconds: 0, terrainId: 'ocean').run, isNot(same(first)));
  });

  test('hazard bonus is awarded once per hazard', () {
    expect(book.destroyHazard(9, 250), 250);
    expect(book.destroyHazard(9, 250), isNull);
    expect(book.score, 250);
    expect(book.hazardsDestroyed, 1);
  });

  test('reset clears everything', () {
    book
      ..rescue(1)
      ..lose(2)
      ..destroyHazard(3, 100)
      ..reset();
    expect(book.score, 0);
    expect(book.lives, cfg.initialLives);
    expect(book.coins, 0);
    expect(book.rescue(1), isNotNull, reason: 'ids are forgotten after reset');
  });

  test('result summarises the run', () {
    book
      ..rescue(1)
      ..rescue(2)
      ..lose(3);
    final r = book.result(seconds: 12, terrainId: 'ocean');
    expect(r.rescued, 2);
    expect(r.lost, 1);
    expect(r.rescueRate, closeTo(2 / 3, 1e-9));
    expect(r.coinsEarned, 2 * cfg.coinsPerRescue);
  });
}
