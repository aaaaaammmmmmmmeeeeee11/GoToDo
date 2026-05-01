import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/focus_enums.dart';
import '../../../core/providers.dart';
import '../../../core/stats/stats_calculator.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/donut_chart.dart';

enum TimelineScope { day, all }

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  TimelineScope _scope = TimelineScope.day;
  DateTime _selectedDay = dateOnly(DateTime.now());
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month);
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(completedSessionsProvider);
    final projectsAsync = ref.watch(allProjectsProvider);

    return SafeArea(
      child: sessionsAsync.when(
        data: (sessions) {
          final projects = projectsAsync.value ?? const <Project>[];
          final records = sessions.map(_sessionRecord).toList();
          final projectRecords = projects.map(_projectRecord).toList();
          final rangeStart = _scope == TimelineScope.day
              ? _selectedDay
              : DateTime(2000);
          final rangeEnd = _scope == TimelineScope.day
              ? _selectedDay.add(const Duration(days: 1))
              : DateTime(2100);
          final summary = summarizeRange(
            sessions: records,
            projects: projectRecords,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            goalBasis: _scope == TimelineScope.day
                ? GoalBasis.daily
                : GoalBasis.none,
          );
          final visibleSessions = _visibleSessions(
            records,
            sessions,
            rangeStart,
            rangeEnd,
          );
          final recentSevenDays = _recentSevenDayPoints(records);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: _TimelineHeader(
                    scope: _scope,
                    onScopeChanged: (scope) => setState(() => _scope = scope),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_scope == TimelineScope.day) ...[
                        _MonthCalendar(
                          visibleMonth: _visibleMonth,
                          selectedDay: _selectedDay,
                          records: records,
                          onPreviousMonth: () => setState(() {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month - 1,
                            );
                          }),
                          onNextMonth: () => setState(() {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                            );
                          }),
                          onDaySelected: _selectDay,
                        ),
                        const SizedBox(height: 20),
                      ],
                      _SummaryStrip(summary: summary),
                      const SizedBox(height: 16),
                      FocusDonutChart(
                        items: summary.projects,
                        totalSeconds: summary.totalSeconds,
                      ),
                      const SizedBox(height: 24),
                      if (_scope == TimelineScope.day) ...[
                        Text(
                          '当天记录',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (visibleSessions.isEmpty)
                          const _EmptySessionList()
                        else
                          _SessionList(
                            sessions: visibleSessions,
                            projects: projects,
                          ),
                      ] else
                        _RecentSevenDaysLineChart(points: recentSevenDays),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(message: '时间线加载失败：$error'),
      ),
    );
  }

  void _selectDay(DateTime day) {
    final selected = dateOnly(day);
    setState(() {
      _selectedDay = selected;
      _visibleMonth = DateTime(selected.year, selected.month);
      _scope = TimelineScope.day;
    });
  }

  List<FocusSession> _visibleSessions(
    List<FocusRecord> records,
    List<FocusSession> sessions,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final visibleIds = {
      for (final record in records)
        if (effectiveSecondsInRange(record, rangeStart, rangeEnd) > 0)
          record.id,
    };
    return sessions
        .where((session) => visibleIds.contains(session.id))
        .toList();
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({required this.scope, required this.onScopeChanged});

  final TimelineScope scope;
  final ValueChanged<TimelineScope> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('时间线', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        SegmentedButton<TimelineScope>(
          segments: const [
            ButtonSegment(
              value: TimelineScope.day,
              icon: Icon(Icons.today),
              label: Text('按天'),
            ),
            ButtonSegment(
              value: TimelineScope.all,
              icon: Icon(Icons.all_inclusive),
              label: Text('总体'),
            ),
          ],
          selected: {scope},
          onSelectionChanged: (value) => onScopeChanged(value.first),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.selectedDay,
    required this.records,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final List<FocusRecord> records;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = _calendarDays(visibleMonth);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${visibleMonth.year}年${visibleMonth.month}月',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '上个月',
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _WeekdayRow(),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileHeight = constraints.maxWidth >= 420 ? 44.0 : 40.0;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: tileHeight,
                  ),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final inCurrentMonth =
                        day.month == visibleMonth.month &&
                        day.year == visibleMonth.year;
                    final selected = _isSameDay(day, selectedDay);
                    final isToday = _isSameDay(day, DateTime.now());
                    final hasRecord = _hasRecord(day);

                    return _CalendarDayCell(
                      day: day,
                      selected: selected,
                      isToday: isToday,
                      inCurrentMonth: inCurrentMonth,
                      hasRecord: hasRecord,
                      onTap: () => onDaySelected(day),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                formatDateWithWeekday(selectedDay),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasRecord(DateTime day) {
    final start = dateOnly(day);
    final end = start.add(const Duration(days: 1));
    for (final record in records) {
      if (effectiveSecondsInRange(record, start, end) > 0) return true;
    }
    return false;
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        for (final weekday in weekdays)
          Expanded(
            child: Center(
              child: Text(
                weekday,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.inCurrentMonth,
    required this.hasRecord,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool inCurrentMonth;
  final bool hasRecord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onPrimary
        : inCurrentMonth
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.28);

    return Semantics(
      button: true,
      selected: selected,
      label: '${day.year}年${day.month}月${day.day}日',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 34, height: 34),
                  )
                else if (isToday)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.primary),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 34, height: 34),
                  ),
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                if (hasRecord && !selected)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: inCurrentMonth
                            ? scheme.primary
                            : scheme.outlineVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: '总时长',
            value: formatHumanDuration(summary.totalSeconds),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(label: '项目数', value: '${summary.projects.length}'),
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

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions, required this.projects});

  final List<FocusSession> sessions;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final project = _findProject(session.projectId);
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(project?.colorValue ?? 0xFF64748B),
              child: Icon(
                session.mode == FocusMode.countDown.storageValue
                    ? Icons.hourglass_bottom
                    : Icons.timer_outlined,
                color: Colors.white,
              ),
            ),
            title: Text(project?.name ?? '已删除项目'),
            subtitle: Text(formatDateWithWeekday(session.startAt)),
            trailing: Text(formatHumanDuration(session.effectiveSeconds)),
          ),
        );
      },
    );
  }

  Project? _findProject(String id) {
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }
}

