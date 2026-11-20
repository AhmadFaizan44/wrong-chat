import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_service.dart';
import '../audio/sfx.dart';
import '../core/chats.dart';
import '../core/run.dart';
import 'widgets.dart';

enum _Phase { playing, over }

/// A short-lived visual effect, driven by the screen clock.
class _Fx {
  _Fx(this.kind, this.t0, this.dur, {this.lane = 0, this.text = '', this.color = Pal.text, this.sub = ''});
  final String kind; // float | stamp | burst | combo | banner
  final double t0, dur;
  final int lane;
  final String text, sub;
  final Color color;
  double age(double clock) => ((clock - t0) / dur).clamp(0.0, 1.0);
}

class _Reply {
  _Reply(this.text, this.t0, {required this.good});
  final String text;
  final double t0;
  final bool good;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.seed});
  final int? seed;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Run run;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double clock = 0;
  bool paused = false;
  _Phase phase = _Phase.playing;

  final Map<int, double> _x = {};
  final List<_Fx> _fx = [];
  final Map<int, double> _pulse = {};
  final Map<int, _Reply> _replies = {};
  int? _grab;
  double _shake = 0, _flash = 0, _shownScore = 0;
  double _overAt = -1;
  String _wrongReply = '';
  int _bestAtStart = 0;
  bool _bestCheered = false;
  final GlobalKey _receiptKey = GlobalKey();

  bool _finalized = false, _doubled = false, _newBest = false, _busy = false;
  int _earned = 0;

  static const double _dockH = 96;
  static const double _bubbleH = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newRun();
    _ticker = createTicker(_onTick)..start();
  }

  void _newRun() {
    run = Run(seed: widget.seed, tutorial: App.progress.runs == 0);
    _bestAtStart = App.progress.best;
    _bestCheered = false;
    phase = _Phase.playing;
    _x.clear();
    _fx.clear();
    _pulse.clear();
    _replies.clear();
    _grab = null;
    _shownScore = 0;
    _finalized = _doubled = _newBest = false;
    _overAt = -1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && phase == _Phase.playing && !App.ads.showing) setState(() => paused = true);
  }

  // ------------------------------------------------------------------ loop

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (paused || !mounted) return;
    clock += dt;
    if (phase == _Phase.playing) {
      run.tick(dt);
      _drain();
    }
    _shake = math.max(0, _shake - dt * 2.8);
    _flash = math.max(0, _flash - dt * 2.4);
    _shownScore += (run.score - _shownScore) * math.min(1, dt * 12);
    _fx.removeWhere((f) => clock - f.t0 > f.dur);
    _replies.removeWhere((_, r) => clock - r.t0 > 1.5);
    if (_overAt > 0 && phase == _Phase.playing && clock >= _overAt) {
      phase = _Phase.over;
      Sfx.play('lose');
    }
    setState(() {});
  }

  void _drain() {
    final rng = math.Random();
    for (final e in run.events) {
      switch (e) {
        case Delivered(:final bubble, :final points, :final quick, :final combo):
          final lane = bubble.lane;
          final chat = run.lanes[lane];
          _pulse[lane] = clock;
          _replies[lane] = _Reply(chat.happy[rng.nextInt(chat.happy.length)], clock, good: true);
          _fx.add(_Fx('float', clock, 0.9, lane: lane, text: '+$points', color: chat.color));
          _fx.add(_Fx('burst', clock, 0.6, lane: lane, color: chat.color));
          if (quick) _fx.add(_Fx('float', clock + 0.0, 1.0, lane: lane, text: 'QUICK!', color: Pal.gold, sub: 'q'));
          Sfx.delivered(combo);
          Sfx.haptic();
          if (const [20, 35, 50, 70].contains(run.delivered)) {
            _fx.add(_Fx('banner', clock, 2.2, text: '📈 Rush hour! Texts are coming in faster', color: const Color(0xFFFF7A59)));
          }
          if (!_bestCheered && _bestAtStart > 0 && run.score > _bestAtStart) {
            _bestCheered = true;
            _fx.add(_Fx('combo', clock, 1.3, text: '🏆 NEW BEST!'));
            Sfx.play('fanfare', volume: 0.8);
          }
          if (combo >= 4 && combo % 4 == 0 && combo <= 16) {
            _fx.add(_Fx('combo', clock, 1.1, text: 'x${run.multiplier} COMBO!'));
            Sfx.play('star');
            Sfx.haptic(2);
          }
        case WrongSend(:final bubble):
          final lane = bubble.lane;
          final chat = run.lanes[lane];
          _wrongReply = chat.confused[rng.nextInt(chat.confused.length)];
          _pulse[lane] = clock;
          _replies[lane] = _Reply(_wrongReply, clock, good: false);
          _fx.add(_Fx('stamp', clock, 1.15, lane: lane, text: 'SEEN', sub: '${chat.avatar} ${chat.name}', color: Pal.seen));
          _shake = 1;
          _flash = 1;
          Sfx.play('invalid');
          Sfx.haptic(3);
        case LaneJoined(:final chat):
          _pulse[run.lanes.length - 1] = clock;
          _fx.add(_Fx('banner', clock, 2.6, text: '${chat.avatar} ${chat.name} added you to the group chat!', color: chat.color));
          Sfx.play('fanfare', volume: 0.7);
        case RunOver():
          _overAt = clock + 1.0;
          _grab = null;
      }
    }
    run.events.clear();
  }

  // ------------------------------------------------------------------ input

  double _laneW(double w) => w / run.lanes.length;
  double _laneCenter(int lane, double w) => (lane + 0.5) * _laneW(w);
  double _bubbleW(double w) => math.min(w * 0.66, 280);

  double _targetX(Bubble b, double w) {
    final bw = _bubbleW(w);
    return _laneCenter(b.lane, w).clamp(bw / 2 + 8, w - bw / 2 - 8);
  }

  Rect _rectOf(Bubble b, Size s) {
    final bw = _bubbleW(s.width);
    final cx = _x[b.id] ?? _targetX(b, s.width);
    return Rect.fromLTWH(cx - bw / 2, b.y * s.height - _bubbleH, bw, _bubbleH);
  }

  Bubble? _hit(Offset p, Size s) {
    final sorted = List.of(run.bubbles)..sort((a, b) => b.y.compareTo(a.y));
    for (final b in sorted) {
      if (!b.sending && _rectOf(b, s).inflate(18).contains(p)) return b;
    }
    return null;
  }

  void _panStart(DragStartDetails d, Size s) {
    if (phase != _Phase.playing) return;
    final b = _hit(d.localPosition, s);
    _grab = b?.id;
    if (b != null) {
      Sfx.play('pickup', volume: 0.5);
      Sfx.haptic();
    }
  }

  void _panUpdate(DragUpdateDetails d, Size s) {
    final id = _grab;
    if (id == null) return;
    final b = run.byId(id);
    if (b == null) return;
    final lane = (d.localPosition.dx / _laneW(s.width)).floor().clamp(0, run.lanes.length - 1);
    if (lane != b.lane) {
      run.steer(id, lane);
      Sfx.play('place', volume: 0.35);
      Sfx.haptic();
    }
  }

  void _panEnd(DragEndDetails d) {
    final id = _grab;
    _grab = null;
    if (id != null && d.velocity.pixelsPerSecond.dy > 550) _send(id);
  }

  void _tap(TapUpDetails d, Size s) {
    if (phase != _Phase.playing) return;
    final b = _hit(d.localPosition, s);
    if (b != null) _send(b.id);
  }

  void _send(int id) {
    run.send(id);
    if (run.byId(id)?.sending != true) {
      Sfx.play('invalid', volume: 0.4); // tutorial: aim it first
      return;
    }
    Sfx.play('whoosh', volume: 0.7);
    Sfx.haptic(2);
  }

  /// Shares a PNG of the cringe card (the system share sheet; on web, the browser's share or nothing).
  Future<void> _share() async {
    try {
      final box = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (box == null) return;
      final img = await box.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'wrong-chat.png')],
          text: 'I just sent the WRONG text 💀 Score ${run.score} in Wrong Chat. Can you beat it?',
        ),
      );
    } catch (_) {
      // sharing is optional: ignore platforms without a share sheet
    }
  }

  void _useDnd() {
    if (App.progress.dnd <= 0 || run.slowLeft > 0 || phase != _Phase.playing) return;
    App.progress.dnd--;
    App.progress.save();
    run.useDnd();
    _fx.add(_Fx('banner', clock, 1.8, text: '🌙 Do Not Disturb: everything slows down', color: const Color(0xFF8FA8FF)));
    Sfx.play('star');
  }

  // ------------------------------------------------------------------ end of run

  void _finalize({bool doubled = false}) {
    if (_finalized) return;
    _finalized = true;
    _doubled = doubled;
    _earned = run.coins * (doubled ? 2 : 1);
    _newBest = App.progress.finishRun(run.score, _earned);
    if (_earned > 0) Sfx.play('coin');
    if (_newBest && run.score > 0) Sfx.play('fanfare');
  }

  Future<void> _unsend() async {
    if (_busy) return;
    _busy = true;
    final ok = await App.ads.showRewarded(RewardPlacement.unsend);
    _busy = false;
    if (!ok || !mounted) return;
    setState(() {
      run.revive();
      phase = _Phase.playing;
      _overAt = -1;
      _x.clear();
      _fx.add(_Fx('banner', clock, 2.0, text: '↩️ Message unsent. Phew!', color: const Color(0xFF7CF0C0)));
    });
  }

  Future<void> _doubleCoins() async {
    if (_busy || _finalized) return;
    _busy = true;
    final ok = await App.ads.showRewarded(RewardPlacement.doubleCoins);
    _busy = false;
    if (!mounted) return;
    setState(() => _finalize(doubled: ok));
  }

  Future<void> _again() async {
    if (_busy) return;
    _finalize();
    _busy = true;
    await App.ads.afterRun();
    _busy = false;
    if (mounted) setState(_newRun);
  }

  Future<void> _home() async {
    if (_busy) return;
    if (phase == _Phase.over) {
      _finalize();
      _busy = true;
      await App.ads.afterRun();
      _busy = false;
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final shakeOff = _shake > 0 ? Offset(math.sin(clock * 90) * 9 * _shake, math.cos(clock * 77) * 5 * _shake) : Offset.zero;
    return Scaffold(
      backgroundColor: Pal.night,
      body: Backdrop(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: shakeOff,
              child: SafeArea(
                child: Column(
                  children: [
                    _topBar(),
                    Expanded(child: LayoutBuilder(builder: (_, c) => _playArea(Size(c.maxWidth, c.maxHeight)))),
                    _dock(),
                  ],
                ),
              ),
            ),
            if (_flash > 0)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1,
                      colors: [
                        Colors.transparent,
                        Pal.seen.withValues(alpha: 0.45 * _flash),
                      ],
                    ),
                  ),
                ),
              ),
            if (paused) _pauseOverlay(),
            if (phase == _Phase.over) _gameOver(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.pause_rounded, onTap: phase == _Phase.playing ? () => setState(() => paused = true) : null),
          Expanded(
            child: Column(
              children: [
                Text('${_shownScore.round()}', style: displayStyle(40)),
                Text('BEST ${math.max(App.progress.best, run.score)}', style: uiStyle(12, color: Pal.dim, weight: 700)),
              ],
            ),
          ),
          _strikes(),
        ],
      ),
    );
  }

  Widget _strikes() {
    return Glass(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      radius: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < Run.maxStrikes; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedScale(
                scale: i < run.strikes ? 1.15 : 0.85,
                duration: const Duration(milliseconds: 260),
                curve: Curves.elasticOut,
                child: Opacity(
                  opacity: i < run.strikes ? 1 : 0.3,
                  child: Text(i < run.strikes ? '😬' : '💬', style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _playArea(Size s) {
    final w = s.width;
    final lw = _laneW(w);
    final grabbed = _grab == null ? null : run.byId(_grab!);
    final children = <Widget>[];

    // lane guides
    for (var i = 0; i < run.lanes.length; i++) {
      final chat = run.lanes[i];
      final aimed = grabbed?.lane == i;
      children.add(
        Positioned(
          left: i * lw + 3,
          width: lw - 6,
          top: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  chat.color.withValues(alpha: 0),
                  chat.color.withValues(alpha: aimed ? 0.30 : 0.08),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Do Not Disturb tint
    if (run.slowLeft > 0) {
      children.add(
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: const Color(0xFF4060FF).withValues(alpha: 0.08 + 0.04 * math.sin(clock * 4))),
          ),
        ),
      );
    }

    // bubbles
    final bw = _bubbleW(w);
    final k = 1 - math.exp(-18 * 0.016);
    for (final b in run.bubbles) {
      final target = _targetX(b, w);
      final x = _x[b.id] = _x.containsKey(b.id) ? _x[b.id]! + (target - _x[b.id]!) * k : target;
      final top = b.y * s.height - _bubbleH;
      final chat = run.lanes.firstWhere((c) => c.id == b.msg.to, orElse: () => run.lanes.first);
      final colors = b.hinted ? [chat.color, Color.lerp(chat.color, Pal.ink, 0.35)!] : const [Pal.you1, Pal.you2];
      final isGrab = b.id == _grab;
      // urgency: an unsent text about to land pulses red (says nothing about where it should go)
      final danger = !b.sending && b.y > 0.8;
      final glow = isGrab
          ? Colors.white
          : danger
          ? Color.lerp(colors.first, Pal.seen, 0.5 + 0.5 * math.sin(clock * 18))!
          : colors.first;
      children.add(
        Positioned(
          left: x - bw / 2,
          top: top,
          width: bw,
          height: _bubbleH,
          child: Transform.scale(
            scaleX: b.sending ? 0.94 : (isGrab ? 1.06 : 1),
            scaleY: b.sending ? 1.08 : (isGrab ? 1.06 : 1),
            child: CustomPaint(
              painter: BubblePainter(colors: colors, tailX: _laneCenter(b.lane, w) - (x - bw / 2), glow: glow),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Center(
                  child: Text(
                    b.msg.text,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: uiStyle(16.5, weight: 650, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    _x.removeWhere((id, _) => run.byId(id) == null);

    // replies popping up above the dock
    _replies.forEach((lane, r) {
      if (lane >= run.lanes.length) return;
      final a = ((clock - r.t0) / 1.5).clamp(0.0, 1.0);
      final rise = Curves.easeOutBack.transform(math.min(1, a * 4));
      final fade = a > 0.75 ? 1 - (a - 0.75) / 0.25 : 1.0;
      final cx = _laneCenter(lane, w).clamp(70.0, w - 70.0);
      children.add(
        Positioned(
          left: cx - 70,
          width: 140,
          bottom: 6 + 26 * rise,
          child: IgnorePointer(
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Center(
                child: Transform.scale(
                  scale: 0.6 + 0.4 * rise,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: r.good ? const Color(0xFF2C2752) : const Color(0xFF5A1430),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: r.good ? Pal.glassEdge : Pal.seen.withValues(alpha: 0.7)),
                    ),
                    child: clock - r.t0 < 0.32 ? _TypingDots(clock - r.t0) : Text(r.text, style: uiStyle(14, weight: 650), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });

    // effects
    for (final f in _fx) {
      final a = f.age(clock);
      switch (f.kind) {
        case 'float':
          final cx = _laneCenter(f.lane, w);
          final yOff = f.sub == 'q' ? 92.0 : 60.0;
          children.add(
            Positioned(
              left: cx - 60,
              width: 120,
              bottom: yOff + 70 * Curves.easeOut.transform(a),
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1 - a * a).clamp(0.0, 1.0),
                  child: Center(
                    child: Text(f.text, style: displayStyle(f.sub == 'q' ? 20 : 28, color: f.color)),
                  ),
                ),
              ),
            ),
          );
        case 'burst':
          children.add(
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _BurstPainter(Offset(_laneCenter(f.lane, w), s.height), a, f.color))),
            ),
          );
        case 'stamp':
          final pop = a < 0.16 ? 2.4 - 1.4 * Curves.easeIn.transform(a / 0.16) : 1.0;
          final fade = a > 0.8 ? 1 - (a - 0.8) / 0.2 : 1.0;
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: -0.21,
                      child: Transform.scale(
                        scale: pop,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                          decoration: BoxDecoration(
                            color: Pal.ink.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Pal.seen, width: 5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('SEEN ✓✓', style: displayStyle(58, color: Pal.seen)),
                              const SizedBox(height: 4),
                              Text('by ${f.sub}', style: uiStyle(16, weight: 700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        case 'combo':
          final sc = Curves.elasticOut.transform(math.min(1, a * 2.2));
          children.add(
            Positioned(
              left: 0,
              right: 0,
              top: s.height * 0.28,
              child: IgnorePointer(
                child: Opacity(
                  opacity: (a > 0.7 ? 1 - (a - 0.7) / 0.3 : 1.0).clamp(0.0, 1.0),
                  child: Center(
                    child: Transform.scale(
                      scale: 0.4 + 0.6 * sc,
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(colors: [Pal.gold, Color(0xFFFF7A59)]).createShader(r),
                        child: Text(f.text, style: displayStyle(44, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        case 'banner':
          final inA = Curves.easeOutBack.transform(math.min(1, a * 6));
          final out = a > 0.85 ? (a - 0.85) / 0.15 : 0.0;
          children.add(
            Positioned(
              left: 16,
              right: 16,
              top: 6 + 20 * (inA - 1) - 30 * out,
              child: IgnorePointer(
                child: Opacity(
                  opacity: (inA * (1 - out)).clamp(0.0, 1.0),
                  child: Glass(
                    color: f.color.withValues(alpha: 0.22),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(f.text, textAlign: TextAlign.center, style: uiStyle(15, weight: 700)),
                  ),
                ),
              ),
            ),
          );
      }
    }

    // tutorial: the waiting text, a hand showing where to drag it, and what to do next
    final tb = run.tutorialBubble;
    // (only once the text has arrived where it waits, so the coach never points at empty space)
    if (tb != null && tb.y >= Run.holdAt - 0.02 && phase == _Phase.playing) {
      final rect = _rectOf(tb, s);
      final target = run.lanes.indexWhere((c) => c.id == tb.msg.to);
      final chat = run.lanes[target];
      final aimed = run.aimedRight(tb);
      final loop = (clock * 0.8) % 1.0;
      final from = Offset(rect.center.dx, rect.bottom - 10);
      final to = aimed ? from + const Offset(0, 40) : Offset(_laneCenter(target, w), rect.bottom - 10);
      final hand = Offset.lerp(from, to, Curves.easeInOut.transform(math.min(1, loop * 1.4)))!;
      children.add(
        Positioned(
          left: 0,
          right: 0,
          top: rect.bottom + 70,
          child: IgnorePointer(
            child: Center(
              child: Glass(
                radius: 30,
                color: chat.color.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  aimed ? 'Perfect! Now TAP it to send ⬇' : 'This one\'s for ${chat.avatar} ${chat.name}.\nDrag it over their chat ↔',
                  textAlign: TextAlign.center,
                  style: uiStyle(16, weight: 700),
                ),
              ),
            ),
          ),
        ),
      );
      children.add(
        Positioned(
          left: hand.dx - 18,
          top: hand.dy,
          child: IgnorePointer(
            child: Opacity(
              opacity: (loop < 0.85 ? 1.0 : (1 - loop) / 0.15).clamp(0.0, 1.0),
              child: const Text('👆', style: TextStyle(fontSize: 40)),
            ),
          ),
        ),
      );
    } else if (App.progress.runs < 2 && run.delivered < 3 && !run.tutorial && phase == _Phase.playing) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          bottom: s.height * 0.42,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.75 + 0.25 * math.sin(clock * 4),
              child: Center(
                child: Glass(
                  radius: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Text(
                    '👆 Drag a text ↔ over the right chat\nthen tap or flick ⬇ to send',
                    textAlign: TextAlign.center,
                    style: uiStyle(14.5, weight: 650),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Do Not Disturb button
    final dnd = App.progress.dnd;
    children.add(
      Positioned(
        left: 10,
        top: 6,
        child: Pressable(
          onTap: dnd > 0 && run.slowLeft <= 0 && phase == _Phase.playing ? _useDnd : null,
          child: Glass(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            color: run.slowLeft > 0 ? const Color(0x554060FF) : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text(run.slowLeft > 0 ? '${run.slowLeft.ceil()}s' : '×$dnd', style: uiStyle(15, weight: 700)),
              ],
            ),
          ),
        ),
      ),
    );

    // combo meter
    if (run.multiplier > 1) {
      children.add(
        Positioned(
          right: 10,
          top: 6,
          child: Glass(
            radius: 30,
            color: const Color(0x33FFB020),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('🔥 x${run.multiplier}', style: uiStyle(15, weight: 700, color: Pal.gold)),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _panStart(d, s),
      onPanUpdate: (d) => _panUpdate(d, s),
      onPanEnd: _panEnd,
      onTapUp: (d) => _tap(d, s),
      child: Stack(clipBehavior: Clip.hardEdge, children: children),
    );
  }

  Widget _dock() {
    return Container(
      height: _dockH,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Pal.glassEdge),
      ),
      child: Row(children: [for (var i = 0; i < run.lanes.length; i++) Expanded(child: _chatCard(i))]),
    );
  }

  Widget _chatCard(int i) {
    final chat = run.lanes[i];
    final p = _pulse[i];
    final age = p == null ? 9.0 : clock - p;
    final bump = age < 0.5 ? math.sin(age / 0.5 * math.pi) * math.exp(-age * 4) : 0.0;
    final grabbed = _grab == null ? null : run.byId(_grab!);
    final aimed = grabbed?.lane == i;
    return Transform.scale(
      scale: 1 + 0.35 * bump + (aimed ? 0.08 : 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [chat.color, Color.lerp(chat.color, Pal.ink, 0.45)!]),
              border: Border.all(
                color: Colors.white.withValues(alpha: aimed ? 0.9 : 0.35),
                width: aimed ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: chat.color.withValues(alpha: aimed ? 0.7 : 0.35),
                  blurRadius: aimed ? 22 : 12,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(chat.avatar, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 5),
          Text(chat.name, style: uiStyle(13.5, weight: 700)),
        ],
      ),
    );
  }

  Widget _pauseOverlay() {
    return ColoredBox(
      color: Pal.ink.withValues(alpha: 0.82),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PAUSED', style: displayStyle(46)),
              const SizedBox(height: 8),
              Text('Your phone is face down. For now.', style: uiStyle(15, color: Pal.dim)),
              const SizedBox(height: 28),
              BigButton(label: 'RESUME', icon: '▶️', onTap: () => setState(() => paused = false)),
              const SizedBox(height: 14),
              BigButton(
                label: 'QUIT RUN',
                colors: const [Color(0xFF5B5680), Color(0xFF3B365E)],
                height: 54,
                fontSize: 20,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameOver() {
    final w = run.lastWrong;
    final wrongChat = w == null ? null : run.lanes[w.bubble.lane];
    final showUnsend = run.canRevive && !_finalized;
    final appear = Curves.easeOutBack.transform(((clock - _overAt) / 0.45).clamp(0.0, 1.0));
    return ColoredBox(
      color: Pal.ink.withValues(alpha: 0.86 * appear.clamp(0.0, 1.0)),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Transform.scale(
              scale: 0.85 + 0.15 * appear,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('CRINGE', style: displayStyle(50, color: Pal.seen)),
                  Text('OVERLOAD 😬', style: displayStyle(34)),
                  const SizedBox(height: 16),
                  if (w != null && wrongChat != null) ...[
                    RepaintBoundary(key: _receiptKey, child: _receipt(w.bubble.msg.text, wrongChat)),
                    const SizedBox(height: 8),
                    Pressable(
                      onTap: _share,
                      child: Glass(
                        radius: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('📸 Share the cringe', style: uiStyle(15, weight: 700)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stat('SCORE', '${run.score}'),
                      _stat('BEST', '${math.max(App.progress.best, run.score)}'),
                      _stat('COMBO', '🔥${run.bestCombo}'),
                    ],
                  ),
                  if (_finalized && _newBest && run.score > 0) ...[const SizedBox(height: 8), Text('🏆 NEW BEST!', style: displayStyle(26, color: Pal.gold))],
                  const SizedBox(height: 10),
                  Text(
                    _finalized ? '+$_earned 🪙 collected${_doubled ? ' (doubled!)' : ''}' : '+${run.coins} 🪙',
                    style: uiStyle(18, weight: 700, color: Pal.gold),
                  ),
                  const SizedBox(height: 18),
                  if (showUnsend) ...[
                    BigButton(
                      label: 'UNSEND',
                      icon: '↩️',
                      sub: '🎬 Watch a video, take back that text',
                      colors: const [Color(0xFFFF5F8F), Color(0xFFFF3B5C)],
                      onTap: _unsend,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!_finalized && run.coins >= 5) ...[
                    BigButton(
                      label: 'DOUBLE COINS',
                      icon: '🎬',
                      sub: '+${run.coins * 2} 🪙 instead of +${run.coins}',
                      colors: const [Color(0xFFFFC94D), Color(0xFFFF8A3D)],
                      height: 56,
                      fontSize: 22,
                      onTap: _doubleCoins,
                    ),
                    const SizedBox(height: 12),
                  ],
                  BigButton(label: 'PLAY AGAIN', icon: '🔁', height: 56, fontSize: 22, onTap: _again),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _home,
                    child: Text('Home', style: uiStyle(16, color: Pal.dim)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      children: [
        Text(label, style: uiStyle(11, color: Pal.dim, weight: 700)),
        const SizedBox(height: 2),
        Text(value, style: displayStyle(26)),
      ],
    ),
  );

  /// A mock chat screenshot of the worst wrong send.
  Widget _receipt(String text, Chat chat) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: const Color(0xFF15122E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Pal.glassEdge),
        boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 30, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Pal.glassEdge)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: chat.color),
                  child: Text(chat.avatar, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chat.name, style: uiStyle(15, weight: 700)),
                    Text('online', style: uiStyle(11, color: const Color(0xFF7CF0C0))),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Pal.you1, Pal.you2]),
                      borderRadius: BorderRadius.circular(18).copyWith(bottomRight: const Radius.circular(4)),
                    ),
                    child: Text(text, style: uiStyle(15, weight: 600, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Seen ✓✓ just now', style: uiStyle(10.5, color: Pal.seen, weight: 700)),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2752),
                      borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: const Radius.circular(4)),
                    ),
                    child: Text(_wrongReply, style: uiStyle(15, weight: 600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.origin, this.t, this.color);
  final Offset origin;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOut.transform(t);
    final paint = Paint()..color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
    for (var i = 0; i < 12; i++) {
      final ang = -math.pi * (0.1 + 0.8 * i / 11);
      final sp = 70.0 + (i * 37 % 50);
      final p = origin + Offset(math.cos(ang), math.sin(ang)) * sp * ease + Offset(0, 40 * t * t);
      canvas.drawCircle(p, (5 - 3 * t) * (i.isEven ? 1 : 0.7), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// "•••" typing indicator shown for a moment before a chat replies.
class _TypingDots extends StatelessWidget {
  const _TypingDots(this.t);
  final double t;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Transform.translate(
            offset: Offset(0, -4 * math.max(0, math.sin(t * 22 - i * 1.1))),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: Pal.dim, shape: BoxShape.circle),
            ),
          ),
        ),
    ],
  );
}
