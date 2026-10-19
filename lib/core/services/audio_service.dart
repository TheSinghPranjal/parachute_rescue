import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Every sound effect in the game. File names map to `assets/audio/<name>.wav`.
enum Sfx {
  plane,
  release,
  chute,
  wind,
  rescue,
  splash,
  thud,
  bite,
  heliHit,
  explosion,
  zap,
  beam,
  lifeLost,
  button,
  gameOver,
  newBest;

  String get file => '$name.wav';
}

/// Plays sound effects and music, respecting the user's toggles.
abstract class AudioService {
  bool sfxEnabled = true;
  bool musicEnabled = true;

  Future<void> preload();
  void play(Sfx sfx, {double volume = 0.8});

  /// Starts (or resumes) the background loop if music is enabled.
  void startMusic();
  void pauseMusic();
  void stopMusic();
  void dispose();
}

/// Silent implementation for tests and when audio is unavailable.
class SilentAudioService extends AudioService {
  final List<Sfx> played = [];

  @override
  Future<void> preload() async {}

  @override
  void play(Sfx sfx, {double volume = 0.8}) {
    if (sfxEnabled) played.add(sfx);
  }

  @override
  void startMusic() {}

  @override
  void pauseMusic() {}

  @override
  void stopMusic() {}

  @override
  void dispose() {}
}

/// [AudioService] using flame_audio. Missing files and platform errors are
/// swallowed so audio can never crash or block the game.
class FlameAudioService extends AudioService {
  static const musicFile = 'music.wav';

  bool _ready = false;
  bool _musicPlaying = false;
  final Map<Sfx, double> _lastPlayed = {};
  final Stopwatch _clock = Stopwatch()..start();

  @override
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([
        for (final s in Sfx.values) s.file,
        musicFile,
      ]);
      await FlameAudio.bgm.initialize();
      _ready = true;
    } on Object catch (e) {
      debugPrint('Audio preload failed, continuing silently: $e');
    }
  }

  @override
  void play(Sfx sfx, {double volume = 0.8}) {
    if (!sfxEnabled || !_ready) return;
    // Throttle identical sounds fired in the same instant.
    final now = _clock.elapsedMilliseconds / 1000;
    if (now - (_lastPlayed[sfx] ?? -1) < 0.05) return;
    _lastPlayed[sfx] = now;
    unawaited(
      FlameAudio.play(sfx.file, volume: volume).then<void>(
        (_) {},
        onError: (Object e) => debugPrint('sfx ${sfx.name} failed: $e'),
      ),
    );
  }

  @override
  void startMusic() {
    if (!musicEnabled || !_ready) return;
    try {
      if (_musicPlaying) {
        unawaited(FlameAudio.bgm.resume());
      } else {
        unawaited(FlameAudio.bgm.play(musicFile, volume: 0.35));
        _musicPlaying = true;
      }
    } on Object catch (e) {
      debugPrint('music failed: $e');
    }
  }

  @override
  void pauseMusic() {
    if (!_ready || !_musicPlaying) return;
    unawaited(FlameAudio.bgm.pause());
  }

  @override
  void stopMusic() {
    if (!_ready || !_musicPlaying) return;
    _musicPlaying = false;
    unawaited(FlameAudio.bgm.stop());
  }

  @override
  void dispose() {
    stopMusic();
    if (_ready) FlameAudio.bgm.dispose();
  }
}
