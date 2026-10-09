import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Home Run Derby rules (see RULES.md — the authoritative source).
// - Each batter gets [pitchesPerTurn] pitches.
// - A swing is timed against the ball crossing the plate (t = 1.0).
// - Perfect timing (|dt| <= 0.05): home run, 395–460 ft.
// - Good contact (|dt| <= 0.12): 45% home run, else off-the-wall double.
// - Late/early (|dt| <= 0.22): foul tip.
// - Worse: swinging strike. No swing past t = 1.12: called strike.
// - Consecutive home runs build a streak multiplier: 1 + (streak-1)*0.5.
// - Bot Battle: the bot swings with reaction error scaled by its skill.
// ---------------------------------------------------------------------------

const pitchesPerTurn = 10;

/// Pitch archetypes.
enum PitchKind { fastball, curveball, changeup, sinker }

/// Phases owned entirely by the engine. The UI only renders.
/// [idle] waits for input (human taps PLAY BALL, or a bot auto-pitch timer).
/// Every other phase always has a live timer, or the watchdog recovers it —
/// stuck states are impossible by construction.
enum Phase { idle, windup, flying, hit, result, over }

/// Audio/UI events emitted by the engine.
enum HomerunEvent {
  pitchReleased,
  swung,
  batCrack,
  homer,
  foul,
  whiff,
  strikeCalled,
  streakLost,
  turnChanged,
  gameOver,
}

class DerbyPlayer {
  String name;
  final bool isBot;
  int score = 0;
  int homers = 0;
  int longest = 0;
  int streak = 0;
  int pitches = 0; // pitches faced this turn

  DerbyPlayer({required this.name, required this.isBot});
}

/// Bot skill tiers (RULES.md §11).
enum BotSkill { rookie, pro, allstar }

/// Pitch difficulty tiers — scale pitch speed and break (RULES.md §5).
enum PitchDifficulty { rookie, pro, allstar }

/// A pitch in flight. Ball position is a pure function of elapsed time,
/// so the UI can render smoothly while the engine owns the phase machine.
class Pitch {
  final PitchKind kind;
  final String label;
  /// Seconds from release until the ball crosses the plate (t = 1.0).
  final double flightSecs;
  /// Lateral break amplitude (fraction of half-width).
  final double wiggle;
  /// Late vertical drop (fraction of travel), sinker only.
  final double drop;

  const Pitch({
    required this.kind,
    required this.label,
    required this.flightSecs,
    required this.wiggle,
    required this.drop,
  });
}

/// Outcome of a resolved swing (RULES.md §8).
class SwingResult {
  final String title;
  final String sub;
  final int gained;
  final bool homer;
  final int distance; // feet, 0 for non-hits

  const SwingResult({
    required this.title,
    required this.sub,
    required this.gained,
    required this.homer,
    required this.distance,
  });
}

class HomerunEngine extends ChangeNotifier {
  final List<DerbyPlayer> players;
  final PitchDifficulty pitchDifficulty;
  final BotSkill botSkill;
  final _rand = Random();

  int turn = 0;
  Phase phase = Phase.idle;
  String banner = '';
  Pitch? pitch;
  SwingResult? lastResult;

  /// Moment the current pitch was released (pitch clock). Read through
  /// [_now] so pause/resume shifts time instead of jumping the ball.
  DateTime? _releaseAt;
  /// When the current hit-flight animation started.
  DateTime? _hitAt;
  /// How long the hit ball stays in the air (secs).
  double hitFlightSecs = 1.5;
  /// When the current result banner started.
  DateTime? _resultAt;
  /// Did the human swing yet on this pitch (prevents double swings).
  bool _swung = false;

  /// Bot swing timer target (absolute pitch-clock time of bot contact attempt).
  double? _botSwingT;

  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;

  // Pause-safe clock: [_now] = wall clock + accumulated paused shift.
  Duration _clockShift = Duration.zero;
  DateTime? _pauseStart;

  void Function(HomerunEvent)? onEvent;

  /// Test hook: force the next pitch kind. Consumed after one use.
  @visibleForTesting
  PitchKind? forcedKind;

  static const windupMs = 650;
  static const resultMs = 1100;
  static const betweenPitchMs = 450;

