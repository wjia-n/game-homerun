import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Home-run derby: 10 pitches, swipe up to swing with perfect timing.
class HomeRunScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const HomeRunScreen({super.key, required this.players, required this.callbacks});

  @override
  State<HomeRunScreen> createState() => _HomeRunScreenState();
}

class _Pitch {
  double t = 0; // 0 = release, 1 = past the plate
  double speed; // t per second
  double wiggle; // lateral curve amount
  String kind;
  _Pitch(this.speed, this.wiggle, this.kind);
}

class _HomeRunScreenState extends State<HomeRunScreen> {
  static const _bestKey = 'homerun_best';
  static const totalPitches = 10;

  final _rand = Random();
  Ticker? _ticker;
  double _lastT = 0;

  int pitchNum = 0; // pitches thrown so far
  int streak = 0;
  int best = 0;
  _Pitch? pitch;
  String phase = 'idle'; // idle | flying | result
  String pop = '';
  String popSub = '';
  bool over = false;
  double ballX = 0; // -1..1 lateral

  int get score => widget.players[0].score;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => best = prefs.getInt(_bestKey) ?? 0);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _throwPitch() {
    if (phase == 'flying' || over || pitchNum >= totalPitches) return;
    final kind = _rand.nextInt(3);
    pitch = switch (kind) {
      0 => _Pitch(1.05, 0.0, '🔥 Fastball'),
      1 => _Pitch(0.75, 0.55, '🌀 Curveball'),
      _ => _Pitch(0.6, 0.15, '🐢 Changeup'),
    };
    ballX = 0;
    pitchNum++;
    setState(() {
      phase = 'flying';
      pop = '';
      popSub = '';
    });
    Sfx.tap();
    _lastT = 0;
    _ticker?.dispose();
    _ticker = Ticker(_tick)..start();
  }

  void _tick(Duration d) {
    final t = d.inMicroseconds / 1e6;
    final dt = _lastT == 0 ? 0.016 : min(0.05, t - _lastT);
    _lastT = t;
    if (!mounted || phase != 'flying' || pitch == null) return;
    setState(() {
      pitch!.t += pitch!.speed * dt;
      ballX = sin(pitch!.t * pi * 1.2) * pitch!.wiggle * 0.35;
      if (pitch!.t >= 1.15) {
        // took the pitch — called strike
        _resolveSwing(null);
      }
    });
  }

  void _swing() {
    if (phase != 'flying' || pitch == null) return;
    _resolveSwing(pitch!.t);
  }

  void _resolveSwing(double? contactT) {
    _ticker?.stop();
    final t = contactT ?? 2.0;
    String title, sub;
    int gained = 0;
    bool homer = false;
    if ((t - 0.90).abs() < 0.045) {
      // PERFECT
      final dist = 395 + _rand.nextInt(65);
      streak++;
      final mult = 1 + (streak - 1) * 0.5;
      gained = (500 * mult).round() + dist;
      homer = true;
      title = 'HOME RUN! 🚀';
      sub = '$dist ft${streak > 1 ? ' • $streak in a row x${mult.toStringAsFixed(1)}!' : ''}';
      Sfx.win();
    } else if ((t - 0.90).abs() < 0.11) {
      final dist = 320 + _rand.nextInt(60);
      if (_rand.nextDouble() < 0.45) {
        streak++;
        gained = 500 + dist;
        homer = true;
        title = 'IT\'S GONE! 🎆';
        sub = '$dist ft — just over the wall!';
      } else {
        streak = 0;
        gained = 150;
        title = 'Off the wall! 🧱';
        sub = '$dist ft — so close!';
      }
      Sfx.move();
    } else if ((t - 0.90).abs() < 0.2) {
      streak = 0;
      gained = 40;
      title = 'Foul tip! 😅';
      sub = 'Late on it — just a piece.';
      Sfx.tap();
    } else {
      streak = 0;
      gained = 0;
      title = contactT == null ? 'Called strike! 👀' : 'WHIFF! 💨';
      sub = contactT == null ? 'You let it go by.' : 'Swing and a miss!';
      Sfx.lose();
    }
    if (!homer && gained == 0) streak = 0;
    widget.players[0].score += gained;
    widget.callbacks.refreshHud();
    setState(() {
      phase = 'result';
      pop = title;
      popSub = sub.isEmpty ? '' : (gained > 0 ? '+$gained  •  $sub' : sub);
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted || over) return;
      if (pitchNum >= totalPitches) {
        _gameOver();
      } else {
        setState(() {
          phase = 'idle';
          pop = '';
          popSub = '';
        });
        _throwPitch();
      }
    });
  }

  Future<void> _gameOver() async {
    if (over) return;
    over = true;
    final s = score;
    final isBest = s > best;
    if (isBest) {
      best = s;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, best);
    }
    if (!mounted) return;
    widget.callbacks.finish(
      headline: 'Derby over! You scored $s! ⚾',
      subline: '${isBest ? 'NEW BEST! 🏆' : 'Best: $best'} • ${s >= 4000 ? 'Hall-of-fame power! 💪' : s >= 2000 ? 'Solid lumber! 🌳' : 'Keep swinging, slugger!'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        _hud(theme),
        const SizedBox(height: 8),
        Expanded(
          child: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -250) _swing();
            },
            onTap: _swing,
            child: _stadium(theme),
          ),
        ),
        const SizedBox(height: 8),
        if (phase == 'idle' && pitchNum < totalPitches && !over)
          WajihaButton(label: pitchNum == 0 ? 'Play ball!' : 'Next pitch', emoji: '⚾', primary: true, onTap: _throwPitch),
        if (phase == 'flying')
          Text('Swipe UP to swing! 👆', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _hud(GameTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _cell(t, 'Score', '$score'),
          _cell(t, 'Pitch', '$pitchNum/$totalPitches'),
          _cell(t, 'Streak', streak > 1 ? '🔥 $streak' : '$streak'),
          _cell(t, 'Best', '$best'),
        ],
      ),
    );
  }

  Widget _cell(GameTheme t, String label, String value) => Column(
        children: [
          Text(label, style: TextStyle(color: t.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          Text(value, style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      );

  Widget _stadium(GameTheme t) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: t.radius,
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B3E), Color(0xFF1B2F6B), Color(0xFF2E7D32)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.55, 0.56],
        ),
      ),
      child: LayoutBuilder(
        builder: (ctx, box) {
          final h = box.maxHeight;
          final w = box.maxWidth;
          final ballT = pitch?.t ?? 0;
          final ballY = h * 0.06 + ballT * h * 0.72;
          final ballSize = 10 + ballT * 26;
          return Stack(
            children: [
              const Positioned(top: 14, left: 0, right: 0, child: Center(child: Text('🧢', style: TextStyle(fontSize: 40)))),
              if (pitch != null)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(pitch!.kind, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              // strike zone
              Positioned(
                top: h * 0.70,
                left: w * 0.5 - 45,
                child: Container(
                  width: 90,
                  height: 110,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amberAccent, width: 3),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.amberAccent.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const Positioned(bottom: 10, left: 0, right: 0, child: Center(child: Text('🏠', style: TextStyle(fontSize: 34)))),
              if (phase == 'flying' && pitch != null)
                Positioned(
                  top: ballY - ballSize / 2,
                  left: w * 0.5 + ballX * w * 0.3 - ballSize / 2,
                  child: Text('⚾', style: TextStyle(fontSize: ballSize)),
                ),
              if (pop.isNotEmpty)
                Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(pop),
                    tween: Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.elasticOut,
                    builder: (_, v, _) => Transform.scale(
                      scale: v,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(pop, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                            if (popSub.isNotEmpty)
                              Text(popSub, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.amberAccent)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
