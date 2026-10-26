import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/utils/date_time_utils.dart';
import 'package:spendwise/core/utils/money.dart';
import 'package:spendwise/domain/entities/analytics.dart';
import 'package:spendwise/domain/entities/transaction.dart';
import 'package:spendwise/presentation/ads/dashboard_banner_ad.dart';
import 'package:spendwise/presentation/screens/settings/settings_screen.dart';
import 'package:spendwise/presentation/screens/transactions/transaction_detail_sheet.dart';
import 'package:spendwise/presentation/widgets/cash_flow_chart.dart';
import 'package:spendwise/presentation/widgets/empty_state.dart';
import 'package:spendwise/presentation/widgets/month_switcher.dart';
import 'package:spendwise/presentation/widgets/section_header.dart';
import 'package:spendwise/presentation/widgets/sync_status_card.dart';
import 'package:spendwise/presentation/widgets/transaction_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final analytics = ref.watch(analyticsProvider);
    final transactions =
        ref.watch(transactionsProvider).valueOrNull ?? const <Transaction>[];
    final summary =
        analytics.valueOrNull ?? FinanceAnalytics.emptyFor(month);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            floating: true,
            title: const Text('Spendwise'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Overview',
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
                _SpendHeroCard(summary: summary),
                const SizedBox(height: 16),
                const SyncStatusCard(),
                if (transactions.isEmpty && !analytics.isLoading)
                  Card(
                    child: EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'No transactions yet',
                      message:
                          'Connect Gmail or allow SMS access, and Spendwise will '
                          'build your ledger automatically. Everything is parsed '
                          'on this device.',
                      actionLabel: 'Open settings',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  )
                else ...<Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SectionHeader(title: 'Cash flow'),
                          Text(
                            'Spending and income over the last six months',
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
                          CashFlowChart(points: summary.trend),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        children: <Widget>[
                          SectionHeader(
                            title: 'Recent activity',
                            actionLabel: 'View all',
                            onAction: () => ref
                                .read(homeTabProvider.notifier)
                                .state = 1,
                          ),
                          if (transactions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                'Nothing here yet for this device.',
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
                                index < transactions.length && index < 5;
                                index++) ...<Widget>[
                              if (index > 0) const Divider(height: 1),
                              TransactionTile(
                                transaction: transactions[index],
                                onTap: () => showTransactionDetail(
                                  context,
                                  transactions[index],
                                ),
                              ),
                            ],
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const DashboardBannerAd(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendHeroCard extends StatelessWidget {
  const _SpendHeroCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final netPositive = summary.net >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            scheme.primary,
            isDark ? const Color(0xFF115E59) : const Color(0xFF115E59),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SPENT IN ${DateTimeUtils.monthLabel(summary.month).toUpperCase()}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withOpacity(0.72),
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(summary.totalSpend),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _HeroMetric(
                label: 'Income',
                value: Money.format(summary.totalIncome),
                icon: Icons.south_west_rounded,
              ),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: Colors.white.withOpacity(0.22),
              ),
              _HeroMetric(
                label: 'Net',
                value:
                    '${netPositive ? '+' : '−'}${Money.format(summary.net.abs())}',
                icon: netPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${summary.transactionCount} alerts',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 13, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
