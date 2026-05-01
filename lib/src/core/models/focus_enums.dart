enum FocusMode {
  countUp,
  countDown,
}

enum SessionStatus {
  running,
  paused,
  completed,
  cancelled,
}

extension FocusModeLabel on FocusMode {
  String get storageValue => switch (this) {
    FocusMode.countUp => 'count_up',
    FocusMode.countDown => 'count_down',
  };

  String get label => switch (this) {
    FocusMode.countUp => '正向计时',
    FocusMode.countDown => '倒计时',
  };
}

extension SessionStatusValue on SessionStatus {
  String get storageValue => switch (this) {
    SessionStatus.running => 'running',
    SessionStatus.paused => 'paused',
    SessionStatus.completed => 'completed',
    SessionStatus.cancelled => 'cancelled',
  };
}

FocusMode focusModeFromStorage(String value) {
  return switch (value) {
    'count_down' => FocusMode.countDown,
    _ => FocusMode.countUp,
  };
}

SessionStatus sessionStatusFromStorage(String value) {
  return switch (value) {
    'paused' => SessionStatus.paused,
    'completed' => SessionStatus.completed,
    'cancelled' => SessionStatus.cancelled,
    _ => SessionStatus.running,
  };
}
