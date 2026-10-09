import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/ballpark_style.dart';
import '../theme/ballpark_themes.dart';
import 'menu_screen.dart';

/// Launch flow: WAJIHA company splash → game splash
/// (logo + name + animated loading line + "Credits: WAJIHA").
class SplashScreen extends StatefulWidget {
  final BallparkAudio audio;
  final HomerunSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the company splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _companyDone = true);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Ballparks.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0D1008),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _companyDone
            ? _GameSplash(key: const ValueKey('game'), theme: theme, loader: _loader)
            : _CompanySplash(key: const ValueKey('company')),
      ),
    );
  }
}

/// Company splash: the official WAJIHA logo, untouched.
class _CompanySplash extends StatelessWidget {
  const _CompanySplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/wajiha_logo.png',
            width: 170,
            height: 170,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 18),
          const Text(
            'WAJIHA',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final BallparkTheme theme;
  final AnimationController loader;
  const _GameSplash(
      {super.key, required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return FieldBackdrop(
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/homerun_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('HOME RUN', style: Ballpark.display(46, theme: theme)),
            const SizedBox(height: 6),
            Text('DERBY', style: Ballpark.label(18, theme: theme)),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [theme.accent, theme.accentDark],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1 ? 'Warming up the bats…' : 'Play ball!',
                      style: Ballpark.body(13,
                          theme: theme,
                          color: theme.text.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Ballpark.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
