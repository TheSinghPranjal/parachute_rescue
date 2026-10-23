import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parachute_rescue/core/config/game_config.dart';
import 'package:parachute_rescue/core/services/audio_service.dart';
import 'package:parachute_rescue/core/utils/random_source.dart';
import 'package:parachute_rescue/domain/scoring.dart';
import 'package:parachute_rescue/domain/spawn_plan.dart';
import 'package:parachute_rescue/game/entities/person.dart';
import 'package:parachute_rescue/game/game_events.dart';
import 'package:parachute_rescue/game/hazards/helicopter.dart';
import 'package:parachute_rescue/game/hazards/thundercloud.dart';
import 'package:parachute_rescue/game/hazards/ufo.dart';
import 'package:parachute_rescue/game/rescue_game.dart';
import 'package:parachute_rescue/game/skins.dart';
import 'package:parachute_rescue/game/terrain/terrain.dart';

/// A quiet config: decks stand still and nothing spawns on its own, so each
/// test controls exactly which entities exist.
const quiet = GameConfig(
  difficulty: DifficultyConfig(
    phases: [
      DifficultyPhase(
        time: 0,
        spawnInterval: 999,
        maxActivePeople: 0,
        landingSpeed: 0,
        landingCount: 1,
        hazardInterval: 999,
        maxHazards: 0,
        hazardSpeedMultiplier: 1,
      ),
    ],
  ),
);

RescueGame quietGame({TerrainTheme terrain = TerrainTheme.ocean}) => RescueGame(
  config: quiet,
  terrain: terrain,
  random: RandomSource(1),
  autoStart: true,
);

void advance(RescueGame game, double seconds, {double dt = 1 / 60}) {
  for (var t = 0.0; t < seconds; t += dt) {
    game.update(dt);
  }
}

