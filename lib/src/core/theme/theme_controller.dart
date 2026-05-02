import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class AppThemeSettings {
  const AppThemeSettings({
    required this.themeMode,
    required this.seedColorValue,
    required this.themeType,
    required this.colorfulVariant,
  });

  final ThemeMode themeMode;
  final int seedColorValue;
  final String themeType; // 'color' | 'colorful'
  final String colorfulVariant; // 'test1' | ...

  AppThemeSettings copyWith({
    ThemeMode? themeMode,
    int? seedColorValue,
    String? themeType,
    String? colorfulVariant,
  }) {
    return AppThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      themeType: themeType ?? this.themeType,
      colorfulVariant: colorfulVariant ?? this.colorfulVariant,
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
      themeType: 'color',
      colorfulVariant: 'test1',
    );
  }

  Future<void> _load() async {
    final repository = ref.read(settingsRepositoryProvider);
    final themeMode = await repository.readThemeMode();
    final seedColorValue = await repository.readSeedColor();
    final themeType = await repository.readThemeType();
    final colorfulVariant = await repository.readColorfulVariant();
    state = AppThemeSettings(
      themeMode: themeMode,
      seedColorValue: seedColorValue,
      themeType: themeType,
      colorfulVariant: colorfulVariant,
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

  Future<void> setThemeType(String type) async {
    state = state.copyWith(themeType: type);
    await ref.read(settingsRepositoryProvider).setThemeType(type);
  }

  Future<void> setColorfulVariant(String variant) async {
    state = state.copyWith(colorfulVariant: variant);
    await ref.read(settingsRepositoryProvider).setColorfulVariant(variant);
  }
}

final appThemeControllerProvider =
    NotifierProvider<AppThemeController, AppThemeSettings>(
  AppThemeController.new,
);
