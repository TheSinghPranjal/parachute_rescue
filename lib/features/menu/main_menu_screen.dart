import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/config/game_config.dart';
import '../../core/utils/random_source.dart';
import '../../game/entities/parachute.dart';
import '../../game/entities/person.dart';
import '../../game/rescue_game.dart';
import '../../game/skins.dart';
import '../../game/terrain/terrain.dart';
import '../../providers/providers.dart';
import '../common/animated_doodle.dart';
import '../common/sound_toggles.dart';
import '../play/gameplay_screen.dart';
import 'how_to_play_screen.dart';
import 'settings_screen.dart';
import 'skins_screen.dart';
import 'terrain_picker.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key, this.showLiveBackdrop = true});

  /// Widget tests turn the live Flame backdrop off.
  final bool showLiveBackdrop;

  void _play(BuildContext context, WidgetRef ref) {
    ref.read(audioProvider).play(Sfx.button);
    final tutorialDone = ref.read(settingsProvider).tutorialDone;
    if (tutorialDone) {
      unawaited(Navigator.of(context).push(GameplayScreen.route()));
    } else {
      unawaited(
        Navigator.of(context).push(HowToPlayScreen.route(playAfter: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final terrain = progress.terrain;
    return Scaffold(
      backgroundColor: terrain.sky.top,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showLiveBackdrop)
            IgnorePointer(
              child: _AttractBackdrop(
                key: ValueKey(
                  'attract-${terrain.id}-${progress.chuteSkin}-${progress.shirtSkin}',
                ),
                terrain: terrain,
                skins: progress.skins,
              ),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            DoodleIconButton(
                              icon: Icons.settings_rounded,
                              tooltip: 'Settings',
                              onPressed: () => unawaited(
                                Navigator.of(
                                  context,
                                ).push(SettingsScreen.route()),
                              ),
                            ),
                            const Spacer(),
                            _CoinChip(coins: progress.coins),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const _Title(),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: doodleBox(radius: 12),
                          child: Text(
                            'BEST  ${progress.bestScore}',
                            key: const Key('menu-best'),
                            style: const TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TerrainPicker(
                          selectedId: terrain.id,
                          onSelect: (id) => unawaited(
                            ref
                                .read(progressProvider.notifier)
                                .selectTerrain(id),
                          ),
                        ),
                        SizedBox(height: math.max(16, c.maxHeight * 0.12)),
                        DoodleButton(
                          key: const Key('play-button'),
                          label: 'PLAY',
                          icon: Icons.play_arrow_rounded,
                          fontSize: 40,
                          height: 84,
                          expand: true,
                          onPressed: () => _play(context, ref),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DoodleButton(
                                label: 'SKINS',
                                icon: Icons.checkroom_rounded,
                                color: AppColors.red,
                                textColor: Colors.white,
                                fontSize: 20,
                                expand: true,
                                onPressed: () => unawaited(
                                  Navigator.of(
                                    context,
                                  ).push(SkinsScreen.route()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DoodleButton(
                                key: const Key('how-button'),
                                label: 'HOW TO',
                                icon: Icons.help_outline_rounded,
                                color: AppColors.purple,
                                textColor: Colors.white,
                                fontSize: 20,
                                expand: true,
                                onPressed: () => unawaited(
                                  Navigator.of(
                                    context,
                                  ).push(HowToPlayScreen.route()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const SoundToggles(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The menu's live background: the real game in attract mode.
class _AttractBackdrop extends StatefulWidget {
  const _AttractBackdrop({
    super.key,
    required this.terrain,
    required this.skins,
  });

  final TerrainTheme terrain;
  final SkinSet skins;

  @override
  State<_AttractBackdrop> createState() => _AttractBackdropState();
}

class _AttractBackdropState extends State<_AttractBackdrop> {
  late final RescueGame _game = RescueGame(
    config: const GameConfig().fittedTo(MediaQuery.sizeOf(context)),
    terrain: widget.terrain,
    skins: widget.skins,
    attractMode: true,
    random: RandomSource(7),
  );

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedLabel(
                  'PARACHUTE',
                  size: 50,
                  color: AppColors.yellow,
                  stroke: 9,
                ),
                OutlinedLabel(
                  'RESCUE!',
                  size: 58,
                  color: AppColors.blue,
                  stroke: 9,
                ),
              ],
            ),
          ),
          // Mascot floating beside the title.
          SizedBox(
            width: 92,
            height: 140,
            child: AnimatedDoodle(
              paint: (canvas, size, t) {
                canvas.translate(size.width / 2, 80 + math.sin(t * 2) * 4);
                canvas.rotate(math.sin(t * 1.3) * 0.08);
                canvas.save();
                canvas.translate(0, 0);
                Parachute.draw(canvas, ChuteSkin.classicPairs.first, sway: 0);
                canvas.restore();
                canvas.translate(-kPersonSize.x / 2, -2);
                Person.drawFigure(canvas, FigurePose.hanging, t, 3);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: doodleBox(color: AppColors.ink, radius: 22),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.yellow,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.star_rounded,
            size: 16,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$coins',
          key: const Key('menu-coins'),
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}
