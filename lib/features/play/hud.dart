import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/rescue_game.dart';

/// Pause button, score, rescued counter, hearts and streak. Each value
/// rebuilds only when its notifier changes (on game events, not per frame).
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.game});

  final RescueGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DoodleIconButton(
                  icon: Icons.pause_rounded,
                  tooltip: 'Pause',
                  onPressed: game.pause,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Card(
                    child: ValueListenableBuilder<int>(
                      valueListenable: game.score,
                      builder: (_, v, _) => _Stat(label: 'SCORE', value: '$v'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Card(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([game.rescued, game.dropped]),
                    builder: (_, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.accessibility_new_rounded,
                          color: AppColors.ink,
                          size: 24,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${game.rescued.value}/${game.dropped.value}',
                          key: const Key('hud-rescued'),
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 22,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Card(
                  child: ValueListenableBuilder<int>(
                    valueListenable: game.lives,
                    builder: (_, v, _) => _Hearts(
                      lives: v,
                      slots: game.config.scoring.initialLives,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<int>(
              valueListenable: game.streak,
              builder: (_, s, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: s >= 2
                    ? Container(
                        key: ValueKey(s),
                        margin: const EdgeInsets.only(left: 60),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: doodleBox(
                          color: AppColors.yellow,
                          radius: 10,
                        ),
                        child: Text(
                          'STREAK x$s',
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 16,
                            color: AppColors.ink,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.center,
    decoration: doodleBox(),
    child: child,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => FittedBox(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 11,
            color: AppColors.ink,
            height: 1,
          ),
        ),
        FittedBox(
          child: Text(
            value,
            key: const Key('hud-score'),
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 24,
              color: AppColors.ink,
              height: 1.1,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Hearts extends StatelessWidget {
  const _Hearts({required this.lives, required this.slots});
  final int lives;
  final int slots;

  @override
  Widget build(BuildContext context) {
    final total = lives > slots ? lives : slots;
    if (total > 5) {
      // Compact form so the HUD never overflows.
      return Semantics(
        label: '$lives lives',
        child: Row(
          key: const Key('hud-lives'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 22, color: AppColors.red),
            Text(
              '×$lives',
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 20,
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      label: '$lives lives',
      child: Row(
        key: const Key('hud-lives'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                Icons.favorite,
                size: 22,
                color: i < lives ? AppColors.red : Colors.grey.shade500,
                shadows: const [
                  Shadow(
                    color: AppColors.ink,
                    blurRadius: 0,
                    offset: Offset(1.2, 1.2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
