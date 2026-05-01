import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class AppThemeSettings {
  const AppThemeSettings({
    required this.themeMode,
    required this.seedColorValue,
  });

  final ThemeMode themeMode;
  final int seedColorValue;

  AppThemeSettings copyWith({
    ThemeMode? themeMode,
    int? seedColorValue,
  }) {
    return AppThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
    );
  }
}

class AppThemeController extends Notifier<AppThemeSettings> {
  @override
  AppThemeSettings build() {
    Future.microtask(_load);
    return const AppThemeSettings(
      themeMode: ThemeMode.system,
      seedColorValue: 0xFF0F766E,
    );
  }

  Future<void> _load() async {
    final repository = ref.read(settingsRepositoryProvider);
    final themeMode = await repository.readThemeMode();
    final seedColorValue = await repository.readSeedColor();
    state = AppThemeSettings(
      themeMode: themeMode,
      seedColorValue: seedColorValue,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
  }

  Future<void> setSeedColor(int colorValue) async {
    state = state.copyWith(seedColorValue: colorValue);
    await ref.read(settingsRepositoryProvider).setSeedColor(colorValue);
  }
}

final appThemeControllerProvider =
    NotifierProvider<AppThemeController, AppThemeSettings>(
  AppThemeController.new,
);
