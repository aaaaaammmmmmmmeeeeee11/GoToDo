import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import 'main_shell.dart';

class GoToDoApp extends ConsumerWidget {
  const GoToDoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(appThemeControllerProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoToDo',
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _colorfulLight(themeSettings)
          ?? AppTheme.light(themeSettings.seedColorValue),
      darkTheme: _colorfulDark(themeSettings)
          ?? AppTheme.dark(themeSettings.seedColorValue),
      themeMode: themeSettings.themeMode,
      home: const MainShell(),
    );
  }
}

ThemeData? _colorfulLight(AppThemeSettings s) {
  if (s.themeType != 'colorful') return null;
  return switch (s.colorfulVariant) {
    'test1' => AppTheme.colorfulLight(),
    _ => AppTheme.colorfulLight(),
  };
}

ThemeData? _colorfulDark(AppThemeSettings s) {
  if (s.themeType != 'colorful') return null;
  return switch (s.colorfulVariant) {
    'test1' => AppTheme.colorfulDark(),
    _ => AppTheme.colorfulDark(),
  };
}
