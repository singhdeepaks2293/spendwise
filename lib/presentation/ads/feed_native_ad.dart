import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/constants/app_constants.dart';
import 'package:spendwise/core/logging/app_logger.dart';
import 'package:spendwise/presentation/ads/ad_service.dart';

const AppLogger _logger = AppLogger('NativeAd');

/// Native ad card inserted into the transaction feed.
///
/// The layout is rendered by the platform factories registered in
/// `MainActivity.kt` / `AppDelegate.swift` under [AppConstants.nativeAdFactoryId].
/// Every instance owns its own [NativeAd], as required by `AdWidget`.
class FeedNativeAd extends ConsumerStatefulWidget {
  const FeedNativeAd({required this.slot, super.key});

  /// Distinguishes repeated ad slots in the same list for element reuse.
  final int slot;

  @override
  ConsumerState<FeedNativeAd> createState() => _FeedNativeAdState();
}

class _FeedNativeAdState extends ConsumerState<FeedNativeAd> {
  NativeAd? _ad;
  AdService? _service;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _service = ref.read(adsProvider);
    _service!.addListener(_onServiceChanged);
    // The service is initialised once at startup. If this widget is created
    // afterwards, `initialize()` returns an already-completed future and no
    // listener notification follows, so explicitly attempt the first load.
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final service = _service;
    if (service == null) return;
    await service.initialize();
    if (!mounted) return;
    if (service.canRequestAds) {
      await _load();
    } else {
      setState(() {});
    }
  }

  void _onServiceChanged() {
    if (!mounted) return;
    if (_service!.canRequestAds) {
      unawaited(_load());
    }
    setState(() {});
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null ||
        !service.canRequestAds ||
        _ad != null ||
        _loading ||
        _failed ||
        !mounted) {
      return;
    }
    setState(() => _loading = true);

    final platform = Theme.of(context).platform;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adUnitId = platform == TargetPlatform.iOS
        ? AppConstants.admobNativeIos
        : AppConstants.admobNativeAndroid;

    final ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: AppConstants.nativeAdFactoryId,
      customOptions: <String, Object>{'darkMode': isDark},
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad loaded) {
          if (!mounted) {
            loaded.dispose();
            return;
          }
          setState(() {
            _ad = loaded as NativeAd;
            _loading = false;
          });
        },
        onAdFailedToLoad: (Ad failed, LoadAdError error) {
          failed.dispose();
          _logger.warning('Native ad failed: ${error.message}');
          if (!mounted) return;
          setState(() {
            _loading = false;
            _failed = true;
          });
        },
      ),
    );

    await ad.load();
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 340,
            child: AdWidget(ad: ad),
          ),
        ),
      );
    }

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            'Sponsored',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
