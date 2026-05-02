import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/settings_repository.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/color_picker_sheet.dart';
import '../../timer/application/focus_timer_controller.dart';

enum _BackupLocation { local, cloud }

enum _BackupDestination { downloads, custom }

enum _RestoreSource { local, cloud }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _seedColors = [
    0xFF0F4C81, // 2020 Classic Blue
    0xFFF5DF4D, // 2021 Illuminating
    0xFF6667AB, // 2022 Very Peri
    0xFFBB2649, // 2023 Viva Magenta
    0xFFFFBE98, // 2024 Peach Fuzz
    0xFFA47864, // 2025 Mocha Mousse
  ];

  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeControllerProvider);
    final usesCustomColor = !_seedColors.contains(theme.seedColorValue);
    final soundValue = ref.watch(
      settingValueProvider(SettingsKeys.notificationSound),
    );
    final vibrationValue = ref.watch(
      settingValueProvider(SettingsKeys.notificationVibration),
    );
    final projects = ref.watch(allProjectsProvider).value ?? const [];
    final sessions = ref.watch(completedSessionsProvider).value ?? const [];
    final errorColor = Theme.of(context).colorScheme.error;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '设置',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (_isBusy)
                    const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '主题',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'color',
                                icon: Icon(Icons.palette_outlined),
                                label: Text('颜色主题'),
                              ),
                              ButtonSegment(
                                value: 'colorful',
                                icon: Icon(Icons.auto_awesome),
                                label: Text('多彩主题'),
                              ),
                            ],
                            selected: {theme.themeType},
                            onSelectionChanged: _isBusy
                                ? null
                                : (value) => ref
                                      .read(appThemeControllerProvider.notifier)
                                      .setThemeType(value.first),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                avatar: const Icon(Icons.light_mode, size: 18),
                                label: const Text('浅色'),
                                selected: theme.themeMode == ThemeMode.light,
                                onSelected: _isBusy
                                    ? null
                                    : (_) => ref
                                          .read(
                                            appThemeControllerProvider.notifier,
                                          )
                                          .setThemeMode(ThemeMode.light),
                              ),
                              ChoiceChip(
                                avatar: const Icon(Icons.dark_mode, size: 18),
                                label: const Text('深色'),
                                selected: theme.themeMode == ThemeMode.dark,
                                onSelected: _isBusy
                                    ? null
                                    : (_) => ref
                                          .read(
                                            appThemeControllerProvider.notifier,
                                          )
                                          .setThemeMode(ThemeMode.dark),
                              ),
                              ChoiceChip(
                                avatar: const Icon(
                                  Icons.brightness_auto,
                                  size: 18,
                                ),
                                label: const Text('跟随系统'),
                                selected: theme.themeMode == ThemeMode.system,
                                onSelected: _isBusy
                                    ? null
                                    : (_) => ref
                                          .read(
                                            appThemeControllerProvider.notifier,
                                          )
                                          .setThemeMode(ThemeMode.system),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (theme.themeType == 'color')
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final color in _seedColors)
                                  _ThemeColorOption(
                                    colorValue: color,
                                    selected:
                                        theme.seedColorValue == color,
                                    enabled: !_isBusy,
                                    onTap: () => ref
                                        .read(
                                          appThemeControllerProvider.notifier,
                                        )
                                        .setSeedColor(color),
                                  ),
                                _ThemeColorPaletteOption(
                                  colorValue: theme.seedColorValue,
                                  selected: usesCustomColor,
                                  enabled: !_isBusy,
                                  onTap: _pickCustomThemeColor,
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _ColorfulVariantTile(
                                  title: 'test1',
                                  subtitle: '极光多彩 — 紫粉青三色碰撞',
                                  selected: theme.colorfulVariant == 'test1',
                                  enabled: !_isBusy,
                                  onTap: () => ref
                                      .read(appThemeControllerProvider.notifier)
                                      .setColorfulVariant('test1'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.notifications_active),
                          title: const Text('倒计时提示音'),
                          value: _settingBool(
                            soundValue.value,
                            defaultValue: true,
                          ),
                          onChanged: _isBusy
                              ? null
                              : (value) => ref
                                    .read(settingsRepositoryProvider)
                                    .setBool(
                                      SettingsKeys.notificationSound,
                                      value,
                                    ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(Icons.vibration),
                          title: const Text('倒计时震动'),
                          value: _settingBool(
                            vibrationValue.value,
                            defaultValue: true,
                          ),
                          onChanged: _isBusy
                              ? null
                              : (value) => ref
                                    .read(settingsRepositoryProvider)
                                    .setBool(
                                      SettingsKeys.notificationVibration,
                                      value,
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          enabled: !_isBusy,
                          leading: const Icon(Icons.backup_outlined),
                          title: const Text('备份数据'),
                          subtitle: const Text('保存到本地或云端'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showBackupOptions,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          enabled: !_isBusy,
                          leading: const Icon(Icons.restore_outlined),
                          title: const Text('恢复数据'),
                          subtitle: const Text('从本地或云端恢复数据'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showRestoreOptions,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          enabled: !_isBusy,
                          leading: Icon(
                            Icons.delete_forever_outlined,
                            color: _isBusy ? null : errorColor,
                          ),
                          title: Text(
                            '清空数据',
                            style: TextStyle(
                              color: _isBusy ? null : errorColor,
                            ),
                          ),
                          subtitle: const Text('删除所有专注项目和专注记录'),
                          onTap: _confirmClearData,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: const Text('专注项目'),
                          trailing: Text('${projects.length}'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: const Text('已完成记录'),
                          trailing: Text('${sessions.length}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBackupOptions() async {
    if (_isBusy) return;
    final location = await showModalBottomSheet<_BackupLocation>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone_android_outlined),
                title: const Text('保存到本地'),
                onTap: () => Navigator.of(context).pop(_BackupLocation.local),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('保存到云端'),
                onTap: () => Navigator.of(context).pop(_BackupLocation.cloud),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || location == null) return;

    switch (location) {
      case _BackupLocation.local:
        await _showLocalBackupOptions();
      case _BackupLocation.cloud:
        _showSnackBar('云端备份正在开发中');
    }
  }

  Future<void> _showLocalBackupOptions() async {
    final destination = await showModalBottomSheet<_BackupDestination>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('保存到 Download/GoToDoBak'),
                onTap: () =>
                    Navigator.of(context).pop(_BackupDestination.downloads),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('选择保存位置'),
                onTap: () =>
                    Navigator.of(context).pop(_BackupDestination.custom),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || destination == null) return;

    switch (destination) {
      case _BackupDestination.downloads:
        await _runDataAction(() async {
          final path = await ref
              .read(dataBackupServiceProvider)
              .backupToDownloads();
          _showSnackBar('已备份到 $path');
        });
      case _BackupDestination.custom:
        await _runDataAction(() async {
          final uri = await ref
              .read(dataBackupServiceProvider)
              .backupToCustomPath();
          if (uri == null) {
            _showSnackBar('已取消备份');
            return;
          }
          _showSnackBar('备份文件已保存');
        });
    }
  }

  Future<void> _showRestoreOptions() async {
    if (_isBusy) return;
    final source = await showModalBottomSheet<_RestoreSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('从本地恢复'),
                onTap: () => Navigator.of(context).pop(_RestoreSource.local),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('从云端恢复'),
                onTap: () => Navigator.of(context).pop(_RestoreSource.cloud),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || source == null) return;

    switch (source) {
      case _RestoreSource.local:
        await _confirmRestoreFromLocal();
      case _RestoreSource.cloud:
        _showSnackBar('云端恢复正在开发中');
    }
  }

  Future<void> _confirmRestoreFromLocal() async {
    if (_isBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复数据'),
        content: const Text('恢复会替换当前所有专注项目、记录和设置。建议先备份当前数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('选择文件'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    await _runDataAction(() async {
      await _stopActiveSession();
      final service = ref.read(dataBackupServiceProvider);
      try {
        final restored = await service.restoreFromPicker();
        if (restored) {
          _showSnackBar('数据已恢复');
        } else {
          _showSnackBar('已取消恢复');
        }
      } finally {
        ref.invalidate(appDatabaseProvider);
        ref.invalidate(appThemeControllerProvider);
        ref.invalidate(focusTimerControllerProvider);
      }
    });
  }

  Future<void> _confirmClearData() async {
    if (_isBusy) return;
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空数据'),
        content: const Text('将删除所有专注项目和专注记录，主题等基础设置会保留。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    await _runDataAction(() async {
      await _stopActiveSession();
      await ref.read(dataBackupServiceProvider).clearUserData();
      ref.invalidate(focusTimerControllerProvider);
      _showSnackBar('数据已清空');
    });
  }

  Future<void> _stopActiveSession() async {
    if (!ref.read(focusTimerControllerProvider).isActive) return;
    await ref.read(focusTimerControllerProvider.notifier).cancel();
  }

  Future<void> _runDataAction(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (error) {
      _showSnackBar(_formatError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  bool _settingBool(String? value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    return value == 'true';
  }

  Future<void> _pickCustomThemeColor() async {
    if (_isBusy) return;
    final picked = await showColorPickerSheet(
      context,
      initialColor: Color(ref.read(appThemeControllerProvider).seedColorValue),
    );
    if (!mounted || picked == null) return;
    await ref.read(appThemeControllerProvider.notifier).setSeedColor(picked);
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.colorValue, this.size = 18});

  final int colorValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ThemeColorOption extends StatelessWidget {
  const _ThemeColorOption({
    required this.colorValue,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ThemeOptionFrame(
      selected: selected,
      enabled: enabled,
      onTap: onTap,
      child: _ColorDot(colorValue: colorValue, size: 20),
    );
  }
}

class _ThemeColorPaletteOption extends StatelessWidget {
  const _ThemeColorPaletteOption({
    required this.colorValue,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _ThemeOptionFrame(
      selected: selected,
      enabled: enabled,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.palette_outlined,
            size: 22,
            color: enabled
                ? (selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant)
                : scheme.onSurface.withValues(alpha: 0.38),
          ),
          Positioned(
            right: -1,
            bottom: -2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : scheme.surface,
                shape: BoxShape.circle,
              ),
              child: _ColorDot(colorValue: colorValue, size: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionFrame extends StatelessWidget {
  const _ThemeOptionFrame({
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Opacity(opacity: enabled ? 1 : 0.45, child: child),
          ),
        ),
      ),
    );
  }
}

class _ColorfulVariantTile extends StatelessWidget {
  const _ColorfulVariantTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 22,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? scheme.onPrimaryContainer
                                  .withValues(alpha: 0.7)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 20, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
