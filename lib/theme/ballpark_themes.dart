import 'package:flutter/material.dart';

/// Ballpark theme catalog — 12 real ballpark moods. No neon, no cyberpunk:
/// real grass, dirt, wood and sky.
///
/// Each theme drives the stadium painter: sky gradient (day or night),
/// grass bands, infield dirt, outfield wall, crowd color, and UI accents.
@immutable
class BallparkTheme {
  final String id;
  final String name;
  final bool isPro;

  // Sky
  final Color skyTop;
  final Color skyBottom;
  final bool night;
  // Field
  final Color grassLight;
  final Color grassDark;
  final Color dirt;
  final Color dirtDark;
  final Color wall;
  final Color wallTrim;
  final Color crowd;
  final Color mound;
  // UI accents
  final Color accent; // gold/trim
  final Color accentDark;
  final Color surface; // cards
  final Color text;
  final Color muted;

  const BallparkTheme({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.skyTop,
    required this.skyBottom,
    required this.night,
    required this.grassLight,
    required this.grassDark,
    required this.dirt,
    required this.dirtDark,
    required this.wall,
    required this.wallTrim,
    required this.crowd,
    required this.mound,
    required this.accent,
    required this.accentDark,
    required this.surface,
    required this.text,
    required this.muted,
  });
}

/// Bat styles — 8 wooden bats, rendered by the batter painter.
@immutable
class BatStyleDef {
  final String name;
  final bool isPro;
  final Color wood;
  final Color woodDark;
  final Color handle;

  const BatStyleDef({
    required this.name,
    this.isPro = false,
    required this.wood,
    required this.woodDark,
    required this.handle,
  });
}

/// Ball styles — 8 balls, rendered by the ball painter.
@immutable
class BallStyleDef {
  final String name;
  final bool isPro;
  final Color hide;
  final Color seam;
  final Color shadow;

  const BallStyleDef({
    required this.name,
    this.isPro = false,
    required this.hide,
    required this.seam,
    required this.shadow,
  });
}

