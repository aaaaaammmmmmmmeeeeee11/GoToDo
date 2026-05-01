import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/settings_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/focus_enums.dart';
import '../../../core/providers.dart';

enum TimerRunStatus { idle, running, paused }

class FocusTimerState {
  const FocusTimerState({
    required this.status,
    required this.mode,
    required this.now,
    this.sessionId,
    this.projectId,
    this.startAt,
    this.lastPausedAt,
    this.plannedSeconds = 0,
    this.pauseSeconds = 0,
    this.effectiveSeconds = 0,
  });

  factory FocusTimerState.idle() {
    return FocusTimerState(
      status: TimerRunStatus.idle,
      mode: FocusMode.countUp,
      now: DateTime.now(),
    );
  }

  final TimerRunStatus status;
  final FocusMode mode;
  final DateTime now;
  final String? sessionId;
  final String? projectId;
  final DateTime? startAt;
  final DateTime? lastPausedAt;
  final int plannedSeconds;
  final int pauseSeconds;
  final int effectiveSeconds;

  bool get isActive => status != TimerRunStatus.idle;

  int elapsedSeconds([DateTime? at]) {
    if (status == TimerRunStatus.idle || startAt == null) return 0;
    if (status == TimerRunStatus.paused) return effectiveSeconds;
    final target = at ?? now;
    return math.max(0, target.difference(startAt!).inSeconds - pauseSeconds);
  }

  int remainingSeconds([DateTime? at]) {
    if (mode == FocusMode.countUp) return 0;
    return math.max(0, plannedSeconds - elapsedSeconds(at));
  }

  FocusTimerState copyWith({
    TimerRunStatus? status,
    FocusMode? mode,
    DateTime? now,
    String? sessionId,
    String? projectId,
    DateTime? startAt,
    DateTime? lastPausedAt,
    int? plannedSeconds,
    int? pauseSeconds,
    int? effectiveSeconds,
    bool clearSession = false,
    bool clearLastPausedAt = false,
  }) {
    if (clearSession) return FocusTimerState.idle();
    return FocusTimerState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      now: now ?? this.now,
      sessionId: sessionId ?? this.sessionId,
      projectId: projectId ?? this.projectId,
      startAt: startAt ?? this.startAt,
      lastPausedAt: clearLastPausedAt
          ? null
          : (lastPausedAt ?? this.lastPausedAt),
      plannedSeconds: plannedSeconds ?? this.plannedSeconds,
      pauseSeconds: pauseSeconds ?? this.pauseSeconds,
      effectiveSeconds: effectiveSeconds ?? this.effectiveSeconds,
    );
  }
}

class FocusTimerController extends Notifier<FocusTimerState> {
  Timer? _ticker;
  bool _autoCompleting = false;

  @override
  FocusTimerState build() {
    ref.onDispose(() => _ticker?.cancel());
    Future.microtask(_restoreActiveSession);
    return FocusTimerState.idle();
  }

  Future<void> start({
    required Project project,
    required FocusMode mode,
    required int plannedSeconds,
  }) async {
    final now = DateTime.now();
    final repository = ref.read(focusSessionRepositoryProvider);
    final sessionId = await repository.startSession(
      projectId: project.id,
      mode: mode,
      plannedSeconds: plannedSeconds,
      startAt: now,
    );

    state = FocusTimerState(
      status: TimerRunStatus.running,
      mode: mode,
      now: now,
      sessionId: sessionId,
      projectId: project.id,
      startAt: now,
      plannedSeconds: plannedSeconds,
    );
    _startTicker();
    final settings = ref.read(settingsRepositoryProvider);
    final soundEnabled = await settings.readBool(
      SettingsKeys.notificationSound,
      defaultValue: true,
    );
    final vibrationEnabled = await settings.readBool(
      SettingsKeys.notificationVibration,
      defaultValue: true,
    );
    await ref
        .read(nativeTimerPlatformProvider)
        .start(
          projectName: project.name,
          mode: mode,
          startAt: now,
          plannedSeconds: plannedSeconds,
          soundEnabled: soundEnabled,
          vibrationEnabled: vibrationEnabled,
        );
  }

