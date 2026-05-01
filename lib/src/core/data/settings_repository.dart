import 'package:flutter/material.dart';

import '../database/app_database.dart';

class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const seedColor = 'seed_color';
  static const notificationSound = 'notification_sound';
  static const notificationVibration = 'notification_vibration';
}

class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  Stream<String?> watchSetting(String key) => _database.watchSetting(key);

  Future<String?> readSetting(String key) => _database.readSetting(key);

  Future<void> writeSetting(String key, String value) {
    return _database.writeSetting(key, value);
  }

  Future<ThemeMode> readThemeMode() async {
    final value = await readSetting(SettingsKeys.themeMode);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<int> readSeedColor() async {
    final value = await readSetting(SettingsKeys.seedColor);
    return int.tryParse(value ?? '') ?? 0xFF0F766E;
  }

  Future<bool> readBool(String key, {required bool defaultValue}) async {
    final value = await readSetting(key);
    if (value == null) return defaultValue;
    return value == 'true';
  }

  Future<void> setThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return writeSetting(SettingsKeys.themeMode, value);
  }

  Future<void> setSeedColor(int colorValue) {
    return writeSetting(SettingsKeys.seedColor, colorValue.toString());
  }

  Future<void> setBool(String key, bool value) {
    return writeSetting(key, value.toString());
  }
}
