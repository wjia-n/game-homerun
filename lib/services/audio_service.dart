import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural ballpark audio — all sounds synthesized in code as WAV bytes.
/// No asset files. Warm, physical, baseball-appropriate sounds.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu in/out,
///   pause/resume, toggles) can never swallow a start or leave the player
///   half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class BallparkAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  BallparkAudio() {
    // Fire-and-forget is fine here: configure() runs before any play.
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02, double decayPow = 2.2}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, decayPow).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _noise(double secs,
      {double attack = 0.02, double decayPow = 2.0, double brightness = 0.5}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    double lp = 0;
    for (int i = 0; i < n; i++) {
      final w = _rand.nextDouble() * 2 - 1;
      // Simple low-pass to shape brightness.
      lp = lp * (1 - brightness) + w * brightness;
      out[i] = _env(i, n, attack: attack, decayPow: decayPow) * lp * 1.6;
    }
    return out;
  }

  List<double> _mix(List<double> a, List<double> b, double bGain) {
    final n = max(a.length, b.length);
    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < a.length; i++) {
      out[i] += a[i];
    }
    for (int i = 0; i < b.length; i++) {
      out[i] += b[i] * bGain;
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      final gap = List<double>.filled((_rate * gapSecs).round(), 0);
      out.addAll(gap);
    }
    return out;
  }

  /// Organ-style voice (ballpark organ): strong fundamental + 2nd/4th
  /// harmonics with a fast attack and long sustain.
  List<double> _organ(double freq, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final ph = 2 * pi * freq * t;
      final tn = i / n;
      final env = (tn / 0.03).clamp(0.0, 1.0) * (1 - pow(tn, 3).toDouble());
      out[i] = env *
          0.5 *
          (sin(ph) +
              0.45 * sin(2 * ph) +
              0.25 * sin(4 * ph) +
              0.12 * sin(8 * ph));
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  // -- "Take Me Out to the Ball Game" chorus (public domain, 1908) on organ.
  // Notes: C E G E | C E G(high) ... rendered as MIDI-ish freqs.
  Uint8List _menuBytes() => _clip('music_menu', () {
        double f(double midi) => 440.0 * pow(2, (midi - 69) / 12);
        // Melody (chorus), MIDI numbers.
        final mel = [
          [60, 0.42], [64, 0.42], [67, 0.42], [64, 0.84], // Take me out to the
          [65, 0.42], [69, 0.42], [72, 0.42], [69, 0.84], // ball game
          [67, 0.42], [64, 0.42], [62, 0.42], [60, 0.84], // take me out with the
          [62, 0.42], [64, 0.42], [65, 1.26], // crowd
          [60, 0.42], [64, 0.42], [67, 0.42], [64, 0.84], // buy me some peanuts
          [65, 0.42], [69, 0.42], [72, 0.42], [69, 0.84], // and cracker jack
          [74, 0.42], [72, 0.42], [69, 0.42], [67, 0.84], // I don't care if I
          [69, 0.42], [72, 0.42], [74, 1.68], // never get back
        ];
        final out = <double>[];
        for (final pair in mel) {
          final note = _organ(f(pair[0].toDouble()), pair[1].toDouble());
          // Soft root bass under each note.
          final bass = _organ(f(pair[0].toDouble() - 24), pair[1].toDouble());
          final mixed = _mix(note, bass, 0.35);
          out.addAll(mixed);
        }
        // Pad the loop to a round 16s with a gentle outro chord.
        final target = _rate * 16;
        while (out.length < target) {
          out.add(0);
        }
        return out.sublist(0, target);
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Lazy summer-afternoon loop: soft bass pulse + sparse plucks, 12s.
        final n = (_rate * 12).round();
        final out = List<double>.filled(n, 0.0);
        // Bass pulse on beats.
        for (int beat = 0; beat < 12; beat++) {
          final start = (_rate * beat).round();
          final tone = _tone(110.0, 0.35, harmonics: 0.3);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.22;
          }
        }
        // Sparse pentatonic plucks.
        final plucks = [392.0, 440.0, 523.25, 587.33, 659.25, 587.33];
        for (int k = 0; k < plucks.length; k++) {
          final start = (_rate * (k * 2 + 0.5)).round();
          final tone = _tone(plucks[k], 0.5, harmonics: 0.35);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.28;
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));

  /// Bat crack: sharp wooden snap + low thump.
  Future<void> batCrack() => _play(_clip('crack', () {
        final snap = _noise(0.09, attack: 0.004, decayPow: 3.5, brightness: 0.9);
        final thump = _tone(150, 0.12, freqEnd: 80, harmonics: 0.4);
        return _mix(snap, thump, 1.4);
      }));

  /// Foul tick: softer wood tick.
  Future<void> foulTick() => _play(_clip('foul', () {
        final snap = _noise(0.07, attack: 0.004, decayPow: 3.0, brightness: 0.7);
        final thump = _tone(220, 0.09, freqEnd: 140, harmonics: 0.4);
        return _mix(snap, thump, 1.0);
      }));

  /// Crowd roar: big swell of crowd noise after a home run.
  Future<void> crowdRoar() => _play(_clip('roar', () {
        final n = (_rate * 2.6).round();
        final out = List<double>.filled(n, 0.0);
        double lp = 0;
        for (int i = 0; i < n; i++) {
          final w = _rand.nextDouble() * 2 - 1;
          lp = lp * 0.86 + w * 0.14;
          final t = i / n;
          // Swell up fast, long tail.
          final env = t < 0.15
              ? t / 0.15
              : pow(1 - (t - 0.15) / 0.85, 1.6).toDouble();
          out[i] = lp * 2.4 * env.clamp(0.0, 1.0);
        }
        return out;
      }));

  /// Crowd gasp: short "ooh" for fouls/whiffs.
  Future<void> crowdGasp() => _play(_clip('gasp', () {
        final n = (_rate * 0.9).round();
        final out = List<double>.filled(n, 0.0);
        double lp = 0;
        for (int i = 0; i < n; i++) {
          final w = _rand.nextDouble() * 2 - 1;
          lp = lp * 0.9 + w * 0.1;
          final t = i / n;
          final env = sin(pi * t.clamp(0.0, 1.0));
          out[i] = lp * 2.0 * env;
        }
        return out;
      }));

  /// Swing whiff: airy whoosh falling in pitch.
  Future<void> whiff() => _play(_clip('whiff', () {
        final n = (_rate * 0.28).round();
        final out = List<double>.filled(n, 0.0);
        double lp = 0;
        for (int i = 0; i < n; i++) {
          final w = _rand.nextDouble() * 2 - 1;
          lp = lp * 0.55 + w * 0.45;
          final t = i / n;
          final env = sin(pi * t.clamp(0.0, 1.0));
          out[i] = lp * 1.5 * env;
        }
        return out;
      }));

  /// Pitch whoosh as the ball leaves the mound.
  Future<void> pitchWhoosh() => _play(_clip('whoosh', () {
        final n = (_rate * 0.35).round();
        final out = List<double>.filled(n, 0.0);
        double lp = 0;
        for (int i = 0; i < n; i++) {
          final w = _rand.nextDouble() * 2 - 1;
          lp = lp * 0.75 + w * 0.25;
          final t = i / n;
          final env = sin(pi * t.clamp(0.0, 1.0));
          out[i] = lp * 0.9 * env;
        }
        return out;
      }));

  /// Umpire's strike call: low buzz.
  Future<void> strikeCall() => _play(_clip(
      'strike', () => _tone(110, 0.3, freqEnd: 90, harmonics: 0.6)));

  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));

  Future<void> homerJingle() => _play(_clip(
      'homer',
      () => _arp([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5], 0.15, 0.02)));

  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));

  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    // Wait for any in-flight op, then bail if superseded meanwhile.
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