Future<List<GameEvent>> collect(
  RescueGame game,
  Future<void> Function() body,
) async {
  final events = <GameEvent>[];
  final sub = game.events.listen(events.add);
  await body();
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return events;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('person size', () {
    test('is identical for every terrain, skin and state', () {
      for (final terrain in TerrainTheme.all) {
        for (final chute in ChuteSkin.all) {
          for (final shirt in ShirtSkin.all) {
            final p = Person(
              id: 1,
              x: 0,
              y: 0,
              canopyColors: chute.panels,
              shirt: shirt.color,
            );
            expect(
              p.size,
              kPersonSize,
              reason: '${terrain.id}/${chute.id}/${shirt.id}',
            );
            expect(p.scale, Vector2.all(1));
          }
        }
      }
      expect(kPersonSize, Vector2(34, 56));
    });

    testWithGame<RescueGame>('does not change while playing', quietGame, (
      game,
    ) async {
      final p = game.debugSpawnPerson(360, 400);
      await game.ready();
      p.deploy();
      advance(game, 3);
      expect(p.size, kPersonSize);
      expect(p.scale, Vector2.all(1));
    });
  });

  group('landing', () {
    testWithGame<RescueGame>(
      'a chute landing on the deck is a rescue, scored once',
      quietGame,
      (game) async {
        final deck = game.landingSpaces.single;
        final events = await collect(game, () async {
          final p = game.debugSpawnPerson(
            deck.position.x + 20,
            deck.deckY - 160,
            deployed: true,
          );
          await game.ready();
          advance(game, 4);
          expect(p.fate, PersonFate.rescued);
        });
        expect(game.scoreBook.score, quiet.scoring.rescuePoints);
        expect(game.rescued.value, 1);
        expect(events.whereType<CharacterRescued>().length, 1);
        expect(game.lives.value, quiet.scoring.initialLives);
      },
    );

    testWithGame<RescueGame>(
      'missing every deck is lost at the waterline, one life',
      quietGame,
      (game) async {
        final deck = game.landingSpaces.single;
        final x = deck.position.x > 360 ? 80.0 : 640.0;
        final events = await collect(game, () async {
          final p = game.debugSpawnPerson(x, 900, deployed: true);
          await game.ready();
          advance(game, 5);
          expect(p.lossCause, LossCause.water);
        });
        expect(game.lives.value, quiet.scoring.initialLives - 1);
        expect(events.whereType<CharacterLost>().length, 1);
        expect(game.scoreBook.score, 0);
        // The fish dashes over and bites the fallen person.
        advance(game, 3);
        expect(game.fish.bites, 1);
      },
    );

    testWithGame<RescueGame>(
      'free-falling onto the deck is a crash',
      quietGame,
      (game) async {
        final deck = game.landingSpaces.single;
        final p = game.debugSpawnPerson(deck.position.x, deck.deckY - 300);
        await game.ready();
        advance(game, 2);
        expect(p.lossCause, LossCause.crash);
        expect(game.scoreBook.rescued, 0);
      },
    );

    testWithGame<RescueGame>(
      'the fish never takes an airborne person',
      quietGame,
      (game) async {
        game.fish.attack(200);
        final p = game.debugSpawnPerson(200, 700, deployed: true);
        await game.ready();
        advance(game, 3);
        expect(p.isAirborne, isTrue);
        expect(game.lives.value, quiet.scoring.initialLives);
      },
    );

    testWithGame<RescueGame>(
      'a person wraps around the side edge and stays on screen',
      quietGame,
      (game) async {
        final p = game.debugSpawnPerson(715, 300, deployed: true);
        await game.ready();
        p.body.vx = 200;
        advance(game, 0.2);
        expect(p.body.x, inInclusiveRange(0, 720));
        expect(p.body.x, lessThan(100));
        expect(p.isAirborne, isTrue);
      },
    );
  });

  group('input', () {
    testWithGame<RescueGame>(
      'tap deploys, swipe makes wind and never deploys',
      quietGame,
      (game) async {
        final p = game.debugSpawnPerson(300, 300);
        await game.ready();
        // A swipe straight across the person must not open the chute.
        final gust = game.handleSwipe(
          Vector2(200, 300),
          Vector2(420, 300),
          0.15,
        );
        expect(gust, isNotNull);
        expect(p.chuteDeployed, isFalse);
        expect(game.wind.acceleration, greaterThan(0));
        // A tap near the person opens it.
        expect(game.handleTap(Vector2(p.body.x + 10, p.body.y + 5)), same(p));
        expect(p.chuteDeployed, isTrue);
        // A second tap does nothing to the chute.
        expect(game.handleTap(Vector2(p.body.x, p.body.y)), isNull);
      },
    );

    testWithGame<RescueGame>(
      'a swipe only pushes the person nearest to it',
      quietGame,
      (game) async {
        final near = game.debugSpawnPerson(200, 300);
        final far = game.debugSpawnPerson(600, 300);
        await game.ready();
        near.deploy();
        far.deploy();
        final gust = game.handleSwipe(
          Vector2(120, 300),
          Vector2(280, 300),
          0.15,
        );
        expect(gust, isNotNull);
        expect(game.wind.accelerationFor(near), greaterThan(0));
        expect(game.wind.accelerationFor(far), 0);
        // Nobody within reach: no gust at all.
        expect(
          game.handleSwipe(Vector2(380, 700), Vector2(460, 700), 0.15),
          isNull,
        );
      },
    );

    testWithGame<RescueGame>('a tiny drag is not wind', quietGame, (
      game,
    ) async {
      expect(
        game.handleSwipe(Vector2(100, 100), Vector2(105, 102), 0.1),
        isNull,
      );
      expect(game.wind.gusts, isEmpty);
    });

    testWithGame<RescueGame>('input is ignored while paused', quietGame, (
      game,
    ) async {
      final p = game.debugSpawnPerson(300, 300);
      await game.ready();
      game.pause();
      expect(game.handleTap(Vector2(300, 300)), isNull);
      expect(game.handleSwipe(Vector2(0, 300), Vector2(300, 300), 0.1), isNull);
      expect(p.chuteDeployed, isFalse);
    });
  });

  group('lifecycle', () {
    testWithGame<RescueGame>(
      'pause stops simulation time completely',
      quietGame,
      (game) async {
        final p = game.debugSpawnPerson(300, 300);
        final deckX = game.landingSpaces.single.position.x;
        await game.ready();
        advance(game, 0.2);
        game.pause();
        final y = p.body.y;
        final elapsed = game.director.elapsed;
        advance(game, 5);
        expect(p.body.y, y);
        expect(game.director.elapsed, elapsed);
        expect(game.landingSpaces.single.position.x, deckX);
        game.resume();
        game.update(1 / 60);
        expect(p.body.y, greaterThan(y));
      },
    );

    testWithGame<RescueGame>(
      'a huge frame delta does not teleport people',
      quietGame,
      (game) async {
        final p = game.debugSpawnPerson(300, 300);
        await game.ready();
        game.update(10);
        expect(
          p.body.y - 300,
          lessThan(
            quiet.physics.freeFallTerminal * quiet.physics.maxFrameDt + 1,
          ),
        );
      },
    );

    testWithGame<RescueGame>(
      'restart clears entities, score and lives',
      quietGame,
      (game) async {
        game.debugSpawnPerson(300, 300);
        game.debugSpawnHazard(HazardKind.helicopter);
        game.scoreBook.rescue(999);
        await game.ready();
        game.debugSpawnPerson(80, 1000, deployed: true);
        await game.ready();
        advance(game, 2);
        expect(game.lives.value, lessThan(quiet.scoring.initialLives));
        game.restart();
        await game.ready();
        expect(game.people, isEmpty);
        expect(game.hazards, isEmpty);
        expect(game.world.children.whereType<Person>(), isEmpty);
        expect(game.landingSpaces.length, 1);
        expect(game.score.value, 0);
        expect(game.lives.value, quiet.scoring.initialLives);
        expect(game.isPlaying, isTrue);
      },
    );

    testWithGame<RescueGame>(
      'game over triggers exactly once and freezes play',
      quietGame,
      (game) async {
        final events = await collect(game, () async {
          for (var i = 0; i < 5; i++) {
            game.debugSpawnPerson(60.0 + i * 8, 1000, deployed: true);
          }
          await game.ready();
          advance(game, 4);
        });
        expect(events.whereType<GameOver>().length, 1);
        expect(game.state.value, SessionState.gameOver);
        expect(game.lives.value, 0);
        expect(game.lastResult!.lost, 3);
        final survivors = game.people
            .where((p) => p.isAirborne)
            .map((p) => p.body.y)
            .toList();
        advance(game, 2);
        expect(
          game.people.where((p) => p.isAirborne).map((p) => p.body.y).toList(),
          survivors,
        );
      },
    );
  });

  group('hazards', () {
    testWithGame<RescueGame>(
      'helicopter: destroyed after N taps, bonus once',
      quietGame,
      (game) async {
        final heli =
            game.debugSpawnHazard(HazardKind.helicopter, y: 500) as Helicopter;
        await game.ready();
        advance(game, 1.2);
        final events = await collect(game, () async {
          for (var i = 0; i < quiet.hazards.helicopterHits + 3; i++) {
            game.handleTap(heli.position.clone());
            advance(game, 0.1);
          }
        });
        expect(heli.destroyed, isTrue);
        expect(events.whereType<HazardDestroyed>().length, 1);
        expect(game.scoreBook.score, quiet.hazards.helicopterBonus);
        advance(game, 3);
        expect(game.hazards, isEmpty, reason: 'wreck removes itself');
      },
    );

    testWithGame<RescueGame>(
      'tap cooldown stops one gesture counting twice',
      quietGame,
      (game) async {
        final heli =
            game.debugSpawnHazard(HazardKind.helicopter, y: 500) as Helicopter;
        await game.ready();
        advance(game, 1.2);
        game.handleTap(heli.position.clone());
        game.handleTap(heli.position.clone());
        expect(heli.hits, 1);
      },
    );

    testWithGame<RescueGame>(
      'helicopter knocks out a person it touches',
      quietGame,
      (game) async {
        final heli =
            game.debugSpawnHazard(HazardKind.helicopter, y: 500) as Helicopter;
        await game.ready();
        final p = game.debugSpawnPerson(100, 480, deployed: true);
        await game.ready();
        advance(game, 3);
        expect(p.lossCause, LossCause.helicopter);
        expect(heli.destroyed, isFalse);
        expect(game.lives.value, quiet.scoring.initialLives - 1);
      },
    );

    testWithGame<RescueGame>(
      'lightning only hits people inside its column',
      quietGame,
      (game) async {
        final cloud =
            game.debugSpawnHazard(HazardKind.thundercloud) as Thundercloud;
        await game.ready();
        // Let it drift in and reach the warning phase.
        while (cloud.phase != StormPhase.warning) {
          game.update(1 / 60);
        }
        final column = cloud.strikeRect;
        final inside = game.debugSpawnPerson(
          column.center.dx,
          600,
          deployed: true,
        );
        final outside = game.debugSpawnPerson(
          column.center.dx + 200,
          600,
          deployed: true,
        );
        await game.ready();
        while (cloud.phase != StormPhase.cooldown) {
          game.update(1 / 60);
        }
        expect(inside.lossCause, LossCause.lightning);
        expect(outside.isAirborne, isTrue);
      },
    );

    testWithGame<RescueGame>(
      'UFO abducts a person who stays in the beam',
      quietGame,
      (game) async {
        final ufo = game.debugSpawnHazard(HazardKind.ufo, y: 400) as Ufo;
        await game.ready();
        while (ufo.beam != BeamPhase.active) {
          game.update(1 / 60);
        }
        final p = game.debugSpawnPerson(
          ufo.position.x,
          ufo.position.y + 120,
          deployed: true,
        );
        await game.ready();
        var t = 0.0;
        while (p.isAirborne && t < 3) {
          // Keep them pinned under the saucer.
          p.body
            ..x = ufo.position.x
            ..y = ufo.position.y + 120;
          game.update(1 / 60);
          t += 1 / 60;
        }
        expect(p.lossCause, LossCause.ufo);
      },
    );
  });

  group('terrains', () {
    for (final terrain in TerrainTheme.all) {
      testWithGame<RescueGame>(
        '${terrain.id} loads and plays',
        () => quietGame(terrain: terrain),
        (game) async {
          expect(game.fish.variant, terrain.fish);
          expect(game.landingSpaces.single.variant, terrain.landing);
          final p = game.debugSpawnPerson(80, 1000, deployed: true);
          await game.ready();
          advance(game, 2);
          expect(p.lossCause, LossCause.water);
          advance(game, 3);
          expect(game.fish.bites, 1);
        },
      );
    }
  });

  testWithGame<RescueGame>(
    'simulated 5-minute run stays bounded and consistent',
    () => RescueGame(
      random: RandomSource(2024),
      autoStart: true,
      audio: SilentAudioService(),
    ),
    (game) async {
      var gameOvers = 0;
      final sub = game.events.listen((e) {
        if (e is GameOver) gameOvers++;
      });
      final last = game.config.difficulty.phases.last;
      var swipeCooldown = 0.0;
      for (var frame = 0; frame < 60 * 300 && game.isPlaying; frame++) {
        // A simple bot: open chutes mid-sky, swipe toward the nearest deck,
        // and tap any hazard in reach.
        for (final p in game.airbornePeople.toList()) {
          if (!p.chuteDeployed && p.body.y > 380) {
            game.handleTap(Vector2(p.body.x, p.body.y));
          }
        }
        swipeCooldown -= 1 / 60;
        final target = game.airbornePeople
            .where((p) => p.chuteDeployed)
            .firstOrNull;
        if (target != null && swipeCooldown <= 0) {
          final deck = game.landingSpaces.first;
          final dx = deck.position.x - target.body.x;
          if (dx.abs() > 40) {
            final at = Vector2(target.body.x, target.body.y);
            game.handleSwipe(
              at - Vector2(dx.sign * 60, 0),
              at + Vector2(dx.sign * 60, 0),
              0.12,
            );
            swipeCooldown = 0.6;
          }
        }
        for (final h in game.hazards.where((h) => h.attackable).toList()) {
          game.handleTap(h.position.clone());
        }
        game.update(1 / 60);
        expect(
          game.people.length,
          lessThanOrEqualTo(last.maxActivePeople + 12),
        );
        expect(game.hazards.length, lessThanOrEqualTo(last.maxHazards + 2));
        expect(game.landingSpaces.length, lessThanOrEqualTo(last.landingCount));
        expect(game.lives.value, greaterThanOrEqualTo(0));
      }
      await Future<void>.delayed(Duration.zero);
      expect(gameOvers, lessThanOrEqualTo(1));
      expect(game.scoreBook.rescued + game.scoreBook.lost, greaterThan(5));
      // ignore: avoid_print
      print(
        'bot run: score=${game.scoreBook.score} rescued=${game.scoreBook.rescued} '
        'lost=${game.scoreBook.lost} t=${game.director.elapsed.toStringAsFixed(0)}s',
      );
      await sub.cancel();
    },
  );
}
