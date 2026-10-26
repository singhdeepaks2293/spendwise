import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/constants/app_constants.dart';
import 'package:spendwise/core/error/failures.dart';
import 'package:spendwise/core/platform/permission_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  bool _connectingGmail = false;
  bool _requestingSms = false;
  bool _finishing = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

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
      unawaited(_resumeSmsBackfillIfGranted());
    }
  }

  Future<void> _resumeSmsBackfillIfGranted() async {
    if (!_isAndroid) return;
    try {
      final status = await ref.read(permissionServiceProvider).smsStatus();
      if (!mounted || !status.isGranted) return;
      await ref.read(syncEngineProvider).startSmsBackfillInBackground();
    } catch (_) {
      // The sync status card reports failures.
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Continue',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _connectGmail() async {
    if (_connectingGmail) return;
    final confirmed = await _confirm(
      title: 'Connect Gmail?',
      message:
          'Spendwise will ask Google for read-only access to your mailbox so it '
          'can find bank and card alerts. It cannot send, delete or modify mail, '
          'and no email content is uploaded anywhere.',
      confirmLabel: 'Continue to Google',
    );
    if (!confirmed || !mounted) return;

    setState(() => _connectingGmail = true);
    try {
      await ref.read(syncEngineProvider).connectGmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gmail connected. Historical alerts are scanning in the background.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gmail could not be connected.')),
      );
    } finally {
      if (mounted) setState(() => _connectingGmail = false);
    }
  }

  Future<void> _requestSms() async {
    if (_requestingSms) return;
    final confirmed = await _confirm(
      title: 'Allow SMS access?',
      message:
          'Android requires SMS permission for Spendwise to read bank and UPI '
          'alerts. Messages are filtered on-device: personal conversations are '
          'ignored, and nothing is sent to a server.',
      confirmLabel: 'Allow access',
    );
    if (!confirmed || !mounted) return;

    setState(() => _requestingSms = true);
    try {
      final status = await ref.read(permissionServiceProvider).requestSms();
      ref.invalidate(smsPermissionProvider);
      if (!mounted) return;
      if (status == AppPermissionStatus.permanentlyDenied) {
        await _showOpenSettings(
          'SMS access is blocked',
          'Android will not show the permission prompt again. Enable SMS for '
              'Spendwise in system settings, or continue with Gmail only.',
        );
      } else if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('SMS access was not granted. You can enable it later.'),
          ),
        );
      } else {
        unawaited(
          ref.read(syncEngineProvider).startSmsBackfillInBackground(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS access granted. Scanning history…'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingSms = false);
    }
  }

  Future<void> _enableNotifications() async {
    final confirmed = await _confirm(
      title: 'Enable notification access?',
      message:
          'Spendwise can turn payment notifications from GPay, PhonePe, Paytm '
          'and banking apps into transactions. Android opens a system screen '
          'where you grant access to Spendwise. Notification content is '
          'processed on-device and never uploaded.',
      confirmLabel: 'Open settings',
    );
    if (!confirmed || !mounted) return;
    await ref.read(deviceMessageSourceProvider).openNotificationSettings();
  }

  Future<void> _showOpenSettings(String title, String message) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (open ?? false) {
      await ref.read(permissionServiceProvider).openSystemSettings();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setBool(AppConstants.kOnboardingComplete, true);
      if (!mounted) return;
      ref.read(onboardingCompleteProvider.notifier).state = true;
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your preference could not be saved. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sync = ref.watch(syncSnapshotProvider).valueOrNull;
    final smsStatus = ref.watch(smsPermissionProvider).valueOrNull;
    final notificationAccess =
        ref.watch(notificationAccessProvider).valueOrNull ?? false;
    final gmailConnected = sync?.gmailConnected ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              children: <Widget>[
                Container(
                  height: 132,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        scheme.primary,
                        scheme.primary.withOpacity(0.72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        right: -16,
                        bottom: -18,
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 150,
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white.withOpacity(0.92),
                              size: 22,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your money, without\nthe spreadsheet.',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Spendwise reads bank emails, SMS alerts and payment '
                  'notifications, then builds a categorised ledger that stays '
                  'encrypted on this device.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                const _FeatureRow(
                  icon: Icons.mail_lock_rounded,
                  title: 'Read-only Gmail',
                  subtitle:
                      'Bank and card alerts are found with a restricted scope. '
                      'No mail is ever modified.',
                ),
                const _FeatureRow(
                  icon: Icons.sms_rounded,
                  title: 'SMS & UPI notifications',
                  subtitle:
                      'Bank sender IDs only. Personal messages are filtered out '
                      'before parsing.',
                ),
                const _FeatureRow(
                  icon: Icons.offline_bolt_rounded,
                  title: 'Offline by design',
                  subtitle:
                      'No Spendwise account and no cloud ledger. Your data is '
                      'encrypted with a key held in the device keystore.',
                ),
                const SizedBox(height: 26),
                Text('Connect your sources',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'You can add or remove these later in Settings.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                _SourceCard(
                  icon: Icons.mail_rounded,
                  title: 'Gmail',
                  subtitle: gmailConnected
                      ? (sync?.gmailEmail ?? 'Connected')
                      : 'Find historical and new bank alerts',
                  trailing: gmailConnected
                      ? const _StatusPill(label: 'Connected')
                      : FilledButton.tonal(
                          onPressed: _connectingGmail ? null : _connectGmail,
                          child: _connectingGmail
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Connect'),
                        ),
                ),
                if (_isAndroid) ...<Widget>[
                  const SizedBox(height: 10),
                  _SourceCard(
                    icon: Icons.sms_rounded,
                    title: 'SMS alerts',
                    subtitle: smsStatus?.isGranted ?? false
                        ? 'Bank and UPI messages are parsed on-device'
                        : 'Required to import bank SMS history',
                    trailing: smsStatus?.isGranted ?? false
                        ? const _StatusPill(label: 'Allowed')
                        : FilledButton.tonal(
                            onPressed: _requestingSms ? null : _requestSms,
                            child: _requestingSms
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Allow'),
                          ),
                  ),
                  const SizedBox(height: 10),
                  _SourceCard(
                    icon: Icons.notifications_active_rounded,
                    title: 'Payment notifications',
                    subtitle: notificationAccess
                        ? 'GPay, PhonePe, Paytm and banking apps'
                        : 'Optional: captures live UPI payments',
                    trailing: notificationAccess
                        ? const _StatusPill(label: 'Enabled')
                        : FilledButton.tonal(
                            onPressed: _enableNotifications,
                            child: const Text('Enable'),
                          ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 10),
                  const _SourceCard(
                    icon: Icons.info_outline_rounded,
                    title: 'iOS limitation',
                    subtitle:
                        'Apple does not allow apps to read SMS or other apps’ '
                        'notifications. Gmail is the supported source on iOS.',
                    trailing: SizedBox.shrink(),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.lock_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Spendwise has no server. Parsing, categorisation and '
                          'storage happen on your phone, and you can delete '
                          'everything from Settings at any time.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton(
                  onPressed: _finishing ? null : _finish,
                  child: _finishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          gmailConnected
                              ? 'Start using Spendwise'
                              : 'Continue without Gmail',
                        ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _finishing ? null : _finish,
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
