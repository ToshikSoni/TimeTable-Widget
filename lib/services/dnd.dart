import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/schedule.dart';

/// Android only: silences the phone while activities marked
/// "Do not disturb" are running. The timing is handled natively so it works
/// with the app closed; this just hands over the upcoming windows.
class DndService {
  const DndService._();

  static const _channel = MethodChannel('io.github.toshiksoni.cadence/dnd');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<bool> hasAccess() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestAccess() async {
    if (supported) await _channel.invokeMethod('requestAccess');
  }

  /// Merged DND windows for the next [days] days.
  /// [extra] adds one more window, e.g. a running focus session.
  static List<List<int>> windows(
    AppData data,
    DateTime now, {
    int days = 7,
    ({DateTime start, DateTime end})? extra,
  }) {
    final tt = data.active;
    final spans = <List<int>>[];
    if (extra != null && extra.end.isAfter(now)) {
      spans.add([extra.start.millisecondsSinceEpoch, extra.end.millisecondsSinceEpoch]);
    }
    if (tt != null) {
      final from = DateTime(now.year, now.month, now.day - 1);
      for (final o in ScheduleEngine.occurrencesBetween(tt, from, now.add(Duration(days: days)))) {
        if (!o.entry.doNotDisturb || !o.end.isAfter(now)) continue;
        spans.add([o.start.millisecondsSinceEpoch, o.end.millisecondsSinceEpoch]);
      }
    }
    spans.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<int>>[];
    for (final s in spans) {
      if (merged.isNotEmpty && s[0] <= merged.last[1]) {
        if (s[1] > merged.last[1]) merged.last[1] = s[1];
      } else {
        merged.add([...s]);
      }
    }
    return merged;
  }

  static Future<void> sync(AppData data, {({DateTime start, DateTime end})? extra}) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('schedule', {
        'windows': windows(data, DateTime.now(), extra: extra),
      });
    } catch (e) {
      debugPrint('DND scheduling failed: $e');
    }
  }
}
