/// Application-wide, compile-time constants.
///
/// Anything that a release engineer might need to tune (page sizes, polling
/// cadence, Gmail search filters) lives here rather than being scattered
/// through the code base.
abstract final class AppConstants {
  static const String appName = 'Spendwise';
  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------------
  // Platform channels (must match MainActivity.kt / AppDelegate.swift).
  // ---------------------------------------------------------------------------
  static const String nativeChannel = 'com.spendwise.app/native';
  static const String nativeEventChannel = 'com.spendwise.app/events';

  // ---------------------------------------------------------------------------
  // Gmail.
  // ---------------------------------------------------------------------------
  static const String gmailReadonlyScope =
      'https://www.googleapis.com/auth/gmail.readonly';

  /// Page size for `users.messages.list` / `users.history.list` (Gmail max 500,
  /// 100 keeps individual responses small and progress updates frequent).
  static const int gmailPageSize = 100;

  /// Number of `messages.get` calls in flight during backfill. Gmail quota is
  /// 250 units/second; a get costs 5 units, so 4 concurrent calls is safe.
  static const int gmailFetchConcurrency = 4;

  /// Bodies are truncated before parsing/storage. Alert emails are tiny; the
  /// cap protects against HTML marketing blasts and giant statements.
  static const int maxEmailBodyChars = 20000;

  /// Raw alert text kept alongside each transaction (encrypted at rest). Shown
  /// only when the user explicitly expands "View source alert".
  static const int maxStoredRawTextChars = 4000;

  /// Foreground incremental sync cadence. Gmail push notifications require a
  /// server-side Pub/Sub relay, which this offline-first app deliberately
  /// avoids; polling is the privacy-preserving compromise.
  static const Duration gmailPollInterval = Duration(minutes: 15);

  /// Don't hit Gmail more often than this on app resume.
  static const Duration gmailMinSyncGap = Duration(minutes: 2);

  /// Sender domains that are known to emit transactional alerts. Used to build
  /// the Gmail search query and as a secondary client-side guard.
  static const List<String> gmailSenderDomains = <String>[
    'hdfcbank.net',
    'hdfcbank.com',
    'icicibank.com',
    'sbi.co.in',
    'onlinesbi.sbi',
    'axisbank.com',
    'kotak.com',
    'kotakbank.com',
    'idfcfirstbank.com',
    'federalbank.co.in',
    'indusind.com',
    'rblbank.com',
    'yesbank.in',
    'hsbc.co.in',
    'americanexpress.com',
    'aexp.com',
    'citibank.co.in',
    'bobibanking.com',
    'bankofbaroda.com',
    'canarabank.com',
    'pnbindia.in',
    'unionbankofindia.co.in',
    'bankofindia.co.in',
    'centralbankofindia.co.in',
    'idbibank.com',
    'bandhanbank.com',
    'au-sfb.com',
    'equitasbank.com',
    'cred.club',
    'sliceit.com',
    'onecard.co.in',
    'jupiter.money',
    'fi.money',
    'paytm.com',
    'phonepe.com',
    'amazon.in',
  ];

  /// Words that appear in genuine transaction alerts. Combined with the sender
  /// list to keep the Gmail result set small.
  static const List<String> gmailTransactionKeywords = <String>[
    'debited',
    'credited',
    'spent',
    'withdrawn',
    'transaction alert',
    'txn alert',
    'payment',
    'refund',
  ];

  // ---------------------------------------------------------------------------
  // SMS backfill.
  // ---------------------------------------------------------------------------
  static const int smsPageSize = 500;
  static const int maxSmsMessagesToScan = 50000;
  static const Duration smsPageDelay = Duration(milliseconds: 120);

  // ---------------------------------------------------------------------------
  // Encrypted Hive storage.
  // ---------------------------------------------------------------------------
  static const String transactionBoxName = 'transactions_v1';
  static const String settingsBoxName = 'settings_v1';
  static const String encryptionKeyStorageKey = 'spendwise.hive.aes256.v1';

  // ---------------------------------------------------------------------------
  // Sync / persistence keys.
  // ---------------------------------------------------------------------------
  static const String kOnboardingComplete = 'onboarding_complete';
  static const String kThemeMode = 'theme_mode';
  static const String kGmailEmail = 'gmail_email';
  static const String kGmailInitialSyncComplete = 'gmail_initial_sync_complete';
  static const String kGmailHistoryId = 'gmail_history_id';
  static const String kGmailBackfillPageToken = 'gmail_backfill_page_token';
  static const String kGmailBackfillStartedAt = 'gmail_backfill_started_at';
  static const String kGmailLastSyncAt = 'gmail_last_sync_at';
  static const String kSmsInitialSyncComplete = 'sms_initial_sync_complete';
  static const String kSmsBackfillCursorMs = 'sms_backfill_cursor_ms';
  static const String kSmsBackfillCursorId = 'sms_backfill_cursor_id';
  static const String kSmsLastSyncAt = 'sms_last_sync_at';
  static const String kNotificationLastSeenAt = 'notification_last_seen_at';
  static const String kLastNotificationAccessCheck =
      'notification_access_last_check';

  // ---------------------------------------------------------------------------
  // Notifications.
  // ---------------------------------------------------------------------------
  static const int maxPendingNativeEvents = 500;

  // ---------------------------------------------------------------------------
  // Ads. Real unit IDs are injected at build time:
  //   flutter build apk --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-...
  // The defaults below are Google's official *test* IDs and are safe to ship in
  // debug builds only.
  // ---------------------------------------------------------------------------
  static const String admobBannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String admobNativeAndroid = String.fromEnvironment(
    'ADMOB_NATIVE_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/2247696110',
  );
  static const String admobBannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const String admobNativeIos = String.fromEnvironment(
    'ADMOB_NATIVE_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/3986624511',
  );
  static const String nativeAdFactoryId = 'transactionFeedNative';

  /// Set `--dart-define=DISABLE_ADS=true` for CI, tests and screenshots.
  static const bool adsDisabled = bool.fromEnvironment('DISABLE_ADS');

  /// Insert a native ad after this many feed rows. Keeps the feed useful rather
  /// than ad-dominated (AdMob policy and user experience both benefit).
  static const int nativeAdFeedInterval = 10;
}
