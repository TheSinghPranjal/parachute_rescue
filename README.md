# Parachute Rescue

An original, hand-drawn doodle arcade game for Android and iOS. Tap falling stick figures to open their parachutes, swipe to blow wind, and land them on the moving deck while dodging helicopters, UFOs, and lightning.

Built with **Flutter 3.41 / Dart 3.11**, **Flame** (engine), and **Riverpod** (app state).

## Run

```bash
flutter pub get
flutter run            # portrait-only, on a device or simulator
```

## Test and verify

```bash
dart format .
flutter analyze
flutter test           # domain, Flame game, and widget tests
flutter build apk --debug
flutter build ios --no-codesign --debug
```

To regenerate the synthesized sound effects:

```bash
python3 tool/gen_sfx.py assets/audio
```

## Production deploy

The **Production Deploy** workflow (`.github/workflows/deploy.yml`) uploads a release app bundle to the Play production track. It runs only when started by hand: Actions → Production Deploy → Run workflow. It has no inputs and does not run on push.

Create these repository secrets before the first run:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | Base64-encoded upload keystore. The job writes it to `android/app/keystore/upload-keystore.jks`. |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Upload key alias |
| `KEY_PASSWORD` | Upload key password |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Play service-account JSON, pasted as raw text |

`android/app/build.gradle.kts` sets `applicationId` to `com.the_lazy_bear_club.parachute_rescue`. That has to be the same package as the Play listing.

`pubspec.yaml` is `1.0.0+2`, so the first run commits `1.0.0+3` and uploads version code 3. Play rejects a version code it already has. If the listing is already at 3 or higher, set the `+build` number above that code and run the workflow again.

If the upload fails with "The caller does not have permission", the Play service account has no release access to this app. Grant it under Users and permissions in Play Console. A version code that is already on Play fails the same step; run the workflow again after the build number is higher.

This app does not use AdMob, and there are no ad-unit ids to replace.

## Dependencies

| Package | Version | Note |
|---|---|---|
| flame | ^1.38.2 | game loop, components, camera |
| flutter_riverpod | ^3.3.2 | 3.4.x requires Dart ^3.12; 3.3.2 is the newest version compatible with the installed Dart 3.11 |
| flame_audio | ^2.12.2 | sound effects and music |
| shared_preferences | ^2.5.6 | uses `SharedPreferencesWithCache` |
| flame_test (dev) | ^2.3.1 | headless game tests |

Forge2D is deliberately **not** used. Physics is a custom, frame-rate-independent kinematic model with swept landing tests.

## Layout

```
lib/
  core/config/game_config.dart   every tunable value (physics, wind, scoring, hazards, difficulty)
  core/services/                 storage, audio, haptics (injected through Riverpod)
  core/utils/doodle.dart         shared ink-drawing helpers (outline, wobble, clouds, paper)
  domain/                        pure Dart rules: fall physics, swept landing, swipe→gust,
                                 ScoreBook, difficulty curve, deterministic SpawnDirector
  game/
    rescue_game.dart             FlameGame: session state machine, input routing, event bridge
    input_layer.dart             single raw-pointer arbiter (tap vs swipe)
    entities/                    ★ one file each: person, parachute, fish, landing_space, plane
    hazards/                     helicopter, ufo, thundercloud
    terrain/                     TerrainTheme presets + backdrop/ground rendering
    effects/                     wind lines, splash/dust, explosions, score popups
  features/menu, features/play   Flutter screens, HUD, and overlays
  providers/providers.dart       settings, progress (best score, coins, skins, terrain), session
```

## Terrains

All terrains are selectable from the main menu. A terrain changes **only colours and accent shapes**. Sizes, hitboxes, and behaviour come from `GameConfig`. The person is always `kPersonSize` (34×56), regardless of terrain or skin.

| Terrain | Landing space | Predator | Plane |
|---|---|---|---|
| Ocean Bay | boat | shark | airliner |
| Battlefield | armoured medic truck | mini tank | cargo plane |
| Desert Dunes | camel cart | sandworm | airliner |
| Arctic Ice | ice sled | orca | airliner |
| Swamp | log raft | crocodile | prop cargo plane |

## Rules (defaults, all in `GameConfig`)

- **Lives:** 3 lives, with +1 every 5,000 points (maximum 5).
- **Losing a life:** each lost person costs exactly one life, and game over fires once.
- **Rescue score:** 100 points plus 25 × (streak − 1), capped at 10 steps. Opening the chute within 160 units above the deck counts as a "Daring" landing worth ×2.
- **Crashes:** a free-fall landing on the deck is a crash. This can be changed with `requireChuteToLand`.
- **Edges:** people wrap around the side edges (`EdgeRule.wrap`, or `clamp`).
- **Helicopter:** destroyed in 3 taps for +250.
- **UFO:** destroyed in 2 taps for +200. Its beam is telegraphed, then abducts anyone who stays under it for 0.8 s.
- **Thundercloud:** cannot be tapped. It shows a 1.5 s warning column before each strike and retires after 3 strikes.
- **Predator:** the fish, tank, worm, orca or crocodile only bites people who are already lost. It never kills anyone who could still be rescued.
- **Coins:** earned from rescues and hazard kills, and spent on cosmetic skins.

## Assets

- **Art:** all art is drawn procedurally in code, with no image assets.
- **Fonts:** Lilita One and Patrick Hand, both under the SIL Open Font License (see `assets/fonts/`).
- **Audio:** sound effects and the music loop are original syntheses produced by `tool/gen_sfx.py`.
