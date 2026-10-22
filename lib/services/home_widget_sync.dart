import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:home_widget/home_widget.dart';

import '../core/models.dart';
import '../core/palette.dart';
import '../core/schedule.dart';

const _providers = [
  'io.github.toshiksoni.cadence.widget.NextClassWidgetProvider',
  'io.github.toshiksoni.cadence.widget.TodayWidgetProvider',
];

/// Pushes the upcoming schedule to the Android home-screen widgets.
///
/// The widgets are rendered natively and pick "now / next" themselves from
/// this payload, so they stay correct for days without the app running.
class HomeWidgetSync {
  const HomeWidgetSync._();

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Map<String, dynamic> buildPayload(
    AppData data, {
    required DateTime now,
    required bool use24h,
    int days = 8,
  }) {
    final tt = data.active;
    final events = <Map<String, dynamic>>[];
    final banners = <Map<String, dynamic>>[];
    if (tt != null) {
      var day = dateOnly(now);
      for (var i = 0; i < days; i++) {
        final plan = ScheduleEngine.dayPlan(tt, day);
        for (final o in plan.active) {
          events.add({
            's': o.start.millisecondsSinceEpoch,
            'e': o.end.millisecondsSinceEpoch,
            't': o.title,
            'c': o.code,
            'r': o.room ?? '',
            'p': o.teacher?.code ?? '',
            'k': o.entry.kind.name,
            'col': o.color.toSigned(32),
            if (o.entry.note != null) 'n': o.entry.note,
          });
        }
        final label = switch (plan) {
          final p when p.isHoliday => 'Holiday${_suffix(p.special?.label)}',
          final p when p.followsOtherDay => 'Follows ${_weekday(p.effectiveWeekday!)} timetable',
          final p when p.special?.label != null => p.special!.label!,
          _ => null,
        };
        if (label != null) banners.add({'d': dateKey(day), 'label': label});
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }
    return {
      'v': 1,
      'generatedAt': now.millisecondsSinceEpoch,
      'timetable': tt?.name ?? '',
      'use24h': use24h,
      'theme': switch (data.settings.themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
      'accent': (data.settings.accent ?? kBrandColor).toSigned(32),
      'events': events,
      'days': banners,
    };
  }

  static Future<void> push(AppData data, {required bool use24h}) async {
    if (!supported) return;
    final now = DateTime.now();
    final payload = buildPayload(data, now: now, use24h: use24h);
    try {
      await HomeWidget.saveWidgetData<String>('cadence_payload', jsonEncode(payload));
      final boundaries = <DateTime>{
        for (final e in (payload['events'] as List).cast<Map>()) ...[
          DateTime.fromMillisecondsSinceEpoch(e['s'] as int),
          DateTime.fromMillisecondsSinceEpoch(e['e'] as int),
        ],
        // Roll the date over at midnight for the next few days.
        for (var i = 1; i <= 7; i++) DateTime(now.year, now.month, now.day + i, 0, 1),
      }.where((t) => t.isAfter(now)).toList()..sort();
      for (final name in _providers) {
        await HomeWidget.updateWidget(qualifiedAndroidName: name);
        await HomeWidget.scheduleWidgetUpdates(
          boundaries.take(120).toList(),
          qualifiedAndroidName: name,
        );
      }
    } catch (e) {
      debugPrint('Home widget update failed: $e');
    }
  }

  static Future<bool> canPin() async {
    if (!supported) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pin({bool today = false}) =>
      HomeWidget.requestPinWidget(qualifiedAndroidName: _providers[today ? 1 : 0]);
}

String _suffix(String? label) => label == null || label.isEmpty ? '' : ' · $label';

String _weekday(int d) =>
    const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d - 1];
