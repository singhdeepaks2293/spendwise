# Spendwise

Spendwise is a privacy-first, on-device finance tracker for Android and iOS. It
turns bank emails, Android SMS alerts, and payment notifications into a
categorised ledger without a Spendwise backend.

- **Gmail** — read-only OAuth (`gmail.readonly`), historical backfill with
  resumable pagination, incremental history sync, and foreground polling.
- **Android SMS** — paginated inbox backfill plus a live `SMS_RECEIVED` receiver,
  restricted to bank sender IDs and financial message bodies.
- **Android notifications** — optional notification-listener access for GPay,
  PhonePe, Paytm, and banking apps, with an encrypted pending-event queue.
- **On-device parsing** — amount, direction, merchant, date/time, payment mode,
  instrument, reference, and balance extraction with negative filters for OTPs,
  promotions, statements, failed/scheduled payments, and payment requests.
- **Encrypted storage** — Hive AES-256 ledger and settings; the key lives in
  Android Keystore / iOS Keychain via `flutter_secure_storage`.
- **Monetisation** — AdMob UMP consent, a dashboard banner, and native in-feed
  ads. No ads on Settings, Analytics, onboarding, or permission dialogs.

The app is built with Flutter, Riverpod, Hive, `google_sign_in`, `googleapis`,
`fl_chart`, `permission_handler`, and `google_mobile_ads`.

---

## 1. Requirements

| Tool | Version |
| --- | --- |
| Flutter | 3.24.x or newer (Dart 3.5+) |
| Android | JDK 17, Android SDK 34, minSdk 23 |
| iOS | Xcode 15+, CocoaPods, iOS 12+ |
| Google Cloud | Gmail API enabled, OAuth consent screen configured |
| AdMob | Android and iOS apps created in AdMob |

```bash
flutter --version
flutter doctor
flutter pub get
```

---

## 2. Quick start (test IDs, no production credentials)

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Out of the box the app uses Google's official AdMob **test** IDs and the Gmail
OAuth flow will only work after you configure a Google Cloud OAuth client (see
below). You can run the UI and parser tests without any credentials.

To disable ads entirely (CI, screenshots, parser development):

```bash
flutter run --dart-define=DISABLE_ADS=true
```

---

## 3. Google Cloud / Gmail setup

