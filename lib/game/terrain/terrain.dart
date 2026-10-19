import 'dart:ui';

/// Terrains only change colours and a few accent shapes. Sizes, hitboxes
/// and behaviour always come from GameConfig, so every terrain plays the same.
enum GroundStyle { water, dirt, sand, snow, swamp }

enum LandingVariant { boat, armoredTruck, camelCart, iceSled, raft }

enum FishVariant { shark, tank, sandworm, orca, crocodile }

enum PlaneVariant { airliner, cargo }

enum BackdropProps { island, battlefield, desert, arctic, swamp }

class SkyPalette {
  const SkyPalette({
    required this.top,
    required this.bottom,
    required this.grain,
    required this.cloud,
    required this.sun,
  });

  final Color top;
  final Color bottom;
  final Color grain;
  final Color cloud;
  final Color sun;
}

class LandingPalette {
  const LandingPalette({
    required this.hull,
    required this.trim,
    required this.deck,
    required this.cabin,
    required this.flag,
  });

  final Color hull;
  final Color trim;
  final Color deck;
  final Color cabin;
  final Color flag;
}

class FishPalette {
  const FishPalette({
    required this.body,
    required this.belly,
    required this.accent,
  });

  final Color body;
  final Color belly;
  final Color accent;
}

class PlanePalette {
  const PlanePalette({
    required this.body,
    required this.stripe,
    required this.window,
  });

  final Color body;
  final Color stripe;
  final Color window;
}

class HazardPalette {
  const HazardPalette({
    required this.helicopter,
    required this.helicopterAccent,
    required this.ufo,
    required this.ufoDome,
    required this.stormCloud,
    required this.bolt,
  });

  final Color helicopter;
  final Color helicopterAccent;
  final Color ufo;
  final Color ufoDome;
  final Color stormCloud;
  final Color bolt;
}

class TerrainTheme {
  const TerrainTheme({
    required this.id,
    required this.name,
    required this.tagline,
    required this.sky,
    required this.ground,
    required this.groundFill,
    required this.groundDeep,
    required this.groundAccent,
    required this.landing,
    required this.landingColors,
    required this.fish,
    required this.fishColors,
    required this.plane,
    required this.planeColors,
    required this.props,
    required this.propPrimary,
    required this.propSecondary,
    required this.hazards,
  });

  final String id;
  final String name;
  final String tagline;
  final SkyPalette sky;
  final GroundStyle ground;
  final Color groundFill;
  final Color groundDeep;
  final Color groundAccent;
  final LandingVariant landing;
  final LandingPalette landingColors;
  final FishVariant fish;
  final FishPalette fishColors;
  final PlaneVariant plane;
  final PlanePalette planeColors;
  final BackdropProps props;
  final Color propPrimary;
  final Color propSecondary;
  final HazardPalette hazards;

  /// Water terrains splash; land terrains kick up dust.
  bool get isLiquid =>
      ground == GroundStyle.water || ground == GroundStyle.swamp;

