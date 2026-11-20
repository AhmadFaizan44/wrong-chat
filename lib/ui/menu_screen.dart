import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ads/ad_pacing.dart';
import '../ads/ad_service.dart';
import '../audio/sfx.dart';
import '../core/chats.dart';
import '../core/run.dart';
import '../save/progress.dart';
import 'game_screen.dart';
import 'widgets.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    Sfx.play('whoosh');
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => const GameScreen(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 1.06, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _getDnd() async {
    final p = App.progress;
    if (p.freeDndReady) {
      setState(p.claimFreeDnd);
      Sfx.play('coin');
      return;
    }
    if (_busy) return;
    _busy = true;
    final ok = await App.ads.showRewarded(RewardPlacement.freeDnd);
    _busy = false;
    if (ok && mounted) {
      setState(() {
        p.dnd++;
        p.save();
      });
      Sfx.play('coin');
    }
  }

  void _buyDnd() {
    if (App.progress.buyDnd()) {
      Sfx.play('coin');
      setState(() {});
    } else {
      Sfx.play('invalid', volume: 0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = App.progress;
    return Scaffold(
      backgroundColor: Pal.night,
      body: Backdrop(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(animation: _c, builder: (_, _) => _FloatingTexts(_c.value)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (_, box) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CoinChip(p.coins),
                              const Spacer(),
                              RoundIconButton(
                                icon: p.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                onTap: () => setState(() {
                                  p.muted = !p.muted;
                                  Sfx.muted = p.muted;
                                  Music.enabled = !p.muted;
                                  p.save();
                                }),
                              ),
                              const SizedBox(width: 10),
                              RoundIconButton(icon: Icons.help_outline_rounded, onTap: () => showHowToPlay(context)),
                            ],
                          ),
                          const Spacer(flex: 2),
                          AnimatedBuilder(animation: _c, builder: (_, _) => _Logo(_c.value)),
                          const SizedBox(height: 14),
                          Text(
                            'Flick every text to the right person.\nOne wrong send and it\'s ✓✓ SEEN.',
                            textAlign: TextAlign.center,
                            style: uiStyle(16, color: Pal.dim),
                          ),
                          const Spacer(flex: 2),
                          if (p.best > 0) ...[Text('BEST  ${p.best}', style: displayStyle(24, color: Pal.gold)), const SizedBox(height: 14)],
                          BigButton(label: 'PLAY', icon: '💬', height: 76, fontSize: 36, onTap: _play),
                          const SizedBox(height: 16),
                          _dndCard(p),
                          const Spacer(),
                          Text('Ad-supported · rules & odds under ?', style: uiStyle(11.5, color: Pal.dim.withValues(alpha: 0.5))),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dndCard(Progress p) {
    final free = p.freeDndReady;
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Do Not Disturb ×${p.dnd}', maxLines: 1, overflow: TextOverflow.ellipsis, style: uiStyle(15, weight: 700)),
                Text(
                  'Slows texts for ${Run.dndSeconds.round()} s',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(12, color: Pal.dim),
                ),
              ],
            ),
          ),
          _smallBtn(free ? '🎁 Free' : '🎬 +1', free ? const Color(0xFF3DDC97) : const Color(0xFFFF9F43), _getDnd),
          const SizedBox(width: 6),
          _smallBtn('${Progress.dndPrice}🪙', p.coins >= Progress.dndPrice ? Pal.you1 : const Color(0xFF4A4670), _buyDnd),
        ],
      ),
    );
  }

  Widget _smallBtn(String label, Color c, VoidCallback onTap) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
      child: Text(label, style: uiStyle(14, weight: 700, color: Colors.white)),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo(this.t);
  final double t;
  @override
  Widget build(BuildContext context) {
    final bob = math.sin(t * 2 * math.pi * 2) * 4;
    final stampPulse = 1 + 0.04 * math.sin(t * 2 * math.pi * 3);
    return SizedBox(
      height: 190,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, bob),
                child: CustomPaint(
                  painter: BubblePainter(colors: const [Pal.you1, Pal.you2], tailX: 210, glow: Pal.you2, radius: 34),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 18, 26, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('WRONG', style: displayStyle(62)),
                        Text('CHAT', style: displayStyle(62)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: 4,
                child: Transform.rotate(
                  angle: -0.25,
                  child: Transform.scale(
                    scale: stampPulse,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
                      decoration: BoxDecoration(
                        color: Pal.ink.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Pal.seen, width: 3),
                      ),
                      child: Text('SEEN ✓✓', style: displayStyle(22, color: Pal.seen)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faint message bubbles drifting up behind the menu.
class _FloatingTexts extends StatelessWidget {
  const _FloatingTexts(this.t);
  final double t;
  static final _lines = [for (final l in messageBank.values) ...l.take(4)];
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final kids = <Widget>[];
        for (var i = 0; i < 9; i++) {
          final speed = 0.6 + (i % 3) * 0.25;
          final p = (t * speed + i / 9) % 1.0;
          final x = (i * 0.37 % 1.0) * (c.maxWidth - 150);
          final y = c.maxHeight * (1.1 - p * 1.3);
          kids.add(
            Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: 0.10 + 0.08 * math.sin(p * math.pi),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                  child: Text(_lines[(i * 5) % _lines.length], style: uiStyle(13, color: Pal.ink)),
                ),
              ),
            ),
          );
        }
        return IgnorePointer(child: Stack(children: kids));
      },
    );
  }
}

