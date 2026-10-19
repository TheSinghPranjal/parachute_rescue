import '../core/config/game_config.dart';
import '../core/utils/random_source.dart';
import 'difficulty.dart';

enum HazardKind { helicopter, ufo, thundercloud }

/// A decision produced by the [SpawnDirector] for the game to execute.
sealed class SpawnOrder {
  const SpawnOrder();
}

class SpawnPerson extends SpawnOrder {
  const SpawnPerson({required this.id, required this.releaseX});
  final int id;
  final double releaseX;
}

class SpawnHazard extends SpawnOrder {
  const SpawnHazard({
    required this.id,
    required this.kind,
    required this.fromLeft,
    required this.y,
  });
  final int id;
  final HazardKind kind;
  final bool fromLeft;
  final double y;
}

/// The sole owner of spawn timing. Pure and deterministic for a given seed:
/// the game calls [tick] each step with live entity counts and executes the
/// returned orders.
class SpawnDirector {
  SpawnDirector({required this.cfg, required this.random})
    : curve = DifficultyCurve(cfg.difficulty) {
    reset();
  }

  final GameConfig cfg;
  final RandomSource random;
  final DifficultyCurve curve;

  late double elapsed;
  late double _personTimer;
  late double _hazardTimer;
  int _nextId = 1;

  /// Weights for helicopter, ufo, thundercloud.
  List<double> hazardWeights = const [1.0, 0.8, 0.7];

  DifficultySnapshot get difficulty => curve.at(elapsed);

  void reset() {
    elapsed = 0;
    // The first person drops quickly so the run starts with action.
    _personTimer = 1.2;
    _hazardTimer = cfg.hazards.hazardFreeTime;
    _nextId = 1;
  }

  int nextId() => _nextId++;

  /// Advances timers and returns any spawns due this step.
  List<SpawnOrder> tick(
    double dt, {
    required int activePeople,
    required int activeHazards,
    required double planeX,
    bool planeReady = true,
  }) {
    elapsed += dt;
    final d = difficulty;
    final orders = <SpawnOrder>[];

    _personTimer -= dt;
    if (_personTimer <= 0) {
      if (activePeople < d.maxActivePeople && planeReady) {
        orders.add(SpawnPerson(id: nextId(), releaseX: clampRelease(planeX)));
        _personTimer = d.spawnInterval * random.range(0.85, 1.15);
      } else {
        // Try again shortly rather than queueing a burst.
        _personTimer = 0.4;
      }
    }

    _hazardTimer -= dt;
    if (_hazardTimer <= 0) {
      if (activeHazards < d.maxHazards) {
        final kind = HazardKind.values[random.weighted(hazardWeights)];
        final w = cfg.world;
        orders.add(
          SpawnHazard(
            id: nextId(),
            kind: kind,
            fromLeft: random.nextBool(),
            y: random.range(w.skyTop + 120, w.skyBottom - 260),
          ),
        );
        _hazardTimer = d.hazardInterval * random.range(0.8, 1.2);
      } else {
        _hazardTimer = 1.5;
      }
    }
    return orders;
  }

  /// Keeps release points inside the playfield with a safe margin.
  double clampRelease(double x) {
    const margin = 60.0;
    return x.clamp(margin, cfg.world.width - margin);
  }
}
