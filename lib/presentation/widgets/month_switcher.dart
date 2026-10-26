import 'package:flutter/material.dart';
import 'package:spendwise/core/utils/date_time_utils.dart';

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    required this.month,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = DateTimeUtils.firstDayOfMonth(DateTime.now());
    final canGoForward = DateTimeUtils.firstDayOfMonth(month).isBefore(current);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: 'Previous month',
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              onChanged(DateTimeUtils.addMonths(month, -1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: compact ? 104 : 132),
          child: Text(
            DateTimeUtils.monthLabel(month),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          visualDensity: VisualDensity.compact,
          onPressed: canGoForward
              ? () => onChanged(DateTimeUtils.addMonths(month, 1))
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
