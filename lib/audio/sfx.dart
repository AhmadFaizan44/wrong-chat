import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Play alongside whatever else is on the phone and never steal audio focus.
final AudioContext _mixContext = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

/// Short synth sounds (pre-rendered WAVs). Each sound has a small pool of low-latency players created once at boot.
class Sfx {
  Sfx._();
  static bool muted = false;
  static bool haptics = true;
  static bool _ready = false;
  static final Map<String, List<AudioPlayer>> _pool = {};
  static final Map<String, int> _next = {};
  static final AudioCache _cache = AudioCache(prefix: 'assets/audio/');

  static const _voices = {'whoosh': 3, 'pop': 3, 'invalid': 2, 'coin': 2, 'click': 2, 'lose': 1, 'fanfare': 1, 'star': 2, 'pickup': 2, 'place': 2};

  static String _chime(int s) => 'chime_${s.toString().padLeft(2, '0')}';

  static Future<void> init() async {
    try {
      final jobs = <Future<void>>[];
      void make(String name, int voices) {
        final list = _pool[name] = [];
        _next[name] = 0;
        for (var k = 0; k < voices; k++) {
          final p = AudioPlayer()..audioCache = _cache;
          list.add(p);
          jobs.add(() async {
            await p.setAudioContext(_mixContext);
            await p.setPlayerMode(PlayerMode.lowLatency);
            await p.setReleaseMode(ReleaseMode.stop);
            await p.setSourceAsset('$name.wav');
          }());
        }
      }

      _voices.forEach(make);
      for (var s = 0; s <= 28; s++) {
        make(_chime(s), 1);
      }
      await Future.wait(jobs).timeout(const Duration(seconds: 8));
      _ready = true;
    } catch (_) {
      _ready = false; // audio unavailable (e.g. tests): stay silent
    }
  }

  static void play(String name, {double volume = 1}) {
    if (muted || !_ready) return;
    final list = _pool[name];
    if (list == null || list.isEmpty) return;
    final i = _next[name]!;
    _next[name] = (i + 1) % list.length;
    final p = list[i];
    unawaited(() async {
      try {
        await p.stop();
        await p.setVolume(volume);
        await p.resume();
      } catch (_) {}
    }());
  }

  /// A rising two-note "delivered" ping; longer combos raise the key.
  static void delivered(int combo) {
    final base = math.min(combo, 20);
    play(_chime(base), volume: 0.85);
    Timer(const Duration(milliseconds: 70), () => play(_chime(math.min(base + 7, 28)), volume: 0.85));
  }

  static void haptic([int strength = 1]) {
    if (!haptics) return;
    if (strength >= 3) {
      HapticFeedback.heavyImpact();
    } else if (strength == 2) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }
}

/// Looping background music (tool/gen_music.mjs). Pauses in the background, while muted, and while an ad plays.
class Music with WidgetsBindingObserver {
  Music._();
  static final Music _i = Music._();
  static const double volume = 0.32;
  static AudioPlayer? _p;
  static bool _enabled = true, _ducked = false, _foreground = true, _playing = false;

  static Future<void> init({required bool enabled}) async {
    _enabled = enabled;
    try {
      final p = AudioPlayer(playerId: 'wrongchat-music')..audioCache = Sfx._cache;
      await p.setAudioContext(_mixContext);
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setSourceAsset('music.ogg');
      await p.setVolume(volume);
      _p = p;
      WidgetsBinding.instance.addObserver(_i);
      _apply();
    } catch (e) {
      if (kDebugMode) debugPrint('music unavailable: $e');
      _p = null;
    }
  }

  static set enabled(bool v) {
    _enabled = v;
    _apply();
  }

  static void duck(bool v) {
    _ducked = v;
    _apply();
  }

  static void _apply() {
    final p = _p;
    if (p == null) return;
    final want = _enabled && !_ducked && _foreground;
    if (want == _playing) return;
    _playing = want;
    unawaited((want ? p.resume() : p.pause()).then((_) {}, onError: (_) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _apply();
  }
}
