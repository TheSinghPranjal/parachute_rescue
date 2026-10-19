/// Every tunable gameplay value lives here. Components read from this object;
/// none of them hard-code physics, scoring or difficulty numbers.
library;

/// What happens when a parachutist drifts past a side edge.
enum EdgeRule { wrap, clamp }

class WorldConfig {
  const WorldConfig({
    this.width = 720,
    this.height = 1280,
    this.planeLaneY = 130,
    this.skyTop = 190,
    this.skyBottom = 1000,
    this.groundY = 1080,
  });

  final double width;
  final double height;
  final double planeLaneY;
  final double skyTop;
  final double skyBottom;

  /// The waterline / ground surface. Crossing it unrescued means "lost".
  final double groundY;
}

class PhysicsConfig {
  const PhysicsConfig({
    this.gravity = 900,
    this.freeFallTerminal = 340,
    this.chuteDescent = 72,
    this.chuteRelaxRate = 6,
    this.openingDuration = 0.25,
    this.freeFallWindFactor = 0.25,
    this.chuteWindFactor = 1.0,
    this.freeFallDrag = 0.4,
    this.chuteDrag = 1.4,
    this.maxHorizontalSpeed = 260,
    this.maxFrameDt = 1 / 20,
    this.maxSubstep = 1 / 120,
    this.edgeRule = EdgeRule.wrap,
  });

  /// World units / s².
  final double gravity;

  /// Terminal speed with a closed chute (world units / s).
  final double freeFallTerminal;

  /// Terminal descent speed under an open chute.
  final double chuteDescent;

  /// Exponential approach rate (1/s) of vy toward [chuteDescent].
  final double chuteRelaxRate;

  /// Seconds the canopy takes to inflate; taps are ignored meanwhile.
  final double openingDuration;

  final double freeFallWindFactor;
  final double chuteWindFactor;

  /// Exponential horizontal damping rates (1/s): vx *= exp(-drag·dt).
  final double freeFallDrag;
  final double chuteDrag;

  final double maxHorizontalSpeed;

  /// Frame deltas longer than this are clamped (e.g. after a hitch).
  final double maxFrameDt;

  /// Simulation substep upper bound.
  final double maxSubstep;

  final EdgeRule edgeRule;
}

class WindConfig {
  const WindConfig({
    this.minSwipeDistance = 24,
    this.forceScale = 0.9,
    this.minStrength = 260,
    this.maxStrength = 900,
    this.gustDuration = 0.7,
    this.maxActiveGusts = 3,
  });

  /// Drags shorter than this are treated as taps, never wind.
  final double minSwipeDistance;

  /// Multiplies horizontal swipe speed (u/s) into wind acceleration (u/s²).
  final double forceScale;
  final double minStrength;
  final double maxStrength;
  final double gustDuration;
  final int maxActiveGusts;
}

class LandingConfig {
  const LandingConfig({
    this.footprintHalfWidth = 14,
    this.requireChuteToLand = true,
    this.riskWindow = 160,
    this.riskMultiplier = 2,
    this.deckWidth = 150,
    this.baseSpeed = 70,
    this.edgeMargin = 70,
  });

  /// Half-width of a person's feet when testing deck overlap.
  final double footprintHalfWidth;

  /// When true, landing on a deck in free fall is a crash.
  final bool requireChuteToLand;

  /// Opening the chute within this distance above the deck earns the risk bonus.
  final double riskWindow;
  final int riskMultiplier;

  final double deckWidth;
  final double baseSpeed;

  /// Landing spaces turn around this far from the side edges.
  final double edgeMargin;
}

class ScoringConfig {
  const ScoringConfig({
    this.initialLives = 3,
    this.maxLives = 5,
    this.initialScore = 0,
    this.rescuePoints = 100,
    this.streakBonus = 25,
    this.maxStreakBonusSteps = 10,
    this.extraLifeEvery = 5000,
    this.coinsPerRescue = 1,
    this.coinsPerHazard = 2,
  });

  final int initialLives;
  final int maxLives;
  final int initialScore;
  final int rescuePoints;
  final int streakBonus;
  final int maxStreakBonusSteps;
  final int extraLifeEvery;
  final int coinsPerRescue;
  final int coinsPerHazard;
}

