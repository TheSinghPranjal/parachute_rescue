import '../domain/scoring.dart';
import '../domain/spawn_plan.dart';

/// Session state machine shared by Flame and Flutter.
///
/// ready → playing ⇄ paused → gameOver (restart → playing)
enum SessionState { ready, playing, paused, gameOver }

/// Typed messages from the Flame simulation to the application layer.
/// Emitted only on meaningful changes — never per frame.
sealed class GameEvent {
  const GameEvent();
}

class SessionStateChanged extends GameEvent {
  const SessionStateChanged(this.state);
  final SessionState state;
}

class CharacterRescued extends GameEvent {
  const CharacterRescued({
    required this.points,
    required this.currentStreak,
    required this.totalScore,
    required this.risky,
  });

  final int points;
  final int currentStreak;
  final int totalScore;
  final bool risky;
}

class CharacterLost extends GameEvent {
  const CharacterLost(this.cause);
  final LossCause cause;
}

class LifeCountChanged extends GameEvent {
  const LifeCountChanged(this.remainingLives);
  final int remainingLives;
}

class HazardDestroyed extends GameEvent {
  const HazardDestroyed({required this.kind, required this.bonus});
  final HazardKind kind;
  final int bonus;
}

class GameOver extends GameEvent {
  const GameOver(this.result);
  final GameResult result;
}
