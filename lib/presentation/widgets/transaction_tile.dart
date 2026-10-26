import 'package:flutter/material.dart';
import 'package:spendwise/core/theme/app_theme.dart';
import 'package:spendwise/core/utils/date_time_utils.dart';
import 'package:spendwise/core/utils/money.dart';
import 'package:spendwise/domain/entities/category.dart';
import 'package:spendwise/domain/entities/transaction.dart';
import 'package:spendwise/presentation/theme/category_icons.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.transaction,
    this.onTap,
    this.showDate = true,
    super.key,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  /// False inside day-grouped lists where the header already shows the date.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = CategoryCatalog.byId(transaction.categoryId);
    final accent = AppTheme.categoryColor(category.id);
    final isCredit = transaction.type.isIncome;

    final meta = <String>[
      if (showDate) transaction.dayLabel,
      if (showDate) DateTimeUtils.timeLabel(transaction.occurredAt),
      transaction.paymentMode.label,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(categoryIcon(category.iconKey), color: accent, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    transaction.merchantDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  Money.formatSigned(
                    transaction.amount,
                    isCredit: isCredit,
                    currency: transaction.currency,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isCredit
                        ? AppTheme.positive
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
