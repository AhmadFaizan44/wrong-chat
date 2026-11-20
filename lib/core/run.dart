import 'dart:math';

import 'chats.dart';

/// A message bubble falling towards the dock.
class Bubble {
  Bubble(this.id, this.msg, this.lane, {required this.hinted});
  final int id;
  final Msg msg;

  /// The dock column the bubble is aimed at (where it will land).
  int lane;

  /// 0 = top of the play area, 1 = the dock.
  double y = -Run.bubbleHeight;
  bool sending = false;

  /// Training wheels: tinted in its chat's colour.
  final bool hinted;

  /// Where it was when the player sent it (for the "quick send" bonus).
  double? sentAt;

  /// Tutorial texts wait at [Run.holdAt] until the player aims and sends them.
  bool hold = false;
}

sealed class RunEvent {}

class Delivered extends RunEvent {
  Delivered(this.bubble, this.points, {required this.quick, required this.combo});
  final Bubble bubble;
  final int points;
  final bool quick;
  final int combo;
}

class WrongSend extends RunEvent {
  WrongSend(this.bubble);
  final Bubble bubble;
}

class LaneJoined extends RunEvent {
  LaneJoined(this.chat);
  final Chat chat;
}

class RunOver extends RunEvent {}

/// The rules of one run. Pure Dart: the UI calls [tick] every frame and reads [events].
///
/// Published rules (the same for every player, nothing is tuned per person):
///  - messages fall faster and arrive more often as your delivered count grows, up to a fixed cap;
///  - every message fits exactly one chat; the first [hintedSpawns] messages of a run are tinted as a hint;
///  - 3 wrong sends end the run; one "Unsend" (rewarded ad) per run takes back the last wrong send.
class Run {
  /// [tutorial]: the player's very first run. The first [tutorialSteps] texts wait for the player.
  Run({int? seed, this.tutorial = false}) : _rng = Random(seed) {
    _deck = MessageDeck(_rng);
    lanes = List.of(Chats.all.take(Chats.startLanes));
  }

  static const maxStrikes = 3;
  static const bubbleHeight = 0.11;
  static const hintedSpawns = 5;
  static const sendSpeed = 2.6;
  static const quickBefore = 0.45;
  static const dndSeconds = 8.0;
  static const tutorialSteps = 2;
  static const holdAt = 0.42;

  final bool tutorial;

  final Random _rng;
  late final MessageDeck _deck;
  late final List<Chat> lanes;
  final List<Bubble> bubbles = [];
  final List<RunEvent> events = [];

  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int strikes = 0;
  int delivered = 0;
  int spawned = 0;
  double time = 0;
  double _spawnIn = 0.6;
  double slowLeft = 0;
  double graceLeft = 0;
  bool revived = false;
  bool get over => strikes >= maxStrikes;

  /// The most embarrassing wrong send this run (shown on the game-over card).
  WrongSend? lastWrong;
  int _ids = 0;

  /// Falling speed in play-heights per second.
  double get fallSpeed => min(0.105 + 0.0055 * delivered, 0.32);

  /// Seconds between new messages.
  double get spawnGap => max(0.8, 2.5 - 0.04 * delivered);

  int get maxOnScreen => min(2 + delivered ~/ 7, 6);

  /// Combo multiplier: x1, then +1 every 4 correct sends in a row, up to x5.
  int get multiplier => 1 + min(combo ~/ 4, 4);

  void tick(double dt) {
    if (over) return;
    dt = min(dt, 0.05);
    time += dt;
    if (graceLeft > 0) {
      graceLeft = max(0, graceLeft - dt);
      return;
    }
    final slow = slowLeft > 0 ? 0.45 : 1.0;
    slowLeft = max(0, slowLeft - dt);

    _spawnIn -= dt * slow;
    if (tutorialBubble != null) _spawnIn = max(_spawnIn, 0.5);
    if (_spawnIn <= 0 && bubbles.length < maxOnScreen && _topClear()) {
      _spawn();
      _spawnIn = spawnGap;
    }

    for (final b in List.of(bubbles)) {
      b.y += (b.sending ? sendSpeed : fallSpeed * slow) * dt;
      if (b.hold && !b.sending && b.y > holdAt) b.y = holdAt;
      if (b.y >= 1) _land(b);
      if (over) return;
    }
  }

  bool _topClear() => bubbles.every((b) => b.y > bubbleHeight * 1.6);

  void _spawn() {
    final chat = lanes[_rng.nextInt(lanes.length)];
    final msg = _deck.draw(chat.id);
    // Start above a different column than the answer most of the time, so every message needs a swipe.
    var lane = _rng.nextInt(lanes.length);
    final teach = tutorial && spawned < tutorialSteps;
    if (lane == lanes.indexOf(chat) && (teach || _rng.nextDouble() < 0.75)) lane = (lane + 1 + _rng.nextInt(lanes.length - 1)) % lanes.length;
    bubbles.add(Bubble(_ids++, msg, lane, hinted: spawned < hintedSpawns)..hold = teach);
    spawned++;
  }

  /// The tutorial text currently waiting for the player, if any.
  Bubble? get tutorialBubble {
    for (final b in bubbles) {
      if (b.hold && !b.sending) return b;
    }
    return null;
  }

  /// True if [b] is aimed at the chat it belongs to (used only by the tutorial coach).
  bool aimedRight(Bubble b) => lanes[b.lane].id == b.msg.to;

  Bubble? byId(int id) {
    for (final b in bubbles) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Aim a bubble at a dock column (the player is dragging it sideways).
  void steer(int id, int lane) {
    final b = byId(id);
    if (b == null || b.sending || over) return;
    b.lane = lane.clamp(0, lanes.length - 1);
  }

  /// Send it now: it shoots down into the column it's aimed at.
  void send(int id) {
    final b = byId(id);
    if (b == null || b.sending || over) return;
    if (b.hold && !aimedRight(b)) return; // tutorial: aim it first
    b.sending = true;
    b.sentAt = b.y;
  }

  void _land(Bubble b) {
    bubbles.remove(b);
    final chat = lanes[b.lane];
    if (chat.id == b.msg.to) {
      combo++;
      bestCombo = max(bestCombo, combo);
      delivered++;
      final quick = (b.sentAt ?? 1) < quickBefore;
      final pts = 10 * multiplier + (quick ? 5 : 0);
      score += pts;
      events.add(Delivered(b, pts, quick: quick, combo: combo));
      if (delivered == Chats.squadUnlockAt && lanes.length < Chats.all.length) {
        final next = Chats.all[lanes.length];
        lanes.add(next);
        events.add(LaneJoined(next));
      }
    } else {
      combo = 0;
      strikes++;
      final w = WrongSend(b);
      lastWrong = w;
      events.add(w);
      if (over) {
        bubbles.clear();
        events.add(RunOver());
      }
    }
  }

  /// "Do Not Disturb": everything falls at 45% speed for [dndSeconds].
  void useDnd() => slowLeft = dndSeconds;

  bool get canRevive => over && !revived;

  /// "Unsend" (rewarded ad): takes back the last wrong send, clears the screen and gives a 2 s breather.
  void revive() {
    if (!canRevive) return;
    revived = true;
    strikes = maxStrikes - 1;
    bubbles.clear();
    graceLeft = 2;
    _spawnIn = 0.4;
  }

  /// Coins earned for a run: 1 per 10 points, rounded down.
  int get coins => score ~/ 10;
}