class Ballparks {
  static const List<BallparkTheme> all = [
    BallparkTheme(
      id: 'classic_day',
      name: 'Classic Day Game',
      skyTop: Color(0xFF7EC8F7),
      skyBottom: Color(0xFFD8F0FF),
      night: false,
      grassLight: Color(0xFF4C9A4C),
      grassDark: Color(0xFF3B7F3E),
      dirt: Color(0xFFC68B59),
      dirtDark: Color(0xFF9E6B3F),
      wall: Color(0xFF2F5D34),
      wallTrim: Color(0xFFF5E9C9),
      crowd: Color(0xFF8A6B52),
      mound: Color(0xFFB57E4E),
      accent: Color(0xFFC9A227),
      accentDark: Color(0xFF8A6D1A),
      surface: Color(0xFF1E2B1E),
      text: Color(0xFFF7F2E4),
      muted: Color(0xFFB9C4AE),
    ),
    BallparkTheme(
      id: 'sunset',
      name: 'Sunset Slugfest',
      skyTop: Color(0xFF3B3A72),
      skyBottom: Color(0xFFFF9E5E),
      night: false,
      grassLight: Color(0xFF4E8F46),
      grassDark: Color(0xFF3A6F36),
      dirt: Color(0xFFC08452),
      dirtDark: Color(0xFF96643C),
      wall: Color(0xFF37474F),
      wallTrim: Color(0xFFFFD08A),
      crowd: Color(0xFF6E5560),
      mound: Color(0xFFB57E4E),
      accent: Color(0xFFFFB347),
      accentDark: Color(0xFFB97A1F),
      surface: Color(0xFF2A2233),
      text: Color(0xFFFFF3E0),
      muted: Color(0xFFC9B8A8),
    ),
    BallparkTheme(
      id: 'night_game',
      name: 'Friday Night Lights',
      skyTop: Color(0xFF0B1030),
      skyBottom: Color(0xFF24335E),
      night: true,
      grassLight: Color(0xFF3E8543),
      grassDark: Color(0xFF2E6532),
      dirt: Color(0xFFB07B4D),
      dirtDark: Color(0xFF8A5E39),
      wall: Color(0xFF1F3A24),
      wallTrim: Color(0xFFFFE08A),
      crowd: Color(0xFF5A4A63),
      mound: Color(0xFFA06F45),
      accent: Color(0xFFFFD54F),
      accentDark: Color(0xFFB89A00),
      surface: Color(0xFF141A24),
      text: Color(0xFFF5F0DC),
      muted: Color(0xFF9AA3B2),
    ),
    BallparkTheme(
      id: 'vintage',
      name: 'Vintage 1920s',
      skyTop: Color(0xFFD9C9A8),
      skyBottom: Color(0xFFF3E9D2),
      night: false,
      grassLight: Color(0xFF6B9E57),
      grassDark: Color(0xFF567E46),
      dirt: Color(0xFFB98A5E),
      dirtDark: Color(0xFF966B44),
      wall: Color(0xFF5C4A33),
      wallTrim: Color(0xFF2E2620),
      crowd: Color(0xFF7A6A58),
      mound: Color(0xFFA87F55),
      accent: Color(0xFF8C5E2E),
      accentDark: Color(0xFF5E3E1C),
      surface: Color(0xFF2E2620),
      text: Color(0xFFF3E9D2),
      muted: Color(0xFFB3A488),
    ),
    BallparkTheme(
      id: 'coastal',
      name: 'Coastal Breeze',
      skyTop: Color(0xFF4FB6D9),
      skyBottom: Color(0xFFDFF6F7),
      night: false,
      grassLight: Color(0xFF55A05A),
      grassDark: Color(0xFF42844A),
      dirt: Color(0xFFD2A66B),
      dirtDark: Color(0xFFA87F4E),
      wall: Color(0xFF2E6E8E),
      wallTrim: Color(0xFFFFFFFF),
      crowd: Color(0xFF7FA3B0),
      mound: Color(0xFFC08F58),
      accent: Color(0xFF2E9EBA),
      accentDark: Color(0xFF1C6B7E),
      surface: Color(0xFF17303A),
      text: Color(0xFFF2FAFB),
      muted: Color(0xFFA8C6CF),
    ),
    BallparkTheme(
      id: 'autumn',
      name: 'Autumn Classic',
      skyTop: Color(0xFF8FB8D8),
      skyBottom: Color(0xFFF2DFC0),
      night: false,
      grassLight: Color(0xFF7A9448),
      grassDark: Color(0xFF5F7539),
      dirt: Color(0xFFB9834F),
      dirtDark: Color(0xFF8F6439),
      wall: Color(0xFF6E3B2A),
      wallTrim: Color(0xFFF2C14E),
      crowd: Color(0xFF8A6A52),
      mound: Color(0xFFA87B4E),
      accent: Color(0xFFD98E2B),
      accentDark: Color(0xFF9A6116),
      surface: Color(0xFF2E2418),
      text: Color(0xFFFAF0DC),
      muted: Color(0xFFC4B090),
    ),
    BallparkTheme(
      id: 'spring_training',
      name: 'Spring Training',
      skyTop: Color(0xFF9ADCF0),
      skyBottom: Color(0xFFEAFBF3),
      night: false,
      grassLight: Color(0xFF5CB85C),
      grassDark: Color(0xFF479647),
      dirt: Color(0xFFD9B078),
      dirtDark: Color(0xFFAD885A),
      wall: Color(0xFF3E7C43),
      wallTrim: Color(0xFFFFFFFF),
      crowd: Color(0xFF9AB8A0),
      mound: Color(0xFFC79A5F),
      accent: Color(0xFF4CAF50),
      accentDark: Color(0xFF357A38),
      surface: Color(0xFF1C2E1C),
      text: Color(0xFFF4FBF4),
      muted: Color(0xFFAECFAE),
    ),
    BallparkTheme(
      id: 'desert',
      name: 'Desert Diamond',
      skyTop: Color(0xFF5BB8E8),
      skyBottom: Color(0xFFFFE3B3),
      night: false,
      grassLight: Color(0xFF6FA35B),
      grassDark: Color(0xFF587F48),
      dirt: Color(0xFFD9A05E),
      dirtDark: Color(0xFFA9743D),
      wall: Color(0xFF8A5A2E),
      wallTrim: Color(0xFFF7E3B8),
      crowd: Color(0xFFA88A68),
      mound: Color(0xFFC08F58),
      accent: Color(0xFFE0A43C),
      accentDark: Color(0xFFA06F1C),
      surface: Color(0xFF2E2318),
      text: Color(0xFFFAF2DF),
      muted: Color(0xFFC9B48E),
    ),
    BallparkTheme(
      id: 'mountain',
      name: 'Mountain View',
      skyTop: Color(0xFF6FA8DC),
      skyBottom: Color(0xFFE8F3FA),
      night: false,
      grassLight: Color(0xFF4E9A52),
      grassDark: Color(0xFF3C7A41),
      dirt: Color(0xFFB98A5E),
      dirtDark: Color(0xFF916A45),
      wall: Color(0xFF3D5A45),
      wallTrim: Color(0xFFDCE8DC),
      crowd: Color(0xFF7E9A84),
      mound: Color(0xFFB08252),
      accent: Color(0xFF3E7CB1),
      accentDark: Color(0xFF2A567E),
      surface: Color(0xFF1B2620),
      text: Color(0xFFF2F7F2),
      muted: Color(0xFFA9BFAE),
    ),
    BallparkTheme(
      id: 'golden_hour',
      name: 'Golden Hour',
      isPro: true,
      skyTop: Color(0xFF4A3A6E),
      skyBottom: Color(0xFFFFC86B),
      night: false,
      grassLight: Color(0xFF57A05A),
      grassDark: Color(0xFF437C46),
      dirt: Color(0xFFC9985E),
      dirtDark: Color(0xFF9C7440),
      wall: Color(0xFF2E3A55),
      wallTrim: Color(0xFFFFD98A),
      crowd: Color(0xFF7A6A7A),
      mound: Color(0xFFB98A55),
      accent: Color(0xFFFFC53D),
      accentDark: Color(0xFFB88A00),
      surface: Color(0xFF241F33),
      text: Color(0xFFFFF6E0),
      muted: Color(0xFFC9BFA8),
    ),
    BallparkTheme(
      id: 'city_lights',
      name: 'City Lights',
      isPro: true,
      skyTop: Color(0xFF080C1E),
      skyBottom: Color(0xFF2A2A4A),
      night: true,
      grassLight: Color(0xFF3A7A42),
      grassDark: Color(0xFF2B5C32),
      dirt: Color(0xFFA87B4E),
      dirtDark: Color(0xFF7F5D3A),
      wall: Color(0xFF1A2333),
      wallTrim: Color(0xFFFFE08A),
      crowd: Color(0xFF4E5A72),
      mound: Color(0xFF9C7048),
      accent: Color(0xFF7FD4FF),
      accentDark: Color(0xFF3E8FB8),
      surface: Color(0xFF0F1420),
      text: Color(0xFFEAF6FF),
      muted: Color(0xFF93A3B8),
    ),
    BallparkTheme(
      id: 'harvest_moon',
      name: 'Harvest Moon',
      isPro: true,
      skyTop: Color(0xFF1A1030),
      skyBottom: Color(0xFF6E3A4A),
      night: true,
      grassLight: Color(0xFF4A7A3E),
      grassDark: Color(0xFF375E30),
      dirt: Color(0xFFB0824F),
      dirtDark: Color(0xFF84613A),
      wall: Color(0xFF33222E),
      wallTrim: Color(0xFFFFC98A),
      crowd: Color(0xFF6A5570),
      mound: Color(0xFFA2764A),
      accent: Color(0xFFFFB85C),
      accentDark: Color(0xFFB87A2A),
      surface: Color(0xFF1E1522),
      text: Color(0xFFFBEEDD),
      muted: Color(0xFFB8A8A0),
    ),
  ];

