import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/constants/app_constants.dart';
import 'package:spendwise/core/error/failures.dart';
import 'package:spendwise/core/platform/permission_service.dart';
import 'package:spendwise/core/utils/date_time_utils.dart';
import 'package:spendwise/domain/entities/sync_state.dart';
import 'package:spendwise/domain/entities/transaction_filter.dart';
import 'package:spendwise/presentation/widgets/app_dialogs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationAccessProvider);
      ref.invalidate(smsPermissionProvider);
      // The user may have granted SMS access from system settings.
      unawaited(_resumeSmsBackfillIfGranted());
    }
  }

  /// Starts the first SMS scan when permission is already available.
  ///
  /// [SyncEngine] treats a completed or running backfill as a no-op, so calling
  /// this on every resume is safe and makes permission changes self-healing.
  Future<void> _resumeSmsBackfillIfGranted() async {
    final source = ref.read(deviceMessageSourceProvider);
    if (!source.isSupported) return;
    try {
      final status = await ref.read(permissionServiceProvider).smsStatus();
      if (!mounted || !status.isGranted) return;
      await ref.read(syncEngineProvider).startSmsBackfillInBackground();
    } catch (_) {
      // Failures are surfaced by the sync status card.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = ref.watch(syncSnapshotProvider).valueOrNull;
    final smsStatus = ref.watch(smsPermissionProvider).valueOrNull;
    final notificationAccess =
        ref.watch(notificationAccessProvider).valueOrNull ?? false;
    final deviceSupported = ref.watch(deviceMessageSourceProvider).isSupported;
    final ads = ref.watch(adsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final transactionCount =
        ref.watch(transactionsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          const _SectionLabel('Accounts & sync'),
          _SettingsCard(
            children: <Widget>[
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.mail_rounded,
                      color: scheme.onPrimaryContainer, size: 20),
                ),
                title: const Text('Gmail'),
                subtitle: Text(
                  snapshot?.gmailConnected ?? false
                      ? (snapshot?.gmailEmail ?? 'Connected')
                      : 'Not connected',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: <Widget>[
                    if (snapshot?.gmailConnected ?? false) ...<Widget>[
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _syncNow,
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('Sync now'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _disconnectGmail,
                        child: const Text('Disconnect'),
                      ),
                    ] else
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _connectGmail,
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('Connect Gmail'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _InfoTile(
                icon: Icons.schedule_rounded,
                title: 'Last email sync',
                value: snapshot?.lastGmailSyncAt == null
                    ? 'Never'
                    : DateTimeUtils.dateTimeLabel(snapshot!.lastGmailSyncAt!),
              ),
              _InfoTile(
                icon: Icons.history_rounded,
                title: 'Email history',
                value: (snapshot?.initialGmailComplete ?? false)
                    ? 'Backfill complete'
                    : 'Backfill pending',
              ),
              _InfoTile(
                icon: Icons.sms_rounded,
                title: 'SMS history',
                value: !deviceSupported
                    ? 'Unavailable on this platform'
                    : !(smsStatus?.isGranted ?? false)
                        ? 'Permission required'
                        : (snapshot?.initialSmsComplete ?? false)
                            ? 'Backfill complete'
                            : 'Backfill pending',
              ),
              if (snapshot?.gmail.isRunning ?? false)
                _ProgressLine(progress: snapshot!.gmail),
              if (snapshot?.sms.isRunning ?? false)
                _ProgressLine(progress: snapshot!.sms),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('Re-run historical backfill'),
                subtitle: const Text(
                  'Scan the full Gmail history and SMS inbox again. Existing '
                  'transactions are deduplicated.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                enabled: !_busy,
                onTap: _rerunBackfill,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Device access'),
          _SettingsCard(
            children: <Widget>[
              if (deviceSupported) ...<Widget>[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('SMS access'),
                  subtitle: Text(_smsLabel(smsStatus)),
                  trailing: FilledButton.tonal(
                    onPressed: _busy ? null : () => _handleSms(smsStatus),
                    child: Text(
                      smsStatus?.isGranted ?? false ? 'Manage' : 'Allow',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notification access'),
                  subtitle: Text(
                    notificationAccess
                        ? 'Enabled for payment notifications'
                        : 'Optional: captures live UPI payments',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: _busy ? null : _handleNotifications,
                    child: Text(notificationAccess ? 'Manage' : 'Enable'),
                  ),
                ),
              ] else
                const ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('SMS and notifications are Android-only'),
                  subtitle: Text(
                    'iOS does not permit apps to read SMS or other apps’ '
                    'notifications. Gmail is the supported source here.',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Privacy'),
          _SettingsCard(
            children: <Widget>[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.policy_outlined),
                title: const Text('How your data is handled'),
                subtitle: const Text(
                  'Alerts are parsed on-device, the ledger is encrypted with an '
                  'AES-256 key in the device keystore, and no Spendwise server '
                  'receives your transactions.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showPrivacy,
              ),
              if (ads.isSupported && ads.privacyOptionsRequired) ...<Widget>[
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Ad privacy settings'),
                  subtitle: const Text(
                    'Review or change your consent for personalised ads.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showAdPrivacyOptions,
                ),
              ],
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading:
                    Icon(Icons.delete_forever_rounded, color: scheme.error),
                title: Text(
                  'Delete all local data',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: Text(
                  '$transactionCount '
                  '${transactionCount == 1 ? 'transaction' : 'transactions'}, '
                  'sync cursors and sign-in state on this device.',
                ),
                enabled: !_busy,
                onTap: _deleteEverything,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Appearance'),
          _SettingsCard(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded, size: 17),
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded, size: 17),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded, size: 17),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: <ThemeMode>{themeMode},
                  onSelectionChanged: (selection) => ref
                      .read(themeModeProvider.notifier)
                      .setMode(selection.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('About'),
          _SettingsCard(
            children: <Widget>[
              const _InfoTile(
                icon: Icons.info_outline_rounded,
                title: 'Version',
                value: AppConstants.appVersion,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open-source licences'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConstants.appName,
                  applicationVersion: AppConstants.appVersion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Spendwise · processed on your device',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _smsLabel(AppPermissionStatus? status) {
    return switch (status) {
      AppPermissionStatus.granted => 'Allowed · bank SMS can be imported',
      AppPermissionStatus.limited => 'Limited access granted',
      AppPermissionStatus.permanentlyDenied =>
        'Blocked in system settings · tap Manage',
      AppPermissionStatus.restricted => 'Restricted by this device',
      AppPermissionStatus.denied => 'Not allowed',
      null => 'Checking…',
    };
  }

  Future<void> _connectGmail() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Connect Gmail?',
      message:
          'Spendwise requests read-only Gmail access to find bank and card '
          'alerts. It cannot send, delete or modify mail. No email content is '
          'uploaded to a Spendwise server.',
      confirmLabel: 'Continue to Google',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final email = await ref.read(syncEngineProvider).connectGmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected $email. Backfill is running.'),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showError(failure.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Gmail could not be connected.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnectGmail() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Disconnect Gmail?',
      message: 'Spendwise will sign out and stop importing email. Transactions '
          'already in your ledger stay on this device.',
      confirmLabel: 'Disconnect',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(syncEngineProvider).disconnectGmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gmail disconnected.')),
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Gmail could not be disconnected.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    final engine = ref.read(syncEngineProvider);
    final snapshot = ref.read(syncSnapshotProvider).valueOrNull;
    try {
      if (snapshot?.gmailConnected ?? false) {
        await engine.syncGmailIncremental();
      }
      if (ref.read(deviceMessageSourceProvider).isSupported) {
        await engine.drainPendingEvents();
        final smsGranted =
            (await ref.read(permissionServiceProvider).smsStatus()).isGranted;
        if (smsGranted && !(snapshot?.initialSmsComplete ?? false)) {
          await engine.runSmsBackfill();
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync finished.')),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showError(failure.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Sync could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rerunBackfill() async {
    final snapshot = ref.read(syncSnapshotProvider).valueOrNull;
    final source = ref.read(deviceMessageSourceProvider);
    final smsGranted = source.isSupported &&
        (await ref.read(permissionServiceProvider).smsStatus()).isGranted;
    if (!mounted) return;
    final gmailConnected = snapshot?.gmailConnected ?? false;
    if (!gmailConnected && !smsGranted) {
      _showError('Connect Gmail or allow SMS access before running a backfill.');
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Re-run historical backfill?',
      message:
          'Spendwise will scan your full Gmail history and SMS inbox again. '
          'This can take several minutes on large mailboxes, and duplicates are '
          'skipped automatically.',
      confirmLabel: 'Start backfill',
    );
    if (!confirmed || !mounted) return;

    final engine = ref.read(syncEngineProvider);
    unawaited(() async {
      try {
        if (gmailConnected) {
          await engine.runInitialGmailBackfill(force: true);
        }
        if (smsGranted) {
          await engine.runSmsBackfill(force: true);
        }
      } on AppFailure catch (failure) {
        if (!mounted) return;
        _showError(failure.message);
      } catch (_) {
        if (!mounted) return;
        _showError('The backfill stopped unexpectedly.');
      }
    }());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Backfill started. You can keep using the app.')),
    );
  }

  Future<void> _handleSms(AppPermissionStatus? status) async {
    if (status?.isGranted ?? false) {
      await ref.read(permissionServiceProvider).openSystemSettings();
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Allow SMS access?',
      message:
          'Android requires SMS permission so Spendwise can read bank and UPI '
          'alerts. Personal messages are filtered out on-device and nothing is '
          'uploaded.',
      confirmLabel: 'Allow access',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(permissionServiceProvider).requestSms();
      ref.invalidate(smsPermissionProvider);
      if (!mounted) return;
      if (result == AppPermissionStatus.permanentlyDenied) {
        final open = await showAppConfirmDialog(
          context,
          title: 'SMS access is blocked',
          message:
              'Android will not show the prompt again. Enable SMS for Spendwise '
              'in system settings, or use Gmail and notifications instead.',
          confirmLabel: 'Open settings',
        );
        if (open) {
          await ref.read(permissionServiceProvider).openSystemSettings();
        }
      } else if (!result.isGranted) {
        _showError('SMS access was not granted.');
      } else {
        // Permission was just granted: start the historical scan immediately
        // instead of waiting for the next app resume.
        unawaited(
          ref.read(syncEngineProvider).startSmsBackfillInBackground(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS access granted. Scanning history…'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleNotifications() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Notification access',
      message:
          'Android opens a system screen where you grant Spendwise access to '
          'notifications. Payment alerts from GPay, PhonePe, Paytm and banking '
          'apps are processed on-device and never uploaded.',
      confirmLabel: 'Open settings',
    );
    if (!confirmed || !mounted) return;
    await ref.read(deviceMessageSourceProvider).openNotificationSettings();
  }

  Future<void> _showAdPrivacyOptions() async {
    final shown = await ref.read(adsProvider).showPrivacyOptions();
    if (!mounted) return;
    if (!shown) {
      _showError('Ad privacy options are not available right now.');
    }
  }

  void _showPrivacy() {
    showAppMessageDialog(
      context,
      title: 'Privacy by design',
      message:
          'Spendwise has no backend. Bank alerts are read directly from Gmail '
          'with a read-only scope, from the Android SMS provider, or from '
          'notifications you explicitly allow.\n\n'
          'Parsing and categorisation happen on this device. The ledger and '
          'sync cursors are stored in an encrypted Hive database whose AES-256 '
          'key lives in the platform keystore. Raw alert text is kept only so '
          'you can verify a transaction, and is deleted with the ledger.\n\n'
          'Ads are served by Google AdMob on the dashboard and inside the '
          'activity feed. They never appear in Settings, Analytics, permission '
          'dialogs or onboarding.',
    );
  }

  Future<void> _deleteEverything() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete all local data?',
      message:
          'This permanently deletes every transaction, sync cursor and sign-in '
          'state from this device. Your Google account and bank records are not '
          'affected. This cannot be undone.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final engine = ref.read(syncEngineProvider);
    try {
      // Stop both scans before deleting their cursors, otherwise an in-flight
      // page can write a stale cursor back after the boxes are cleared.
      engine.cancelCurrentSync();
      engine.stopGmailPolling();
      await engine.waitForScans();
      await engine.disconnectGmail();
      await ref.read(transactionRepositoryProvider).deleteAll();
      await ref.read(settingsRepositoryProvider).clear();
      // Reset the in-memory snapshot; otherwise "backfill complete" flags from
      // the previous account would survive the wipe.
      await engine.reload();
      if (!mounted) return;
      ref.read(transactionFilterProvider.notifier).state =
          const TransactionFilter();
      ref.read(selectedMonthProvider.notifier).state =
          DateTimeUtils.firstDayOfMonth(DateTime.now());
      ref.read(homeTabProvider.notifier).state = 0;
      ref.read(onboardingCompleteProvider.notifier).state = false;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      _showError('Local data could not be deleted.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.bodySmall),
      trailing: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final ChannelSyncProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            progress.message ?? 'Scanning…',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
