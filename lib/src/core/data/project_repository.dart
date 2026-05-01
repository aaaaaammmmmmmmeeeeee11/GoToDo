import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/focus_enums.dart';

class ProjectRepository {
  ProjectRepository(this._database);

  final AppDatabase _database;
  final _uuid = const Uuid();

  Stream<List<Project>> watchActiveProjects() =>
      _database.watchActiveProjects();

  Stream<List<Project>> watchAllProjects() => _database.watchAllProjects();

  Future<Project?> findProject(String id) => _database.findProject(id);

  Future<Project> createProject({
    required String name,
    required int colorValue,
    required FocusMode defaultMode,
    required int defaultCountdownSeconds,
  }) async {
    final id = _uuid.v4();
    await _database
        .into(_database.projects)
        .insert(
          ProjectsCompanion.insert(
            id: id,
            name: name.trim(),
            colorValue: colorValue,
            sortOrder: Value(DateTime.now().millisecondsSinceEpoch),
            defaultMode: Value(defaultMode.storageValue),
            defaultCountdownSeconds: Value(defaultCountdownSeconds),
          ),
        );
    final project = await _database.findProject(id);
    return project!;
  }

  Future<Project> updateProject({
    required String id,
    required String name,
    required int colorValue,
    required FocusMode defaultMode,
    required int defaultCountdownSeconds,
  }) async {
    await (_database.update(
      _database.projects,
    )..where((tbl) => tbl.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(name.trim()),
        colorValue: Value(colorValue),
        defaultMode: Value(defaultMode.storageValue),
        defaultCountdownSeconds: Value(defaultCountdownSeconds),
      ),
    );
    final project = await _database.findProject(id);
    return project!;
  }

  Future<void> archiveProject(String id) {
    return (_database.update(_database.projects)
          ..where((tbl) => tbl.id.equals(id)))
        .write(const ProjectsCompanion(isArchived: Value(true)));
  }
}
