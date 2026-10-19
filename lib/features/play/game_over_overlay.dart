import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/scoring.dart';
import '../../providers/providers.dart';
import '../common/sound_toggles.dart';

/// Result card: score, best, stats, new-record badge and replay options.
class GameOverOverlay extends ConsumerWidget {
  const GameOverOverlay({
    super.key,
    required this.fallbackResult,
    required this.onPlayAgain,
    required this.onMenu,
  });

  /// Used until the session controller has banked the result.
  final GameResult? fallbackResult;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    final best = ref.watch(progressProvider.select((p) => p.bestScore));
    final result = session.result ?? fallbackResult;
    if (result == null) return const SizedBox.shrink();
    final newBest = session.newBest;

    return ColoredBox(
      color: const Color(0x99000000),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: doodleBox(radius: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OutlinedLabel(
                        'GAME OVER',
                        size: 40,
                        color: AppColors.red,
                      ),
                      if (newBest) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            key: const Key('new-best'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: doodleBox(
                              color: AppColors.yellow,
                              radius: 12,
                            ),
                            child: const Text(
                              'NEW BEST!',
                              style: TextStyle(
                                fontFamily: AppFonts.display,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        '${result.score}',
                        key: const Key('final-score'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 52,
                          color: AppColors.ink,
                          height: 1,
                        ),
                      ),
                      Text(
                        'Best: ${best > result.score ? best : result.score}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 12),
                      _row('Rescued', '${result.rescued}'),
                      _row('Lost', '${result.lost}'),
                      _row('Longest streak', '${result.longestStreak}'),
                      _row(
                        'Rescue rate',
                        '${(result.rescueRate * 100).round()}%',
                      ),
                      _row('Hazards destroyed', '${result.hazardsDestroyed}'),
                      _row('Coins earned', '+${result.coinsEarned}'),
                      const SizedBox(height: 16),
                      DoodleButton(
                        label: 'PLAY AGAIN',
                        icon: Icons.replay_rounded,
                        color: AppColors.green,
                        onPressed: onPlayAgain,
                        expand: true,
                      ),
                      const SizedBox(height: 12),
                      DoodleButton(
                        label: 'MAIN MENU',
                        icon: Icons.home_rounded,
                        color: AppColors.paper,
                        onPressed: onMenu,
                        expand: true,
                      ),
                      const SizedBox(height: 12),
                      const SoundToggles(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 20))),
        Text(
          value,
          style: const TextStyle(fontFamily: AppFonts.display, fontSize: 20),
        ),
      ],
    ),
  );
}