  Future<void> pause() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.status != TimerRunStatus.running) return;
    final now = DateTime.now();
    final elapsed = state.elapsedSeconds(now);
    await ref
        .read(focusSessionRepositoryProvider)
        .pauseSession(id: sessionId, effectiveSeconds: elapsed, pausedAt: now);
    state = state.copyWith(
      status: TimerRunStatus.paused,
      now: now,
      lastPausedAt: now,
      effectiveSeconds: elapsed,
    );
    await ref.read(nativeTimerPlatformProvider).pause();
  }

  Future<void> resume() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.status != TimerRunStatus.paused) return;
    final now = DateTime.now();
    final lastPausedAt = state.lastPausedAt;
    final addedPause = lastPausedAt == null
        ? 0
        : math.max(0, now.difference(lastPausedAt).inSeconds);
    final pauseSeconds = state.pauseSeconds + addedPause;
    await ref
        .read(focusSessionRepositoryProvider)
        .resumeSession(id: sessionId, pauseSeconds: pauseSeconds);
    state = state.copyWith(
      status: TimerRunStatus.running,
      now: now,
      pauseSeconds: pauseSeconds,
      clearLastPausedAt: true,
    );
    _startTicker();
    await ref.read(nativeTimerPlatformProvider).resume();
  }

  Future<void> complete({bool notifyCountdownDone = false}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.status == TimerRunStatus.idle) return;

    final now = DateTime.now();
    var pauseSeconds = state.pauseSeconds;
    if (state.status == TimerRunStatus.paused && state.lastPausedAt != null) {
      pauseSeconds += math.max(
        0,
        now.difference(state.lastPausedAt!).inSeconds,
      );
    }
    var elapsed = state.elapsedSeconds(now);
    if (state.mode == FocusMode.countDown && state.plannedSeconds > 0) {
      elapsed = math.min(elapsed, state.plannedSeconds);
    }
    if (elapsed <= 0) {
      await cancel();
      return;
    }

    final shouldNotifyCountdownDone =
        notifyCountdownDone && state.mode == FocusMode.countDown;
    await ref
        .read(focusSessionRepositoryProvider)
        .completeSession(
          id: sessionId,
          endAt: now,
          effectiveSeconds: elapsed,
          pauseSeconds: pauseSeconds,
        );
    _ticker?.cancel();
    state = state.copyWith(clearSession: true);
    if (shouldNotifyCountdownDone) {
      await ref.read(nativeTimerPlatformProvider).completeCountdown();
    } else {
      await ref.read(nativeTimerPlatformProvider).stop();
    }
  }

  Future<void> cancel() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    await ref.read(focusSessionRepositoryProvider).cancelSession(sessionId);
    _ticker?.cancel();
    state = state.copyWith(clearSession: true);
    await ref.read(nativeTimerPlatformProvider).stop();
  }

  Future<void> _restoreActiveSession() async {
    final session = await ref
        .read(focusSessionRepositoryProvider)
        .getActiveSession();
    if (session == null) return;

    final status = sessionStatusFromStorage(session.status);
    state = FocusTimerState(
      status: status == SessionStatus.paused
          ? TimerRunStatus.paused
          : TimerRunStatus.running,
      mode: focusModeFromStorage(session.mode),
      now: DateTime.now(),
      sessionId: session.id,
      projectId: session.projectId,
      startAt: session.startAt,
      lastPausedAt: session.lastPausedAt,
      plannedSeconds: session.plannedSeconds,
      pauseSeconds: session.pauseSeconds,
      effectiveSeconds: session.effectiveSeconds,
    );
    if (state.status == TimerRunStatus.running) _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status != TimerRunStatus.running) return;
      state = state.copyWith(now: DateTime.now());
      if (state.mode == FocusMode.countDown &&
          state.remainingSeconds() <= 0 &&
          !_autoCompleting) {
        _autoCompleting = true;
        complete(
          notifyCountdownDone: true,
        ).whenComplete(() => _autoCompleting = false);
      }
    });
  }
}

final focusTimerControllerProvider =
    NotifierProvider<FocusTimerController, FocusTimerState>(
      FocusTimerController.new,
    );
