import 'dart:math' as math;

class FocusRecord {
  const FocusRecord({
    required this.id,
    required this.projectId,
    required this.startAt,
    required this.endAt,
    required this.effectiveSeconds,
    required this.status,
  });

  final String id;
  final String projectId;
  final DateTime startAt;
  final DateTime? endAt;
  final int effectiveSeconds;
  final String status;
}

class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.dailyGoalSeconds,
    required this.weeklyGoalSeconds,
  });

  final String id;
  final String name;
  final int colorValue;
  final int dailyGoalSeconds;
  final int weeklyGoalSeconds;
}

class ProjectAggregate {
  const ProjectAggregate({
    required this.projectId,
    required this.name,
    required this.colorValue,
    required this.seconds,
    required this.goalSeconds,
  });

  final String projectId;
  final String name;
  final int colorValue;
  final int seconds;
  final int goalSeconds;

  double get goalProgress {
    if (goalSeconds <= 0) return 0;
    return (seconds / goalSeconds).clamp(0, 1);
  }
}

class StatsSummary {
  const StatsSummary({
    required this.totalSeconds,
    required this.projects,
    required this.goalSeconds,
  });

  final int totalSeconds;
  final List<ProjectAggregate> projects;
  final int goalSeconds;

  double get goalProgress {
    if (goalSeconds <= 0) return 0;
    return (totalSeconds / goalSeconds).clamp(0, 1);
  }
}

enum GoalBasis {
  none,
  daily,
  weekly,
}

StatsSummary summarizeRange({
  required List<FocusRecord> sessions,
  required List<ProjectRecord> projects,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  GoalBasis goalBasis = GoalBasis.none,
}) {
  final projectMap = {for (final project in projects) project.id: project};
  final secondsByProject = <String, int>{};

  for (final session in sessions) {
    final seconds = effectiveSecondsInRange(session, rangeStart, rangeEnd);
    if (seconds <= 0) continue;
    secondsByProject.update(
      session.projectId,
      (value) => value + seconds,
      ifAbsent: () => seconds,
    );
  }

  final aggregates = secondsByProject.entries.map((entry) {
    final project = projectMap[entry.key];
    return ProjectAggregate(
      projectId: entry.key,
      name: project?.name ?? '已删除项目',
      colorValue: project?.colorValue ?? 0xFF64748B,
      seconds: entry.value,
      goalSeconds: switch (goalBasis) {
        GoalBasis.daily => project?.dailyGoalSeconds ?? 0,
        GoalBasis.weekly => project?.weeklyGoalSeconds ?? 0,
        GoalBasis.none => 0,
      },
    );
  }).toList()
    ..sort((a, b) => b.seconds.compareTo(a.seconds));

  return StatsSummary(
    totalSeconds: aggregates.fold(0, (sum, item) => sum + item.seconds),
    projects: aggregates,
    goalSeconds: aggregates.fold(0, (sum, item) => sum + item.goalSeconds),
  );
}

int effectiveSecondsInRange(
  FocusRecord session,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final endAt = session.endAt;
  if (session.status != 'completed' || endAt == null) return 0;
  if (!endAt.isAfter(rangeStart) || !session.startAt.isBefore(rangeEnd)) {
    return 0;
  }

  final totalWallSeconds =
      math.max(1, endAt.difference(session.startAt).inSeconds);
  final overlapStart =
      session.startAt.isAfter(rangeStart) ? session.startAt : rangeStart;
  final overlapEnd = endAt.isBefore(rangeEnd) ? endAt : rangeEnd;
  final overlapSeconds =
      math.max(0, overlapEnd.difference(overlapStart).inSeconds);

  return ((session.effectiveSeconds * overlapSeconds) / totalWallSeconds)
      .round();
}

int computeStreakDays({
  required List<FocusRecord> sessions,
  required DateTime today,
}) {
  var cursor = dateOnly(today);
  var streak = 0;

  while (true) {
    final start = cursor;
    final end = start.add(const Duration(days: 1));
    final seconds = sessions.fold<int>(
      0,
      (sum, session) => sum + effectiveSecondsInRange(session, start, end),
    );
    if (seconds <= 0) return streak;
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime startOfWeek(DateTime date) {
  final day = dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