  static BallparkTheme byId(String id, {BallparkTheme? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) => all.any((t) => t.id == id && t.isPro);

  static const List<BatStyleDef> bats = [
    BatStyleDef(
        name: 'Classic Ash',
        wood: Color(0xFFD9A85E),
        woodDark: Color(0xFF9C7440),
        handle: Color(0xFF4A3421)),
    BatStyleDef(
        name: 'Maple Slugger',
        wood: Color(0xFFE8C07A),
        woodDark: Color(0xFFB08A4E),
        handle: Color(0xFF3A2A1A)),
    BatStyleDef(
        name: 'Black Beauty',
        wood: Color(0xFF3A3A3A),
        woodDark: Color(0xFF1E1E1E),
        handle: Color(0xFF8A8A8A)),
    BatStyleDef(
        name: 'Cherry Bomb',
        wood: Color(0xFFB04A3A),
        woodDark: Color(0xFF7E3327),
        handle: Color(0xFF2E1E18)),
    BatStyleDef(
        name: 'Blue Steel',
        isPro: true,
        wood: Color(0xFF3E6E9E),
        woodDark: Color(0xFF2A4E72),
        handle: Color(0xFFD8D8D8)),
    BatStyleDef(
        name: 'Green Monster',
        isPro: true,
        wood: Color(0xFF3E7C43),
        woodDark: Color(0xFF2A5730),
        handle: Color(0xFFF5E9C9)),
    BatStyleDef(
        name: 'Gold Pro',
        isPro: true,
        wood: Color(0xFFD9A93C),
        woodDark: Color(0xFF9C7420),
        handle: Color(0xFF3A2E14)),
    BatStyleDef(
        name: 'Candy Stripe',
        isPro: true,
        wood: Color(0xFFE88A8A),
        woodDark: Color(0xFFB85C5C),
        handle: Color(0xFF7E2E2E)),
  ];

  static bool isProBat(int i) => i >= 0 && i < bats.length && bats[i].isPro;

  static const List<BallStyleDef> balls = [
    BallStyleDef(
        name: 'Classic White',
        hide: Color(0xFFFAF6EC),
        seam: Color(0xFFC0392B),
        shadow: Color(0xFFD8D0BC)),
    BallStyleDef(
        name: 'Cream Vintage',
        hide: Color(0xFFF3E9D2),
        seam: Color(0xFF8C2E22),
        shadow: Color(0xFFD9CBA8)),
    BallStyleDef(
        name: 'Night Game',
        hide: Color(0xFFF8F8F8),
        seam: Color(0xFF2E5E8C),
        shadow: Color(0xFFD0D8DC)),
    BallStyleDef(
        name: 'Autumn League',
        hide: Color(0xFFF6EFDD),
        seam: Color(0xFFD97A2B),
        shadow: Color(0xFFD9CDAE)),
    BallStyleDef(
        name: 'Gold Series',
        isPro: true,
        hide: Color(0xFFFFF3D6),
        seam: Color(0xFFC9A227),
        shadow: Color(0xFFE0D0A0)),
    BallStyleDef(
        name: 'Blue Ribbon',
        isPro: true,
        hide: Color(0xFFEAF4FB),
        seam: Color(0xFF2E7CB1),
        shadow: Color(0xFFC4D4E0)),
    BallStyleDef(
        name: 'Fireball',
        isPro: true,
        hide: Color(0xFFFFE8D6),
        seam: Color(0xFFE04A2B),
        shadow: Color(0xFFE0B89A)),
    BallStyleDef(
        name: 'Mint Fresh',
        isPro: true,
        hide: Color(0xFFEAFBF0),
        seam: Color(0xFF2E9E6B),
        shadow: Color(0xFFBFE0CC)),
  ];

  static bool isProBall(int i) => i >= 0 && i < balls.length && balls[i].isPro;
}

/// Custom-theme color slots (persisted as ARGB ints).
const Map<String, int> defaultCustomColors = {
  'skyTop': 0xFF7EC8F7,
  'skyBottom': 0xFFD8F0FF,
  'grassLight': 0xFF4C9A4C,
  'grassDark': 0xFF3B7F3E,
  'dirt': 0xFFC68B59,
  'wall': 0xFF2F5D34,
  'accent': 0xFFC9A227,
  'crowd': 0xFF8A6B52,
};
