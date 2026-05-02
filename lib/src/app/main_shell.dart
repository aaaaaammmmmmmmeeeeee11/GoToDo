import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_controller.dart';
import '../features/review/presentation/weekly_review_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/timeline/presentation/timeline_page.dart';
import '../features/timer/presentation/start_execution_page.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _pages = [
    StartExecutionPage(),
    TimelinePage(),
    WeeklyReviewPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(appThemeControllerProvider);
    final isColorful = themeSettings.themeType == 'colorful';
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: isColorful
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: isDark
                      ? const [Color(0xFF1A1430), Color(0xFF0A0614)]
                      : const [Color(0xFFFAFAFE), Color(0xFFE8E0F8)],
                ),
              ),
              child: IndexedStack(index: _index, children: _pages),
            )
          : IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: isColorful
          ? _ColorfulNavBar(index: _index, isDark: isDark, onTap: (v) => setState(() => _index = v))
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: _destinations,
            ),
    );
  }
}

const _destinations = [
  NavigationDestination(
    icon: Icon(Icons.play_circle_outline),
    selectedIcon: Icon(Icons.play_circle),
    label: 'GoToDo!',
  ),
  NavigationDestination(
    icon: Icon(Icons.calendar_month_outlined),
    selectedIcon: Icon(Icons.calendar_month),
    label: '时间线',
  ),
  NavigationDestination(
    icon: Icon(Icons.donut_large_outlined),
    selectedIcon: Icon(Icons.donut_large),
    label: '一周回顾',
  ),
  NavigationDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: '设置',
  ),
];

class _ColorfulNavBar extends StatelessWidget {
  const _ColorfulNavBar({
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  final int index;
  final bool isDark;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surface.withValues(alpha: 0.65)
                : scheme.surface.withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(
                color: scheme.primary.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: onTap,
                elevation: 0,
                backgroundColor: Colors.transparent,
                indicatorColor: scheme.primary.withValues(alpha: 0.18),
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: _destinations,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
