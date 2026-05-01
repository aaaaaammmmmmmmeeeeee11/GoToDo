import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/focus_enums.dart';

part 'app_database.g.dart';

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get colorValue => integer()();
  TextColumn get iconName => text().withDefault(const Constant('work'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get dailyGoalSeconds => integer().withDefault(const Constant(0))();
  IntColumn get weeklyGoalSeconds => integer().withDefault(const Constant(0))();
  TextColumn get defaultMode =>
      text().withDefault(const Constant('count_up'))();
  IntColumn get defaultCountdownSeconds =>
      integer().withDefault(const Constant(1500))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class FocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.restrict)();
  TextColumn get mode => text().withLength(min: 1, max: 20)();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();
  DateTimeColumn get lastPausedAt => dateTime().nullable()();
  IntColumn get effectiveSeconds => integer().withDefault(const Constant(0))();
  IntColumn get plannedSeconds => integer().withDefault(const Constant(0))();
  IntColumn get pauseSeconds => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withLength(min: 1, max: 20)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Projects, FocusSessions, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(projects, projects.defaultMode);
        await migrator.addColumn(projects, projects.defaultCountdownSeconds);
      }
    },
  );

  Stream<List<Project>> watchActiveProjects() {
    return (select(projects)
          ..where((tbl) => tbl.isArchived.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.sortOrder),
            (tbl) => OrderingTerm.asc(tbl.createdAt),
          ]))
        .watch();
  }

  Stream<List<Project>> watchAllProjects() {
    return (select(projects)..orderBy([
          (tbl) => OrderingTerm.asc(tbl.sortOrder),
          (tbl) => OrderingTerm.asc(tbl.createdAt),
        ]))
        .watch();
  }

  Future<Project?> findProject(String id) {
    return (select(
      projects,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Stream<List<FocusSession>> watchCompletedSessions() {
    return (select(focusSessions)
          ..where(
            (tbl) => tbl.status.equals(SessionStatus.completed.storageValue),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startAt)]))
        .watch();
  }

  Future<List<FocusSession>> getCompletedSessions() {
    return (select(focusSessions)
          ..where(
            (tbl) => tbl.status.equals(SessionStatus.completed.storageValue),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startAt)]))
        .get();
  }

  Future<FocusSession?> getActiveSession() {
    return (select(focusSessions)
          ..where(
            (tbl) =>
                tbl.status.equals(SessionStatus.running.storageValue) |
                tbl.status.equals(SessionStatus.paused.storageValue),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<String?> readSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) {
    return (select(appSettings)..where((tbl) => tbl.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> writeSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<void> checkpoint() {
    return customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
  }

  Future<void> clearUserData() {
    return transaction(() async {
      await delete(focusSessions).go();
      await delete(projects).go();
    });
  }
}

Future<File> resolveAppDatabaseFile() async {
  final directory = await getApplicationDocumentsDirectory();
  return File(p.join(directory.path, 'gotodo.sqlite'));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await resolveAppDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}
