// Renders the Wrong Chat app icon to assets/icon/*.png (a glossy chat bubble with a red SEEN ✓✓ stamp).
// Run from wrong-chat/:  flutter test tool/gen_icon_test.dart   then   sh tool/gen_icons.sh
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _px = 1024.0;

void _background(Canvas c) {
  const r = Rect.fromLTWH(0, 0, _px, _px);
  c.drawRect(r, Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(_px, _px), const [Color(0xFF2A1670), Color(0xFF0A0720)]));
  c.drawRect(r, Paint()..shader = ui.Gradient.radial(const Offset(_px * 0.2, _px * 0.15), _px * 0.7, const [Color(0x664DA3FF), Color(0x004DA3FF)]));
  c.drawRect(r, Paint()..shader = ui.Gradient.radial(const Offset(_px * 0.85, _px * 0.9), _px * 0.7, const [Color(0x66FF5FA2), Color(0x00FF5FA2)]));
}

Path _bubblePath(Rect b) {
  final body = Path()..addRRect(RRect.fromRectAndRadius(b, Radius.circular(b.height * 0.32)));
  final tx = b.left + b.width * 0.26;
  final tail = Path()
    ..moveTo(tx - b.width * 0.05, b.bottom - 4)
    ..quadraticBezierTo(tx, b.bottom + b.height * 0.1, tx - b.width * 0.07, b.bottom + b.height * 0.25)
    ..quadraticBezierTo(tx + b.width * 0.08, b.bottom + b.height * 0.16, tx + b.width * 0.12, b.bottom - 4)
    ..close();
  return Path.combine(PathOperation.union, body, tail);
}

void _check(Canvas c, Offset o, double s, Paint p) {
  c.drawPath(
    Path()
      ..moveTo(o.dx, o.dy + s * 0.5)
      ..lineTo(o.dx + s * 0.35, o.dy + s * 0.85)
      ..lineTo(o.dx + s, o.dy),
    p,
  );
}

/// The bubble + stamp, centred, [size] wide.
void _mark(Canvas c, double size) {
  final cx = _px / 2, cy = _px / 2;
  final b = Rect.fromCenter(center: Offset(cx, cy - size * 0.06), width: size, height: size * 0.68);
  final path = _bubblePath(b);
  // shadow
  c.drawPath(
    path.shift(Offset(0, size * 0.04)),
    Paint()
      ..color = const Color(0x88000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.04),
  );
  // body
  c.drawPath(path, Paint()..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, const [Color(0xFF4D8BFF), Color(0xFF8A5BFF)]));
  // gloss
  c.save();
  c.clipPath(path);
  c.drawRect(
    Rect.fromLTWH(b.left, b.top, b.width, b.height * 0.48),
    Paint()..shader = ui.Gradient.linear(b.topCenter, b.center, const [Color(0x55FFFFFF), Color(0x00FFFFFF)]),
  );
  c.restore();
  // typing dots
  final dot = Paint()..color = const Color(0xFFFFFFFF);
  for (var i = -1; i <= 1; i++) {
    c.drawCircle(Offset(cx + i * size * 0.2, b.center.dy - size * 0.02), size * 0.065, dot);
  }

  // SEEN ✓✓ stamp, tilted across the lower right
  c.save();
  c.translate(cx + size * 0.12, cy + size * 0.3);
  c.rotate(-0.26);
  final sw = size * 0.8, sh = size * 0.27;
  final stamp = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: sw, height: sh), Radius.circular(sh * 0.22));
  c.drawRRect(stamp.shift(Offset(0, size * 0.02)), Paint()..color = const Color(0x66000000));
  c.drawRRect(stamp, Paint()..color = const Color(0xFF1A0B2E));
  c.drawRRect(
    stamp,
    Paint()
      ..color = const Color(0xFFFF3B5C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sh * 0.11,
  );
  final tp = TextPainter(
    text: TextSpan(
      text: 'SEEN',
      style: TextStyle(fontFamily: 'Lilita', fontSize: sh * 0.62, color: const Color(0xFFFF3B5C), height: 1),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final textX = -sw / 2 + sw * 0.1;
  tp.paint(c, Offset(textX, -tp.height / 2 + sh * 0.03));
  final ck = Paint()
    ..color = const Color(0xFFFF3B5C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = sh * 0.1
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final cs = sh * 0.32;
  final ckX = textX + tp.width + sw * 0.05;
  _check(c, Offset(ckX, -cs / 2), cs, ck);
  _check(c, Offset(ckX + cs * 0.72, -cs / 2), cs, ck);
  c.restore();
}

Future<void> _save(String path, void Function(Canvas c) paint) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final img = await rec.endRecording().toImage(_px.toInt(), _px.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render app icon', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Lilita')..addFont(Future.value(ByteData.sublistView(File('assets/fonts/LilitaOne-Regular.ttf').readAsBytesSync())));
      await loader.load();
      await _save('assets/icon/icon.png', (c) {
        _background(c);
        _mark(c, _px * 0.72);
      });
      await _save('assets/icon/icon_bg.png', _background);
      // adaptive icons crop to roughly the centre 66%
      await _save('assets/icon/icon_fg.png', (c) => _mark(c, _px * math.min(0.5, 1.0)));
    });
  });
}
