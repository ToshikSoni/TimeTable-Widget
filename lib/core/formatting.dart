import 'package:intl/intl.dart';

import 'models.dart';

const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String weekdayName(int weekday) => weekdayNames[weekday - 1];
String weekdayShort(int weekday) => weekdayNames[weekday - 1].substring(0, 3);

/// Formats wall-clock times consistently across the app.
class TimeFormat {
  const TimeFormat(this.use24h);
  final bool use24h;

  String minutes(Minutes m) {
    final h = (m ~/ 60) % 24;
    final min = m % 60;
    if (use24h) {
      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    final suffix = h < 12 ? 'AM' : 'PM';
    return '$hour12:${min.toString().padLeft(2, '0')} $suffix';
  }

  String time(DateTime t) => minutes(t.hour * 60 + t.minute);

  String range(Minutes a, Minutes b) => '${minutes(a)} – ${minutes(b)}';
  String rangeOf(DateTime a, DateTime b) => '${time(a)} – ${time(b)}';
}

/// "in 5 min", "in 1 h 20 min", "2 days".
String humanDuration(Duration d, {bool short = false}) {
  final mins = d.inMinutes;
  if (mins < 1) return short ? '<1m' : 'less than a minute';
  if (mins < 60) return short ? '${mins}m' : '$mins min';
  final h = d.inHours;
  if (h < 24) {
    final m = mins % 60;
    if (short) return m == 0 ? '${h}h' : '${h}h ${m}m';
    return m == 0 ? '$h h' : '$h h $m min';
  }
  final days = d.inDays;
  return short ? '${days}d' : '$days ${days == 1 ? 'day' : 'days'}';
}

/// "Today", "Tomorrow", "Yesterday" or "Mon, 3 Feb".
String relativeDay(DateTime date, DateTime now) {
  final d = dateOnly(date).difference(dateOnly(now)).inDays;
  if (d == 0) return 'Today';
  if (d == 1) return 'Tomorrow';
  if (d == -1) return 'Yesterday';
  if (d > 1 && d < 7) return DateFormat('EEEE').format(date);
  return DateFormat('EEE, d MMM').format(date);
}

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String leadTimeLabel(int minutes) {
  if (minutes == 0) return 'At start time';
  if (minutes < 60) return '$minutes minutes before';
  if (minutes % 1440 == 0) {
    final d = minutes ~/ 1440;
    return '$d ${d == 1 ? 'day' : 'days'} before';
  }
  if (minutes % 60 == 0) {
    final h = minutes ~/ 60;
    return '$h ${h == 1 ? 'hour' : 'hours'} before';
  }
  return '${minutes ~/ 60} h ${minutes % 60} min before';
}
