import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../audio/sfx.dart';
import '../save/progress.dart';

/// App-wide singletons, set up once at boot.
class App {
  static final nav = GlobalKey<NavigatorState>();
  static late Progress progress;
  static late AdService ads;
}

class Pal {
  static const night = Color(0xFF0A0720);
  static const night2 = Color(0xFF1A1046);
  static const ink = Color(0xFF070418);
  static const text = Color(0xFFF2EEFF);
  static const dim = Color(0xA6D9D2FF);
  static const you1 = Color(0xFF3D7BFF);
  static const you2 = Color(0xFF8A5BFF);
  static const seen = Color(0xFFFF3B5C);
  static const gold = Color(0xFFFFD34D);
  static const glass = Color(0x1AFFFFFF);
  static const glassEdge = Color(0x33FFFFFF);
}

TextStyle uiStyle(double size, {Color color = Pal.text, double weight = 600, double height = 1.15}) => TextStyle(
  fontFamily: 'Fredoka',
  fontSize: size,
  color: color,
  fontVariations: [FontVariation('wght', weight)],
  decoration: TextDecoration.none,
  height: height,
);

TextStyle displayStyle(double size, {Color color = Pal.text, List<Shadow>? shadows}) => TextStyle(
  fontFamily: 'Lilita',
  fontSize: size,
  color: color,
  decoration: TextDecoration.none,
  height: 1.0,
  letterSpacing: 0.5,
  shadows: shadows ?? const [Shadow(color: Color(0x99000000), offset: Offset(0, 3), blurRadius: 0)],
);

/// Shrinks a little while pressed, clicks and buzzes on tap.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.94});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap == null
        ? null
        : () {
            Sfx.play('click', volume: 0.6);
            Sfx.haptic();
            widget.onTap!();
          },
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: AnimatedOpacity(opacity: widget.onTap == null ? 0.45 : 1, duration: const Duration(milliseconds: 150), child: widget.child),
    ),
  );
}

/// A chunky glossy button with a gradient face and a darker lip underneath.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    this.onTap,
    this.colors = const [Pal.you1, Pal.you2],
    this.icon,
    this.sub,
    this.height = 64,
    this.fontSize = 26,
  });
  final String label;
  final String? icon;
  final String? sub;
  final VoidCallback? onTap;
  final List<Color> colors;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final lip = Color.lerp(colors.last, Colors.black, 0.45)!;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2.6),
          color: lip,
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2.6),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          child: Stack(
            children: [
              // gloss
              Positioned(
                left: 10,
                right: 10,
                top: 4,
                height: height * 0.32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[Text(icon!, style: TextStyle(fontSize: fontSize * 0.9)), const SizedBox(width: 10)],
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(label, style: displayStyle(fontSize)),
                            ),
                            if (sub != null) Text(sub!, style: uiStyle(12, color: Colors.white.withValues(alpha: 0.85))),
                          ],
                        ),
                      ),
                    ],
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

/// Frosted rounded panel.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 22, this.color});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Pal.glass,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Pal.glassEdge, width: 1.2),
    ),
    child: child,
  );
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, this.onTap, this.size = 46});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Pal.glass,
        border: Border.all(color: Pal.glassEdge, width: 1.2),
      ),
      child: Icon(icon, color: Pal.text, size: size * 0.5),
    ),
  );
}

class CoinChip extends StatelessWidget {
  const CoinChip(this.coins, {super.key});
  final int coins;
  @override
  Widget build(BuildContext context) => Glass(
    padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
    radius: 30,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🪙', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text('$coins', style: uiStyle(18, weight: 700)),
      ],
    ),
  );
}

/// Midnight gradient with slow drifting colour glows (the four chat colours).
class Backdrop extends StatefulWidget {
  const Backdrop({super.key, required this.child, this.flash});

  final Widget child;

  /// 0..1 red flash over everything (wrong send).
  final double? flash;
  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _GlowPainter(_c.value)),
        ),
      ),
      widget.child,
    ],
  );
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.t);
  final double t;
  static const _blobs = [Color(0xFFFF9F43), Color(0xFF4DA3FF), Color(0xFFFF5FA2), Color(0xFF3DDC97), Color(0xFF8A5BFF)];

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Pal.night2, Pal.night]).createShader(r),
    );
    final a = t * 2 * math.pi;
    for (var i = 0; i < _blobs.length; i++) {
      final ph = i * 1.7;
      final c = Offset(size.width * (0.5 + 0.42 * math.sin(a + ph)), size.height * (0.45 + 0.4 * math.cos(a * (i.isEven ? 1 : -1) + ph * 1.3)));
      final rad = size.width * (0.55 + 0.1 * math.sin(a * 2 + i));
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..shader = RadialGradient(colors: [_blobs[i].withValues(alpha: 0.16), _blobs[i].withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: rad)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}

/// Chat-bubble shape: rounded rectangle with a little tail on the bottom edge at [tailX].
class BubblePainter extends CustomPainter {
  BubblePainter({required this.colors, required this.tailX, this.glow, this.tailDown = true, this.radius = 20});
  final List<Color> colors;
  final double tailX;
  final Color? glow;
  final bool tailDown;
  final double radius;

  Path _path(Size s) {
    final body = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(radius));
    final p = Path()..addRRect(body);
    final tx = tailX.clamp(radius * 0.8, s.width - radius * 0.8);
    final tail = Path();
    if (tailDown) {
      tail
        ..moveTo(tx - 9, s.height - 2)
        ..quadraticBezierTo(tx, s.height + 4, tx, s.height + 12)
        ..quadraticBezierTo(tx + 3, s.height + 3, tx + 11, s.height - 2)
        ..close();
    } else {
      tail
        ..moveTo(tx - 9, 2)
        ..quadraticBezierTo(tx, -4, tx - 2, -11)
        ..quadraticBezierTo(tx + 5, -3, tx + 11, 2)
        ..close();
    }
    return Path.combine(PathOperation.union, p, tail);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    if (glow != null) {
      canvas.drawPath(
        path.shift(const Offset(0, 6)),
        Paint()
          ..color = glow!.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black.withValues(alpha: 0.28));
    final r = Offset.zero & size;
    canvas.drawPath(path, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors).createShader(r));
    // top sheen
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
        ).createShader(r),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BubblePainter old) => old.tailX != tailX || old.colors != colors || old.glow != glow;
}
