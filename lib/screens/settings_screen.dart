import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/ballpark_style.dart';
import '../theme/ballpark_themes.dart';

/// Audio controls + lifetime stats.
class SettingsScreen extends StatefulWidget {
  final BallparkAudio audio;
  final HomerunSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BallparkTheme get _t => Ballparks.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  void _applyAudio() {
    widget.audio.configure(
      musicOn: widget.settings.musicOn,
      sfxOn: widget.settings.sfxOn,
      volume: widget.settings.volume,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return FieldBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Ballpark.display(22, theme: t)),
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => ListView(
            padding: const EdgeInsets.all(22),
            children: [
              _section(t, '🔊 AUDIO', [
                SwitchListTile(
                  title: Text('Music', style: Ballpark.body(16, theme: t)),
                  value: s.musicOn,
                  activeThumbColor: t.accent,
                  onChanged: (v) async {
                    await s.setMusic(v);
                    _applyAudio();
                    if (v) {
                      widget.audio.startMenuMusic();
                    }
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  title:
                      Text('Sound effects', style: Ballpark.body(16, theme: t)),
                  value: s.sfxOn,
                  activeThumbColor: t.accent,
                  onChanged: (v) async {
                    await s.setSfx(v);
                    _applyAudio();
                    widget.audio.click();
                    setState(() {});
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('Volume',
                          style: Ballpark.body(16, theme: t)),
                      Expanded(
                        child: Slider(
                          value: s.volume,
                          activeColor: t.accent,
                          onChanged: (v) {
                            s.setVolume(v);
                            _applyAudio();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              _section(t, '📊 CAREER', [
                _stat(t, 'Games played', '${s.gamesPlayed}'),
                _stat(t, 'Derbies won', '${s.wins}'),
                _stat(t, 'Best score', '${s.bestScore}'),
                _stat(t, 'Most HR in a derby', '${s.bestHomers}'),
              ]),
              const SizedBox(height: 14),
              Text('Credits: WAJIHA',
                  textAlign: TextAlign.center,
                  style: Ballpark.label(13, theme: t)),
              const SizedBox(height: 4),
              Text('Made with ⚾ in Karachi',
                  textAlign: TextAlign.center,
                  style: Ballpark.body(13, theme: t, color: t.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BallparkTheme t, String title, List<Widget> kids) {
    return Container(
      decoration: Ballpark.card(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: Ballpark.label(13, theme: t)),
          ),
          ...kids,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _stat(BallparkTheme t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Ballpark.body(15, theme: t)),
          Text(value, style: Ballpark.heading(16, theme: t)),
        ],
      ),
    );
  }
}
