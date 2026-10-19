import '../core/config/game_config.dart';

/// Why a person was lost; used for feedback text and stats.
enum LossCause { water, crash, helicopter, ufo, lightning }

/// Immutable summary of a finished run.
class GameResult {
  const GameResult({
    required this.score,
    required this.rescued,
    required this.lost,
    required this.longestStreak,
    required this.hazardsDestroyed,
    required this.coinsEarned,
    required this.survivalSeconds,
    required this.terrainId,
  });

  final int score;
  final int rescued;
  final int lost;
  final int longestStreak;
  final int hazardsDestroyed;
  final int coinsEarned;
  final double survivalSeconds;
  final String terrainId;

  double get rescueRate {
    final total = rescued + lost;
    return total == 0 ? 0 : rescued / total;
  }
}

/// Outcome of one rescue for effects and events.
class RescueAward {
  const RescueAward({
    required this.points,
    required this.streak,
    required this.risky,
    required this.extraLife,
  });

  final int points;
  final int streak;
  final bool risky;
  final bool extraLife;
}

/// The single authority over score, streak, lives and game over.
///
/// Every mutation is keyed by entity id, so a single incident can never be
/// counted twice no matter how many collision callbacks report it.
class ScoreBook {
  ScoreBook(this.cfg) {
    reset();
  }

  final ScoringConfig cfg;

  late int score;
  late int lives;
  late int streak;
  late int longestStreak;
  late int rescued;
  late int lost;
  late int hazardsDestroyed;
  late int coins;
  bool _gameOver = false;
  int _nextExtraLifeAt = 0;
  final Set<int> _resolvedPeople = {};
  final Set<int> _resolvedHazards = {};

  bool get isGameOver => _gameOver;

  void reset() {
    score = cfg.initialScore;
    lives = cfg.initialLives;
    streak = 0;
    longestStreak = 0;
    rescued = 0;
    lost = 0;
    hazardsDestroyed = 0;
    coins = 0;
    _gameOver = false;
    _nextExtraLifeAt = cfg.extraLifeEvery;
    _resolvedPeople.clear();
    _resolvedHazards.clear();
  }

  /// Points for the next rescue given the current streak (before increment).
  int rescueValue({
    required int streakAfter,
    required bool risky,
    int mult = 2,
  }) {
    final steps = (streakAfter - 1).clamp(0, cfg.maxStreakBonusSteps);
    final base = cfg.rescuePoints + cfg.streakBonus * steps;
    return risky ? base * mult : base;
  }

  /// Records a rescue once per [personId]. Returns null if already resolved
  /// or the game is over.
  RescueAward? rescue(
    int personId, {
    bool risky = false,
    int riskMultiplier = 2,
  }) {
    if (_gameOver || !_resolvedPeople.add(personId)) return null;
    streak++;
    if (streak > longestStreak) longestStreak = streak;
    rescued++;
    coins += cfg.coinsPerRescue;
    final points = rescueValue(
      streakAfter: streak,
      risky: risky,
      mult: riskMultiplier,
    );
    final extra = _addPoints(points);
    return RescueAward(
      points: points,
      streak: streak,
      risky: risky,
      extraLife: extra,
    );
  }

  /// Records a lost person once per [personId]: resets the streak and removes
  /// exactly one life. Returns true if this call caused the game to end.
  bool lose(int personId) {
    if (_gameOver || !_resolvedPeople.add(personId)) return false;
    lost++;
    streak = 0;
    if (lives > 0) lives--;
    if (lives == 0) {
      _gameOver = true;
      return true;
    }
    return false;
  }

  /// Awards a hazard bonus once per [hazardId]. Returns the points or null.
  int? destroyHazard(int hazardId, int bonus) {
    if (_gameOver || !_resolvedHazards.add(hazardId)) return null;
    hazardsDestroyed++;
    coins += cfg.coinsPerHazard;
    _addPoints(bonus);
    return bonus;
  }

  bool _addPoints(int points) {
    score += points;
    var extra = false;
    while (cfg.extraLifeEvery > 0 && score >= _nextExtraLifeAt) {
      _nextExtraLifeAt += cfg.extraLifeEvery;
      if (lives < cfg.maxLives) {
        lives++;
        extra = true;
      }
    }
    return extra;
  }

  GameResult result({required double seconds, required String terrainId}) =>
      GameResult(
        score: score,
        rescued: rescued,
        lost: lost,
        longestStreak: longestStreak,
        hazardsDestroyed: hazardsDestroyed,
        coinsEarned: coins,
        survivalSeconds: seconds,
        terrainId: terrainId,
      );
}
