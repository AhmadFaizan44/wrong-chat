import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../audio/sfx.dart';
import 'ad_pacing.dart';

/// Every place a player can choose to watch an ad for a reward.
enum RewardPlacement { unsend, doubleCoins, freeDnd }

abstract class AdService {
  AdPacing get pacing;

  /// True while an ad (or its heads-up card) is on screen. Only one ad ever runs at a time:
  /// extra taps or end-of-level breaks that arrive meanwhile are ignored.
  bool get showing;

  /// Shows a rewarded ad; completes with true only if the reward was earned.
  Future<bool> showRewarded(RewardPlacement placement);

  /// Called after a run ends; shows an interstitial only if pacing allows.
  Future<void> afterRun();

  static AdService create({required int sessions, required GlobalKey<NavigatorState> nav}) {
    final pacing = AdPacing(sessions: sessions);
    if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      return StubAdService(pacing, nav);
    }
    return AdMobAdService(pacing, nav);
  }
}

/// Google's public test unit IDs — swap for real IDs (milestone C) before release.
/// The interstitial unit should allow skippable video (skip after 5 s) and image ads; see README.
class AdIds {
  static const rewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const banner = 'ca-app-pub-3940256099942544/6300978111';
}

/// Runs [run] only if no other ad is showing; records when the ad ended for the pacing cooldown.
mixin _OneAdAtATime {
  AdPacing get pacing;
  bool _showing = false;
  bool get showing => _showing;

  Future<T> _locked<T>(T ifBusy, Future<T> Function() run) async {
    if (_showing) return ifBusy;
    _showing = true;
    try {
      return await run();
    } finally {
      _showing = false;
      pacing.noteAdEnded();
    }
  }
}

class AdMobAdService with _OneAdAtATime implements AdService {
  AdMobAdService(this.pacing, this.nav) {
    _init();
  }

  @override
  final AdPacing pacing;
  final GlobalKey<NavigatorState> nav;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _loadingRewarded = false, _loadingInterstitial = false;

  // Non-personalised until the consent flow (Google UMP) lands.
  static const _request = AdRequest(nonPersonalizedAds: true);

  Future<void> _init() async {
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.t));
    _loadRewarded();
    _loadInterstitial();
  }

  void _loadRewarded() {
    if (_loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (_) {
          _loadingRewarded = false;
          Timer(const Duration(seconds: 20), _loadRewarded);
        },
      ),
    );
  }

  void _loadInterstitial() {
    if (_loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: _request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (_) {
          _loadingInterstitial = false;
          Timer(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded(RewardPlacement placement) => _locked(false, _showRewarded);

  Future<bool> _showRewarded() async {
    // The first ad of a session can still be loading: give it a few seconds before giving up.
    if (_rewarded == null) {
      _loadRewarded();
      for (var i = 0; i < 20 && _rewarded == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    final ad = _rewarded;
    if (ad == null) {
      final ctx = nav.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          const SnackBar(
            content: Text('No video available right now. Try again in a moment.', textAlign: TextAlign.center),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
    _rewarded = null;
    pacing.noteRewarded();
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        Music.duck(false);
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        Music.duck(false);
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    Music.duck(true);
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  Future<void> _showInterstitial() => _locked(null, () async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    await showAdBreakNotice(nav);
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        Music.duck(false);
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        Music.duck(false);
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
    );
    Music.duck(true);
    await ad.show();
    return done.future;
  });

  @override
  Future<void> afterRun() async {
    if (!showing && pacing.runFinished()) await _showInterstitial();
  }
}

/// A short "ad break" card before an interstitial, so a break never appears out of nowhere.
Future<void> showAdBreakNotice(GlobalKey<NavigatorState> nav) async {
  final ctx = nav.currentContext;
  if (ctx == null || !ctx.mounted) return;
  final navigator = Navigator.of(ctx);
  final route = DialogRoute<void>(context: ctx, barrierDismissible: false, barrierColor: const Color(0xD9030814), builder: (_) => const _AdBreakCard());
  unawaited(navigator.push(route));
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  if (route.isActive) navigator.removeRoute(route);
}

class _AdBreakCard extends StatelessWidget {
  const _AdBreakCard();
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Fredoka', color: Color(0xFFDFF3FF), decoration: TextDecoration.none);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'QUICK AD BREAK',
            style: style.copyWith(fontFamily: 'Lilita', fontSize: 30, color: const Color(0xFFF3FF9A)),
          ),
          const SizedBox(height: 8),
          Text('You can skip it in a few seconds', style: style.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('Ads keep Wrong Chat free. Thanks!', style: style.copyWith(fontSize: 13, color: const Color(0x99DFF3FF))),
        ],
      ),
    );
  }
}

/// Web/desktop preview: a clearly labelled placeholder instead of a real ad.
class StubAdService with _OneAdAtATime implements AdService {
  StubAdService(this.pacing, this.nav);
  @override
  final AdPacing pacing;
  final GlobalKey<NavigatorState> nav;

  Future<void> _placeholder(String label, int seconds, {int? skipAfter}) async {
    final ctx = nav.currentContext;
    if (ctx == null) return;
    Music.duck(true);
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: const Color(0xEB030814),
      builder: (_) => _AdPlaceholder(label: label, seconds: seconds, skipAfter: skipAfter),
    );
    Music.duck(false);
  }

  @override
  Future<bool> showRewarded(RewardPlacement placement) => _locked(false, () async {
    pacing.noteRewarded();
    await _placeholder('Rewarded ad placeholder · ${placement.name}', 3);
    return true;
  });

  Future<void> _interstitial() => _locked(null, () async {
    await showAdBreakNotice(nav);
    await _placeholder('Interstitial ad placeholder', 15, skipAfter: 5);
  });

  @override
  Future<void> afterRun() async {
    if (!showing && pacing.runFinished()) await _interstitial();
  }
}

class _AdPlaceholder extends StatefulWidget {
  const _AdPlaceholder({required this.label, required this.seconds, this.skipAfter});
  final String label;
  final int seconds;
  final int? skipAfter;
  @override
  State<_AdPlaceholder> createState() => _AdPlaceholderState();
}

class _AdPlaceholderState extends State<_AdPlaceholder> {
  late int left = widget.seconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => left--);
      if (left <= 0) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Fredoka', color: Color(0xFFDFF3FF), decoration: TextDecoration.none);
    final skip = widget.skipAfter;
    final elapsed = widget.seconds - left;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('AD', style: style.copyWith(fontSize: 13, letterSpacing: 3, color: const Color(0x99DFF3FF))),
          const SizedBox(height: 10),
          Text(widget.label, style: style.copyWith(fontSize: 18, fontVariations: const [FontVariation('wght', 600)])),
          const SizedBox(height: 14),
          Text(left > 0 ? '$left' : 'Reward ready ✓', style: style.copyWith(fontSize: 40)),
          if (skip != null) ...[
            const SizedBox(height: 14),
            elapsed >= skip
                ? TextButton(
                    onPressed: () {
                      _t?.cancel();
                      Navigator.of(context).pop();
                    },
                    child: Text('Skip ›', style: style.copyWith(fontSize: 18)),
                  )
                : Text('Skip in ${skip - elapsed}', style: style.copyWith(fontSize: 14, color: const Color(0x99DFF3FF))),
          ],
        ],
      ),
    );
  }
}
