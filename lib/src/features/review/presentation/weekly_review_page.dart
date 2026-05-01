import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/stats/stats_calculator.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/donut_chart.dart';

enum ReviewRange { current, previous }

class WeeklyReviewPage extends ConsumerStatefulWidget {
  const WeeklyReviewPage({super.key});

  @override
  ConsumerState<WeeklyReviewPage> createState() => _WeeklyReviewPageState();
}

class _WeeklyReviewPageState extends ConsumerState<WeeklyReviewPage> {
  ReviewRange _range = ReviewRange.current;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(completedSessionsProvider);
    final projectsAsync = ref.watch(allProjectsProvider);

    return SafeArea(
      child: sessionsAsync.when(
        data: (sessions) {
          final projects = projectsAsync.value ?? const <Project>[];
          final now = DateTime.now();
          final currentWeekStart = startOfWeek(now);
          final rangeStart = _range == ReviewRange.current
              ? currentWeekStart
              : currentWeekStart.subtract(const Duration(days: 7));
          final rangeEnd = rangeStart.add(const Duration(days: 7));
          final records = sessions.map(_sessionRecord).toList();
          final projectRecords = projects.map(_projectRecord).toList();
          final summary = summarizeRange(
            sessions: records,
            projects: projectRecords,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            goalBasis: GoalBasis.weekly,
          );
          final streak = computeStreakDays(sessions: records, today: now);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '一周回顾',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ReviewRange>(
                        segments: const [
                          ButtonSegment(
                            value: ReviewRange.current,
                            icon: Icon(Icons.date_range),
                            label: Text('本周'),
                          ),
                          ButtonSegment(
                            value: ReviewRange.previous,
                            icon: Icon(Icons.history),
                            label: Text('上周'),
                          ),
                        ],
                        selected: {_range},
                        onSelectionChanged: (value) =>
                            setState(() => _range = value.first),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${formatDate(rangeStart)} - ${formatDate(rangeEnd.subtract(const Duration(days: 1)))}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_range == ReviewRange.current &&
                          now.weekday != DateTime.sunday)
                        const _SundayNotice(),
                      _WeeklyMetrics(summary: summary, streak: streak),
                      const SizedBox(height: 16),
                      FocusDonutChart(
                        items: summary.projects,
                        totalSeconds: summary.totalSeconds,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(message: '周回顾加载失败：$error'),
      ),
    );
  }
}

class _SundayNotice extends StatelessWidget {
  const _SundayNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.event_available),
          title: const Text('周日结算'),
          subtitle: const Text('当前显示本周实时预览，周日会形成完整回顾。'),
        ),
      ),
    );
  }
}

class _WeeklyMetrics extends StatelessWidget {
  const _WeeklyMetrics({required this.summary, required this.streak});

  final StatsSummary summary;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: '本段总时长',
            value: formatHumanDuration(summary.totalSeconds),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(label: '连续天数', value: '$streak天'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

FocusRecord _sessionRecord(FocusSession session) {
  return FocusRecord(
    id: session.id,
    projectId: session.projectId,
    startAt: session.startAt,
    endAt: session.endAt,
    effectiveSeconds: session.effectiveSeconds,
    status: session.status,
  );
}

ProjectRecord _projectRecord(Project project) {
  return ProjectRecord(
    id: project.id,
    name: project.name,
    colorValue: project.colorValue,
    dailyGoalSeconds: project.dailyGoalSeconds,
    weeklyGoalSeconds: project.weeklyGoalSeconds,
  );
}
