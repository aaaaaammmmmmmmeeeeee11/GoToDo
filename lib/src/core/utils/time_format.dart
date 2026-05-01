String formatDurationSeconds(int totalSeconds) {
  final seconds = totalSeconds.abs();
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remain = seconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remain.toString().padLeft(2, '0')}';
}

String formatDurationHms(int totalSeconds) {
  final seconds = totalSeconds.abs();
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remain = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
}

String formatHumanDuration(int totalSeconds) {
  final seconds = totalSeconds.abs();
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0 && minutes == 0) return '${seconds % 60}秒';
  if (hours == 0) return '$minutes分钟';
  if (minutes == 0) return '$hours小时';
  return '$hours小时$minutes分钟';
}

String formatDurationPreset(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (seconds == 0) return '$minutes分钟';
  if (minutes == 0) return '$seconds秒';
  return '$minutes分$seconds秒';
}

String formatDate(DateTime date) => '${date.month}月${date.day}日';

String formatDateWithWeekday(DateTime date) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${date.month}月${date.day}日 周${weekdays[date.weekday - 1]}';
}
