import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spendwise/core/constants/app_constants.dart';
import 'package:spendwise/core/logging/app_logger.dart';

/// Owns AdMob SDK initialisation and the UMP consent lifecycle.
///
/// Ads are strictly opt-in from a compliance perspective: nothing is requested
/// until Google's consent SDK confirms that ads may be requested. On platforms
/// where AdMob is unavailable (desktop/web), or when `DISABLE_ADS=true`, every
/// ad widget collapses to zero height.
class AdService extends ChangeNotifier {
  AdService({AppLogger logger = const AppLogger('Ads')}) : _logger = logger;

  final AppLogger _logger;

  bool _initialized = false;
  bool _sdkReady = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  String? _error;
  Future<void>? _startup;
  bool _disposed = false;

  bool get isInitialized => _initialized;
  bool get canRequestAds => _sdkReady && _canRequestAds;
  bool get privacyOptionsRequired => _privacyOptionsRequired;
  String? get error => _error;

  /// True when this build/platform can show ads at all.
  bool get isSupported {
    if (AppConstants.adsDisabled || kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Idempotent. Safe to call from every ad widget.
  Future<void> initialize() => _startup ??= _initialize();

  Future<void> _initialize() async {
    if (!isSupported) {
      _initialized = true;
      _notify();
      return;
    }

    try {
      final consent = ConsentInformation.instance;
      final settled = Completer<void>();

      consent.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            if (await consent.canRequestAds()) {
              await _startSdk();
            }

            await ConsentForm.loadAndShowConsentFormIfRequired(
              (FormError? formError) async {
                if (formError != null) {
                  _error = 'Consent form unavailable.';
                  _logger.warning('Consent form error: ${formError.message}');
                }
                if (await consent.canRequestAds()) {
                  await _startSdk();
                }
                await _refreshPrivacyRequirement();
                if (!settled.isCompleted) settled.complete();
                _notify();
              },
            );
          } catch (error, stackTrace) {
            _error = 'Could not resolve ad consent.';
            _logger.warning('Consent flow failed', error, stackTrace);
            if (!settled.isCompleted) settled.complete();
            _notify();
          }
        },
        (FormError formError) {
          // A failure here usually means the device is offline. Ads stay off;
          // the rest of the app is unaffected.
          _error = 'Ad consent could not be refreshed.';
          _logger.warning('Consent update failed: ${formError.message}');
          if (!settled.isCompleted) settled.complete();
          _notify();
        },
      );

      // Never block a screen indefinitely on a third-party consent sheet.
      await settled.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
    } catch (error, stackTrace) {
      _error = 'Ads are unavailable right now.';
      _logger.warning('Ad initialisation failed', error, stackTrace);
    } finally {
      _initialized = true;
      _notify();
    }
  }

  Future<void> _startSdk() async {
    if (_sdkReady) return;
    await MobileAds.instance.initialize();
    _sdkReady = true;
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
  }

  Future<void> _refreshPrivacyRequirement() async {
    try {
      _privacyOptionsRequired =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      _privacyOptionsRequired = false;
    }
  }

  /// Opens the Google-rendered privacy options form.
  ///
  /// Returns true when the form was shown and dismissed without an error.
  Future<bool> showPrivacyOptions() async {
    if (!isSupported) return false;
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? formError) async {
        if (formError != null) {
          _logger.warning('Privacy options error: ${formError.message}');
        }
      });
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      await _refreshPrivacyRequirement();
      _notify();
      return true;
    } catch (error, stackTrace) {
      _logger.warning('Privacy options unavailable', error, stackTrace);
      return false;
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
