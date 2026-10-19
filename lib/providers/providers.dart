import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/game_config.dart';
import '../core/services/audio_service.dart';
import '../core/services/haptics_service.dart';
import '../core/services/storage_service.dart';
import '../domain/scoring.dart';
import '../game/game_events.dart';
import '../game/rescue_game.dart';
import '../game/skins.dart';
import '../game/terrain/terrain.dart';

// ------------------------------------------------------------ services ----

/// Overridden in `main()` (and tests) with a ready storage instance.
final storageProvider = Provider<StorageService>(
  (ref) => MemoryStorageService(),
);

/// Overridden in `main()` with a preloaded [FlameAudioService].
final audioProvider = Provider<AudioService>((ref) => SilentAudioService());

final hapticsProvider = Provider<HapticsService>((ref) => HapticsService());

final gameConfigProvider = Provider<GameConfig>((ref) => const GameConfig());

// ------------------------------------------------------------ settings ----

class Settings {
  const Settings({
    required this.sfx,
    required this.music,
    required this.haptics,
    required this.tutorialDone,
  });

  final bool sfx;
  final bool music;
  final bool haptics;
  final bool tutorialDone;

  Settings copyWith({
    bool? sfx,
    bool? music,
    bool? haptics,
    bool? tutorialDone,
  }) => Settings(
    sfx: sfx ?? this.sfx,
    music: music ?? this.music,
    haptics: haptics ?? this.haptics,
    tutorialDone: tutorialDone ?? this.tutorialDone,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  StorageService get _store => ref.read(storageProvider);

  @override
  Settings build() {
    final s = ref.watch(storageProvider);
    final settings = Settings(
      sfx: s.getBool(StorageKeys.sfx, true),
      music: s.getBool(StorageKeys.music, true),
      haptics: s.getBool(StorageKeys.haptics, true),
      tutorialDone: s.getBool(StorageKeys.tutorialDone, false),
    );
    _applyToServices(settings);
    return settings;
  }

  void _applyToServices(Settings s) {
    final audio = ref.read(audioProvider);
    audio
      ..sfxEnabled = s.sfx
      ..musicEnabled = s.music;
    if (!s.music) audio.stopMusic();
    ref.read(hapticsProvider).enabled = s.haptics;
  }

  void _set(Settings next) {
    state = next;
    _applyToServices(next);
  }

  Future<void> setSfx(bool v) async {
    _set(state.copyWith(sfx: v));
    await _store.setBool(StorageKeys.sfx, v);
  }

  Future<void> setMusic(bool v) async {
    _set(state.copyWith(music: v));
    await _store.setBool(StorageKeys.music, v);
  }

  Future<void> setHaptics(bool v) async {
    _set(state.copyWith(haptics: v));
    await _store.setBool(StorageKeys.haptics, v);
  }

  Future<void> setTutorialDone(bool v) async {
    _set(state.copyWith(tutorialDone: v));
    await _store.setBool(StorageKeys.tutorialDone, v);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

// ------------------------------------------------------------ progress ----

class Progress {
  const Progress({
    required this.bestScore,
    required this.coins,
    required this.ownedSkins,
    required this.chuteSkin,
    required this.shirtSkin,
    required this.terrainId,
  });

  final int bestScore;
  final int coins;
  final Set<String> ownedSkins;
  final String chuteSkin;
  final String shirtSkin;
  final String terrainId;

  TerrainTheme get terrain => TerrainTheme.byId(terrainId);

  SkinSet get skins => SkinSet(
    chute: ChuteSkin.byId(chuteSkin),
    shirt: ShirtSkin.byId(shirtSkin),
  );

  bool owns(String skinId) => ownedSkins.contains(skinId);

  Progress copyWith({
    int? bestScore,
    int? coins,
    Set<String>? ownedSkins,
    String? chuteSkin,
    String? shirtSkin,
    String? terrainId,
  }) => Progress(
    bestScore: bestScore ?? this.bestScore,
    coins: coins ?? this.coins,
    ownedSkins: ownedSkins ?? this.ownedSkins,
    chuteSkin: chuteSkin ?? this.chuteSkin,
    shirtSkin: shirtSkin ?? this.shirtSkin,
    terrainId: terrainId ?? this.terrainId,
  );
}

/// Best score, coins, owned/equipped skins and the selected terrain.
class ProgressNotifier extends Notifier<Progress> {
  StorageService get _store => ref.read(storageProvider);

  static const _freeSkins = {'classic', 'plain'};

  @override
  Progress build() {
    final s = ref.watch(storageProvider);
    return Progress(
      bestScore: s.getInt(StorageKeys.bestScore, 0).clamp(0, 1 << 31),
      coins: s.getInt(StorageKeys.coins, 0).clamp(0, 1 << 31),
      ownedSkins: {..._freeSkins, ...s.getStringList(StorageKeys.ownedSkins)},
      chuteSkin: s.getString(StorageKeys.chuteSkin, 'classic'),
      shirtSkin: s.getString(StorageKeys.shirtSkin, 'plain'),
      terrainId: s.getString(StorageKeys.terrain, TerrainTheme.ocean.id),
    );
  }

  /// Banks a finished run. Writes to disk once per result.
  /// Returns true if it set a new best score.
  Future<bool> recordResult(GameResult result) async {
    final newBest = result.score > state.bestScore;
    state = state.copyWith(
      bestScore: newBest ? result.score : state.bestScore,
      coins: state.coins + result.coinsEarned,
    );
    if (newBest) await _store.setInt(StorageKeys.bestScore, state.bestScore);
    if (result.coinsEarned > 0) {
      await _store.setInt(StorageKeys.coins, state.coins);
    }
    return newBest;
  }

  Future<void> selectTerrain(String id) async {
    state = state.copyWith(terrainId: TerrainTheme.byId(id).id);
    await _store.setString(StorageKeys.terrain, state.terrainId);
  }

  /// Buys a skin if affordable. Returns false if not enough coins.
  Future<bool> buy(String skinId, int price) async {
    if (state.owns(skinId)) return true;
    if (state.coins < price) return false;
    state = state.copyWith(
      coins: state.coins - price,
      ownedSkins: {...state.ownedSkins, skinId},
    );
    await _store.setInt(StorageKeys.coins, state.coins);
    await _store.setStringList(
      StorageKeys.ownedSkins,
      state.ownedSkins.difference(_freeSkins).toList(),
    );
    return true;
  }

  Future<void> equipChute(String id) async {
    if (!state.owns(id)) return;
    state = state.copyWith(chuteSkin: id);
    await _store.setString(StorageKeys.chuteSkin, id);
  }

  Future<void> equipShirt(String id) async {
    if (!state.owns(id)) return;
    state = state.copyWith(shirtSkin: id);
    await _store.setString(StorageKeys.shirtSkin, id);
  }

  /// Wipes all local data and returns to defaults.
  Future<void> resetAll() async {
    await _store.clear();
    ref.invalidateSelf();
    ref.invalidate(settingsProvider);
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, Progress>(
  ProgressNotifier.new,
);

// ------------------------------------------------------------- session ----

class SessionSummary {
  const SessionSummary({
    this.state = SessionState.ready,
    this.result,
    this.newBest = false,
  });

  final SessionState state;
  final GameResult? result;
  final bool newBest;
}

/// Bridges one live [RescueGame] to app state. Attaching a new game cancels
/// the previous subscription, so restarts never stack listeners.
class GameSessionController extends Notifier<SessionSummary> {
  StreamSubscription<GameEvent>? _sub;
  RescueGame? _game;

  /// Number of live event subscriptions (always 0 or 1).
  int get subscriptionCount => _sub == null ? 0 : 1;

  @override
  SessionSummary build() {
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _sub = null;
    });
    return const SessionSummary();
  }

  void attach(RescueGame game) {
    if (identical(game, _game)) return;
    unawaited(_sub?.cancel());
    _game = game;
    _sub = game.events.listen(_onEvent);
  }

  void detach(RescueGame game) {
    if (!identical(game, _game)) return;
    unawaited(_sub?.cancel());
    _sub = null;
    _game = null;
  }

  Future<void> _onEvent(GameEvent e) async {
    switch (e) {
      case SessionStateChanged(:final state):
        this.state = SessionSummary(
          state: state,
          result: this.state.result,
          newBest: this.state.newBest,
        );
        if (state == SessionState.playing) {
          this.state = const SessionSummary(state: SessionState.playing);
        }
      case GameOver(:final result):
        final newBest = await ref
            .read(progressProvider.notifier)
            .recordResult(result);
        if (newBest) ref.read(audioProvider).play(Sfx.newBest);
        state = SessionSummary(
          state: SessionState.gameOver,
          result: result,
          newBest: newBest,
        );
      case CharacterRescued():
      case CharacterLost():
      case LifeCountChanged():
      case HazardDestroyed():
        break;
    }
  }
}

final gameSessionProvider =
    NotifierProvider<GameSessionController, SessionSummary>(
      GameSessionController.new,
    );
