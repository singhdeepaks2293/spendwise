import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/theme/app_theme.dart';
import 'package:spendwise/core/utils/date_time_utils.dart';
import 'package:spendwise/core/utils/money.dart';
import 'package:spendwise/domain/entities/analytics.dart';
import 'package:spendwise/domain/entities/category.dart';
import 'package:spendwise/domain/entities/transaction.dart';
import 'package:spendwise/presentation/theme/category_icons.dart';
import 'package:spendwise/presentation/widgets/cash_flow_chart.dart';
import 'package:spendwise/presentation/widgets/empty_state.dart';
import 'package:spendwise/presentation/widgets/month_switcher.dart';
import 'package:spendwise/presentation/widgets/section_header.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final analytics = ref.watch(analyticsProvider);
    final summary =
        analytics.valueOrNull ?? FinanceAnalytics.emptyFor(month);
    final hasData = summary.totalSpend > 0 || summary.totalIncome > 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverAppBar(
            floating: true,
            title: Text('Insights'),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        DateTimeUtils.monthLabel(month),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    MonthSwitcher(
                      month: month,
                      compact: true,
                      onChanged: (value) => ref
                          .read(selectedMonthProvider.notifier)
                          .state = value,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatCard(
                        label: 'Spent',
                        value: Money.format(summary.totalSpend, compact: true),
                        accent: AppTheme.negative,
                        icon: Icons.south_east_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Income',
                        value: Money.format(summary.totalIncome, compact: true),
                        accent: AppTheme.positive,
                        icon: Icons.north_east_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Net',
                        value:
                            '${summary.net >= 0 ? '+' : '−'}${Money.format(summary.net.abs(), compact: true)}',
                        accent: Theme.of(context).colorScheme.primary,
                        icon: Icons.balance_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!hasData)
                  Card(
                    child: EmptyState(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'Nothing to analyse yet',
                      message:
                          'Once transactions arrive for ${DateTimeUtils.monthLabel(month)}, '
                          'category and channel breakdowns will appear here.',
                    ),
                  )
                else ...<Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SectionHeader(title: 'Where it went'),
                          Text(
                            '${summary.transactionCount} alerts · '
                            '${summary.categories.length} categories',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _CategoryPie(summary: summary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SectionHeader(title: 'How you paid'),
                          const SizedBox(height: 4),
                          Text(
                            'Spending by payment mode',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 18),
                          _ChannelBars(channels: summary.channels),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SectionHeader(title: 'Top merchants'),
                          if (summary.merchants.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Merchant names were not present in this '
                                'month’s alerts.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            )
                          else
                            for (var index = 0;
                                index < summary.merchants.length;
                                index++)
                              _MerchantRow(
                                rank: index + 1,
                                merchant: summary.merchants[index],
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SectionHeader(title: 'Six-month trend'),
                          const SizedBox(height: 18),
                          CashFlowChart(points: summary.trend),
                        ],
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPie extends StatelessWidget {
  const _CategoryPie({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Keep the chart legible: top six slices plus an aggregated remainder.
    final slices = <_Slice>[];
    var otherTotal = 0.0;
    for (var index = 0; index < summary.categories.length; index++) {
      final category = summary.categories[index];
      if (index < 6) {
        slices.add(
          _Slice(
            id: category.categoryId,
            label: category.label,
            total: category.total,
            share: category.share,
          ),
        );
      } else {
        otherTotal += category.total;
      }
    }
    if (otherTotal > 0) {
      slices.add(
        _Slice(
          id: '__remainder',
          label: 'Other categories',
          total: otherTotal,
          share: summary.totalSpend == 0
              ? 0
              : otherTotal / summary.totalSpend,
        ),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 196,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 54,
                  startDegreeOffset: -90,
                  sections: <PieChartSectionData>[
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.total,
                        color: AppTheme.categoryColor(slice.id),
                        radius: 34,
                        showTitle: slice.share >= 0.07,
                        title: '${(slice.share * 100).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Money.format(summary.totalSpend, compact: true),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: <Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppTheme.categoryColor(slice.id),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  '${(slice.share * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 86,
                  child: Text(
                    Money.format(slice.total, compact: true),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Slice {
  const _Slice({
    required this.id,
    required this.label,
    required this.total,
    required this.share,
  });

  final String id;
  final String label;
  final double total;
  final double share;
}

class _ChannelBars extends StatelessWidget {
  const _ChannelBars({required this.channels});

  final List<ChannelBreakdown> channels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (channels.isEmpty) {
      return Text(
        'No payment-mode data for this month.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final maxTotal = channels
        .map((channel) => channel.total)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          maxY: maxTotal <= 0 ? 100 : maxTotal * 1.18,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxTotal <= 0 ? 100 : maxTotal * 1.18) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withOpacity(0.45),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              tooltipRoundedRadius: 10,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final channel = channels[group.x];
                return BarTooltipItem(
                  '${channel.mode.label}\n'
                  '${Money.format(channel.total)} · ${channel.count} alerts',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= channels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 52,
                      child: Text(
                        _shortMode(channels[index].mode),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (var index = 0; index < channels.length; index++)
              BarChartGroupData(
                x: index,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: channels[index].total,
                    color: AppTheme.categoryColor(
                      channels[index].mode.name,
                    ),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _shortMode(PaymentMode mode) => switch (mode) {
        PaymentMode.creditCard => 'Credit\ncard',
        PaymentMode.debitCard => 'Debit\ncard',
        PaymentMode.upi => 'UPI',
        PaymentMode.netBanking => 'Net\nbanking',
        PaymentMode.wallet => 'Wallet',
        PaymentMode.bankTransfer => 'Transfer',
        PaymentMode.cash => 'Cash',
        PaymentMode.unknown => 'Other',
      };
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({required this.rank, required this.merchant});

  final int rank;
  final MerchantBreakdown merchant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              categoryIcon(
                CategoryCatalog.byId(
                  _categoryForMerchant(merchant.name),
                ).iconKey,
              ),
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  merchant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${merchant.count} '
                  '${merchant.count == 1 ? 'alert' : 'alerts'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Money.format(merchant.total),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Best-effort icon without another classifier pass; the merchant list is
  /// already aggregated and this keeps the row visually anchored.
  String _categoryForMerchant(String name) {
    final lower = name.toLowerCase();
    for (final category in CategoryCatalog.all) {
      for (final keyword in category.keywords) {
        if (lower.contains(keyword)) return category.id;
      }
    }
    return 'other';
  }
}