  static TerrainTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => ocean);

  static const List<TerrainTheme> all = [
    ocean,
    battlefield,
    desert,
    arctic,
    swamp,
  ];

  static const _defaultHazards = HazardPalette(
    helicopter: Color(0xFF6E8B3D),
    helicopterAccent: Color(0xFFF2C14E),
    ufo: Color(0xFF8E7CC3),
    ufoDome: Color(0xFF9BE37B),
    stormCloud: Color(0xFF6B6F7A),
    bolt: Color(0xFFFFD43B),
  );

  static const ocean = TerrainTheme(
    id: 'ocean',
    name: 'Ocean Bay',
    tagline: 'Boats, waves and one hungry shark',
    sky: SkyPalette(
      top: Color(0xFFBFE6FA),
      bottom: Color(0xFFE6F6FD),
      grain: Color(0x22357DA8),
      cloud: Color(0xFFFFFFFF),
      sun: Color(0xFFFFD35A),
    ),
    ground: GroundStyle.water,
    groundFill: Color(0xFF4FA9E8),
    groundDeep: Color(0xFF2F7FC4),
    groundAccent: Color(0xFFE8F6FF),
    landing: LandingVariant.boat,
    landingColors: LandingPalette(
      hull: Color(0xFFE8504F),
      trim: Color(0xFFFFFFFF),
      deck: Color(0xFFD9A066),
      cabin: Color(0xFFFFFFFF),
      flag: Color(0xFFE8504F),
    ),
    fish: FishVariant.shark,
    fishColors: FishPalette(
      body: Color(0xFF7D8A9C),
      belly: Color(0xFFEFF2F5),
      accent: Color(0xFFE8504F),
    ),
    plane: PlaneVariant.airliner,
    planeColors: PlanePalette(
      body: Color(0xFFFFFFFF),
      stripe: Color(0xFFE8504F),
      window: Color(0xFF3A5A80),
    ),
    props: BackdropProps.island,
    propPrimary: Color(0xFF5DBB63),
    propSecondary: Color(0xFFC8A06A),
    hazards: _defaultHazards,
  );

  static const battlefield = TerrainTheme(
    id: 'battlefield',
    name: 'Battlefield',
    tagline: 'Drop zone under fire — land on the truck!',
    sky: SkyPalette(
      top: Color(0xFFD9D2BF),
      bottom: Color(0xFFEDE6D3),
      grain: Color(0x2A5B4A2E),
      cloud: Color(0xFFCFC8B8),
      sun: Color(0xFFF0A45A),
    ),
    ground: GroundStyle.dirt,
    groundFill: Color(0xFF8A6A45),
    groundDeep: Color(0xFF5E4630),
    groundAccent: Color(0xFFB08B5C),
    landing: LandingVariant.armoredTruck,
    landingColors: LandingPalette(
      hull: Color(0xFF5F6E3A),
      trim: Color(0xFF3F4A26),
      deck: Color(0xFF8C8F5A),
      cabin: Color(0xFF7A8848),
      flag: Color(0xFFE8504F),
    ),
    fish: FishVariant.tank,
    fishColors: FishPalette(
      body: Color(0xFF6B7440),
      belly: Color(0xFF4A5230),
      accent: Color(0xFFF2C14E),
    ),
    plane: PlaneVariant.cargo,
    planeColors: PlanePalette(
      body: Color(0xFF6E7B45),
      stripe: Color(0xFF3F4A26),
      window: Color(0xFF2E3A44),
    ),
    props: BackdropProps.battlefield,
    propPrimary: Color(0xFFC9B27C),
    propSecondary: Color(0xFF7F7F7F),
    hazards: HazardPalette(
      helicopter: Color(0xFF4F5A2E),
      helicopterAccent: Color(0xFFE8504F),
      ufo: Color(0xFF8E7CC3),
      ufoDome: Color(0xFF9BE37B),
      stormCloud: Color(0xFF55545A),
      bolt: Color(0xFFFFD43B),
    ),
  );

  static const desert = TerrainTheme(
    id: 'desert',
    name: 'Desert Dunes',
    tagline: 'Hot sand, a camel cart and a sneaky sandworm',
    sky: SkyPalette(
      top: Color(0xFFFFE2B0),
      bottom: Color(0xFFFFF4DE),
      grain: Color(0x2AA8743A),
      cloud: Color(0xFFFFFAF0),
      sun: Color(0xFFFF9F43),
    ),
    ground: GroundStyle.sand,
    groundFill: Color(0xFFF2C77E),
    groundDeep: Color(0xFFD9A25A),
    groundAccent: Color(0xFFFFE3AE),
    landing: LandingVariant.camelCart,
    landingColors: LandingPalette(
      hull: Color(0xFFB5713A),
      trim: Color(0xFF7A4A24),
      deck: Color(0xFFE0B07A),
      cabin: Color(0xFFE3A857),
      flag: Color(0xFF3FA7D6),
    ),
    fish: FishVariant.sandworm,
    fishColors: FishPalette(
      body: Color(0xFFC98B5B),
      belly: Color(0xFFF1C9A2),
      accent: Color(0xFF8A3B2E),
    ),
    plane: PlaneVariant.airliner,
    planeColors: PlanePalette(
      body: Color(0xFFFFF4DE),
      stripe: Color(0xFF3FA7D6),
      window: Color(0xFF3A5A80),
    ),
    props: BackdropProps.desert,
    propPrimary: Color(0xFF6DAA4F),
    propSecondary: Color(0xFFE0B26A),
    hazards: _defaultHazards,
  );

  static const arctic = TerrainTheme(
    id: 'arctic',
    name: 'Arctic Ice',
    tagline: 'Slide onto the sled before the orca surfaces',
    sky: SkyPalette(
      top: Color(0xFFD7E9F7),
      bottom: Color(0xFFF3F9FD),
      grain: Color(0x22597A99),
      cloud: Color(0xFFFFFFFF),
      sun: Color(0xFFFFE08A),
    ),
    ground: GroundStyle.snow,
    groundFill: Color(0xFFEAF4FB),
    groundDeep: Color(0xFFB9D7EC),
    groundAccent: Color(0xFF8FB8D8),
    landing: LandingVariant.iceSled,
    landingColors: LandingPalette(
      hull: Color(0xFF3F7CC0),
      trim: Color(0xFFE8504F),
      deck: Color(0xFFC9DDF0),
      cabin: Color(0xFFFFFFFF),
      flag: Color(0xFFE8504F),
    ),
    fish: FishVariant.orca,
    fishColors: FishPalette(
      body: Color(0xFF2B2F36),
      belly: Color(0xFFFFFFFF),
      accent: Color(0xFF3F7CC0),
    ),
    plane: PlaneVariant.airliner,
    planeColors: PlanePalette(
      body: Color(0xFFFFFFFF),
      stripe: Color(0xFF3F7CC0),
      window: Color(0xFF2E3A44),
    ),
    props: BackdropProps.arctic,
    propPrimary: Color(0xFF4E8A6A),
    propSecondary: Color(0xFFFFFFFF),
    hazards: _defaultHazards,
  );

  static const swamp = TerrainTheme(
    id: 'swamp',
    name: 'Swamp',
    tagline: 'Hop on the raft — the croc is waiting',
    sky: SkyPalette(
      top: Color(0xFFCFE3C4),
      bottom: Color(0xFFEAF3E2),
      grain: Color(0x22476B3A),
      cloud: Color(0xFFF6FBF2),
      sun: Color(0xFFFFE08A),
    ),
    ground: GroundStyle.swamp,
    groundFill: Color(0xFF6E9C5A),
    groundDeep: Color(0xFF4C7340),
    groundAccent: Color(0xFFA9C98B),
    landing: LandingVariant.raft,
    landingColors: LandingPalette(
      hull: Color(0xFF9B6B3F),
      trim: Color(0xFF6B4626),
      deck: Color(0xFFC08A55),
      cabin: Color(0xFFE8D7A8),
      flag: Color(0xFFF2C14E),
    ),
    fish: FishVariant.crocodile,
    fishColors: FishPalette(
      body: Color(0xFF5C8A3A),
      belly: Color(0xFFD9E3A0),
      accent: Color(0xFFF2C14E),
    ),
    plane: PlaneVariant.cargo,
    planeColors: PlanePalette(
      body: Color(0xFFF2C14E),
      stripe: Color(0xFF6B4626),
      window: Color(0xFF2E3A44),
    ),
    props: BackdropProps.swamp,
    propPrimary: Color(0xFF3E6B35),
    propSecondary: Color(0xFF7A5A3A),
    hazards: _defaultHazards,
  );
}
