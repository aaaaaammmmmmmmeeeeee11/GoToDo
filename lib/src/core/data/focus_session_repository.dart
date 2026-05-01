import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/focus_enums.dart';

class FocusSessionRepository {
  FocusSessionRepository(this._database);

  final AppDatabase _database;
  final _uuid = const Uuid();

  Stream<List<FocusSession>> watchCompletedSessions() {
    return _database.watchCompletedSessions();
  }

  Future<List<FocusSession>> getCompletedSessions() {
    return _database.getCompletedSessions();
  }

  Future<FocusSession?> getActiveSession() => _database.getActiveSession();

  Future<String> startSession({
    required String projectId,
    required FocusMode mode,
    required int plannedSeconds,
    required DateTime startAt,
  }) async {
    final id = _uuid.v4();
    await _database
        .into(_database.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: id,
            projectId: projectId,
            mode: mode.storageValue,
            startAt: startAt,
            plannedSeconds: Value(plannedSeconds),
            status: SessionStatus.running.storageValue,
          ),
        );
    return id;
  }

  Future<void> pauseSession({
    required String id,
    required int effectiveSeconds,
    required DateTime pausedAt,
  }) {
    return (_database.update(
      _database.focusSessions,
    )..where((tbl) => tbl.id.equals(id))).write(
      FocusSessionsCompanion(
        effectiveSeconds: Value(effectiveSeconds),
        lastPausedAt: Value(pausedAt),
        status: Value(SessionStatus.paused.storageValue),
      ),
    );
  }

  Future<void> resumeSession({required String id, required int pauseSeconds}) {
    return (_database.update(
      _database.focusSessions,
    )..where((tbl) => tbl.id.equals(id))).write(
      FocusSessionsCompanion(
        pauseSeconds: Value(pauseSeconds),
        lastPausedAt: const Value(null),
        status: Value(SessionStatus.running.storageValue),
      ),
    );
  }

  Future<void> completeSession({
    required String id,
    required DateTime endAt,
    required int effectiveSeconds,
    required int pauseSeconds,
  }) {
    return (_database.update(
      _database.focusSessions,
    )..where((tbl) => tbl.id.equals(id))).write(
      FocusSessionsCompanion(
        endAt: Value(endAt),
        effectiveSeconds: Value(effectiveSeconds),
        pauseSeconds: Value(pauseSeconds),
        lastPausedAt: const Value(null),
        status: Value(SessionStatus.completed.storageValue),
      ),
    );
  }

  Future<void> cancelSession(String id) {
    return (_database.update(
      _database.focusSessions,
    )..where((tbl) => tbl.id.equals(id))).write(
      FocusSessionsCompanion(
        endAt: Value(DateTime.now()),
        lastPausedAt: const Value(null),
        status: Value(SessionStatus.cancelled.storageValue),
      ),
    );
  }
}
