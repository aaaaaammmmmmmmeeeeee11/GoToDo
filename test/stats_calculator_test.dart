import 'package:flutter_test/flutter_test.dart';
import 'package:gotodo/src/core/stats/stats_calculator.dart';

void main() {
  test('summarizeRange allocates cross-day session proportionally', () {
    final session = FocusRecord(
      id: 's1',
      projectId: 'p1',
      startAt: DateTime(2026, 4, 30, 23),
      endAt: DateTime(2026, 5, 1, 1),
      effectiveSeconds: 7200,
      status: 'completed',
    );
    final project = const ProjectRecord(
      id: 'p1',
      name: '学习',
      colorValue: 0xFF0F766E,
      dailyGoalSeconds: 3600,
      weeklyGoalSeconds: 18000,
    );

    final summary = summarizeRange(
      sessions: [session],
      projects: [project],
      rangeStart: DateTime(2026, 4, 30),
      rangeEnd: DateTime(2026, 5, 1),
      goalBasis: GoalBasis.daily,
    );

    expect(summary.totalSeconds, 3600);
    expect(summary.projects.single.goalSeconds, 3600);
  });

  test('computeStreakDays counts consecutive focused days ending today', () {
    final sessions = [
      FocusRecord(
        id: 'today',
        projectId: 'p1',
        startAt: DateTime(2026, 4, 30, 9),
        endAt: DateTime(2026, 4, 30, 10),
        effectiveSeconds: 3600,
        status: 'completed',
      ),
      FocusRecord(
        id: 'yesterday',
        projectId: 'p1',
        startAt: DateTime(2026, 4, 29, 9),
        endAt: DateTime(2026, 4, 29, 10),
        effectiveSeconds: 3600,
        status: 'completed',
      ),
    ];

    expect(
      computeStreakDays(sessions: sessions, today: DateTime(2026, 4, 30)),
      2,
    );
  });
}