class _EmptySessionList extends StatelessWidget {
  const _EmptySessionList();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.inbox_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '这里还没有完成的专注记录。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyFocusPoint {
  const _DailyFocusPoint({required this.day, required this.seconds});

  final DateTime day;
  final int seconds;
}

class _RecentSevenDaysLineChart extends StatelessWidget {
  const _RecentSevenDaysLineChart({required this.points});

  final List<_DailyFocusPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxSeconds = points.fold<int>(
      0,
      (max, point) => point.seconds > max ? point.seconds : max,
    );
    final chartMaxY = _chartMaxY(maxSeconds);
    final spots = [
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), points[index].seconds.toDouble()),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '近七天专注时长',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatHumanDuration(
                    points.fold(0, (sum, point) => sum + point.seconds),
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: 0,
                  maxY: chartMaxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY / 4,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: scheme.outlineVariant, strokeWidth: 1),
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
                        reservedSize: 44,
                        interval: chartMaxY / 4,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatAxisDuration(value.round()),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${points[index].day.month}/${points[index].day.day}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (items) {
                        return [
                          for (final item in items)
                            LineTooltipItem(
                              formatHumanDuration(item.y.round()),
                              TextStyle(color: scheme.onInverseSurface),
                            ),
                        ];
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: scheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: scheme.primary,
                            strokeWidth: 2,
                            strokeColor: scheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _chartMaxY(int maxSeconds) {
    if (maxSeconds <= 0) return 3600;
    final padded = maxSeconds * 1.2;
    if (padded <= 3600) return 3600;
    if (padded <= 7200) return 7200;
    if (padded <= 14400) return 14400;
    return ((padded / 3600).ceil() * 3600).toDouble();
  }

  String _formatAxisDuration(int seconds) {
    if (seconds <= 0) return '0';
    final hours = seconds / 3600;
    if (hours >= 1) {
      return '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)}h';
    }
    return '${(seconds / 60).round()}m';
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

List<DateTime> _calendarDays(DateTime visibleMonth) {
  final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
  final firstGridDay = firstDay.subtract(
    Duration(days: firstDay.weekday - DateTime.monday),
  );
  final daysInMonth = DateTime(
    visibleMonth.year,
    visibleMonth.month + 1,
    0,
  ).day;
  final leadingDays = firstDay.weekday - DateTime.monday;
  final weekCount = ((leadingDays + daysInMonth) / 7).ceil();
  final totalDays = weekCount * 7;
  return [
    for (var index = 0; index < totalDays; index++)
      firstGridDay.add(Duration(days: index)),
  ];
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

List<_DailyFocusPoint> _recentSevenDayPoints(List<FocusRecord> records) {
  final today = dateOnly(DateTime.now());
  return [
    for (var index = 6; index >= 0; index--)
      _dailyFocusPoint(records, today.subtract(Duration(days: index))),
  ];
}

_DailyFocusPoint _dailyFocusPoint(List<FocusRecord> records, DateTime day) {
  final start = dateOnly(day);
  final end = start.add(const Duration(days: 1));
  final seconds = records.fold<int>(
    0,
    (sum, record) => sum + effectiveSecondsInRange(record, start, end),
  );
  return _DailyFocusPoint(day: start, seconds: seconds);
}
