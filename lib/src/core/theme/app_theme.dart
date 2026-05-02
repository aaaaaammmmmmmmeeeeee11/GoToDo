import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light(int seedColorValue) {
    return _build(Brightness.light, Color(seedColorValue));
  }

  static ThemeData dark(int seedColorValue) {
    return _build(Brightness.dark, Color(seedColorValue));
  }

  static ThemeData _build(Brightness brightness, Color seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  // ── Aurora Colorful Theme ──────────────────────────────────────

  static ThemeData colorfulLight() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF7C3AED),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFEDE9FE),
      onPrimaryContainer: Color(0xFF4C1D95),
      primaryFixed: Color(0xFFEDE9FE),
      onPrimaryFixed: Color(0xFF4C1D95),
      primaryFixedDim: Color(0xFFD8B4FE),
      onPrimaryFixedVariant: Color(0xFF6D28D9),
      secondary: Color(0xFFDB2777),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFCE7F3),
      onSecondaryContainer: Color(0xFF831843),
      secondaryFixed: Color(0xFFFCE7F3),
      onSecondaryFixed: Color(0xFF831843),
      secondaryFixedDim: Color(0xFFF9A8D4),
      onSecondaryFixedVariant: Color(0xFFBE185D),
      tertiary: Color(0xFF0891B2),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFCFFAFE),
      onTertiaryContainer: Color(0xFF164E63),
      tertiaryFixed: Color(0xFFCFFAFE),
      onTertiaryFixed: Color(0xFF164E63),
      tertiaryFixedDim: Color(0xFFA5F3FC),
      onTertiaryFixedVariant: Color(0xFF0E7490),
      error: Color(0xFFE11D48),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFE4E6),
      onErrorContainer: Color(0xFF881337),
      surface: Color(0xFFFAFAFE),
      onSurface: Color(0xFF1C1A2E),
      surfaceDim: Color(0xFFDCD8E8),
      surfaceBright: Color(0xFFFAFAFE),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF5F0FF),
      surfaceContainer: Color(0xFFEDE9FE),
      surfaceContainerHigh: Color(0xFFE8E0F8),
      surfaceContainerHighest: Color(0xFFE0D8F0),
      onSurfaceVariant: Color(0xFF4A4458),
      outline: Color(0xFF79747E),
      outlineVariant: Color(0xFFCAC4D0),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: Color(0xFF7C3AED),
      inverseSurface: Color(0xFF2D2A3E),
      onInverseSurface: Color(0xFFF0EEF4),
      inversePrimary: Color(0xFFD8B4FE),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      shadowColor: scheme.primary.withValues(alpha: 0.30),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: scheme.surfaceContainerLow.withValues(alpha: 0.60),
        shadowColor: scheme.primary.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.50),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.40),
        indicatorColor: scheme.primary,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static ThemeData colorfulDark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFA78BFA),
      onPrimary: Color(0xFF2E1065),
      primaryContainer: Color(0xFF4C1D95),
      onPrimaryContainer: Color(0xFFEDE9FE),
      primaryFixed: Color(0xFFEDE9FE),
      onPrimaryFixed: Color(0xFF2E1065),
      primaryFixedDim: Color(0xFFD8B4FE),
      onPrimaryFixedVariant: Color(0xFF6D28D9),
      secondary: Color(0xFFF472B6),
      onSecondary: Color(0xFF4C0519),
      secondaryContainer: Color(0xFF831843),
      onSecondaryContainer: Color(0xFFFCE7F3),
      secondaryFixed: Color(0xFFFCE7F3),
      onSecondaryFixed: Color(0xFF4C0519),
      secondaryFixedDim: Color(0xFFF9A8D4),
      onSecondaryFixedVariant: Color(0xFFBE185D),
      tertiary: Color(0xFF22D3EE),
      onTertiary: Color(0xFF083344),
      tertiaryContainer: Color(0xFF164E63),
      onTertiaryContainer: Color(0xFFCFFAFE),
      tertiaryFixed: Color(0xFFCFFAFE),
      onTertiaryFixed: Color(0xFF083344),
      tertiaryFixedDim: Color(0xFFA5F3FC),
      onTertiaryFixedVariant: Color(0xFF0E7490),
      error: Color(0xFFFB7185),
      onError: Color(0xFF4C0519),
      errorContainer: Color(0xFF881337),
      onErrorContainer: Color(0xFFFFE4E6),
      surface: Color(0xFF0F0A1A),
      onSurface: Color(0xFFE8E0F0),
      surfaceDim: Color(0xFF0F0A1A),
      surfaceBright: Color(0xFF2D2348),
      surfaceContainerLowest: Color(0xFF0A0614),
      surfaceContainerLow: Color(0xFF161028),
      surfaceContainer: Color(0xFF1A1430),
      surfaceContainerHigh: Color(0xFF241E3A),
      surfaceContainerHighest: Color(0xFF2E2845),
      onSurfaceVariant: Color(0xFFCAC4D0),
      outline: Color(0xFF948F9A),
      outlineVariant: Color(0xFF4A4458),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: Color(0xFFA78BFA),
      inverseSurface: Color(0xFFE8E0F0),
      onInverseSurface: Color(0xFF2D2A3E),
      inversePrimary: Color(0xFF6D28D9),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      shadowColor: scheme.primary.withValues(alpha: 0.35),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        color: scheme.surfaceContainerLow.withValues(alpha: 0.50),
        shadowColor: scheme.primary.withValues(alpha: 0.30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.40),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.35),
        indicatorColor: scheme.primary,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
