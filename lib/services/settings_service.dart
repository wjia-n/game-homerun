import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/homerun_engine.dart';
import '../theme/ballpark_themes.dart';

/// Persisted settings + stats for Home Run Derby. Survives app restarts.
///
/// Stores: audio toggles, player names (2 slots), theme/appearance choices
/// (incl. custom theme colors), mode setup (mode, difficulty, bot skill),
/// Pro unlock state, and lifetime stats.
class HomerunSettings extends ChangeNotifier {
  static const _kMusic = 'homerun_music_on';
  static const _kSfx = 'homerun_sfx_on';
  static const _kVolume = 'homerun_volume';
  static const _kNames = 'homerun_player_names'; // legacy unordered StringSet key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so an
  /// old key would scramble name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'homerun_player_names_json';
  static const _kTheme = 'homerun_theme_id';
  static const _kBat = 'homerun_bat_style';
  static const _kBall = 'homerun_ball_style';
  static const _kMode = 'homerun_mode'; // 0 solo, 1 bot, 2 pvp
  static const _kPitchDiff = 'homerun_pitch_difficulty'; // 0,1,2
  static const _kBotSkill = 'homerun_bot_skill'; // 0,1,2
  static const _kBest = 'homerun_best_score';
  static const _kBestHomers = 'homerun_best_homers';
  static const _kGames = 'homerun_games_played';
  static const _kWins = 'homerun_wins';
  static const _kIsPro = 'homerun_is_pro';
  static const _kCustomPrefix = 'homerun_custom_';

  static const defaultNames = ['Slugger', 'Rookie'];

  /// Encode player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i % defaultNames.length] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [for (int i = 0; i < 2; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'classic_day';
  int batStyle = 0;
  int ballStyle = 0;
  int mode = 0; // 0 solo derby, 1 bot battle, 2 pass-and-play
  int pitchDifficulty = 1; // 0 rookie, 1 pro, 2 all-star (Pro)
  int botSkill = 1;
  int bestScore = 0;
  int bestHomers = 0;
  int gamesPlayed = 0;
  int wins = 0;
  bool isPro = true; // everything unlocked — no Pro version

  /// Custom theme colors (ARGB ints). Defaults mirror Classic Day Game.
  Map<String, int> customColors = Map.of(defaultCustomColors);

  /// Builds the user-designed custom theme from stored colors.
  BallparkTheme get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return BallparkTheme(
      id: 'custom',
      name: 'My Ballpark',
      skyTop: c('skyTop'),
      skyBottom: c('skyBottom'),
      night: false,
      grassLight: c('grassLight'),
      grassDark: c('grassDark'),
      dirt: c('dirt'),
      dirtDark: c('dirt'),
      wall: c('wall'),
      wallTrim: c('accent'),
      crowd: c('crowd'),
      mound: c('dirt'),
      accent: c('accent'),
      accentDark: c('accent'),
      surface: const Color(0xFF1E2B1E),
      text: const Color(0xFFF7F2E4),
      muted: const Color(0xFFB9C4AE),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Player names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == 2)
          ? [for (int i = 0; i < 2; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'classic_day';
    batStyle = (p.getInt(_kBat) ?? 0).clamp(0, Ballparks.bats.length - 1);
    ballStyle = (p.getInt(_kBall) ?? 0).clamp(0, Ballparks.balls.length - 1);
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 2);
    pitchDifficulty = (p.getInt(_kPitchDiff) ?? 1).clamp(0, 2);
    botSkill = (p.getInt(_kBotSkill) ?? 1).clamp(0, 2);
    bestScore = p.getInt(_kBest) ?? 0;
    bestHomers = p.getInt(_kBestHomers) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    wins = p.getInt(_kWins) ?? 0;
    isPro = true; // everything unlocked
    for (final k in defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kBat, batStyle);
    await p.setInt(_kBall, ballStyle);
    await p.setInt(_kMode, mode);
    await p.setInt(_kPitchDiff, pitchDifficulty);
    await p.setInt(_kBotSkill, botSkill);
    await p.setInt(_kBest, bestScore);
    await p.setInt(_kBestHomers, bestHomers);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kWins, wins);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || Ballparks.isProTheme(themeId)) {
      themeId = 'classic_day';
      changed = true;
    }
    if (Ballparks.isProBat(batStyle)) {
      batStyle = 0;
      changed = true;
    }
    if (Ballparks.isProBall(ballStyle)) {
      ballStyle = 0;
      changed = true;
    }
    // All-Star pitch difficulty is a Pro feature.
    if (pitchDifficulty > 1) {
      pitchDifficulty = 1;
      changed = true;
    }
    if (botSkill > 1) {
      botSkill = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom ballpark creator is a Pro feature
    if (!defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 2);
    notifyListeners();
    await _save();
  }

  Future<void> setPitchDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return; // All-Star is Pro
    pitchDifficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setBotSkill(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return;
    botSkill = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    final clean = name.trim();
    playerNames[index] =
        clean.isEmpty ? defaultNames[index % defaultNames.length] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || Ballparks.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBatStyle(int v) async {
    v = v.clamp(0, Ballparks.bats.length - 1);
    if (!isPro && Ballparks.isProBat(v)) return;
    batStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setBallStyle(int v) async {
    v = v.clamp(0, Ballparks.balls.length - 1);
    if (!isPro && Ballparks.isProBall(v)) return;
    ballStyle = v;
    notifyListeners();
    await _save();
  }

  PitchDifficulty get pitchDifficultyEnum =>
      PitchDifficulty.values[pitchDifficulty.clamp(0, 2)];
  BotSkill get botSkillEnum => BotSkill.values[botSkill.clamp(0, 2)];

  /// Record a finished game. [humanWon] true if a human won the derby.
  Future<void> recordGame(
      {required bool humanWon,
      required int bestHumanScore,
      required int humanHomers}) async {
    gamesPlayed++;
    if (humanWon) wins++;
    if (bestHumanScore > bestScore) bestScore = bestHumanScore;
    if (humanHomers > bestHomers) bestHomers = humanHomers;
    notifyListeners();
    await _save();
  }
}
