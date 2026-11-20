import 'package:shared_preferences/shared_preferences.dart';

/// Everything saved on the phone. Small enough to write straight away on every change.
class Progress {
  Progress._(this._p);
  final SharedPreferences? _p;

  /// In-memory only (tests).
  Progress.memory() : _p = null;

  static Future<Progress> load() async {
    final p = await SharedPreferences.getInstance();
    return Progress._(p)
      ..best = p.getInt('best') ?? 0
      ..coins = p.getInt('coins') ?? 0
      ..dnd = p.getInt('dnd') ?? 1
      ..sessions = p.getInt('sessions') ?? 0
      ..runs = p.getInt('runs') ?? 0
      ..muted = p.getBool('muted') ?? false
      ..haptics = p.getBool('haptics') ?? true
      ..lastFreeDnd = p.getString('lastFreeDnd') ?? '';
  }

  int best = 0;
  int coins = 0;

  /// "Do Not Disturb" boosters owned. New players start with one.
  int dnd = 1;
  int sessions = 0;
  int runs = 0;
  bool muted = false;
  bool haptics = true;

  /// The day (yyyy-mm-dd) the free daily booster was last claimed.
  String lastFreeDnd = '';

  static const dndPrice = 100;

  void bumpSession() {
    sessions++;
    save();
  }

  String get today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  bool get freeDndReady => lastFreeDnd != today;

  void claimFreeDnd() {
    lastFreeDnd = today;
    dnd++;
    save();
  }

  /// Records a finished run. Returns true if it is a new best.
  bool finishRun(int score, int earned) {
    runs++;
    coins += earned;
    final isBest = score > best;
    if (isBest) best = score;
    save();
    return isBest;
  }

  bool buyDnd() {
    if (coins < dndPrice) return false;
    coins -= dndPrice;
    dnd++;
    save();
    return true;
  }

  void save() {
    final p = _p;
    if (p == null) return;
    p
      ..setInt('best', best)
      ..setInt('coins', coins)
      ..setInt('dnd', dnd)
      ..setInt('sessions', sessions)
      ..setInt('runs', runs)
      ..setBool('muted', muted)
      ..setBool('haptics', haptics)
      ..setString('lastFreeDnd', lastFreeDnd);
  }
}
