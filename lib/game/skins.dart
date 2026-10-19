import 'dart:ui';

/// A cosmetic canopy pattern. Skins only change colours — never sizes.
class ChuteSkin {
  const ChuteSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.panels,
  });

  final String id;
  final String name;
  final int price;

  /// Colours of the canopy gores, repeated left to right. An empty list means
  /// "random classic pair per person".
  final List<Color> panels;

  static const classic = ChuteSkin(
    id: 'classic',
    name: 'Classic Mix',
    price: 0,
    panels: [],
  );

  static const all = [
    classic,
    ChuteSkin(
      id: 'candy',
      name: 'Candy Stripe',
      price: 40,
      panels: [Color(0xFFFF7EB6), Color(0xFFFFFFFF)],
    ),
    ChuteSkin(
      id: 'rainbow',
      name: 'Rainbow',
      price: 90,
      panels: [
        Color(0xFFE8504F),
        Color(0xFFFF9F43),
        Color(0xFFFFD43B),
        Color(0xFF5DBB63),
        Color(0xFF3FA7D6),
        Color(0xFF8E7CC3),
      ],
    ),
    ChuteSkin(
      id: 'camo',
      name: 'Camo',
      price: 60,
      panels: [Color(0xFF5F6E3A), Color(0xFF8C8F5A), Color(0xFF3F4A26)],
    ),
    ChuteSkin(
      id: 'night',
      name: 'Midnight',
      price: 120,
      panels: [Color(0xFF2B2F5E), Color(0xFFFFD43B)],
    ),
  ];

  /// Colour pairs the classic skin chooses from.
  static const classicPairs = [
    [Color(0xFFE8504F), Color(0xFFFFFFFF)],
    [Color(0xFFFF9F43), Color(0xFFFFE3B0)],
    [Color(0xFFFFD43B), Color(0xFFFFF6C8)],
    [Color(0xFF5DBB63), Color(0xFFDDF3DA)],
    [Color(0xFF3FA7D6), Color(0xFFDDF0FA)],
  ];

  static ChuteSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => classic);
}

/// A cosmetic shirt colour for the stick figures.
class ShirtSkin {
  const ShirtSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.color,
  });

  final String id;
  final String name;
  final int price;

  /// Null keeps the classic plain-ink stick figure.
  final Color? color;

  static const plain = ShirtSkin(
    id: 'plain',
    name: 'Ink Stick',
    price: 0,
    color: null,
  );

  static const all = [
    plain,
    ShirtSkin(id: 'red', name: 'Red Tee', price: 25, color: Color(0xFFE8504F)),
    ShirtSkin(
      id: 'blue',
      name: 'Blue Tee',
      price: 25,
      color: Color(0xFF3FA7D6),
    ),
    ShirtSkin(
      id: 'gold',
      name: 'Gold Tee',
      price: 75,
      color: Color(0xFFFFC53D),
    ),
    ShirtSkin(
      id: 'army',
      name: 'Army Tee',
      price: 50,
      color: Color(0xFF5F6E3A),
    ),
  ];

  static ShirtSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => plain);
}

/// The skins equipped for one run.
class SkinSet {
  const SkinSet({this.chute = ChuteSkin.classic, this.shirt = ShirtSkin.plain});

  final ChuteSkin chute;
  final ShirtSkin shirt;
}