class HazardConfig {
  const HazardConfig({
    this.helicopterHits = 3,
    this.helicopterBonus = 250,
    this.helicopterSpeed = 110,
    this.ufoHits = 2,
    this.ufoBonus = 200,
    this.ufoSpeed = 90,
    this.ufoBeamWarning = 1.0,
    this.ufoBeamActive = 1.6,
    this.ufoBeamCooldown = 2.4,
    this.ufoAbductTime = 0.8,
    this.cloudSpeed = 40,
    this.lightningWarning = 1.5,
    this.lightningStrike = 0.25,
    this.lightningCooldown = 3.2,
    this.lightningMaxStrikes = 3,
    this.lightningWidth = 80,
    this.fishPatrolSpeed = 60,
    this.fishDashSpeed = 320,
    this.tapCooldown = 0.08,
    this.hazardFreeTime = 20,
    this.spawnSafetyHorizon = 1.5,
  });

  final int helicopterHits;
  final int helicopterBonus;
  final double helicopterSpeed;
  final int ufoHits;
  final int ufoBonus;
  final double ufoSpeed;
  final double ufoBeamWarning;
  final double ufoBeamActive;
  final double ufoBeamCooldown;
  final double ufoAbductTime;
  final double cloudSpeed;
  final double lightningWarning;
  final double lightningStrike;
  final double lightningCooldown;
  final double lightningWidth;

  /// A cloud retires (stops striking) after this many bolts.
  final int lightningMaxStrikes;
  final double fishPatrolSpeed;
  final double fishDashSpeed;

  /// Minimum seconds between two hits on the same hazard.
  final double tapCooldown;

  /// No hazards spawn during the opening seconds of a run.
  final double hazardFreeTime;

  /// Seconds of predicted person motion a new hazard must not overlap.
  final double spawnSafetyHorizon;
}

/// A difficulty phase anchor: values at [time] seconds of survival.
class DifficultyPhase {
  const DifficultyPhase({
    required this.time,
    required this.spawnInterval,
    required this.maxActivePeople,
    required this.landingSpeed,
    required this.landingCount,
    required this.hazardInterval,
    required this.maxHazards,
    required this.hazardSpeedMultiplier,
  });

  final double time;
  final double spawnInterval;
  final int maxActivePeople;
  final double landingSpeed;
  final int landingCount;
  final double hazardInterval;
  final int maxHazards;
  final double hazardSpeedMultiplier;
}

class DifficultyConfig {
  const DifficultyConfig({
    this.phases = const [
      DifficultyPhase(
        time: 0,
        spawnInterval: 3.4,
        maxActivePeople: 2,
        landingSpeed: 70,
        landingCount: 1,
        hazardInterval: 14,
        maxHazards: 0,
        hazardSpeedMultiplier: 1,
      ),
      DifficultyPhase(
        time: 30,
        spawnInterval: 2.6,
        maxActivePeople: 3,
        landingSpeed: 90,
        landingCount: 1,
        hazardInterval: 12,
        maxHazards: 1,
        hazardSpeedMultiplier: 1,
      ),
      DifficultyPhase(
        time: 75,
        spawnInterval: 2.0,
        maxActivePeople: 4,
        landingSpeed: 115,
        landingCount: 2,
        hazardInterval: 9,
        maxHazards: 2,
        hazardSpeedMultiplier: 1.15,
      ),
      DifficultyPhase(
        time: 130,
        spawnInterval: 1.5,
        maxActivePeople: 6,
        landingSpeed: 145,
        landingCount: 2,
        hazardInterval: 7,
        maxHazards: 2,
        hazardSpeedMultiplier: 1.3,
      ),
      DifficultyPhase(
        time: 200,
        spawnInterval: 1.1,
        maxActivePeople: 7,
        landingSpeed: 170,
        landingCount: 2,
        hazardInterval: 5,
        maxHazards: 3,
        hazardSpeedMultiplier: 1.4,
      ),
    ],
  });

  /// Sorted by time; the last entry is the hard cap.
  final List<DifficultyPhase> phases;
}

class GameConfig {
  const GameConfig({
    this.world = const WorldConfig(),
    this.physics = const PhysicsConfig(),
    this.wind = const WindConfig(),
    this.landing = const LandingConfig(),
    this.scoring = const ScoringConfig(),
    this.hazards = const HazardConfig(),
    this.difficulty = const DifficultyConfig(),
  });

  final WorldConfig world;
  final PhysicsConfig physics;
  final WindConfig wind;
  final LandingConfig landing;
  final ScoringConfig scoring;
  final HazardConfig hazards;
  final DifficultyConfig difficulty;
}
