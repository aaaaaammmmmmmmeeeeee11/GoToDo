import 'package:flutter/services.dart';

import '../models/focus_enums.dart';

class NativeTimerPlatform {
  static const _methodChannel = MethodChannel('gotodo/timer');
  static const _eventChannel = EventChannel('gotodo/timer_events');

  Stream<Map<String, Object?>> timerEvents() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, Object?>{};
    });
  }

  Future<void> start({
    required String projectName,
    required FocusMode mode,
    required DateTime startAt,
    required int plannedSeconds,
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    return _safeInvoke('start', {
      'projectName': projectName,
      'mode': mode.storageValue,
      'startAtMillis': startAt.millisecondsSinceEpoch,
      'plannedSeconds': plannedSeconds,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    });
  }

  Future<void> pause() => _safeInvoke('pause');

  Future<void> resume() => _safeInvoke('resume');

  Future<void> stop() => _safeInvoke('stop');

  Future<void> completeCountdown() => _safeInvoke('complete');

  Future<void> _safeInvoke(String method, [Map<String, Object?>? args]) async {
    try {
      await _methodChannel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
