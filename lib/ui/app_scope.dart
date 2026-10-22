import 'dart:async';

import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../core/models.dart';
import '../core/store.dart';

/// Makes the [AppStore] available to the widget tree and rebuilds
/// dependants when data changes.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// A coarse clock for live UI (countdowns, "now" markers). Ticks on every
/// minute boundary and additionally every [_fine] while a class is running so
/// progress indicators move smoothly.
class Clock extends ChangeNotifier {
  Clock() {
    _schedule();
  }

  static const _fine = Duration(seconds: 15);
  DateTime now = DateTime.now();
  Timer? _timer;

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_fine, () {
      now = DateTime.now();
      notifyListeners();
      _schedule();
    });
  }

  /// Forces an update, e.g. when the app resumes.
  void refresh() {
    now = DateTime.now();
    notifyListeners();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class ClockScope extends InheritedNotifier<Clock> {
  const ClockScope({super.key, required Clock clock, required super.child})
    : super(notifier: clock);

  static DateTime now(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ClockScope>()?.notifier?.now ?? DateTime.now();
}

extension StoreContext on BuildContext {
  AppStore get store => AppScope.of(this);
  AppStore get readStore => AppScope.read(this);
  Settings get settings => AppScope.of(this).settings;

  bool get use24h => AppScope.of(this).settings.use24h ?? MediaQuery.alwaysUse24HourFormatOf(this);

  TimeFormat get timeFormat => TimeFormat(use24h);
}
