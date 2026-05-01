import 'package:flutter/services.dart';

class NativeStoragePlatform {
  static const _methodChannel = MethodChannel('gotodo/storage');

  Future<String> backupDatabaseToDownloads({
    required String sourcePath,
    required String fileName,
  }) async {
    final path = await _invoke<String>('backupDatabaseToDownloads', {
      'sourcePath': sourcePath,
      'fileName': fileName,
    });
    if (path == null || path.isEmpty) {
      throw Exception('备份失败，未返回保存位置');
    }
    return path;
  }

  Future<String?> backupDatabaseWithPicker({
    required String sourcePath,
    required String fileName,
  }) {
    return _invoke<String>('backupDatabaseWithPicker', {
      'sourcePath': sourcePath,
      'fileName': fileName,
    });
  }

  Future<bool> restoreDatabaseWithPicker({required String targetPath}) async {
    final restored = await _invoke<bool>('restoreDatabaseWithPicker', {
      'targetPath': targetPath,
    });
    return restored ?? false;
  }

  Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
    try {
      return await _methodChannel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      throw Exception('当前平台不支持此数据操作');
    } on PlatformException catch (error) {
      final message = error.message;
      if (message == null || message.isEmpty) {
        throw Exception('数据操作失败');
      }
      throw Exception(message);
    }
  }
}
