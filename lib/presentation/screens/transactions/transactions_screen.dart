import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/core/utils/date_range.dart';
import 'package:spendwise/core/utils/date_time_utils.dart';
import 'package:spendwise/core/utils/money.dart';
import 'package:spendwise/domain/entities/category.dart';
import 'package:spendwise/domain/entities/transaction.dart';
import 'package:spendwise/domain/entities/transaction_filter.dart';
import 'package:spendwise/presentation/ads/feed_native_ad.dart';
import 'package:spendwise/presentation/screens/transactions/transaction_detail_sheet.dart';
import 'package:spendwise/presentation/widgets/empty_state.dart';
import 'package:spendwise/presentation/widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(transactionFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    final notifier = ref.read(transactionFilterProvider.notifier);
    notifier.state = notifier.state.copyWith(query: value);
  }

  Future<void> _openFilters() async {
    final current = ref.read(transactionFilterProvider);
    final updated = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: current),
    );
    if (updated == null) return;
    ref.read(transactionFilterProvider.notifier).state = updated;
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(transactionFilterProvider.notifier).state =
        const TransactionFilter();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(transactionFilterProvider);
    final transactions = ref.watch(filteredTransactionsProvider);
    final all = ref.watch(transactionsProvider).valueOrNull ?? const <Transaction>[];
    final entries = _buildEntries(transactions);
    final spent = transactions
        .where((transaction) => transaction.type.isSpend)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            floating: true,
            title: const Text('Activity'),
            actions: <Widget>[
              Stack(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Filter transactions',
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  if (filter.isActive)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _searchController,
                    onChanged: _updateQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search merchant, category, amount…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: filter.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                _updateQuery('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  if (filter.isActive) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _ActiveChip(
                          label: filter.range == null
                              ? 'All time'
                              : _rangeLabel(filter.range!),
                          onRemove: () => ref
                              .read(transactionFilterProvider.notifier)
                              .state = filter.copyWith(range: null),
                        ),
                        if (filter.type != null)
                          _ActiveChip(
                            label: filter.type!.label,
                            onRemove: () => ref
                                .read(transactionFilterProvider.notifier)
                                .state = filter.copyWith(type: null),
                          ),
                        if (filter.categoryIds.isNotEmpty)
                          _ActiveChip(
                            label: filter.categoryIds.length == 1
                                ? CategoryCatalog.labelFor(
                                    filter.categoryIds.first,
                                  )
                                : '${filter.categoryIds.length} categories',
                            onRemove: () => ref
                                .read(transactionFilterProvider.notifier)
                                .state = filter.copyWith(
                                  categoryIds: const <String>{},
                                ),
                          ),
                        if (filter.paymentModes.isNotEmpty)
                          _ActiveChip(
                            label: filter.paymentModes.length == 1
                                ? filter.paymentModes.first.label
                                : '${filter.paymentModes.length} modes',
                            onRemove: () => ref
                                .read(transactionFilterProvider.notifier)
                                .state = filter.copyWith(
                                  paymentModes: const <PaymentMode>{},
                                ),
                          ),
                        if (filter.sources.isNotEmpty)
                          _ActiveChip(
                            label: filter.sources.length == 1
                                ? filter.sources.first.label
                                : '${filter.sources.length} sources',
                            onRemove: () => ref
                                .read(transactionFilterProvider.notifier)
                                .state = filter.copyWith(
                                  sources: const <TransactionSource>{},
                                ),
                          ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Text(
                        '${transactions.length} '
                        '${transactions.length == 1 ? 'transaction' : 'transactions'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const Spacer(),
                      if (spent > 0)
                        Text(
                          '${Money.format(spent)} spent',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: all.isEmpty
                    ? Icons.inbox_rounded
                    : Icons.search_off_rounded,
                title: all.isEmpty ? 'No transactions yet' : 'Nothing matches',
                message: all.isEmpty
                    ? 'New bank alerts will appear here as they arrive. You can '
                        'connect Gmail or allow SMS access in Settings.'
                    : 'Try a different search or clear some filters.',
                actionLabel: all.isEmpty ? null : 'Clear filters',
                onAction: all.isEmpty ? null : _clearFilters,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return switch (entry) {
                    _DayEntry(label: final label) => Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 2 : 18,
                          bottom: 4,
                        ),
                        child: Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ),
                    _TransactionEntry(transaction: final transaction) =>
                      TransactionTile(
                        transaction: transaction,
                        showDate: false,
                        onTap: () => showTransactionDetail(
                          context,
                          transaction,
                        ),
                      ),
                    _AdEntry(slot: final slot) => FeedNativeAd(
                        key: ValueKey<String>('feed-ad-$slot'),
                        slot: slot,
                      ),
                  };
                },
              ),
            ),
        ],
      ),
    );
  }

  List<_FeedEntry> _buildEntries(List<Transaction> transactions) {
    final entries = <_FeedEntry>[];
    String? currentDay;
    var sinceAd = 0;
    var adSlot = 0;

    for (final transaction in transactions) {
      final day = DateTimeUtils.isoDate(transaction.occurredAt);
      if (day != currentDay) {
        currentDay = day;
        entries.add(_DayEntry(transaction.dayLabel));
      }
      entries.add(_TransactionEntry(transaction));
      sinceAd++;
      if (sinceAd >= 10) {
        entries.add(_AdEntry(adSlot++));
        sinceAd = 0;
      }
    }
    return entries;
  }

  String _rangeLabel(DateRange range) {
    final start = DateTimeUtils.isoDate(range.start);
    final end = DateTimeUtils.isoDate(range.end);
    if (start == end) return start;
    return '$start → $end';
  }
}

