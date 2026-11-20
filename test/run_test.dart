import 'package:flutter_test/flutter_test.dart';
import 'package:wrong_chat/ads/ad_pacing.dart';
import 'package:wrong_chat/core/chats.dart';
import 'package:wrong_chat/core/run.dart';

/// Runs the clock until a bubble exists.
Bubble firstBubble(Run r) {
  for (var i = 0; i < 400 && r.bubbles.isEmpty; i++) {
    r.tick(0.02);
  }
  return r.bubbles.first;
}

void landAll(Run r) {
  for (var i = 0; i < 200 && r.bubbles.any((b) => b.sending); i++) {
    r.tick(0.02);
  }
}

void main() {
  test('every message fits exactly one chat (no duplicates across chats)', () {
    final seen = <String, String>{};
    messageBank.forEach((chat, lines) {
      for (final l in lines) {
        expect(seen.containsKey(l), isFalse, reason: '"$l" is in ${seen[l]} and $chat');
        seen[l] = chat;
      }
    });
    for (final c in Chats.all) {
      expect(messageBank[c.id], isNotEmpty);
    }
  });

  test('right chat scores and builds combo; wrong chat is a strike and resets combo', () {
    final r = Run(seed: 1);
    final b = firstBubble(r);
    final right = r.lanes.indexWhere((c) => c.id == b.msg.to);
    r.steer(b.id, right);
    r.send(b.id);
    landAll(r);
    expect(r.delivered, 1);
    expect(r.combo, 1);
    expect(r.score, greaterThanOrEqualTo(10));
    expect(r.events.whereType<Delivered>(), hasLength(1));

    r.events.clear();
    final b2 = firstBubble(r);
    final wrong = (r.lanes.indexWhere((c) => c.id == b2.msg.to) + 1) % r.lanes.length;
    r.steer(b2.id, wrong);
    r.send(b2.id);
    landAll(r);
    expect(r.strikes, 1);
    expect(r.combo, 0);
    expect(r.lastWrong?.bubble.id, b2.id);
  });

  test('quick sends earn +5', () {
    final r = Run(seed: 2);
    final b = firstBubble(r);
    r.steer(b.id, r.lanes.indexWhere((c) => c.id == b.msg.to));
    r.send(b.id); // sent near the top
    landAll(r);
    final d = r.events.whereType<Delivered>().single;
    expect(d.quick, isTrue);
    expect(d.points, 15);
  });

  test('three wrong sends end the run; unsend works once', () {
    final r = Run(seed: 3);
    while (!r.over) {
      final b = firstBubble(r);
      r.steer(b.id, (r.lanes.indexWhere((c) => c.id == b.msg.to) + 1) % r.lanes.length);
      r.send(b.id);
      landAll(r);
    }
    expect(r.events.whereType<RunOver>(), hasLength(1));
    expect(r.canRevive, isTrue);
    r.revive();
    expect(r.over, isFalse);
    expect(r.strikes, Run.maxStrikes - 1);
    expect(r.bubbles, isEmpty);
    expect(r.canRevive, isFalse);
  });

  test('Squad joins after enough correct sends; speed is capped', () {
    final r = Run(seed: 4);
    while (r.delivered < Chats.squadUnlockAt) {
      final b = firstBubble(r);
      r.steer(b.id, r.lanes.indexWhere((c) => c.id == b.msg.to));
      r.send(b.id);
      landAll(r);
      r.bubbles.removeWhere((x) => !x.sending); // keep the test focused on one bubble at a time
    }
    expect(r.lanes.map((c) => c.id), contains('squad'));
    expect(r.events.whereType<LaneJoined>(), hasLength(1));
    r.delivered = 10000;
    expect(r.fallSpeed, 0.32);
    expect(r.spawnGap, 0.8);
  });

  test('tutorial texts wait for the player and only send once aimed right', () {
    final r = Run(seed: 5, tutorial: true);
    final b = firstBubble(r);
    expect(b.hold, isTrue);
    expect(r.aimedRight(b), isFalse, reason: 'tutorial texts start over the wrong chat');
    for (var i = 0; i < 1000; i++) {
      r.tick(0.02); // 20 s: it must not land, and nothing else may spawn
    }
    expect(b.y, Run.holdAt);
    expect(r.bubbles, hasLength(1));
    expect(r.strikes, 0);
    r.send(b.id);
    expect(b.sending, isFalse, reason: 'wrong aim is ignored in the tutorial');
    r.steer(b.id, r.lanes.indexWhere((c) => c.id == b.msg.to));
    r.send(b.id);
    landAll(r);
    expect(r.delivered, 1);
    final b2 = firstBubble(r);
    expect(b2.hold, isTrue);
    r.steer(b2.id, r.lanes.indexWhere((c) => c.id == b2.msg.to));
    r.send(b2.id);
    landAll(r);
    expect(firstBubble(r).hold, isFalse, reason: 'only ${Run.tutorialSteps} tutorial texts');
  });

  test('ad pacing: none in first 3 sessions, then every 3rd run, never after a rewarded ad', () {
    var now = DateTime(2026);
    final early = AdPacing(sessions: 2, now: () => now);
    for (var i = 0; i < 6; i++) {
      expect(early.runFinished(), isFalse);
    }
    final p = AdPacing(sessions: 5, now: () => now);
    expect(p.runFinished(), isFalse);
    expect(p.runFinished(), isFalse);
    expect(p.runFinished(), isTrue);
    now = now.add(const Duration(seconds: 30));
    expect(p.runFinished(), isFalse); // too soon
    now = now.add(const Duration(minutes: 5));
    p.noteRewarded();
    expect(p.runFinished(), isFalse); // right after a rewarded ad
    now = now.add(const Duration(minutes: 5));
    expect(p.runFinished(), isTrue);
  });
}
