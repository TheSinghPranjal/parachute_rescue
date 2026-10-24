import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parachute_rescue/app/app.dart';
import 'package:parachute_rescue/core/config/game_config.dart';
import 'package:parachute_rescue/core/services/audio_service.dart';
import 'package:parachute_rescue/core/services/storage_service.dart';
import 'package:parachute_rescue/domain/scoring.dart';
import 'package:parachute_rescue/features/menu/main_menu_screen.dart';
import 'package:parachute_rescue/game/game_events.dart';
import 'package:parachute_rescue/game/rescue_game.dart';
import 'package:parachute_rescue/providers/providers.dart';

/// Pumps the whole app with in-memory storage and silent audio.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  MemoryStorageService? storage,
  bool liveBackdrop = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      storageProvider.overrideWithValue(storage ?? MemoryStorageService()),
      audioProvider.overrideWithValue(SilentAudioService()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: SkyRescueApp(home: MainMenuScreen(showLiveBackdrop: liveBackdrop)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

Future<void> frames(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 1 / 30) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

RescueGame liveGame(WidgetTester tester) => tester
    .widget<GameWidget<RescueGame>>(find.byType(GameWidget<RescueGame>))
    .game!;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('main menu renders with best score, coins and terrains', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorageService({
        StorageKeys.bestScore: 4321,
        StorageKeys.coins: 12,
      }),
    );
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('BEST  4321'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.byKey(const Key('terrain-battlefield')), findsOneWidget);
    expect(find.text('SKINS'), findsOneWidget);
  });

  testWidgets('menu starts with the live game backdrop and no external art', (
    tester,
  ) async {
    await pumpApp(tester, liveBackdrop: true);
    await frames(tester, 1);
    expect(find.byType(GameWidget<RescueGame>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a terrain persists it', (tester) async {
    final storage = MemoryStorageService();
    await pumpApp(tester, storage: storage);
    await tester.tap(find.byKey(const Key('terrain-battlefield')));
    await tester.pump();
    expect(storage.values[StorageKeys.terrain], 'battlefield');
  });

  testWidgets('first Play shows the tutorial, skipping starts the game', (
    tester,
  ) async {
    final storage = MemoryStorageService();
    await pumpApp(tester, storage: storage);
    await tapKey(tester, 'play-button');
    expect(find.text('HOW TO PLAY'), findsWidgets);
    await tapKey(tester, 'tutorial-skip');
    await frames(tester, 0.5);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(storage.values[StorageKeys.tutorialDone], isTrue);
  });

  testWidgets('How To pages through every step', (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'how-button');
    for (var i = 0; i < 4; i++) {
      await tapKey(tester, 'tutorial-next');
    }
    expect(find.text('5. BUILD A STREAK'), findsWidgets);
    await tapKey(tester, 'tutorial-next');
    expect(find.text('PLAY'), findsOneWidget, reason: 'back on the menu');
  });

  group('gameplay', () {
    Future<RescueGame> startGame(
      WidgetTester tester,
      MemoryStorageService storage,
    ) async {
      await pumpApp(tester, storage: storage);
      await tapKey(tester, 'play-button');
      await frames(tester, 0.3);
      return liveGame(tester);
    }

    testWidgets('pause freezes the game and resume continues', (tester) async {
      final game = await startGame(
        tester,
        MemoryStorageService({StorageKeys.tutorialDone: true}),
      );
      expect(game.isPlaying, isTrue);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.text('PAUSED'), findsWidgets);
      expect(game.state.value, SessionState.paused);
      final t = game.director.elapsed;
      await frames(tester, 1);
      expect(game.director.elapsed, t);
      await tester.tap(find.text('RESUME'));
      await frames(tester, 0.3);
      expect(find.text('PAUSED'), findsNothing);
      expect(game.director.elapsed, greaterThan(t));
    });

    testWidgets('game over shows results and saves the best score', (
      tester,
    ) async {
      final storage = MemoryStorageService({StorageKeys.tutorialDone: true});
      final game = await startGame(tester, storage);
      game.scoreBook.rescue(9000); // +100 so there is a score to save
      for (var i = 0; i < 3; i++) {
        game.debugSpawnPerson(60.0 + i * 10, 1040, deployed: true);
      }
      await frames(tester, 2);
      expect(game.state.value, SessionState.gameOver);
      expect(find.text('GAME OVER'), findsWidgets);
      expect(find.byKey(const Key('final-score')), findsOneWidget);
      expect(find.byKey(const Key('new-best')), findsOneWidget);
      expect(storage.values[StorageKeys.bestScore], 100);
      expect(storage.values[StorageKeys.coins], 1);

      // Play again starts a clean run with the same, single subscription.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).last),
      );
      final session = container.read(gameSessionProvider.notifier);
      expect(session.subscriptionCount, 1);
      await tester.tap(find.text('PLAY AGAIN'));
      await frames(tester, 0.3);
      expect(game.isPlaying, isTrue);
      expect(game.score.value, 0);
      expect(find.text('GAME OVER'), findsNothing);
      expect(session.subscriptionCount, 1);

      // Leaving the game releases the subscription.
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tap(find.text('MAIN MENU'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('PLAY'), findsOneWidget);
      expect(session.subscriptionCount, 0);
    });

    testWidgets('pausing saves progress so quitting mid-run keeps it', (
      tester,
    ) async {
      final storage = MemoryStorageService({StorageKeys.tutorialDone: true});
      final game = await startGame(tester, storage);
      game.scoreBook.rescue(9001); // +100 points, +1 coin
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(storage.values[StorageKeys.bestScore], 100);
      expect(storage.values[StorageKeys.coins], 1);

      // Pausing again (e.g. app backgrounded twice) never re-counts coins.
      await tester.tap(find.text('RESUME'));
      await frames(tester, 0.2);
      game.pause();
      await tester.pump();
      expect(storage.values[StorageKeys.coins], 1);

      // The run then ends: only coins earned since the pause are added, and
      // it still counts as a new best for the game-over card.
      await tester.tap(find.text('RESUME'));
      game.scoreBook.rescue(9002);
      for (var i = 0; i < 3; i++) {
        game.debugSpawnPerson(60.0 + i * 10, 1040, deployed: true);
      }
      await frames(tester, 2);
      expect(game.state.value, SessionState.gameOver);
      expect(find.byKey(const Key('new-best')), findsOneWidget);
      expect(storage.values[StorageKeys.coins], 2);
      expect(storage.values[StorageKeys.bestScore], game.scoreBook.score);
    });

    testWidgets('restart from pause resets the run', (tester) async {
      final game = await startGame(
        tester,
        MemoryStorageService({StorageKeys.tutorialDone: true}),
      );
      game.debugSpawnPerson(80, 1040, deployed: true);
      await frames(tester, 1.5);
      expect(game.lives.value, 2);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tap(find.text('RESTART'));
      await frames(tester, 0.2);
      expect(game.lives.value, 3);
      expect(game.state.value, SessionState.playing);
    });
  });

  testWidgets('settings toggles persist and reset needs confirmation', (
    tester,
  ) async {
    final storage = MemoryStorageService({StorageKeys.bestScore: 500});
    await pumpApp(tester, storage: storage);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('set-sfx')));
    await tester.tap(find.byKey(const Key('set-haptics')));
    await tester.pump();
    expect(storage.values[StorageKeys.sfx], isFalse);
    expect(storage.values[StorageKeys.haptics], isFalse);

    await tapKey(tester, 'reset-data');
    expect(find.text('Reset all data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(storage.values[StorageKeys.bestScore], 500);

    await tapKey(tester, 'reset-data');
    await tester.tap(find.byKey(const Key('confirm-reset')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(storage.values, isEmpty);
  });

  testWidgets('drop speed steps between 1 and 5 and persists', (tester) async {
    final storage = MemoryStorageService();
    final c = await pumpApp(tester, storage: storage);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Normal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('drop-speed-up')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('drop-speed-up')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('drop-speed-up')));
    await tester.pump();
    expect(find.text('Very fast'), findsOneWidget);
    expect(storage.values[StorageKeys.dropSpeed], DropSpeed.max);
    expect(
      c.read(gameConfigProvider).physics.chuteDescent,
      const PhysicsConfig().chuteDescent * DropSpeed.multiplier(DropSpeed.max),
    );

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('drop-speed-down')));
      await tester.pump();
    }
    expect(find.text('Very slow'), findsOneWidget);
    expect(storage.values[StorageKeys.dropSpeed], DropSpeed.min);
  });

  testWidgets('gameplay world widens to fill a tablet screen', (tester) async {
    await pumpApp(
      tester,
      storage: MemoryStorageService({StorageKeys.tutorialDone: true}),
    );
    // A 3:4 tablet in portrait.
    tester.view.physicalSize = const Size(1536, 2048);
    tester.view.devicePixelRatio = 2;
    await tester.pump();
    await tapKey(tester, 'play-button');
    await frames(tester, 0.3);
    final world = liveGame(tester).config.world;
    expect(world.width, closeTo(960, 0.01));
    expect(world.height, 1280);
  });

  test('progress: best score saved only when beaten, coins banked', () async {
    final storage = MemoryStorageService();
    final c = ProviderContainer(
      overrides: [storageProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    final n = c.read(progressProvider.notifier);
    GameResult r(int score, int coins) => GameResult(
      score: score,
      rescued: 1,
      lost: 3,
      longestStreak: 1,
      hazardsDestroyed: 0,
      coinsEarned: coins,
      survivalSeconds: 10,
      terrainId: 'ocean',
    );
    expect(await n.recordResult(r(300, 3)), isTrue);
    final writes = storage.writes;
    expect(await n.recordResult(r(200, 0)), isFalse);
    expect(storage.writes, writes, reason: 'no write when nothing changed');
    expect(c.read(progressProvider).bestScore, 300);
    expect(c.read(progressProvider).coins, 3);

    // A fresh container (app restart) reads the saved values back.
    final again = ProviderContainer(
      overrides: [storageProvider.overrideWithValue(storage)],
    );
    addTearDown(again.dispose);
    expect(again.read(progressProvider).bestScore, 300);

    // Skins: can't buy without coins; can after earning.
    expect(await n.buy('rainbow', 90), isFalse);
    expect(await n.buy('candy', 40), isFalse);
    await n.recordResult(r(10, 50));
    expect(await n.buy('candy', 40), isTrue);
    await n.equipChute('candy');
    expect(c.read(progressProvider).skins.chute.id, 'candy');
    expect(c.read(progressProvider).coins, 13);
  });

  test('settings fall back to defaults for invalid stored values', () {
    final storage = MemoryStorageService({
      StorageKeys.sfx: 'yes',
      StorageKeys.bestScore: 'oops',
    });
    final c = ProviderContainer(
      overrides: [storageProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).sfx, isTrue);
    expect(c.read(progressProvider).bestScore, 0);
    expect(c.read(progressProvider).terrainId, 'ocean');
    expect(c.read(settingsProvider).dropSpeed, DropSpeed.normal);
  });

  test('out-of-range stored drop speed falls back to normal', () {
    final c = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(
          MemoryStorageService({StorageKeys.dropSpeed: 9}),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).dropSpeed, DropSpeed.normal);
    expect(
      c.read(gameConfigProvider).physics.gravity,
      const PhysicsConfig().gravity,
    );
  });
}
