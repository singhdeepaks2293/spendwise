import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:spendwise/core/theme/app_theme.dart';
import 'package:spendwise/core/utils/date_time_utils.dart';
import 'package:spendwise/core/utils/money.dart';
import 'package:spendwise/domain/entities/analytics.dart';

/// Grouped spend/income bars for the trailing six months.
class CashFlowChart extends StatelessWidget {
  const CashFlowChart({
    required this.points,
    this.height = 190,
    super.key,
  });

  final List<MonthlyTrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No cash-flow history yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final maxValue = points.fold<double>(
      0,
      (value, point) =>
          value < point.spend
              ? point.spend
              : (value < point.income ? point.income : value),
    );
    final maxY = maxValue <= 0 ? 100.0 : maxValue * 1.25;
    final interval = maxY / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  tooltipRoundedRadius: 10,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[group.x];
                    final label = rodIndex == 0 ? 'Spent' : 'Income';
                    return BarTooltipItem(
                      '${DateTimeUtils.monthLabel(point.month)}\n$label '
                      '${Money.format(rod.toY, compact: true)}',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withOpacity(0.45),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        _compactAxis(value),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateTimeUtils.shortMonthLabel(points[index].month),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: <BarChartGroupData>[
                for (var index = 0; index < points.length; index++)
                  BarChartGroupData(
                    x: index,
                    barsSpace: 3,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: points[index].spend,
                        color: AppTheme.negative.withOpacity(0.82),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: points[index].income,
                        color: AppTheme.positive.withOpacity(0.82),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          children: <Widget>[
            _LegendDot(color: AppTheme.negative, label: 'Spent'),
            SizedBox(width: 16),
            _LegendDot(color: AppTheme.positive, label: 'Income'),
          ],
        ),
      ],
    );
  }

  String _compactAxis(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(0)}Cr';
    }
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(0)}L';
    }
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(0)}k';
    }
    return '₹${value.toStringAsFixed(0)}';
  }
}


class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