/// Rules, scoring and ad rules — shown openly to every player.
void showHowToPlay(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF14102E),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        children: [
          Center(child: Text('HOW TO PLAY', style: displayStyle(30))),
          const SizedBox(height: 14),
          _rule('👆', 'Drag a falling text left or right. Its little tail shows which chat it will land in.'),
          _rule('⬇️', 'Tap it or flick it down to send it right away. Sending before it\'s halfway down gives +5 QUICK bonus.'),
          _rule('✅', 'Right chat: 10 points × your combo. The combo goes up by 1 for every 4 correct sends in a row (max ×5).'),
          _rule('😬', 'Wrong chat: ✓✓ SEEN. Your combo resets. 3 wrong sends end the run.'),
          _rule('🎉', 'After ${Chats.squadUnlockAt} correct sends, the Squad group chat joins.'),
          _rule(
            '🌙',
            'Do Not Disturb slows every text to 45% speed for ${Run.dndSeconds.round()} s. 1 free per day, or 🎬 a video, or ${Progress.dndPrice} 🪙.',
          ),
          _rule('🪙', 'You earn 1 coin per 10 points.'),
          const SizedBox(height: 10),
          Text('FAIR PLAY', style: displayStyle(20, color: Pal.gold)),
          const SizedBox(height: 6),
          Text(
            'Every player gets the same rules. Speed rises with how many texts you\'ve delivered in this run, up to a fixed cap. '
            'Each chat is equally likely to get the next text. Every message fits exactly one chat. The first ${Run.hintedSpawns} texts '
            'of each run are coloured as a hint. Nothing is adjusted per player.',
            style: uiStyle(14, color: Pal.dim, height: 1.35),
          ),
          const SizedBox(height: 14),
          Text('ADS', style: displayStyle(20, color: Pal.gold)),
          const SizedBox(height: 6),
          Text(
            'Videos are always your choice: ↩️ Unsend (once per run), double coins, or a Do Not Disturb. '
            'A short skippable break may appear between runs: never in your first 3 sessions, at most once every '
            '${AdPacing.runsBetween} runs, at least ${AdPacing.interstitialGap.inSeconds} s apart, and never right after another ad.',
            style: uiStyle(14, color: Pal.dim, height: 1.35),
          ),
          const SizedBox(height: 16),
          Text('WHO GETS WHAT', style: displayStyle(20, color: Pal.gold)),
          const SizedBox(height: 6),
          for (final c in Chats.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${c.avatar} ${c.name}: ${messageBank[c.id]!.take(3).join('  ·  ')}', style: uiStyle(13.5, color: Pal.text, height: 1.3)),
            ),
        ],
      ),
    ),
  );
}

Widget _rule(String icon, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 34, child: Text(icon, style: const TextStyle(fontSize: 22))),
      Expanded(child: Text(text, style: uiStyle(15, height: 1.3))),
    ],
  ),
);
