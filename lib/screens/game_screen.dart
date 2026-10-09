import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/homerun_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/ballpark_style.dart';
import '../theme/ballpark_themes.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.homerun';

/// The derby itself: stadium view, swing input, HUD, pause, game-over.
class GameScreen extends StatefulWidget {
  final BallparkAudio audio;
  final HomerunSettings settings;
  final List<DerbyPlayer> players;
  final StoreService store;
  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.players,
    required this.store,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late HomerunEngine _engine;
  Ticker? _ticker; // drives per-frame repaints; engine owns all state
  DateTime? _swingAnimAt; // last human/bot swing moment (bat swing arc)
  bool _pausedUi = false;
  bool _overHandled = false;
  int _gamesSinceReview = 0;

  BallparkTheme get _t => Ballparks.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _newEngine();
    widget.audio.startGameMusic();
    _ticker = Ticker((_) {
      if (mounted) setState(() {});
    })
      ..start();
  }

  void _newEngine() {
    _engine = HomerunEngine(
      players: widget.players
          .map((p) => DerbyPlayer(name: p.name, isBot: p.isBot))
          .toList(),
      pitchDifficulty: widget.settings.pitchDifficultyEnum,
      botSkill: widget.settings.botSkillEnum,
    );
    _engine.onEvent = _onEvent;
    _engine.addListener(_onEngineChanged);
    _overHandled = false;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    widget.audio.startMenuMusic();
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    if (_engine.isOver && !_overHandled) {
      _overHandled = true;
      _handleGameOver();
    }
    setState(() {});
  }

  void _onEvent(HomerunEvent e) {
    final a = widget.audio;
    switch (e) {
      case HomerunEvent.pitchReleased:
        a.pitchWhoosh();
      case HomerunEvent.swung:
        _swingAnimAt = DateTime.now();
      case HomerunEvent.batCrack:
        a.batCrack();
      case HomerunEvent.homer:
        a.batCrack();
        a.crowdRoar();
        a.homerJingle();
      case HomerunEvent.foul:
        a.foulTick();
        a.crowdGasp();
      case HomerunEvent.whiff:
        a.whiff();
      case HomerunEvent.strikeCalled:
        a.strikeCall();
        a.crowdGasp();
      case HomerunEvent.streakLost:
        break;
      case HomerunEvent.turnChanged:
        a.gameStart();
      case HomerunEvent.gameOver:
        break;
    }
  }

  void _swing() {
    if (_engine.phase != Phase.flying || _pausedUi) return;
    _engine.swing();
  }

  void _togglePause() {
    if (_engine.isOver) return;
    widget.audio.click();
    setState(() => _pausedUi = !_pausedUi);
    _engine.setPaused(_pausedUi);
  }

  void _restart() {
    widget.audio.click();
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    setState(() {
      _pausedUi = false;
      _newEngine();
    });
    widget.audio.startGameMusic();
  }

  void _quit() {
    widget.audio.click();
    Navigator.of(context).pop();
  }

  Future<void> _handleGameOver() async {
    final s = widget.settings;
    final w = _engine.winnerIndex;
    final humanWon = w != null && !_engine.players[w].isBot;
    final humans = _engine.players.where((p) => !p.isBot).toList();
    final bestHumanScore =
        humans.map((p) => p.score).fold(0, max);
    final humanHomers = humans.map((p) => p.homers).fold(0, (a, b) => a + b);
    await s.recordGame(
      humanWon: humanWon,
      bestHumanScore: bestHumanScore,
      humanHomers: humanHomers,
    );
    if (!mounted) return;
    if (humanWon) {
      widget.audio.win();
    } else {
      widget.audio.lose();
    }
    // Ask for a review at a sensible moment: human wins, every few games.
    _gamesSinceReview++;
    if (humanWon && _gamesSinceReview % 3 == 1) {
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {
        // Not from Play / unavailable — stay silent, never crash.
      }
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        engine: _engine,
        theme: _t,
        onReplay: () {
          Navigator.of(context).pop();
          _restart();
        },
        onMenu: () {
          Navigator.of(context).pop();
          _quit();
        },
        onShare: () {
          widget.audio.click();
          SharePlus.instance.share(ShareParams(
            text:
                'I scored $bestHumanScore in Home Run Derby! ⚾ Think you can beat me? $_storeUrl',
            subject: 'Home Run Derby score',
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final e = _engine;
    return FieldBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _quit,
          ),
          title: Text(
            e.players.length > 1
                ? '${e.players[0].name} vs ${e.players[1].name}'
                : 'Home Run Derby',
            style: Ballpark.heading(18, theme: t),
          ),
          actions: [
            IconButton(
              icon: Icon(_pausedUi ? Icons.play_arrow : Icons.pause),
              onPressed: _togglePause,
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _hud(t, e),
                  const SizedBox(height: 6),
                  Expanded(
                    child: GestureDetector(
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) < -200) _swing();
                      },
                      onTap: () {
                        if (e.phase == Phase.idle) {
                          e.startPitch();
                        } else {
                          _swing();
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: Ballpark.radius,
                          border: Border.all(
                              color: t.accent.withValues(alpha: 0.5),
                              width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CustomPaint(
                          painter: _StadiumPainter(
                            theme: t,
                            engine: e,
                            bat: Ballparks.bats[widget.settings.batStyle
                                .clamp(0, Ballparks.bats.length - 1)],
                            ball: Ballparks.balls[widget.settings.ballStyle
                                .clamp(0, Ballparks.balls.length - 1)],
                            swingAnimAt: _swingAnimAt,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _bottomBar(t, e),
                  const SizedBox(height: 10),
                ],
              ),
              if (e.phase == Phase.hit || e.phase == Phase.result)
                _resultBanner(t, e),
              if (_pausedUi) _pauseOverlay(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud(BallparkTheme t, HomerunEngine e) {
    final p = e.current;
    final inPitch = e.phase == Phase.windup ||
        e.phase == Phase.flying ||
        e.phase == Phase.hit ||
        e.phase == Phase.result;
    final pitchNum = (p.pitches + (inPitch ? 1 : 0)).clamp(0, pitchesPerTurn);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: Ballpark.card(t),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _cell(t, p.name, '${p.score}'),
          _cell(t, 'Pitch', '$pitchNum/$pitchesPerTurn'),
          _cell(t, 'HR', '${p.homers}'),
          _cell(t, 'Streak', p.streak > 1 ? '🔥 ${p.streak}' : '${p.streak}'),
          _cell(t, 'Best', '${widget.settings.bestScore}'),
        ],
      ),
    );
  }

  Widget _cell(BallparkTheme t, String label, String value) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: t.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          Text(value,
              style: TextStyle(
                  color: t.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
        ],
      );

  Widget _bottomBar(BallparkTheme t, HomerunEngine e) {
    if (e.phase == Phase.idle &&
        !e.current.isBot &&
        e.current.pitches < pitchesPerTurn) {
      return SluggerButton(
        label: e.current.pitches == 0 ? 'PLAY BALL' : 'PITCH',
        emoji: '⚾',
        theme: t,
        primary: true,
        onTap: e.startPitch,
      );
    }
    if (e.phase == Phase.flying && !e.current.isBot) {
      return SluggerButton(
        label: 'SWING!',
        emoji: '🏏',
        theme: t,
        primary: true,
        onTap: _swing,
      );
    }
    return SizedBox(
      height: 52,
      child: Center(
        child: Text(
          e.banner,
          textAlign: TextAlign.center,
          style: Ballpark.body(14, theme: t, color: t.muted),
        ),
      ),
    );
  }

  Widget _resultBanner(BallparkTheme t, HomerunEngine e) {
    final r = e.lastResult;
    if (r == null) return const SizedBox.shrink();
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${e.turn}-${e.current.pitches}-${r.title}'),
        tween: Tween(begin: 0.5, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.elasticOut,
        builder: (_, v, _) => Transform.scale(
          scale: v,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: r.homer ? t.accent : Colors.white30, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.title,
                    style: TextStyle(
                        fontSize: r.homer ? 34 : 28,
                        fontWeight: FontWeight.w900,
                        color: r.homer ? t.accent : Colors.white)),
                const SizedBox(height: 4),
                Text(
                  r.gained > 0 ? '+${r.gained}  •  ${r.sub}' : r.sub,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay(BallparkTheme t) {
    return Container(
      color: Colors.black72,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: Ballpark.card(t),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Ballpark.display(30, theme: t)),
              const SizedBox(height: 18),
              SluggerButton(
                  label: 'RESUME',
                  emoji: '▶️',
                  theme: t,
                  primary: true,
                  onTap: _togglePause),
              const SizedBox(height: 10),
              SluggerButton(
                  label: 'RESTART',
                  emoji: '🔄',
                  theme: t,
                  onTap: _restart),
              const SizedBox(height: 10),
              SluggerButton(
                  label: 'QUIT', emoji: '🚪', theme: t, onTap: _quit),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scoreboard dialog at the end of the derby.
class _GameOverDialog extends StatelessWidget {
  final HomerunEngine engine;
  final BallparkTheme theme;
  final VoidCallback onReplay;
  final VoidCallback onMenu;
  final VoidCallback onShare;
  const _GameOverDialog({
    required this.engine,
    required this.theme,
    required this.onReplay,
    required this.onMenu,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final w = engine.winnerIndex;
    final rows = engine.players.asMap().entries.map((en) {
      final p = en.value;
      final isW = en.key == w;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isW
              ? t.accent.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isW ? t.accent : Colors.white12, width: isW ? 2 : 1),
        ),
        child: Row(
          children: [
            Text(isW ? '🏆' : '⚾',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(p.name,
                    style: Ballpark.body(16, theme: t))),
            Text('${p.homers} HR',
                style: Ballpark.body(13, theme: t, color: t.muted)),
            const SizedBox(width: 10),
            Text('${p.score}',
                style: Ballpark.heading(18, theme: t)),
          ],
        ),
      );
    }).toList();
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: t.accent, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DERBY OVER!', style: Ballpark.display(30, theme: t)),
            const SizedBox(height: 4),
            Text(engine.banner,
                textAlign: TextAlign.center,
                style: Ballpark.body(15, theme: t, color: t.muted)),
            const SizedBox(height: 16),
            ...rows,
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SluggerButton(
                      label: 'AGAIN',
                      emoji: '🔄',
                      theme: t,
                      primary: true,
                      onTap: onReplay),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SluggerButton(
                      label: 'MENU',
                      emoji: '🏠',
                      theme: t,
                      onTap: onMenu),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share),
              label: const Text('Share my score'),
              style: TextButton.styleFrom(foregroundColor: t.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stadium painter: a real ballpark — sky, crowd, wall, grass, dirt — with
// the pitch in flight, the batter's swing, and the batted-ball flight.
// Pseudo-3D: the ball grows as it approaches, with shadows and depth.
// ---------------------------------------------------------------------------
class _StadiumPainter extends CustomPainter {
  final BallparkTheme theme;
  final HomerunEngine engine;
  final BatStyleDef bat;
  final BallStyleDef ball;
  final DateTime? swingAnimAt;

  _StadiumPainter({
    required this.theme,
    required this.engine,
    required this.bat,
    required this.ball,
    required this.swingAnimAt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _paintSky(canvas, w, h);
    _paintCrowd(canvas, w, h);
    _paintWall(canvas, w, h);
    _paintGrass(canvas, w, h);
    _paintDirt(canvas, w, h);
    _paintMoundAndPitcher(canvas, w, h);
    _paintBatter(canvas, w, h);
    _paintBall(canvas, w, h);
    if (engine.phase == Phase.flying) _paintStrikeZone(canvas, w, h);
  }

  void _paintSky(Canvas canvas, double w, double h) {
    final skyH = h * 0.34;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.skyTop, theme.skyBottom],
      ).createShader(Rect.fromLTWH(0, 0, w, skyH));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, skyH), paint);
    if (theme.night) {
      // Stars.
      final star = Paint()..color = Colors.white70;
      for (int i = 0; i < 40; i++) {
        final x = ((i * 733) % 1000) / 1000 * w;
        final y = ((i * 389) % 1000) / 1000 * skyH * 0.7;
        canvas.drawCircle(Offset(x, y), 1.2, star);
      }
      // Moon.
      canvas.drawCircle(Offset(w * 0.85, skyH * 0.28), 22,
          Paint()..color = const Color(0xFFF5F0DC));
      canvas.drawCircle(Offset(w * 0.85 - 7, skyH * 0.28 - 4), 18,
          Paint()..color = theme.skyTop);
      // Light towers.
      for (final fx in [0.08, 0.92]) {
        final x = w * fx;
        canvas.drawRect(Rect.fromLTWH(x - 3, 8, 6, skyH * 0.5),
            Paint()..color = const Color(0xFF2A2A2A));
        final glow = Paint()
          ..color = Colors.white.withValues(alpha: 0.18);
        canvas.drawCircle(Offset(x, 14), 34, glow);
        final head = Paint()..color = const Color(0xFFFFF2C0);
        for (int i = -1; i <= 1; i++) {
          canvas.drawCircle(Offset(x + i * 9.0, 12), 4.5, head);
        }
      }
    } else {
      // Day-game clouds.
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.75);
      for (final c in [(0.2, 0.10, 34), (0.62, 0.18, 26), (0.85, 0.07, 20)]) {
        final cx = w * c.$1, cy = skyH * c.$2, r = c.$3;
        canvas.drawCircle(Offset(cx, cy), r, cloud);
        canvas.drawCircle(Offset(cx + r, cy + 4), r * 0.7, cloud);
        canvas.drawCircle(Offset(cx - r, cy + 5), r * 0.65, cloud);
      }
    }
  }

  void _paintCrowd(Canvas canvas, double w, double h) {
    final top = h * 0.30, bottom = h * 0.40;
    canvas.drawRect(Rect.fromLTWH(0, top, w, bottom - top),
        Paint()..color = theme.crowd.withValues(alpha: 0.85));
    // Rows of heads — deterministic so they don't shimmer between frames.
    final head = Paint()..color = theme.crowd;
    final headDark = Paint()
      ..color = Color.lerp(theme.crowd, Colors.black, 0.35)!;
    var i = 0;
    for (double y = top + 6; y < bottom - 2; y += 11) {
      for (double x = 6; x < w - 6; x += 12) {
        final pick = ((i * 2654435761) % 100) / 100;
        canvas.drawCircle(
            Offset(x + (pick - 0.5) * 6, y), 3.4, pick > 0.5 ? head : headDark);
        i++;
      }
    }
    // Aisle stairs.
    final stair = Paint()..color = Colors.black26;
    for (final fx in [0.25, 0.5, 0.75]) {
      canvas.drawRect(
          Rect.fromLTWH(w * fx - 4, top, 8, bottom - top), stair);
    }
  }

  void _paintWall(Canvas canvas, double w, double h) {
    final top = h * 0.40, bottom = h * 0.455;
    canvas.drawRect(Rect.fromLTWH(0, top, w, bottom - top),
        Paint()..color = theme.wall);
    canvas.drawRect(Rect.fromLTWH(0, top, w, 4),
        Paint()..color = theme.wallTrim);
    // Distance markers.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final m in [(0.18, '375'), (0.5, '410'), (0.82, '375')]) {
      tp.text = TextSpan(
          text: '${m.$2} FT',
          style: TextStyle(
              color: theme.wallTrim.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w800));
      tp.layout();
      tp.paint(canvas, Offset(w * m.$1 - tp.width / 2, top + 8));
    }
    // Wall padding segments.
    final seg = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (double x = 0; x < w; x += w / 12) {
      canvas.drawLine(Offset(x, top + 4), Offset(x, bottom), seg);
    }
  }

  void _paintGrass(Canvas canvas, double w, double h) {
    final top = h * 0.455;
    // Mowing bands.
    const bands = 6;
    for (int i = 0; i < bands; i++) {
      final y0 = top + (h - top) * i / bands;
      final y1 = top + (h - top) * (i + 1) / bands;
      canvas.drawRect(
          Rect.fromLTWH(0, y0, w, y1 - y0),
          Paint()
            ..color = i.isEven ? theme.grassLight : theme.grassDark);
    }
    // Subtle vignette for depth.
    canvas.drawRect(
        Rect.fromLTWH(0, top, w, h - top),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.25)],
          ).createShader(Rect.fromLTWH(0, top, w, h - top)));
  }

  void _paintDirt(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    // Infield dirt: home area at bottom.
    final homeY = h * 0.92;
    final dirt = Paint()..color = theme.dirt;
    final dirtPath = Path()
      ..moveTo(cx - w * 0.30, h)
      ..quadraticBezierTo(cx - w * 0.22, homeY - h * 0.10, cx, homeY - h * 0.10)
      ..quadraticBezierTo(cx + w * 0.22, homeY - h * 0.10, cx + w * 0.30, h)
      ..close();
    canvas.drawPath(dirtPath, dirt);
    // Batter's boxes.
    final box = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx - 26, homeY - 18), width: 22, height: 30),
        box);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx + 26, homeY - 18), width: 22, height: 30),
        box);
    // Home plate.
    final plate = Paint()..color = Colors.white;
    final pp = Path()
      ..moveTo(cx - 9, homeY - 6)
      ..lineTo(cx + 9, homeY - 6)
      ..lineTo(cx + 9, homeY + 2)
      ..lineTo(cx, homeY + 9)
      ..lineTo(cx - 9, homeY + 2)
      ..close();
    canvas.drawPath(pp, plate);
    // Foul lines to the corners.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx, homeY), Offset(w * 0.06, h * 0.50), line);
    canvas.drawLine(Offset(cx, homeY), Offset(w * 0.94, h * 0.50), line);
  }

  void _paintMoundAndPitcher(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final moundY = h * 0.56;
    // Mound.
    canvas.drawEllipse(
        Rect.fromCenter(center: Offset(cx, moundY), width: 74, height: 26),
        Paint()..color = theme.mound);
    canvas.drawEllipse(
        Rect.fromCenter(
            center: Offset(cx, moundY - 3), width: 56, height: 18),
        Paint()..color = Color.lerp(theme.mound, Colors.white, 0.12)!);
    // Pitcher: simple uniformed figure. During windup his arm rises.
    final windup = engine.phase == Phase.windup
        ? 0.5 + 0.5 * sin(DateTime.now().millisecond / 90)
        : 0.0;
    final px = cx, py = moundY - 34;
    final uniform = Paint()..color = Colors.white;
    final skin = Paint()..color = const Color(0xFFE8B88A);
    // Legs.
    final legP = Paint()
      ..color = const Color(0xFF6E6E6E)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(px - 6, py + 22), Offset(px - 8, py + 38), legP);
    canvas.drawLine(Offset(px + 6, py + 22), Offset(px + 8, py + 38), legP);
    // Body.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(px, py + 10), width: 20, height: 30),
            const Radius.circular(8)),
        uniform);
    // Head + cap.
    canvas.drawCircle(Offset(px, py - 10), 9, skin);
    canvas.drawArc(Rect.fromCircle(center: Offset(px, py - 12), radius: 9),
        pi, 2 * pi, true, Paint()..color = theme.accentDark);
    // Throwing arm: rises during windup, snaps down at release.
    final armAngle = -0.5 - windup * 1.6;
    final ax = px + 10, ay = py + 4;
    canvas.drawLine(
        Offset(ax, ay),
        Offset(ax + cos(armAngle) * 22, ay + sin(armAngle) * 22),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
    // Ball in hand during windup.
    if (engine.phase == Phase.windup) {
      _drawBall(
          canvas,
          Offset(ax + cos(armAngle) * 26, ay + sin(armAngle) * 26),
          7);
    }
  }

  void _paintBatter(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final homeY = h * 0.92;
    final bx = cx - 44; // lefty box
    final by = homeY - 22;
    final uniform = Paint()..color = const Color(0xFF3E5E8C);
    final skin = Paint()..color = const Color(0xFFE8B88A);
    // Swing animation: 0 = rest, 1 = follow-through.
    double swingT = 0;
    if (swingAnimAt != null) {
      final e = DateTime.now().difference(swingAnimAt!).inMilliseconds;
      if (e < 320) swingT = e / 320;
    }
    final ease = swingT == 0
        ? 0.0
        : (swingT < 0.5
            ? 2 * swingT * swingT
            : 1 - pow(-2 * swingT + 2, 2) / 2);
    // Legs.
    final legP = Paint()
      ..color = const Color(0xFF2E2E2E)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(bx - 7, by + 24), Offset(bx - 9, by + 44), legP);
    canvas.drawLine(Offset(bx + 7, by + 24), Offset(bx + 9, by + 44), legP);
    // Body (slight coil when idle, unwinds in swing).
    canvas.save();
    canvas.translate(bx, by + 10);
    canvas.rotate(-0.12 + ease * 0.35);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-11, -18, 22, 38),
            const Radius.circular(9)),
        uniform);
    canvas.restore();
    // Head + helmet.
    canvas.drawCircle(Offset(bx, by - 16), 10, skin);
    canvas.drawArc(Rect.fromCircle(center: Offset(bx, by - 18), radius: 10),
        pi * 0.95, pi * 1.15, true, Paint()..color = const Color(0xFF1E3A5E));
    // Bat: resting on shoulder, whips around on swing.
    final batAngle = -2.4 + ease * 3.4; // rest → contact → follow-through
    final hx = bx + 4, hy = by - 2;
    canvas.save();
    canvas.translate(hx, hy);
    canvas.rotate(batAngle);
    _drawBat(canvas, 64);
    canvas.restore();
    // Swing arc swoosh.
    if (swingT > 0 && swingT < 1) {
      final arc = Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * (1 - swingT))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(hx, hy), radius: 52),
          -2.6,
          2.2 * ease,
          false,
          arc);
    }
  }

  void _drawBat(Canvas canvas, double len) {
    // Bat pointing up from hands: handle at origin, barrel at -len.
    final wood = Paint()..color = bat.wood;
    final dark = Paint()..color = bat.woodDark;
    final handle = Paint()..color = bat.handle;
    // Barrel (tapered).
    final barrel = Path()
      ..moveTo(-5, -len * 0.35)
      ..quadraticBezierTo(-8, -len * 0.75, -6, -len)
      ..quadraticBezierTo(0, -len - 4, 6, -len)
      ..quadraticBezierTo(8, -len * 0.75, 5, -len * 0.35)
      ..close();
    canvas.drawPath(barrel, wood);
    // Wood grain.
    canvas.drawLine(Offset(-2, -len * 0.4), Offset(-3, -len * 0.9),
        Paint()..color = dark..strokeWidth = 2);
    // Handle.
    canvas.drawRect(const Rect.fromLTWH(-3.5, -14, 7, 14), handle);
    // Knob.
    canvas.drawCircle(const Offset(0, 2), 6, handle);
  }

  void _paintStrikeZone(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final homeY = h * 0.92;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, homeY - h * 0.10), width: 84, height: 96),
        const Radius.circular(6),
      ),
      Paint()
        ..color = theme.accent.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _paintBall(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final moundY = h * 0.56;
    final plateY = h * 0.86;
    if (engine.phase == Phase.flying && engine.pitch != null) {
      final t = engine.pitchT.clamp(0.0, 1.25);
      final p = engine.pitch!;
      // Ease-in: the ball accelerates visually toward the plate.
      final te = t * t * (3 - 2 * t) * 0.3 + t * 0.7;
      final y = moundY + (plateY - moundY) * te.clamp(0.0, 1.2);
      // Lateral break + late drop.
      final x = cx + sin(min(t, 1.2) * pi * 1.4) * p.wiggle * w * 0.22;
      final dropY = p.drop * pow(max(0, t - 0.6) / 0.6, 2) * h * 0.08;
      final r = 6 + te.clamp(0.0, 1.0) * 13;
      // Shadow on grass for depth.
      canvas.drawEllipse(
          Rect.fromCenter(
              center: Offset(x, plateY + 26), width: r * 2.4, height: r * 0.9),
          Paint()..color = Colors.black.withValues(alpha: 0.25));
      _drawBall(canvas, Offset(x, y + dropY), r);
      // Motion trail.
      final trail = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = r * 0.7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, y + dropY - r * 3), Offset(x, y + dropY - r),
          trail);
    } else if ((engine.phase == Phase.hit || engine.phase == Phase.result) &&
        engine.lastResult != null) {
      final r = engine.lastResult!;
      final prog = engine.phase == Phase.hit
          ? engine.hitProgress
          : 1.0; // freeze at landing during result
      if (r.homer) {
        // Towering shot: up and out, shrinking with distance.
        final x = cx + (prog - 0.3) * w * 0.9;
        final y = plateY -
            sin(prog.clamp(0.0, 1.0) * pi) * h * 0.55 -
            prog * h * 0.05;
        final rad = (16 * (1 - prog * 0.75)).clamp(4.0, 16.0);
        // Trail.
        final trail = Paint()
          ..color = theme.accent.withValues(alpha: 0.4 * (1 - prog))
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(cx, plateY - 10), Offset(x, y), trail);
        _drawBall(canvas, Offset(x, y), rad);
        if (prog >= 0.97) {
          // Landing burst beyond the wall.
          final burst = Paint()
            ..color = theme.accent.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4;
          canvas.drawCircle(Offset(x, y), 14 + (prog - 0.97) * 900, burst);
        }
      } else if (r.gained == 150) {
        // Off the wall: line drive that dies at the wall.
        final x = cx + prog * w * 0.42;
        final y = plateY - sin(prog * pi * 0.5) * h * 0.28;
        _drawBall(canvas, Offset(x, y), 10);
      } else if (r.gained == 40) {
        // Foul: slices off to the side.
        final x = cx - prog * w * 0.55;
        final y = plateY - prog * h * 0.18;
        _drawBall(canvas, Offset(x, y), 9);
      }
      // Whiffs/strikes: no batted ball.
    }
  }

  void _drawBall(Canvas canvas, Offset c, double r) {
    // Shadow side for a physical leather feel.
    canvas.drawCircle(
        c + Offset(r * 0.25, r * 0.3), r, Paint()..color = ball.shadow);
    canvas.drawCircle(c, r, Paint()..color = ball.hide);
    // Seams.
    final seam = Paint()
      ..color = ball.seam
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, r * 0.12);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.62), -1.1, 2.2,
        false, seam);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.62), pi - 1.1, 2.2,
        false, seam);
    // Highlight.
    canvas.drawCircle(
        c + Offset(-r * 0.35, -r * 0.4),
        r * 0.28,
        Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant _StadiumPainter old) => true;
}
