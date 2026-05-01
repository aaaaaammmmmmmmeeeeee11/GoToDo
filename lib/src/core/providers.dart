import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/data_backup_service.dart';
import 'data/focus_session_repository.dart';
import 'data/project_repository.dart';
import 'data/settings_repository.dart';
import 'database/app_database.dart';
import 'native/storage_platform.dart';
import 'native/timer_platform.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(appDatabaseProvider));
});

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>((ref) {
  return FocusSessionRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final nativeTimerPlatformProvider = Provider<NativeTimerPlatform>((ref) {
  return NativeTimerPlatform();
});

final nativeStoragePlatformProvider = Provider<NativeStoragePlatform>((ref) {
  return NativeStoragePlatform();
});

final dataBackupServiceProvider = Provider<DataBackupService>((ref) {
  return DataBackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(nativeStoragePlatformProvider),
  );
});

final activeProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectRepositoryProvider).watchActiveProjects();
});

final allProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectRepositoryProvider).watchAllProjects();
});

final completedSessionsProvider = StreamProvider<List<FocusSession>>((ref) {
  return ref.watch(focusSessionRepositoryProvider).watchCompletedSessions();
});

final settingValueProvider = StreamProvider.family<String?, String>((ref, key) {
  return ref.watch(settingsRepositoryProvider).watchSetting(key);
});