  HomerunEngine({
    required this.players,
    this.pitchDifficulty = PitchDifficulty.pro,
    this.botSkill = BotSkill.pro,
  }) {
    banner = _firstBanner();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _recover());
    _afterPhase();
  }

  DerbyPlayer get current => players[turn];
  bool get isOver => phase == Phase.over;
  int? get winnerIndex {
    if (!isOver) return null;
    var best = 0;
    for (int i = 1; i < players.length; i++) {
      if (players[i].score > players[best].score) best = i;
    }
    return best;
  }

  /// Effective engine clock (pause-aware).
  DateTime _now() => DateTime.now().add(_clockShift);

  /// Pitch-clock position of the ball: 0 = release, 1 = plate.
  double get pitchT {
    if (pitch == null || _releaseAt == null) return 0;
    final e = _now().difference(_releaseAt!).inMicroseconds / 1e6;
    return e / pitch!.flightSecs;
  }

  /// Hit-flight animation progress 0..1.
  double get hitProgress {
    if (_hitAt == null) return 0;
    final e = _now().difference(_hitAt!).inMicroseconds / 1e6;
    return (e / hitFlightSecs).clamp(0.0, 1.0);
  }

  /// Result banner progress 0..1.
  double get resultProgress {
    if (_resultAt == null) return 0;
    final e = _now().difference(_resultAt!).inMicroseconds / 1e6;
    return (e / (resultMs / 1000)).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer and shift the engine clock so nothing
  /// jumps. Resume re-arms the current phase via the watchdog.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _pauseStart = DateTime.now();
      _timer?.cancel();
      _timer = null;
    } else {
      if (_pauseStart != null) {
        _clockShift += DateTime.now().difference(_pauseStart!);
        _pauseStart = null;
      }
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// Respects [paused]. [idle] is a legitimate wait-for-input state for
  /// humans; bot idle always has a timer.
  void _recover() {
    if (_disposed || isOver || paused || _timer != null) return;
    switch (phase) {
      case Phase.windup:
        _arm(const Duration(milliseconds: 300), _releasePitch);
      case Phase.flying:
        _scheduleFlyingTimer();
      case Phase.hit:
        final remain = _remainMs(_hitAt, hitFlightSecs * 1000);
        _arm(Duration(milliseconds: remain), _afterHitFlight);
      case Phase.result:
        final remain = _remainMs(_resultAt, resultMs);
        _arm(Duration(milliseconds: remain), _afterResult);
      case Phase.idle:
        if (current.isBot) _arm(const Duration(milliseconds: 700), _beginPitch);
      case Phase.over:
        break;
    }
  }

  int _remainMs(DateTime? start, double totalMs) {
    if (start == null) return 50;
    final elapsed = _now().difference(start).inMilliseconds;
    return (totalMs - elapsed).clamp(50, totalMs.toInt());
  }

  // ------------------------------------------------------------ turn flow
  String _firstBanner() {
    final p = players[0];
    return p.isBot ? '${p.name} steps in…' : '${p.name}, tap PLAY BALL!';
  }

  /// Called after construction and whenever entering [Phase.idle].
  void _afterPhase() {
    if (isOver || _disposed || paused) return;
    if (current.isBot) {
      banner = '${current.name} steps in…';
      notifyListeners();
      _arm(const Duration(milliseconds: 900), _beginPitch);
    }
  }

  /// Human taps PLAY BALL (or the big swing area for the first pitch).
  void startPitch() {
    if (phase != Phase.idle || current.isBot || isOver || paused) return;
    _beginPitch();
  }

  void _beginPitch() {
    if (phase != Phase.idle || isOver || _disposed || paused) return;
    if (current.pitches >= pitchesPerTurn) {
      _nextBatter();
      return;
    }
    phase = Phase.windup;
    banner = '${current.name} is ready…';
    notifyListeners();
    _arm(const Duration(milliseconds: windupMs), _releasePitch);
  }

  Pitch _makePitch() {
    final forced = forcedKind;
    forcedKind = null;
    final kind = forced ?? PitchKind.values[_rand.nextInt(4)];
    // Difficulty scales flight time and break (RULES.md §5).
    final speedScale = switch (pitchDifficulty) {
      PitchDifficulty.rookie => 1.25,
      PitchDifficulty.pro => 1.0,
      PitchDifficulty.allstar => 0.82,
    };
    final breakScale = switch (pitchDifficulty) {
      PitchDifficulty.rookie => 0.6,
      PitchDifficulty.pro => 1.0,
      PitchDifficulty.allstar => 1.35,
    };
    return switch (kind) {
      PitchKind.fastball => Pitch(
          kind: kind,
          label: '🔥 Fastball',
          flightSecs: 0.72 * speedScale,
          wiggle: 0.0,
          drop: 0.0,
        ),
      PitchKind.curveball => Pitch(
          kind: kind,
          label: '🌀 Curveball',
          flightSecs: 0.95 * speedScale,
          wiggle: 0.55 * breakScale,
          drop: 0.1,
        ),
      PitchKind.changeup => Pitch(
          kind: kind,
          label: '🐢 Changeup',
          flightSecs: 1.05 * speedScale,
          wiggle: 0.15 * breakScale,
          drop: 0.05,
        ),
      PitchKind.sinker => Pitch(
          kind: kind,
          label: '⬇️ Sinker',
          flightSecs: 0.78 * speedScale,
          wiggle: 0.25 * breakScale,
          drop: 0.35,
        ),
    };
  }

  void _releasePitch() {
    if (phase != Phase.windup || isOver || _disposed || paused) return;
    pitch = _makePitch();
    _releaseAt = _now();
    _swung = false;
    _botSwingT = null;
    phase = Phase.flying;
    banner = current.isBot ? '${current.name} is watching…' : 'Swing!';
    onEvent?.call(HomerunEvent.pitchReleased);
    notifyListeners();
    if (current.isBot) {
      // Bot reaction error (secs of pitch-clock time), scaled by skill.
      final sigma = switch (botSkill) {
        BotSkill.rookie => 0.16,
        BotSkill.pro => 0.08,
        BotSkill.allstar => 0.045,
      };
      final err = _gauss() * sigma;
      _botSwingT = (1.0 + err).clamp(0.55, 1.25);
    }
    _scheduleFlyingTimer();
  }

  /// Arms the single flying timer to the earlier of the bot swing moment and
  /// pitch expiry. The watchdog re-arms this if the timer ever dies.
  void _scheduleFlyingTimer() {
    if (phase != Phase.flying || pitch == null || _releaseAt == null) return;
    final elapsed = _now().difference(_releaseAt!).inMicroseconds / 1e6;
    final targetT = _botSwingT ?? 1.12; // pitch expires at t = 1.12
    var waitSecs = targetT * pitch!.flightSecs - elapsed;
    if (waitSecs < 0.02) waitSecs = 0.02;
    _arm(Duration(microseconds: (waitSecs * 1e6).round()), _flyingTimerFired);
  }

  void _flyingTimerFired() {
    if (phase != Phase.flying || isOver || _disposed || paused) return;
    if (_botSwingT != null && pitchT >= _botSwingT! - 0.001) {
      // Bot takes its cut.
      _doSwing(bot: true);
    } else if (pitchT >= 1.12) {
      _resolveSwing(null); // took the pitch — called strike
    } else {
      // Timer fired early (rounding); re-arm for the true target.
      _scheduleFlyingTimer();
    }
  }

  double _gauss() {
    // Box–Muller.
    final u1 = _rand.nextDouble().clamp(1e-9, 1.0);
    final u2 = _rand.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  /// Human (or bot) swings. Strict: exactly one swing per pitch.
  void swing() {
    if (phase != Phase.flying || _swung || isOver || paused) return;
    _doSwing(bot: current.isBot);
  }

  void _doSwing({required bool bot}) {
    if (_swung || phase != Phase.flying) return;
    _swung = true;
    onEvent?.call(HomerunEvent.swung);
    _resolveSwing(pitchT);
  }

  SwingResult _scoreSwing(double? contactT) {
    final p = current;
    final t = contactT ?? 99.0;
    final dt = (t - 1.0).abs();
    if (dt <= 0.05) {
      // PERFECT — towering home run (RULES.md §8).
      final dist = 395 + _rand.nextInt(66);
      p.streak++;
      final mult = 1 + (p.streak - 1) * 0.5;
      final gained = (500 * mult).round() + dist;
      p.homers++;
      if (dist > p.longest) p.longest = dist;
      return SwingResult(
        title: 'HOME RUN! 🚀',
        sub: '$dist ft${p.streak > 1 ? ' • ${p.streak} in a row! ×${mult.toStringAsFixed(1)}' : ''}',
        gained: gained,
        homer: true,
        distance: dist,
      );
    } else if (dt <= 0.12) {
      final dist = 320 + _rand.nextInt(61);
      if (_rand.nextDouble() < 0.45) {
        p.streak++;
        final mult = 1 + (p.streak - 1) * 0.5;
        final gained = (500 * mult).round() + dist;
        p.homers++;
        if (dist > p.longest) p.longest = dist;
        return SwingResult(
          title: "IT'S GONE! 🎆",
          sub: '$dist ft — just over the wall!',
          gained: gained,
          homer: true,
          distance: dist,
        );
      }
      p.streak = 0;
      onEvent?.call(HomerunEvent.streakLost);
      return const SwingResult(
        title: 'Off the wall! 🧱',
        sub: 'So close — a double.',
        gained: 150,
        homer: false,
        distance: 0,
      )._withDist(dist);
    } else if (dt <= 0.22) {
      p.streak = 0;
      onEvent?.call(HomerunEvent.streakLost);
      return SwingResult(
        title: 'Foul tip! 😅',
        sub: t < 1.0 ? 'Out in front — just a piece.' : 'Late on it — just a piece.',
        gained: 40,
        homer: false,
        distance: 0,
      );
    }
    p.streak = 0;
    onEvent?.call(HomerunEvent.streakLost);
    if (contactT == null) {
      return const SwingResult(
        title: 'Called strike! 👀',
        sub: 'You let it go by.',
        gained: 0,
        homer: false,
        distance: 0,
      );
    }
    return SwingResult(
      title: 'WHIFF! 💨',
      sub: t < 1.0 ? 'Way out in front!' : 'Swing and a miss!',
      gained: 0,
      homer: false,
      distance: 0,
    );
  }

  void _resolveSwing(double? contactT) {
    if (phase != Phase.flying) return;
    final result = _scoreSwing(contactT);
    current.score += result.gained;
    current.pitches++;
    lastResult = result;
    phase = Phase.hit;
    _hitAt = _now();
    // Bigger hits fly longer.
    hitFlightSecs = result.homer ? 1.6 : (result.gained > 0 ? 1.0 : 0.5);
    banner = result.title;
    if (result.homer) {
      onEvent?.call(HomerunEvent.homer);
    } else if (result.gained == 40) {
      onEvent?.call(HomerunEvent.foul);
    } else if (result.gained == 0) {
      if (contactT == null) {
        onEvent?.call(HomerunEvent.strikeCalled);
      } else {
        onEvent?.call(HomerunEvent.whiff);
      }
    } else {
      onEvent?.call(HomerunEvent.batCrack);
    }
    notifyListeners();
    _arm(
      Duration(microseconds: (hitFlightSecs * 1e6).round()),
      _afterHitFlight,
    );
  }

  void _afterHitFlight() {
    if (phase != Phase.hit || isOver || _disposed || paused) return;
    phase = Phase.result;
    _resultAt = _now();
    notifyListeners();
    _arm(const Duration(milliseconds: resultMs), _afterResult);
  }

  void _afterResult() {
    if (phase != Phase.result || isOver || _disposed || paused) return;
    if (current.pitches >= pitchesPerTurn) {
      _nextBatter();
      return;
    }
    phase = Phase.idle;
    pitch = null;
    lastResult = null;
    notifyListeners();
    // Auto-throw the next pitch after a beat (bot OR human).
    _arm(const Duration(milliseconds: betweenPitchMs), _beginPitch);
  }

  void _nextBatter() {
    if (isOver || _disposed) return;
    if (turn + 1 < players.length) {
      turn++;
      phase = Phase.idle;
      pitch = null;
      lastResult = null;
      final p = current;
      banner = p.isBot
          ? '${p.name} steps in…'
          : '${players.length > 1 ? 'Pass the phone — ' : ''}${p.name}, tap PLAY BALL!';
      onEvent?.call(HomerunEvent.turnChanged);
      notifyListeners();
      if (p.isBot) {
        _arm(const Duration(milliseconds: 900), _beginPitch);
      }
      // Human idle: waits for PLAY BALL tap. Watchdog leaves human idle alone.
    } else {
      _gameOver();
    }
  }

  void _gameOver() {
    phase = Phase.over;
    pitch = null;
    final w = winnerIndex;
    banner = w == null
        ? 'Derby over!'
        : '${players[w].name} wins the derby! 🏆';
    onEvent?.call(HomerunEvent.gameOver);
    notifyListeners();
  }

  /// Quit mid-game: jump straight to over.
  void forfeit() {
    if (isOver || _disposed) return;
    _timer?.cancel();
    _timer = null;
    _gameOver();
  }
}

extension on SwingResult {
  SwingResult _withDist(int dist) => SwingResult(
        title: title,
        sub: '$dist ft — so close!',
        gained: gained,
        homer: homer,
        distance: dist,
      );
}
