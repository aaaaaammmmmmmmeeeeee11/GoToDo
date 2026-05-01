import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/stats/stats_calculator.dart';
import '../../core/utils/time_format.dart';

class FocusDonutChart extends StatelessWidget {
  const FocusDonutChart({
    super.key,
    required this.items,
    required this.totalSeconds,
  });

  final List<ProjectAggregate> items;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '暂无专注记录',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final chart = SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 54,
                  sectionsSpace: 2,
                  sections: [
                    for (final item in items)
                      PieChartSectionData(
                        value: item.seconds.toDouble(),
                        color: Color(item.colorValue),
                        title: '',
                        radius: 42,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatHumanDuration(totalSeconds),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '总专注',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        );

        final legend = _Legend(items: items, totalSeconds: totalSeconds);
        if (isWide) {
          return Row(
            children: [
              Expanded(child: chart),
              const SizedBox(width: 16),
              Expanded(child: legend),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [chart, const SizedBox(height: 12), legend],
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items, required this.totalSeconds});

  final List<ProjectAggregate> items;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(item.colorValue),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatHumanDuration(item.seconds)),
                const SizedBox(width: 8),
                Text(
                  '${(item.seconds / totalSeconds * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