1. Create or select a project in [Google Cloud Console](https://console.cloud.google.com/).
2. Enable **Gmail API**.
3. Configure the **OAuth consent screen**:
   - User type: External (or Internal for a Workspace-only build).
   - Add the scope `https://www.googleapis.com/auth/gmail.readonly`.
   - Add test users while the app is in testing mode.
4. Create OAuth client IDs:

### Android

- Application type: **Android**.
- Package name: `com.spendwise.app`.
- Add the SHA-1 fingerprint of the keystore used to sign the build:

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android
```

Create **one Android OAuth client per signing certificate**: debug, your local
release keystore, and the Google Play App Signing certificate. A single client
holds one SHA-1, so use separate clients with the same package name. Play's
certificate is under **Play Console → Test and release → Setup → App signing**
(use the *App signing key certificate* SHA-1, not the upload key).

No `google-services.json` and no client ID are required in the Android build.
Play Services matches the installed app's package name and signing certificate
to the registered OAuth client at runtime.

#### How this works for other users

You register the certificate **once**; every user installs the same signed app
and shares that OAuth client. Users do not create Google Cloud projects, paste
client IDs, or configure anything — they tap **Connect**, choose their account,
and grant the read-only Gmail scope. Tokens are issued per user and stored only
on their device.

What changes with distribution is the consent screen audience, not the client:

- **Testing** (Audience → Test users): only the Google accounts you add (up to
  100) can sign in. Everyone else sees "access blocked".
- **Production**: publish the app in the OAuth consent screen. Because
  `gmail.readonly` is a restricted scope, Google requires OAuth verification,
  a privacy policy, and (for apps storing/transmitting restricted data) a
  CASA security assessment. Only then can any Google user connect.

If you later change signing keys (new upload key, Play App Signing enrolment,
or a different CI keystore), add the new SHA-1 as another Android client.
Removing a certificate immediately breaks sign-in for builds signed with it.

### iOS

- Application type: **iOS**.
- Bundle ID must match the Xcode Runner bundle identifier.
- Put the client ID in `ios/Runner/Info.plist`:

```xml
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>
```

- Replace the URL scheme placeholder with the reversed client ID:

```xml
<string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
```

The `GOOGLE_IOS_CLIENT_ID` dart-define can override the client ID for
multi-tenant builds:

```bash
flutter run --dart-define=GOOGLE_IOS_CLIENT_ID=....apps.googleusercontent.com
```

> Gmail scope verification: `gmail.readonly` is a restricted Google scope. A
> public release needs Google OAuth verification and a privacy policy URL. Until
> then, only test users can sign in.

### Troubleshooting `ApiException: 10` / `DEVELOPER_ERROR`

Play Services returns this when the running build's package name **and** signing
certificate are not registered together. It is not a network error. Print the
fingerprint of the keystore that signed the installed build:

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android
```

For the debug build in this repository that is:

```
Package: com.spendwise.app
SHA-1:   A8:E6:67:16:10:D1:8A:F4:11:09:CD:B2:DA:1C:72:B7:25:4B:4A:06
```

Create (or correct) the **Android** OAuth client in Google Cloud with that
package/SHA-1 pair, make sure the Gmail API is enabled, and reinstall the app.
Registration changes can take a few minutes to propagate. Each machine has its
own debug keystore, so repeat this for every developer machine and for the
release keystore.

---

## 4. AdMob setup

### Android

The Gradle placeholder defaults to Google's test app ID. Override it at build
time:

```bash
flutter build appbundle --release \
  --android-project-arg=admobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
```

The placeholder is consumed by `AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="${admobAppId}" />
```

### iOS

Replace `GADApplicationIdentifier` in `ios/Runner/Info.plist` with the
production iOS app ID. Keep the `SKAdNetworkItems` list and
`NSUserTrackingUsageDescription`.

### Ad unit IDs

Ad unit IDs are compile-time dart-defines. Defaults are Google test IDs:

```bash
flutter build appbundle --release \
  --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-.../... \
  --dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-.../... \
  --android-project-arg=admobAppId=ca-app-pub-...~...
```

```bash
flutter build ios --release \
  --dart-define=ADMOB_BANNER_IOS=ca-app-pub-.../... \
  --dart-define=ADMOB_NATIVE_IOS=ca-app-pub-.../...
```

| Constant | Dart define | Default (test) |
| --- | --- | --- |
| Android banner | `ADMOB_BANNER_ANDROID` | `ca-app-pub-3940256099942544/6300978111` |
| Android native | `ADMOB_NATIVE_ANDROID` | `ca-app-pub-3940256099942544/2247696110` |
| iOS banner | `ADMOB_BANNER_IOS` | `ca-app-pub-3940256099942544/2934735716` |
| iOS native | `ADMOB_NATIVE_IOS` | `ca-app-pub-3940256099942544/3986624511` |

The UMP SDK requests consent before the Mobile Ads SDK is initialised. If
`canRequestAds()` is false, every ad widget collapses to zero height. The
privacy-options entry appears in Settings only when Google reports it as
required.

---

## 5. Android permissions and Google Play policy

`android/app/src/main/AndroidManifest.xml` declares:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
```

`SEND_SMS` is deliberately **not** declared. `permission_handler`'s
`Permission.sms` request expands only to permissions present in the manifest, so
the user sees a read/receive prompt, not a send prompt.

The notification listener is a special grant:

```xml
<service
    android:name=".SpendwiseNotificationListener"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

### Play Console declarations

Before publishing:

1. Complete the **SMS/Call Log permissions** declaration. `READ_SMS` is a
   restricted permission; the core-use-case justification must match the app's
   actual behaviour. If approval is not granted, ship a notification-only
   variant (remove `READ_SMS`/`RECEIVE_SMS`, the `SmsReceiver`, and the SMS UI
   entry points).
2. Disclose notification-listener use in the listing and privacy policy. The
   listener only reads notifications after the user grants access and filters
   for financial content on-device.
3. Complete the **Data safety** form:
   - Gmail message content is processed on-device; only OAuth tokens and the
     connected email are stored locally.
   - No transaction data is sent to a Spendwise server.
   - AdMob may collect device/advertising identifiers subject to UMP consent.
4. Provide a privacy policy URL covering Gmail restricted-scope use, SMS, and
   notifications.
5. Target API level and data-safety answers must match the release build.

---

## 6. Architecture

```text
lib/
├── main.dart                     App entry point
├── app/
│   ├── app.dart                  MaterialApp, startup gate, onboarding gate
│   ├── bootstrap.dart            Dependency graph + encrypted storage startup
│   └── providers.dart            Riverpod providers and derived UI state
├── core/
│   ├── constants/                App-wide constants (scopes, keys, ad IDs)
│   ├── error/                    Typed AppFailure hierarchy
│   ├── logging/                  Redacting logger
│   ├── platform/                 SMS permission wrapper
│   ├── theme/                    Light/dark Material 3 themes
│   └── utils/                    Dates, money, transaction fingerprinting
├── domain/
│   ├── entities/                 Transaction, category, raw message, sync state,
│   │                             analytics, filter
│   ├── repositories/             Persistence/auth/source interfaces
│   └── services/
│       ├── ingestion_engine.dart Parse → classify → persist pipeline
│       ├── sync_engine.dart      Backfill, incremental sync, live events
│       ├── network_monitor.dart  Connectivity abstraction
│       └── transaction_parser.dart
├── data/
│   ├── parsing/                  Text normaliser, HTML extractor, rule parser
│   ├── categorization/           Merchant rules + keyword fallback
│   ├── local/hive/               AES-256 bootstrap and key service
│   ├── local/models/             Hive JSON transaction model
│   ├── repositories/             Hive transaction/settings repositories
│   ├── remote/gmail/             OAuth wrapper + Gmail API client
│   ├── native/                   MethodChannel/EventChannel bridge
│   └── sync/                     connectivity_plus monitor
└── presentation/
    ├── ads/                      UMP service, banner, native feed ad
    ├── screens/                  Startup, onboarding, dashboard, activity,
    │                             analytics, settings, detail sheet
    ├── theme/                    Category icons/colours
    └── widgets/                  Shared cards, charts, tiles, dialogs
```

### Data flow

```text
Gmail API ─┐
SMS inbox ─┼─> RawMessage ─> RuleBasedTransactionParser ─> ParsedTransaction
Notifs ────┘                                      │
                                                   v
                                    RuleBasedCategoryClassifier
                                                   │
                                                   v
                                         IngestionEngine
                                                   │
                                                   v
                              HiveTransactionRepository (AES-256)
                                                   │
                                                   v
                              Riverpod streams → Dashboard / Activity / Insights
```

### Ingestion entry points

| File | Responsibility |
| --- | --- |
| `lib/domain/services/sync_engine.dart` | Orchestrates Gmail/SMS backfill, incremental Gmail sync, polling, live events, cancellation, and progress snapshots. |
| `lib/data/remote/gmail/gmail_api_client.dart` | Gmail `messages.list`, `messages.get`, `history.list`, MIME/HTML extraction, retry/backoff, token refresh. |
| `lib/data/remote/gmail/gmail_auth_service.dart` | Google Sign-In with `gmail.readonly`, silent refresh, revocation. |
| `lib/data/native/native_device_message_source.dart` | Dart-side SMS/notification source, bank-sender pre-filter, live stream. |
| `lib/data/native/native_bridge.dart` | Typed platform-channel contract (`readSmsInbox`, `getSmsCount`, `drainPendingEvents`, notification access). |
| `lib/domain/services/ingestion_engine.dart` | Parses and classifies each raw message; persists accepted transactions. |
| `lib/data/parsing/rule_based_transaction_parser.dart` | Amount/date/merchant/mode/instrument/reference/balance extraction and negative filters. |
| `lib/data/categorization/rule_based_category_classifier.dart` | Merchant-first classification with keyword and fallback categories. |
| `lib/data/repositories/hive_transaction_repository.dart` | Encrypted persistence, stable-id + semantic dedupe, serialized writes. |

### Android native

| File | Responsibility |
| --- | --- |
| `MainActivity.kt` | Registers the method/event channels and the native ad factory. |
| `SmsReader.kt` | Newest-first, composite-cursor (`date`, `_id`) inbox pagination. |
| `SmsReceiver.kt` | Reassembles multipart live SMS and publishes only financial alerts. |
| `SpendwiseNotificationListener.kt` | Reads payment notifications after the special grant. |
| `FinancialMessageFilter.kt` | Conservative native pre-filter shared by SMS and notifications. |
| `NativeEventBridge.kt` | Main-thread event delivery; falls back to encrypted storage. |
| `PendingEventStore.kt` | AES-256 EncryptedSharedPreferences queue, durable `commit()` writes. |
| `TransactionFeedNativeAdFactory.kt` | Binds every AdMob asset view for the in-feed native card. |

### iOS

`ios/Runner/AppDelegate.swift` registers the native ad factory and forwards the
Google Sign-In callback URL. iOS intentionally has no SMS/notification
ingestion; the UI explains the platform limitation and uses Gmail only.

---

## 7. Storage and encryption

- `HiveBootstrap.initialize()` opens two AES-256 Hive boxes:
  - `transactions_v1` — JSON strings of `TransactionModel`.
  - `settings_v1` — sync cursors, connected email, theme, onboarding flag.
- The 256-bit key is generated once and stored in `flutter_secure_storage`
  (Android Keystore / iOS Keychain). It is never written to the Hive files.
- If the encrypted box cannot be opened (corrupt file or lost key), bootstrap
  deletes the unreadable box and starts a fresh encrypted box rather than
  crashing. The trade-off is that unrecoverable local data is discarded; the
  UI surfaces this through startup failure/retry paths.
- Android pending SMS/notification events use
  `EncryptedSharedPreferences` with `AES256_GCM` and `AES256_SIV`. If the
  keystore is unavailable on a broken OEM build, the store degrades to private
  app preferences so ingestion still works.
- Raw alert text is truncated before storage and is deleted with the ledger.
- `Delete all local data` cancels scans, revokes Gmail, clears both boxes,
  resets sync cursors, and reloads the in-memory snapshot.

---

## 8. Sync behaviour

### Gmail historical backfill

1. On OAuth grant, the engine captures the current `historyId`.
2. It lists matching messages with pagination and stores `nextPageToken` after
   each page.
3. A pause/cancel leaves the token in place; the next run resumes rather than
   restarting.
4. When pagination ends, `gmail_initial_sync_complete` is persisted and the
   token is removed.
5. The captured `historyId` means messages that arrived during the scan are
   picked up by the next incremental sync.

Gmail search is narrowed by known sender domains and transaction keywords, then
each message is parsed independently. A deleted or malformed message is skipped
without aborting the backfill.

### Gmail incremental sync

- Uses `users.history.list` from the stored history ID.
- On `HistoryExpiredException`, falls back to a date-bounded `messages.list`
  query.
- Foreground polling runs every 15 minutes while the app is resumed.
- The history cursor is only advanced after all listed IDs are processed; a
  cancelled sync does not skip messages.

### SMS backfill

- Reads `content://sms/inbox` newest-first in pages of 500.
- Cursor is a composite `(date, _id)` so bulk alerts sharing a millisecond
  timestamp cannot be skipped at page boundaries.
- The cursor is persisted after every page; the scan is resumable.
- Personal messages are filtered before parsing; only bank sender IDs (or
  numeric senders with explicit bank/account/UPI wording) enter the parser.
- A completed or running backfill is a no-op, so resume/permission callbacks are
  safe to call repeatedly.

### Live device events

- `SmsReceiver` and `SpendwiseNotificationListener` filter natively, then publish
  through an `EventChannel` when Flutter is alive.
- If the app process is gone, events go into the encrypted pending queue.
- On resume, the queue is drained, deduped by stable event ID, and ingested.
- A race between sink detach and delivery falls back to the queue; duplicates
  are collapsed by the repository.

---

## 9. Parsing and categorisation

The parser is pure Dart and rule-based. It handles common Indian bank formats:

- Currency amounts (`₹`, `Rs.`, `INR`, `dr`/`cr`) and available-balance lines.
- Day-first numeric dates, month names, ISO timestamps, and 12/24-hour times.
- Merchant extraction from `at`, `to`, `from`, `Info`, `Narration`, `VPA`, and
  subject fallbacks.
- Payment modes: UPI, debit card, credit card, net banking, cash/ATM, cheque,
  wallet, and unknown.
- Instrument hints: card last-4, account last-4, UPI VPA.
- References: UTR, RRN, transaction IDs.
- Negative filters: OTP/verification, promotions, statements/bills, failed or
  scheduled payments, payment requests, credit-limit notices, missing
  direction/amount, and too-short messages.

Classification is merchant-first, then keyword-based, with explicit handling for
income credits, transfers/investments, cash withdrawals, and an `Other`
fallback. Rules live in `lib/data/categorization/merchant_category_rules.dart`.

To extend support, add a fixture to
`test/parsing/rule_based_transaction_parser_test.dart` and, if needed, a merchant
rule. The parser intentionally rejects rather than guesses when direction or
amount is ambiguous.

---

## 10. Tests and quality gates

```bash
flutter analyze
flutter test
```

The suite covers:

- Bank SMS/email fixtures across HDFC, ICICI, SBI, Axis, Kotak, Amex, UPI apps,
  salary credits, refunds, and HTML emails.
- Negative filters.
- Date, amount, merchant, mode, instrument, and reference extraction.
- Category classification, transfers, cash, keyword fallback, and unknown
  merchants.
- Analytics aggregation.
- Transaction search/filter semantics.
- Hive persistence, encryption-at-rest, idempotent dedupe, and ordering.
- Transaction tile widget smoke test.

Current baseline: **94 tests passing**, `flutter analyze` clean.

CI recommendation:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=DISABLE_ADS=true
```

---

## 11. Release checklist

1. **Signing** — `android/app/build.gradle` currently uses the debug signing
   config for release builds. Create a release keystore and a `key.properties`
   file, then replace `signingConfig = signingConfigs.debug`. Never commit the
   keystore or passwords.
2. **AdMob** — replace the Android app ID placeholder, iOS
   `GADApplicationIdentifier`, and all four ad unit IDs.
3. **Google OAuth** — add release SHA-1 fingerprints, complete OAuth
   verification for `gmail.readonly`, and set the iOS client ID/URL scheme.
4. **Play policy** — complete SMS and notification declarations, Data safety,
   and privacy policy.
5. **iOS** — set the Runner bundle identifier and team, run `pod install`, and
   archive from Xcode. Verify Google Sign-In URL handling on a device.
6. **Versioning** — update `version` in `pubspec.yaml` and
   `AppConstants.appVersion`.
7. **Smoke test on device** — Gmail connect, historical backfill, SMS grant,
   notification access, live payment, category edit, delete-all, ad consent,
   and privacy options.

Build commands:

```bash
flutter build appbundle --release \
  --android-project-arg=admobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY \
  --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-.../... \
  --dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-.../...

flutter build ios --release \
  --dart-define=ADMOB_BANNER_IOS=ca-app-pub-.../... \
  --dart-define=ADMOB_NATIVE_IOS=ca-app-pub-.../...
```

---

## 12. Known limitations

- Gmail sync is foreground polling, not push. A server-side Pub/Sub relay would
  be required for background push, which conflicts with the no-backend design.
- No bank API or account-aggregator integration; sources are Gmail, SMS, and
  notifications.
- iOS cannot read SMS or other apps' notifications. Gmail is the only source.
- Rule-based parsing will not cover every bank format. Add fixtures and rules
  rather than broadening the amount/date heuristics blindly.
- Large Gmail mailboxes and SMS inboxes can take several minutes; progress is
  shown and scans are resumable.
- AdMob consent and fill depend on network/region; ads fail closed.
- The project has been analysed and unit-tested on Linux. Android/iOS native
  compilation requires the respective SDKs and was not run in this environment.

---

## 13. Privacy summary

- No Spendwise account, backend, or cloud ledger.
- Gmail access is read-only and revocable from Settings or the Google account.
- SMS and notification content is filtered and parsed on-device.
- The ledger and sync cursors are AES-256 encrypted at rest.
- Ads are served by Google AdMob only after UMP consent; transaction data is
  never passed to ad SDKs.
- `Delete all local data` removes transactions, cursors, and sign-in state from
  the encrypted boxes. The platform-held encryption key is retained so future
  storage can be initialised; the emptied boxes contain no recoverable
  transaction data.

See `lib/presentation/screens/settings/settings_screen.dart` for the in-app
privacy explanation and `lib/data/local/hive/encryption_key_service.dart` for
key handling.
