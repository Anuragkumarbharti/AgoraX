import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdmobService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdmobService] Initialized Google Mobile Ads SDK.');
    } catch (e) {
      debugPrint('[AdmobService] Initialization failed: $e');
    }
  }

  static void showRewardedInterstitial({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailedToLoad,
  }) {
    // Rewarded Interstitial Ad unit ID provided by user
    const String adUnitId = 'ca-app-pub-3942296699404624/4537406147';

    RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
          debugPrint('[AdmobService] Rewarded Interstitial Ad loaded.');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (onAdDismissed != null) onAdDismissed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (onAdFailedToLoad != null) onAdFailedToLoad();
            },
          );
          ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            debugPrint('[AdmobService] User earned reward.');
            onRewardEarned();
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('[AdmobService] Rewarded Interstitial Ad failed to load: $error');
          if (onAdFailedToLoad != null) onAdFailedToLoad();
        },
      ),
    );
  }
}