sealed class _FeedEntry {
  const _FeedEntry();
}

class _DayEntry extends _FeedEntry {
  const _DayEntry(this.label);
  final String label;
}

class _TransactionEntry extends _FeedEntry {
  const _TransactionEntry(this.transaction);
  final Transaction transaction;
}

class _AdEntry extends _FeedEntry {
  const _AdEntry(this.slot);
  final int slot;
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final TransactionFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _categories;
  late Set<PaymentMode> _modes;
  late Set<TransactionSource> _sources;
  late TransactionType? _type;
  late DateRange? _range;
  late String _preset;

  @override
  void initState() {
    super.initState();
    _categories = <String>{...widget.initial.categoryIds};
    _modes = <PaymentMode>{...widget.initial.paymentModes};
    _sources = <TransactionSource>{...widget.initial.sources};
    _type = widget.initial.type;
    _range = widget.initial.range;
    _preset = _range == null ? 'all' : 'custom';
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _preset = preset;
      switch (preset) {
        case 'all':
          _range = null;
          break;
        case 'month':
          _range = DateRange(
            start: DateTimeUtils.firstDayOfMonth(now),
            end: now,
          );
          break;
        case '30':
          _range = DateRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );
          break;
        case '90':
          _range = DateRange(
            start: now.subtract(const Duration(days: 90)),
            end: now,
          );
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: _range == null
          ? null
          : DateTimeRange(start: _range!.start, end: _range!.end),
    );
    if (picked == null) return;
    setState(() {
      _range = DateRange(start: picked.start, end: picked.end);
      _preset = 'custom';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text('Filter activity', style: theme.textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _categories = <String>{};
                      _modes = <PaymentMode>{};
                      _sources = <TransactionSource>{};
                      _type = null;
                      _range = null;
                      _preset = 'all';
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SectionLabel('Date range'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _presetChip('All time', 'all'),
                      _presetChip('This month', 'month'),
                      _presetChip('Last 30 days', '30'),
                      _presetChip('Last 90 days', '90'),
                      ChoiceChip(
                        label: const Text('Custom…'),
                        selected: _preset == 'custom',
                        onSelected: (_) => _pickCustomRange(),
                      ),
                    ],
                  ),
                  if (_range != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${DateTimeUtils.isoDate(_range!.start)} → '
                        '${DateTimeUtils.isoDate(_range!.end)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Direction'),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _type == null,
                        onSelected: (_) => setState(() => _type = null),
                      ),
                      for (final type in <TransactionType>[
                        TransactionType.debit,
                        TransactionType.credit,
                      ])
                        ChoiceChip(
                          label: Text(type.label),
                          selected: _type == type,
                          onSelected: (_) => setState(() => _type = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Payment mode'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final mode in PaymentMode.values)
                        FilterChip(
                          label: Text(mode.label),
                          selected: _modes.contains(mode),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _modes.add(mode);
                            } else {
                              _modes.remove(mode);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Source'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final source in TransactionSource.values)
                        FilterChip(
                          label: Text(source.label),
                          selected: _sources.contains(source),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _sources.add(source);
                            } else {
                              _sources.remove(source);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Category'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final category in CategoryCatalog.all)
                        FilterChip(
                          label: Text(category.label),
                          selected: _categories.contains(category.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _categories.add(category.id);
                            } else {
                              _categories.remove(category.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      widget.initial.copyWith(
                        range: _range,
                        categoryIds: _categories,
                        paymentModes: _modes,
                        sources: _sources,
                        type: _type,
                      ),
                    ),
                    child: const Text('Apply filters'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _preset == value,
      onSelected: (_) => _applyPreset(value),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
