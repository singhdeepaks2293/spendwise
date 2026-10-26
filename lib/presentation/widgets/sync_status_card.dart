import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/error/failures.dart';
import 'package:spendwise/domain/entities/sync_state.dart';

/// Compact, honest sync status. It only appears when there is something to say:
/// a running scan, a failure, or an unfinished first-time backfill.
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(syncSnapshotProvider).valueOrNull;
    if (snapshot == null) return const SizedBox.shrink();

    final deviceSupported = ref.watch(deviceMessageSourceProvider).isSupported;
    final smsGranted = deviceSupported &&
        (ref.watch(smsPermissionProvider).valueOrNull?.isGranted ?? false);
    final gmailPending =
        snapshot.gmailConnected && !snapshot.initialGmailComplete;
    // Never advertise an SMS backfill that cannot run: without the runtime
    // permission the native inbox query fails immediately.
    final smsPending = smsGranted && !snapshot.initialSmsComplete;
    final show = snapshot.isBusy ||
        snapshot.gmail.isFailed ||
        snapshot.sms.isFailed ||
        gmailPending ||
        smsPending;
    if (!show) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    snapshot.isBusy
                        ? Icons.sync_rounded
                        : Icons.cloud_sync_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      snapshot.isBusy ? 'Syncing alerts' : 'Sync status',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (snapshot.isBusy)
                    TextButton(
                      onPressed: () =>
                          ref.read(syncEngineProvider).cancelCurrentSync(),
                      child: const Text('Pause'),
                    )
                  else
                    TextButton(
                      onPressed: () => _syncNow(context, ref, snapshot),
                      child: const Text('Sync now'),
                    ),
                ],
              ),
              if (snapshot.gmailConnected || snapshot.gmail.isFailed)
                _ChannelRow(
                  icon: Icons.mail_rounded,
                  label: 'Gmail',
                  progress: snapshot.gmail,
                  fallback: snapshot.initialGmailComplete
                      ? 'Up to date'
                      : 'Waiting to scan',
                ),
              if (smsGranted &&
                  (snapshot.sms.isRunning ||
                      snapshot.sms.isFailed ||
                      smsPending))
                _ChannelRow(
                  icon: Icons.sms_rounded,
                  label: 'SMS',
                  progress: snapshot.sms,
                  fallback: snapshot.initialSmsComplete
                      ? 'Up to date'
                      : 'Waiting to scan',
                ),
              if (!snapshot.gmailConnected && gmailPending == false)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Gmail is not connected. Connect it in Settings to import '
                    'email receipts.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              // A channel failure is already rendered inside its row. Showing
              // the same text again as a global error just doubles the noise.
              if (snapshot.lastError != null &&
                  snapshot.lastError != snapshot.gmail.message &&
                  snapshot.lastError != snapshot.sms.message)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.error_outline_rounded,
                          size: 16, color: scheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          snapshot.lastError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncNow(
    BuildContext context,
    WidgetRef ref,
    SyncSnapshot snapshot,
  ) async {
    final engine = ref.read(syncEngineProvider);
    final deviceSupported = ref.read(deviceMessageSourceProvider).isSupported;
    try {
      final smsGranted = deviceSupported &&
          (await ref.read(permissionServiceProvider).smsStatus()).isGranted;

      if (!snapshot.gmailConnected && !smsGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Connect Gmail or allow SMS access in Settings to sync.',
              ),
            ),
          );
        }
        return;
      }

      if (snapshot.gmailConnected) {
        if (!snapshot.initialGmailComplete) {
          await engine.runInitialGmailBackfill();
        } else {
          await engine.syncGmailIncremental();
        }
      }
      if (smsGranted && !snapshot.initialSmsComplete) {
        await engine.runSmsBackfill();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync finished.')),
        );
      }
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync could not be completed.')),
      );
    }
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.icon,
    required this.label,
    required this.progress,
    required this.fallback,
  });

  final IconData icon;
  final String label;
  final ChannelSyncProgress progress;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = progress.fraction;
    final message = progress.message ??
        (progress.isRunning
            ? 'Scanning…'
            : progress.isFailed
                ? 'Paused after an error'
                : fallback);

    final detail = progress.processed > 0
        ? '$message · ${progress.processed} scanned · ${progress.inserted} new'
        : message;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: progress.isFailed
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                if (progress.isRunning) ...<Widget>[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 5,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
