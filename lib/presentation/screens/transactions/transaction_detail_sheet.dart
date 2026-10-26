import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/theme/app_theme.dart';
import 'package:spendwise/core/utils/date_time_utils.dart';
import 'package:spendwise/core/utils/money.dart';
import 'package:spendwise/domain/entities/category.dart';
import 'package:spendwise/domain/entities/transaction.dart';
import 'package:spendwise/presentation/theme/category_icons.dart';

Future<void> showTransactionDetail(
  BuildContext context,
  Transaction transaction,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TransactionDetailSheet(transactionId: transaction.id),
  );
}

class _TransactionDetailSheet extends ConsumerWidget {
  const _TransactionDetailSheet({required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions =
        ref.watch(transactionsProvider).valueOrNull ?? const <Transaction>[];
    Transaction? transaction;
    for (final candidate in transactions) {
      if (candidate.id == transactionId) {
        transaction = candidate;
        break;
      }
    }
    if (transaction == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('This transaction is no longer available.'),
      );
    }

    final txn = transaction;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = CategoryCatalog.byId(txn.categoryId);
    final accent = AppTheme.categoryColor(category.id);
    final isCredit = txn.type.isIncome;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(categoryIcon(category.iconKey),
                    color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      txn.merchantDisplay,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${txn.source.label} · ${txn.paymentMode.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                Money.formatSigned(
                  txn.amount,
                  isCredit: isCredit,
                  currency: txn.currency,
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCredit ? AppTheme.positive : scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Row(
              children: <Widget>[
                Icon(categoryIcon(category.iconKey), size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  txn.categorySource.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Date & time',
            value: DateTimeUtils.dateTimeLabel(txn.occurredAt),
          ),
          _DetailRow(
            icon: Icons.swap_vert_rounded,
            label: 'Direction',
            value: txn.type.label,
          ),
          _DetailRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Payment mode',
            value: txn.paymentMode.label,
          ),
          if (txn.instrument != null)
            _DetailRow(
              icon: Icons.credit_card_rounded,
              label: 'Instrument',
              value: txn.instrument!,
            ),
          if (txn.referenceId != null)
            _DetailRow(
              icon: Icons.tag_rounded,
              label: 'Reference',
              value: txn.referenceId!,
            ),
          _DetailRow(
            icon: categoryIcon(txn.source.iconKey),
            label: 'Source',
            value: txn.sender,
          ),
          if (txn.balanceAfter != null)
            _DetailRow(
              icon: Icons.account_balance_rounded,
              label: 'Balance after',
              value: Money.format(txn.balanceAfter!, currency: txn.currency),
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickCategory(context, ref, txn),
                  icon: const Icon(Icons.category_outlined, size: 18),
                  label: const Text('Change category'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Delete transaction',
                onPressed: () => _delete(context, ref, txn),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              ),
            ],
          ),
          if (txn.rawText != null && txn.rawText!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                leading: Icon(Icons.notes_rounded, color: scheme.onSurfaceVariant),
                title: Text(
                  'View source alert',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Stored encrypted on this device',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SelectableText(
                      txn.rawText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.45,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Processed on-device · never uploaded',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CategoryPickerSheet(selectedId: transaction.categoryId),
    );
    if (selected == null || selected == transaction.categoryId) return;
    await ref.read(transactionRepositoryProvider).updateCategory(
          transaction.id,
          selected,
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          '${transaction.merchantDisplay} · '
          '${Money.format(transaction.amount, currency: transaction.currency)}'
          '\n\nThis removes it from your ledger. A later sync could import it '
          'again if the original alert is still available.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await ref.read(transactionRepositoryProvider).delete(transaction.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.selectedId});

  final String selectedId;

  @override
  Widget build(BuildContext context) {
    const categories = CategoryCatalog.all;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Choose a category',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category.id == selectedId;
                final accent = AppTheme.categoryColor(category.id);
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(categoryIcon(category.iconKey),
                        size: 19, color: accent),
                  ),
                  title: Text(category.label),
                  trailing: selected
                      ? Icon(Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(category.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
