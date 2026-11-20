/// Interstitial pacing — published rules, the same for every player:
///  - none during a player's first 3 sessions
///  - at most once every 3 finished runs
///  - interstitials are >= 90 s apart
///  - never two ads back to back: no interstitial right after a rewarded ad, or within 60 s of any ad ending
class AdPacing {
  AdPacing({required this.sessions, DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const interstitialGap = Duration(seconds: 90);
  static const anyAdGap = Duration(seconds: 60);
  static const runsBetween = 3;

  final int sessions;
  final DateTime Function() _now;
  int _runsSince = 0;
  DateTime? _lastInterstitial;
  DateTime? _lastAnyAd;
  bool _rewardedJustShown = false;

  /// A rewarded ad was watched (or attempted): the next break is skipped and the cooldown restarts.
  void noteRewarded() {
    _rewardedJustShown = true;
    _lastAnyAd = _now();
  }

  /// Any ad just closed (rewarded or interstitial).
  void noteAdEnded() => _lastAnyAd = _now();

  bool _within(DateTime? t, Duration gap) => t != null && _now().difference(t) < gap;

  /// A run just finished. True if an interstitial may be shown now.
  bool runFinished() {
    _runsSince++;
    final skip = _rewardedJustShown;
    _rewardedJustShown = false;
    if (sessions <= 3 || skip) return false;
    if (_within(_lastInterstitial, interstitialGap)) return false;
    if (_within(_lastAnyAd, anyAdGap)) return false;
    if (_runsSince < runsBetween) return false;
    _runsSince = 0;
    _lastInterstitial = _now();
    return true;
  }
}
