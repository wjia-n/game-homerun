import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/homerun_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/ballpark_style.dart';
import '../theme/ballpark_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.homerun';

/// Main menu: mode cards, difficulty, renameable players, and navigation.
class MenuScreen extends StatefulWidget {
  final BallparkAudio audio;
  final HomerunSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _store = StoreService();
  final _name1 = TextEditingController();
  final _name2 = TextEditingController();
  final _focus1 = FocusNode();
  final _focus2 = FocusNode();

  BallparkTheme get _t => Ballparks.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _name1.text = widget.settings.playerNames[0];
    _name2.text = widget.settings.playerNames[1];
    // Commit on focus loss too: the name saves on every keystroke AND when
    // the field loses focus (belt and suspenders; never names-on-done-only).
    _focus1.addListener(() {
      if (!_focus1.hasFocus) widget.settings.setPlayerName(0, _name1.text);
    });
    _focus2.addListener(() {
      if (!_focus2.hasFocus) widget.settings.setPlayerName(1, _name2.text);
    });
    widget.audio.startMenuMusic();
    _store.init();
  }

  @override
  void dispose() {
    _name1.dispose();
    _name2.dispose();
    _focus1.dispose();
    _focus2.dispose();
    _store.dispose();
    super.dispose();
  }

  void _play() {
    widget.audio.gameStart();
    final s = widget.settings;
    final players = switch (s.mode) {
      0 => [DerbyPlayer(name: s.playerNames[0], isBot: false)],
      1 => [
          DerbyPlayer(name: s.playerNames[0], isBot: false),
          // The bot takes the second (renameable, persisted) name slot.
          DerbyPlayer(name: s.playerNames[1], isBot: true),
        ],
      _ => [
          DerbyPlayer(name: s.playerNames[0], isBot: false),
          DerbyPlayer(name: s.playerNames[1], isBot: false),
        ],
    };
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: s,
          players: players,
          store: _store,
        ),
      ),
    );
  }

  void _share() {
    widget.audio.click();
    SharePlus.instance.share(ShareParams(
      text: 'I just played Home Run Derby! ⚾ Can you out-slug me? $_storeUrl',
      subject: 'Home Run Derby',
    ));
  }

  Future<void> _go(Widget page) async {
    widget.audio.click();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return FieldBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  _header(t),
                  const SizedBox(height: 18),
                  _modeCards(t, s),
                  const SizedBox(height: 14),
                  _difficultyRow(t, s),
                  const SizedBox(height: 14),
                  _nameFields(t, s),
                  const SizedBox(height: 18),
                  SluggerButton(
                    label: 'PLAY BALL',
                    emoji: '⚾',
                    theme: t,
                    primary: true,
                    onTap: _play,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _miniBtn(t, '🏟️ Ballparks', () => _go(CustomThemeScreen(
                          audio: widget.audio, settings: s, store: _store))),
                      _miniBtn(t, '🏏 Bats & Balls', () => _go(BatsBallsScreen(
                          audio: widget.audio, settings: s, store: _store))),
                      _miniBtn(t, '⚙️ Settings', () => _go(SettingsScreen(
                          audio: widget.audio, settings: s))),
                      _miniBtn(t, '⭐ PRO', () => _go(ProScreen(
                          audio: widget.audio,
                          settings: s,
                          store: _store))),
                      _miniBtn(t, '📖 Rules', () => _go(RulesScreen(theme: t))),
                      _miniBtn(t, '📣 Share', _share),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _statsLine(t, s),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BallparkTheme t) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.accent, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54,
                  offset: Offset(0, 6),
                  blurRadius: 16),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/homerun_logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(height: 10),
        Text('HOME RUN', style: Ballpark.display(38, theme: t)),
        Text('D E R B Y', style: Ballpark.label(15, theme: t)),
        if (widget.settings.isPro)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('⭐ PRO',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: Color(0xFF241A08))),
          ),
      ],
    );
  }

  Widget _modeCards(BallparkTheme t, HomerunSettings s) {
    final modes = [
      ('Solo Derby', '⚾', '10 pitches. Beat your best.'),
      ('Bot Battle', '🤖', 'Out-slug the bot.'),
      ('2-Player', '👥', 'Pass-and-play showdown.'),
    ];
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Expanded(
            child: GestureDetector(
              onTap: () {
                widget.audio.click();
                s.setMode(i);
              },
              child: Container(
                margin: EdgeInsets.only(
                    left: i == 0 ? 0 : 5, right: i == 2 ? 0 : 5),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 12),
                decoration: BoxDecoration(
                  color: s.mode == i
                      ? t.accent.withValues(alpha: 0.25)
                      : t.surface,
                  borderRadius: Ballpark.radius,
                  border: Border.all(
                    color: s.mode == i ? t.accent : t.accent.withValues(alpha: 0.3),
                    width: s.mode == i ? 3 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(modes[i].$2, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(modes[i].$1,
                        textAlign: TextAlign.center,
                        style: Ballpark.body(13, theme: t)),
                    Text(modes[i].$3,
                        textAlign: TextAlign.center,
                        style: Ballpark.body(10,
                            theme: t, color: t.muted)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _difficultyRow(BallparkTheme t, HomerunSettings s) {
    final diffs = ['Rookie', 'Pro', 'All-Star'];
    final botDiffs = ['Rookie Bot', 'Pro Bot', 'All-Star Bot'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: Ballpark.card(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PITCH DIFFICULTY', style: Ballpark.label(12, theme: t)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < 3; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      s.setPitchDifficulty(i);
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                          left: i == 0 ? 0 : 4, right: i == 2 ? 0 : 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: s.pitchDifficulty == i
                            ? t.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: t.accent.withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: Text(
                          '${diffs[i]}${i == 2 && !s.isPro ? ' 🔒' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: s.pitchDifficulty == i
                                ? const Color(0xFF241A08)
                                : t.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (s.mode == 1) ...[
            const SizedBox(height: 10),
            Text('BOT SKILL', style: Ballpark.label(12, theme: t)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int i = 0; i < 3; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        s.setBotSkill(i);
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                            left: i == 0 ? 0 : 4, right: i == 2 ? 0 : 4),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: s.botSkill == i
                              ? t.accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: t.accent.withValues(alpha: 0.5)),
                        ),
                        child: Center(
                          child: Text(
                            '${botDiffs[i]}${i == 2 && !s.isPro ? ' 🔒' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: s.botSkill == i
                                  ? const Color(0xFF241A08)
                                  : t.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _nameFields(BallparkTheme t, HomerunSettings s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: Ballpark.card(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BATTERS', style: Ballpark.label(12, theme: t)),
          const SizedBox(height: 8),
          _nameField(t, _name1, _focus1, 'Player 1 name', 0, s),
          if (s.mode == 1) ...[
            const SizedBox(height: 8),
            _nameField(t, _name2, _focus2, 'Bot name', 1, s),
          ],
          if (s.mode == 2) ...[
            const SizedBox(height: 8),
            _nameField(t, _name2, _focus2, 'Player 2 name', 1, s),
          ],
        ],
      ),
    );
  }

  Widget _nameField(BallparkTheme t, TextEditingController c, FocusNode focus,
      String hint, int index, HomerunSettings s) {
    return TextField(
      controller: c,
      focusNode: focus,
      style: Ballpark.body(16, theme: t),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Ballpark.body(15, theme: t, color: t.muted),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.accent.withValues(alpha: 0.5)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      maxLength: 14,
      onChanged: (v) => s.setPlayerName(index, v),
    );
  }

  Widget _miniBtn(BallparkTheme t, String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.accent.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _statsLine(BallparkTheme t, HomerunSettings s) {
    return Text(
      '🏆 Best ${s.bestScore}   •   💥 ${s.bestHomers} HR best   •   🎮 ${s.gamesPlayed} games',
      textAlign: TextAlign.center,
      style: Ballpark.body(13, theme: t, color: t.muted),
    );
  }
}

/// Rules screen (summary of RULES.md).
class RulesScreen extends StatelessWidget {
  final BallparkTheme theme;
  const RulesScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    const rules = [
      '🎯 Objective',
      'Out-slug your opponent. 10 pitches per batter — most runs wins.',
      '⚾ The Pitch',
      'Tap PLAY BALL. The pitcher deals fastballs, curveballs, changeups and sinkers. Pitch speed and break scale with difficulty.',
      '🏏 The Swing',
      'Tap (or swipe up) as the ball crosses the plate. Timing is everything:\n• Perfect → towering HOME RUN (395–460 ft)\n• Great → 45% chance it leaves the yard\n• Early/late → foul tip\n• Way off → whiff. No swing → called strike.',
      '🔥 Streaks',
      'Back-to-back homers build a streak multiplier: ×1, ×1.5, ×2… Any non-homer resets it.',
      '🏆 Scoring',
      'Home run: 500 × streak + distance. Off the wall: 150. Foul: 40. Strike: 0.',
      '👥 Modes',
      'Solo Derby (beat your best), Bot Battle (vs the renameable bot), 2-Player pass-and-play.',
    ];
    return FieldBackdrop(
      theme: theme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('How to Play')),
        body: ListView.builder(
          padding: const EdgeInsets.all(22),
          itemCount: rules.length,
          itemBuilder: (_, i) => i.isEven
              ? Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Text(rules[i],
                      style: Ballpark.heading(17, theme: theme)),
                )
              : Text(rules[i],
                  style: Ballpark.body(15, theme: theme)),
        ),
      ),
    );
  }
}
