import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/game_events.dart';
import '../../game/input_layer.dart';
import '../../game/rescue_game.dart';
import '../../providers/providers.dart';
import 'game_over_overlay.dart';
import 'hud.dart';
import 'pause_overlay.dart';

/// Hosts one [RescueGame] with the HUD and the pause/game-over overlays.
///
/// Overlays are driven by the game's session state, so Flutter and Flame can
/// never disagree about whether the game is paused or over.
class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => const GameplayScreen(),
    transitionsBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen> {
  // Created once the screen size is known, so the world can fit its width.
  RescueGame? _game;
  RescueGame get game => _game!;
  late final GameSessionController _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) return;
    final progress = ref.read(progressProvider);
    final game = _game = RescueGame(
      config: ref.read(gameConfigProvider).fittedTo(MediaQuery.sizeOf(context)),
      terrain: progress.terrain,
      skins: progress.skins,
      audio: ref.read(audioProvider),
      haptics: ref.read(hapticsProvider),
      autoStart: true,
    );
    _session = ref.read(gameSessionProvider.notifier);
    _session.attach(game);
  }

  @override
  void dispose() {
    _session.detach(game);
    game.audio.stopMusic();
    super.dispose();
  }

  void _toMenu() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (game.isPlaying) {
          game.pause();
        } else if (game.state.value == SessionState.paused) {
          game.resume();
        } else {
          _toMenu();
        }
      },
      child: Scaffold(
        backgroundColor: game.terrain.sky.top,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameInputLayer(
              game: game,
              child: GameWidget(game: game),
            ),
            GameHud(game: game),
            ValueListenableBuilder<SessionState>(
              valueListenable: game.state,
              builder: (context, state, _) => switch (state) {
                SessionState.paused => PauseOverlay(
                  onResume: game.resume,
                  onRestart: game.restart,
                  onMenu: _toMenu,
                ),
                SessionState.gameOver => GameOverOverlay(
                  fallbackResult: game.lastResult,
                  onPlayAgain: game.restart,
                  onMenu: _toMenu,
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
