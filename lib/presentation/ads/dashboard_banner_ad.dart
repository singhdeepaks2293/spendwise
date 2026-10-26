import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/constants/app_constants.dart';
import 'package:spendwise/core/logging/app_logger.dart';
import 'package:spendwise/presentation/ads/ad_service.dart';

const AppLogger _logger = AppLogger('AdsWidget');

/// Anchored adaptive banner used at the bottom of the dashboard.
///
/// The widget reserves no space until an ad is actually loaded, so a failed
/// request never leaves a blank strip above the navigation bar.
class DashboardBannerAd extends ConsumerStatefulWidget {
  const DashboardBannerAd({super.key});

  @override
  ConsumerState<DashboardBannerAd> createState() => _DashboardBannerAdState();
}

class _DashboardBannerAdState extends ConsumerState<DashboardBannerAd> {
  BannerAd? _banner;
  AdService? _service;
  bool _loading = false;
  bool _failed = false;
  double? _loadedForWidth;

  @override
  void initState() {
    super.initState();
    _service = ref.read(adsProvider);
    _service!.addListener(_onServiceChanged);
    unawaited(_service!.initialize());
  }

  void _onServiceChanged() {
    if (!mounted) return;
    if (_service!.canRequestAds) {
      unawaited(_load());
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    if (_loadedForWidth == null || (width - _loadedForWidth!).abs() > 40) {
      _loadedForWidth = width;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null ||
        !service.canRequestAds ||
        _banner != null ||
        _loading ||
        _failed ||
        !mounted) {
      return;
    }
    _loading = true;

    final width = (MediaQuery.sizeOf(context).width - 32).clamp(280, 1200);
    final orientation = MediaQuery.orientationOf(context);
    final platform = Theme.of(context).platform;
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
          orientation,
          width.toInt(),
        ) ??
        AdSize.banner;

    final adUnitId = platform == TargetPlatform.iOS
        ? AppConstants.admobBannerIos
        : AppConstants.admobBannerAndroid;

    final banner = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _banner = ad as BannerAd;
            _loading = false;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          _logger.warning('Banner failed: ${error.message}');
          if (!mounted) return;
          setState(() {
            _loading = false;
            _failed = true;
          });
        },
      ),
    );

    await banner.load();
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceChanged);
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (banner == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Center(
        child: SizedBox(
          width: banner.size.width.toDouble(),
          height: banner.size.height.toDouble(),
          child: AdWidget(ad: banner),
        ),
      ),
    );
  }
}
