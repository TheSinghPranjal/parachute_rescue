import 'package:shared_preferences/shared_preferences.dart';

/// Small key-value persistence used for settings, best score, coins and
/// skins. Not a database: only simple, non-critical values live here.
abstract class StorageService {
  int getInt(String key, int fallback);
  bool getBool(String key, bool fallback);
  String getString(String key, String fallback);
  List<String> getStringList(String key);

  Future<void> setInt(String key, int value);
  Future<void> setBool(String key, bool value);
  Future<void> setString(String key, String value);
  Future<void> setStringList(String key, List<String> value);

  /// Removes every stored value.
  Future<void> clear();
}

/// Storage keys in one place.
abstract final class StorageKeys {
  static const bestScore = 'best_score';
  static const coins = 'coins';
  static const sfx = 'sfx_enabled';
  static const music = 'music_enabled';
  static const haptics = 'haptics_enabled';
  static const tutorialDone = 'tutorial_done';
  static const dropSpeed = 'drop_speed';
  static const terrain = 'terrain_id';
  static const ownedSkins = 'owned_skins';
  static const chuteSkin = 'chute_skin';
  static const shirtSkin = 'shirt_skin';
}

/// [StorageService] backed by `SharedPreferencesWithCache`. Reads are
/// synchronous from the cache; writes are asynchronous.
class PrefsStorageService implements StorageService {
  PrefsStorageService(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<PrefsStorageService> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    return PrefsStorageService(prefs);
  }

  // Values of an unexpected type (e.g. from an older build) fall back safely.
  T _read<T>(String key, T fallback) {
    try {
      final v = _prefs.get(key);
      return v is T ? v : fallback;
    } on Object {
      return fallback;
    }
  }

  @override
  int getInt(String key, int fallback) => _read<int>(key, fallback);

  @override
  bool getBool(String key, bool fallback) => _read<bool>(key, fallback);

  @override
  String getString(String key, String fallback) => _read<String>(key, fallback);

  @override
  List<String> getStringList(String key) {
    try {
      return _prefs.getStringList(key) ?? const [];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  Future<void> clear() => _prefs.clear();
}

/// In-memory storage for tests and as a fallback if the platform store fails.
class MemoryStorageService implements StorageService {
  MemoryStorageService([Map<String, Object>? initial]) : values = {...?initial};

  final Map<String, Object> values;

  /// Number of writes performed (lets tests assert we don't spam disk).
  int writes = 0;

  T _read<T>(String key, T fallback) {
    final v = values[key];
    return v is T ? v : fallback;
  }

  @override
  int getInt(String key, int fallback) => _read<int>(key, fallback);

  @override
  bool getBool(String key, bool fallback) => _read<bool>(key, fallback);

  @override
  String getString(String key, String fallback) => _read<String>(key, fallback);

  @override
  List<String> getStringList(String key) => _read<List<String>>(key, const []);

  Future<void> _write(String key, Object value) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) => _write(key, value);

  @override
  Future<void> setBool(String key, bool value) => _write(key, value);

  @override
  Future<void> setString(String key, String value) => _write(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _write(key, List<String>.of(value));

  @override
  Future<void> clear() async {
    writes++;
    values.clear();
  }
}
