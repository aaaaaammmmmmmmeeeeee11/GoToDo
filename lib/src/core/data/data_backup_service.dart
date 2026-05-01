import '../database/app_database.dart';
import '../native/storage_platform.dart';

class DataBackupService {
  DataBackupService(this._database, this._storagePlatform);

  final AppDatabase _database;
  final NativeStoragePlatform _storagePlatform;

  Future<String> backupToDownloads() async {
    final file = await resolveAppDatabaseFile();
    await _database.checkpoint();
    return _storagePlatform.backupDatabaseToDownloads(
      sourcePath: file.path,
      fileName: _backupFileName(),
    );
  }

  Future<String?> backupToCustomPath() async {
    final file = await resolveAppDatabaseFile();
    await _database.checkpoint();
    return _storagePlatform.backupDatabaseWithPicker(
      sourcePath: file.path,
      fileName: _backupFileName(),
    );
  }

  Future<bool> restoreFromPicker() async {
    final file = await resolveAppDatabaseFile();
    await _database.close();
    return _storagePlatform.restoreDatabaseWithPicker(targetPath: file.path);
  }

  Future<void> clearUserData() {
    return _database.clearUserData();
  }

  String _backupFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'gotodo_backup_$stamp.sqlite';
  }
}
