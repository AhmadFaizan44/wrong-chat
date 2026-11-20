import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrong_chat/ads/ad_pacing.dart';
import 'package:wrong_chat/ads/ad_service.dart';
import 'package:wrong_chat/core/chats.dart';
import 'package:wrong_chat/save/progress.dart';
import 'package:wrong_chat/ui/game_screen.dart';
import 'package:wrong_chat/ui/menu_screen.dart';
import 'package:wrong_chat/ui/widgets.dart';

String? chatFor(String text) {
  for (final e in messageBank.entries) {
    if (e.value.contains(text)) return e.key;
  }
  return null;
}

Future<void> pumpFrames(WidgetTester t, double seconds) async {
  for (var i = 0; i < (seconds / 0.016).round(); i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() {
    App.progress = Progress.memory();
    App.ads = StubAdService(AdPacing(sessions: 1), App.nav);
  });

  Widget host(Widget child) => MaterialApp(navigatorKey: App.nav, home: child);

  testWidgets('menu shows the logo and play button', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(host(const MenuScreen()));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('WRONG'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('dragging a text onto the right chat and tapping it delivers it', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(host(const GameScreen(seed: 7)));

    // wait for the first text to fall into view
    Finder bubble = find.byWidgetPredicate((w) => w is Text && w.data != null && chatFor(w.data!) != null);
    for (var i = 0; i < 200 && bubble.evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await pumpFrames(t, 1.5);
    expect(bubble, findsOneWidget);
    final text = (t.widget(bubble) as Text).data!;
    final target = Chats.all.indexWhere((c) => c.id == chatFor(text));
    expect(target, inInclusiveRange(0, Chats.startLanes - 1));

    final width = t.view.physicalSize.width / t.view.devicePixelRatio;
    final laneW = width / Chats.startLanes;
    final start = t.getCenter(bubble);
    final gesture = await t.startGesture(start);
    await t.pump(const Duration(milliseconds: 16));
    final destX = (target + 0.5) * laneW;
    for (var k = 1; k <= 10; k++) {
      await gesture.moveTo(Offset(start.dx + (destX - start.dx) * k / 10, start.dy));
      await t.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await pumpFrames(t, 0.3);

    await t.tapAt(t.getCenter(bubble));
    await pumpFrames(t, 1.2);

    expect(find.text('0'), findsNothing, reason: 'score should have gone up');
    expect(find.textContaining('SEEN'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
