import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/focus_enums.dart';
import '../../../core/providers.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/color_picker_sheet.dart';
import '../application/focus_timer_controller.dart';

class StartExecutionPage extends ConsumerStatefulWidget {
  const StartExecutionPage({super.key});

  @override
  ConsumerState<StartExecutionPage> createState() => _StartExecutionPageState();
}

class _StartExecutionPageState extends ConsumerState<StartExecutionPage> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(activeProjectsProvider);
    final allProjectsAsync = ref.watch(allProjectsProvider);
    final timerState = ref.watch(focusTimerControllerProvider);

    return SafeArea(
      child: projectsAsync.when(
        data: (projects) {
          final allProjects = allProjectsAsync.value ?? projects;
          final selectedProjectId =
              _selectedProjectId ??
              (projects.isEmpty ? null : projects.first.id);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: _PageHeader(
                    title: timerState.isActive ? '正在专注' : 'GoToDo!',
                    subtitle: timerState.isActive
                        ? '当前记录会在结束后进入时间线'
                        : '选择项目后开始记录本次专注',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: timerState.isActive
                      ? Padding(
                          key: const ValueKey('active-timer'),
                          padding: const EdgeInsets.all(20),
                          child: _ActiveTimerPanel(
                            state: timerState,
                            project: _findProject(
                              allProjects,
                              timerState.projectId,
                            ),
                          ),
                        )
                      : projects.isEmpty
                      ? Padding(
                          key: const ValueKey('empty-projects'),
                          padding: const EdgeInsets.all(24),
                          child: _EmptyProjectsState(onCreate: _createProject),
                        )
                      : Padding(
                          key: const ValueKey('timer-form'),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: _TimerSetupForm(
                            projects: projects,
                            selectedProjectId: selectedProjectId,
                            onProjectSelected: (id) =>
                                setState(() => _selectedProjectId = id),
                            onCreateProject: _createProject,
                            onEditProject: _editProject,
                            onDeleteProject: _deleteProject,
                            onStart: selectedProjectId == null
                                ? null
                                : () => _start(projects, selectedProjectId),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(message: '本地数据加载失败：$error'),
      ),
    );
  }

  Project? _findProject(List<Project> projects, String? id) {
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  Future<void> _start(List<Project> projects, String projectId) async {
    final project = _findProject(projects, projectId);
    if (project == null) return;
    final mode = focusModeFromStorage(project.defaultMode);
    await ref
        .read(focusTimerControllerProvider.notifier)
        .start(
          project: project,
          mode: mode,
          plannedSeconds: mode == FocusMode.countDown
              ? project.defaultCountdownSeconds
              : 0,
        );
  }

  Future<void> _createProject() async {
    final project = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ProjectEditorSheet(),
    );
    if (project != null) {
      setState(() => _selectedProjectId = project.id);
    }
  }

  Future<void> _editProject(Project project) async {
    final updated = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProjectEditorSheet(project: project),
    );
    if (updated != null) {
      setState(() => _selectedProjectId = updated.id);
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除专注项目？'),
        content: Text('删除后「${project.name}」不会再出现在 GoToDo! 列表中，历史专注记录仍会保留在统计里。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(projectRepositoryProvider).archiveProject(project.id);
    if (_selectedProjectId == project.id) {
      setState(() => _selectedProjectId = null);
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TimerSetupForm extends StatelessWidget {
  const _TimerSetupForm({
    required this.projects,
    required this.selectedProjectId,
    required this.onProjectSelected,
    required this.onCreateProject,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onStart,
  });

  final List<Project> projects;
  final String? selectedProjectId;
  final ValueChanged<String> onProjectSelected;
  final VoidCallback onCreateProject;
  final ValueChanged<Project> onEditProject;
  final ValueChanged<Project> onDeleteProject;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 640 : double.infinity,
              ),
              child: _ProjectPicker(
                projects: projects,
                selectedProjectId: selectedProjectId,
                onSelected: onProjectSelected,
                onCreate: onCreateProject,
                onEdit: onEditProject,
                onDelete: onDeleteProject,
              ),
            ),
            const SizedBox(height: 28),
            Align(
              alignment: isWide ? Alignment.centerRight : Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: isWide ? 220 : constraints.maxWidth,
                  minHeight: 48,
                ),
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('GoToDo！'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({
    required this.projects,
    required this.selectedProjectId,
    required this.onSelected,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Project> projects;
  final String? selectedProjectId;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreate;
  final ValueChanged<Project> onEdit;
  final ValueChanged<Project> onDelete;

  @override
  Widget build(BuildContext context) {
    final countUpProjects = projects
        .where(
          (project) =>
              focusModeFromStorage(project.defaultMode) == FocusMode.countUp,
        )
        .toList();
    final countDownProjects = projects
        .where(
          (project) =>
              focusModeFromStorage(project.defaultMode) == FocusMode.countDown,
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '专注项目',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '新建项目',
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (countUpProjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ProjectSection(
                title: '正向计时',
                projects: countUpProjects,
                selectedProjectId: selectedProjectId,
                onSelected: onSelected,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ],
            if (countDownProjects.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ProjectSection(
                title: '倒计时',
                projects: countDownProjects,
                selectedProjectId: selectedProjectId,
                onSelected: onSelected,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectSection extends StatelessWidget {
  const _ProjectSection({
    required this.title,
    required this.projects,
    required this.selectedProjectId,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<Project> projects;
  final String? selectedProjectId;
  final ValueChanged<String> onSelected;
  final ValueChanged<Project> onEdit;
  final ValueChanged<Project> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: projects.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final project = projects[index];
            return _ProjectListItem(
              project: project,
              selected: project.id == selectedProjectId,
              onTap: () => onSelected(project.id),
              onLongPress: () => _showProjectActions(context, project),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showProjectActions(
    BuildContext context,
    Project project,
  ) async {
    final action = await showModalBottomSheet<_ProjectAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () => Navigator.of(context).pop(_ProjectAction.edit),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(_ProjectAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == _ProjectAction.edit) {
      onEdit(project);
    } else if (action == _ProjectAction.delete) {
      onDelete(project);
    }
  }
}

enum _ProjectAction { edit, delete }

class _ProjectListItem extends StatelessWidget {
  const _ProjectListItem({
    required this.project,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Project project;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = focusModeFromStorage(project.defaultMode);
    final subtitle = mode == FocusMode.countDown
        ? '${mode.label} · ${formatDurationHms(project.defaultCountdownSeconds)}'
        : mode.label;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(project.colorValue),
                child: Icon(
                  mode == FocusMode.countDown
                      ? Icons.hourglass_bottom
                      : Icons.timer_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: scheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.mode, required this.onChanged});

  final FocusMode mode;
  final ValueChanged<FocusMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FocusMode>(
      segments: const [
        ButtonSegment(
          value: FocusMode.countUp,
          icon: Icon(Icons.timer_outlined),
          label: Text('正向计时'),
        ),
        ButtonSegment(
          value: FocusMode.countDown,
          icon: Icon(Icons.hourglass_bottom),
          label: Text('倒计时'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

class _CustomDurationPicker extends StatefulWidget {
  const _CustomDurationPicker({required this.seconds, required this.onChanged});

  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  State<_CustomDurationPicker> createState() => _CustomDurationPickerState();
}

class _CustomDurationPickerState extends State<_CustomDurationPicker> {
  static const _loopOffset = 240;

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late final FixedExtentScrollController _secondController;
  late int _hours;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _setPartsFromSeconds(widget.seconds);
    _hourController = FixedExtentScrollController(
      initialItem: _loopOffset + _hours,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _loopOffset + _minutes,
    );
    _secondController = FixedExtentScrollController(
      initialItem: _loopOffset + _seconds,
    );
  }

  @override
  void didUpdateWidget(covariant _CustomDurationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds != _currentSeconds) {
      _setPartsFromSeconds(widget.seconds);
      _hourController.jumpToItem(_loopOffset + _hours);
      _minuteController.jumpToItem(_loopOffset + _minutes);
      _secondController.jumpToItem(_loopOffset + _seconds);
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '倒计时时长',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatDurationHms(widget.seconds),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Center(child: Text('小时', style: mutedStyle)),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Center(child: Text('分钟', style: mutedStyle)),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Center(child: Text('秒', style: mutedStyle)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 168,
              child: Row(
                children: [
                  Expanded(
                    child: _DurationWheel(
                      controller: _hourController,
                      itemCount: 24,
                      textStyle: textStyle,
                      onSelected: (value) {
                        _hours = value;
                        _emit();
                      },
                    ),
                  ),
                  Text(':', style: textStyle),
                  Expanded(
                    child: _DurationWheel(
                      controller: _minuteController,
                      itemCount: 60,
                      textStyle: textStyle,
                      onSelected: (value) {
                        _minutes = value;
                        _emit();
                      },
                    ),
                  ),
                  Text(':', style: textStyle),
                  Expanded(
                    child: _DurationWheel(
                      controller: _secondController,
                      itemCount: 60,
                      textStyle: textStyle,
                      onSelected: (value) {
                        _seconds = value;
                        _emit();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _currentSeconds => _hours * 3600 + _minutes * 60 + _seconds;

  void _setPartsFromSeconds(int value) {
    final normalized = value.clamp(0, 23 * 3600 + 59 * 60 + 59);
    _hours = normalized ~/ 3600;
    _minutes = (normalized % 3600) ~/ 60;
    _seconds = normalized % 60;
  }

  void _emit() {
    widget.onChanged(_currentSeconds);
  }
}

class _DurationWheel extends StatelessWidget {
  const _DurationWheel({
    required this.controller,
    required this.itemCount,
    required this.textStyle,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final TextStyle? textStyle;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 56,
      looping: true,
      squeeze: 1.12,
      useMagnifier: true,
      magnification: 1.08,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: (index) => onSelected(index % itemCount),
      children: [
        for (var index = 0; index < itemCount; index++)
          Center(
            child: Text(index.toString().padLeft(2, '0'), style: textStyle),
          ),
      ],
    );
  }
}

class _ActiveTimerPanel extends ConsumerWidget {
  const _ActiveTimerPanel({required this.state, required this.project});

  final FocusTimerState state;
  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final displaySeconds = state.mode == FocusMode.countDown
        ? state.remainingSeconds()
        : state.elapsedSeconds();
    final progress =
        state.mode == FocusMode.countDown && state.plannedSeconds > 0
        ? state.elapsedSeconds() / state.plannedSeconds
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(project?.colorValue ?? 0xFF64748B),
                  child: const Icon(Icons.flag, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project?.name ?? '专注项目',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        state.mode.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                formatDurationSeconds(displaySeconds),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontFeatures: const [],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress.clamp(0, 1)),
            ],
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (state.status == TimerRunStatus.running)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        ref.read(focusTimerControllerProvider.notifier).pause(),
                    icon: const Icon(Icons.pause),
                    label: const Text('暂停'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: () => ref
                        .read(focusTimerControllerProvider.notifier)
                        .resume(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('继续'),
                  ),
                FilledButton.icon(
                  onPressed: () => ref
                      .read(focusTimerControllerProvider.notifier)
                      .complete(),
                  icon: const Icon(Icons.check),
                  label: const Text('结束'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, ref),
                  icon: const Icon(Icons.close),
                  label: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消本次专注？'),
        content: const Text('取消后不会计入时间线和统计。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('取消专注'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(focusTimerControllerProvider.notifier).cancel();
    }
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.playlist_add, size: 52),
          const SizedBox(height: 16),
          Text('先创建一个专注项目', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '例如学习、工作、运动或阅读。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新建项目'),
          ),
        ],
      ),
    );
  }
}

class _ProjectEditorSheet extends ConsumerStatefulWidget {
  const _ProjectEditorSheet({this.project});

  final Project? project;

  @override
  ConsumerState<_ProjectEditorSheet> createState() =>
      _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends ConsumerState<_ProjectEditorSheet> {
  static const _colors = [
    0xFF0F766E,
    0xFF2563EB,
    0xFFE11D48,
    0xFF7C3AED,
    0xFFEA580C,
    0xFF16A34A,
  ];

  late final TextEditingController _nameController;
  FocusMode _mode = FocusMode.countUp;
  int _countdownSeconds = 25 * 60;
  int _colorValue = _colors.first;
  String? _error;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _nameController = TextEditingController(text: project?.name ?? '');
    if (project != null) {
      _mode = focusModeFromStorage(project.defaultMode);
      _countdownSeconds = project.defaultCountdownSeconds;
      _colorValue = project.colorValue;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    final usesCustomColor = !_colors.contains(_colorValue);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.project == null ? '新建项目' : '编辑项目',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '项目名称',
                  errorText: _error,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _colors)
                    ChoiceChip(
                      label: _ColorDot(colorValue: color),
                      selected: _colorValue == color,
                      onSelected: (_) => setState(() => _colorValue = color),
                    ),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.palette_outlined, size: 18),
                        const SizedBox(width: 8),
                        _ColorDot(colorValue: _colorValue),
                      ],
                    ),
                    selected: usesCustomColor,
                    onSelected: (_) => _pickCustomColor(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ModePicker(
                mode: _mode,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _mode == FocusMode.countDown
                    ? Padding(
                        key: const ValueKey('new-project-countdown'),
                        padding: const EdgeInsets.only(top: 16),
                        child: _CustomDurationPicker(
                          seconds: _countdownSeconds,
                          onChanged: (value) =>
                              setState(() => _countdownSeconds = value),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('new-project-countup'),
                      ),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('保存')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入项目名称');
      return;
    }
    final repository = ref.read(projectRepositoryProvider);
    final existingProject = widget.project;
    final project = existingProject == null
        ? await repository.createProject(
            name: name,
            colorValue: _colorValue,
            defaultMode: _mode,
            defaultCountdownSeconds: _countdownSeconds,
          )
        : await repository.updateProject(
            id: existingProject.id,
            name: name,
            colorValue: _colorValue,
            defaultMode: _mode,
            defaultCountdownSeconds: _countdownSeconds,
          );
    if (mounted) Navigator.of(context).pop(project);
  }

  Future<void> _pickCustomColor() async {
    final picked = await showColorPickerSheet(
      context,
      initialColor: Color(_colorValue),
    );
    if (picked != null) {
      setState(() => _colorValue = picked);
    }
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.colorValue});

  final int colorValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
      ),
    );
  }
}
