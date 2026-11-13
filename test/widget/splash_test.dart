import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parachute_rescue/app/app.dart';
import 'package:parachute_rescue/app/theme.dart';
import 'package:parachute_rescue/core/services/audio_service.dart';
import 'package:parachute_rescue/core/services/storage_service.dart';
import 'package:parachute_rescue/features/menu/main_menu_screen.dart';
import 'package:parachute_rescue/features/splash/splash_screen.dart';
import 'package:parachute_rescue/providers/providers.dart';

void expectClean(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

Future<void> pumpSplash(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeData? theme,
  Widget? home,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(MemoryStorageService()),
        audioProvider.overrideWithValue(SilentAudioService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme ?? buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: home ?? const SplashScreen(hold: Duration(hours: 1)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('app opens on the branded splash, not the menu', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SkyRescueApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byKey(const Key('splash-screen')), findsOneWidget);
    expect(find.text('PARACHUTE'), findsWidgets);
    expect(find.text('RESCUE!'), findsWidgets);
    expect(find.text('by'), findsOneWidget);
    expect(find.text('The Lazy Bear Club'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);

    final by = tester.getRect(find.text('by'));
    final studio = tester.getRect(find.text('The Lazy Bear Club'));
    final icon = tester.getRect(find.byKey(const Key('lazy-bear-icon')));
    final title = tester.getRect(find.text('PARACHUTE').first);
    expect(title.bottom, lessThan(by.top));
    expect(by.bottom, lessThanOrEqualTo(studio.top));
    expect(icon.center.dy, closeTo(studio.center.dy, 12));
    expect(icon.right, lessThanOrEqualTo(studio.left));

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('lazy-bear-icon')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/branding/lazy_bear_club.png',
    );

    final card = tester.widget<Container>(
      find.byKey(const Key('splash-byline')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.paper);
    expect(
      tester.widget<Text>(find.text('The Lazy Bear Club')).style?.color,
      AppColors.ink,
    );
    expect(tester.widget<Text>(find.text('by')).style?.color, AppColors.ink);

    expectClean(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('splash fades into the main menu after about two seconds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(MemoryStorageService()),
          audioProvider.overrideWithValue(SilentAudioService()),
        ],
        child: const SkyRescueApp(
          home: SplashScreen(next: MainMenuScreen(showLiveBackdrop: false)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('The Lazy Bear Club'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('The Lazy Bear Club'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('The Lazy Bear Club'), findsNothing);
    expect(find.text('by'), findsNothing);
    expect(find.text('PLAY'), findsOneWidget);
    expectClean(tester);
  });

  testWidgets('byline stays on screen for phones, tablets, and large text', (
    tester,
  ) async {
    const sizes = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(768, 1024),
      Size(1024, 1366),
      Size(1280, 720),
      Size(600, 400),
    ];
    for (final size in sizes) {
      await pumpSplash(tester, size: size);
      expect(
        find.text('The Lazy Bear Club'),
        findsOneWidget,
        reason: 'studio name on $size',
      );
      expect(find.text('by'), findsOneWidget, reason: 'by on $size');
      expect(find.text('PARACHUTE'), findsWidgets, reason: 'title on $size');
      expectClean(tester);
    }

    await pumpSplash(tester, size: const Size(320, 568), textScale: 2);
    expect(find.text('The Lazy Bear Club'), findsOneWidget);
    expect(find.text('by'), findsOneWidget);
    expectClean(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dark theme keeps the byline ink-on-paper', (tester) async {
    await pumpSplash(
      tester,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF143044),
    );
    final card = tester.widget<Container>(
      find.byKey(const Key('splash-byline')),
    );
    expect((card.decoration! as BoxDecoration).color, AppColors.paper);
    expect(
      tester.widget<Text>(find.text('The Lazy Bear Club')).style?.color,
      AppColors.ink,
    );
    expect(tester.widget<Text>(find.text('by')).style?.color, AppColors.ink);
    final labels = tester.widgetList<OutlinedLabel>(find.byType(OutlinedLabel));
    expect(
      labels.every((label) => label.strokeColor == AppColors.paper),
      isTrue,
    );
    expectClean(tester);
    await tester.pumpWidget(const SizedBox());
  });
}
