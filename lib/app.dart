import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/formatting.dart';
import 'core/palette.dart';
import 'core/reminders.dart';
import 'core/schedule.dart';
import 'core/store.dart';
import 'services/desktop.dart';
import 'services/home_widget_sync.dart';
import 'services/notifications.dart';
import 'ui/app_scope.dart';
import 'ui/screens/alarm_screen.dart';
import 'ui/screens/desktop_widget_view.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

class CadenceApp extends StatefulWidget {
  const CadenceApp({super.key, required this.store});
  final AppStore store;

  @override
  State<CadenceApp> createState() => _CadenceAppState();
}

class _CadenceAppState extends State<CadenceApp> with WidgetsBindingObserver {
  final _clock = Clock();
  Timer? _syncDebounce;
  Timer? _hourly;
  int _lastMinute = -1;

  AppStore get store => widget.store;

  bool get _use24h => store.settings.use24h ?? PlatformDispatcher.instance.alwaysUse24HourFormat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_onDataChanged);
    _clock.addListener(_onTick);
    NotificationService.instance.startTicker();
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => _sync());
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_onDataChanged);
    _clock.dispose();
    _syncDebounce?.cancel();
    _hourly?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clock.refresh();
      _sync();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      store.flush();
    }
  }

  void _onDataChanged() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 800), _sync);
  }

  /// Pushes the current data to everything that lives outside the UI:
  /// scheduled notifications, home-screen widgets and the tray.
  Future<void> _sync() async {
    await NotificationService.instance.reschedule(store.data, use24h: _use24h);
    await HomeWidgetSync.push(store.data, use24h: _use24h);
    _updateTray();
  }

  void _onTick() {
    final now = _clock.now;
    if (now.minute != _lastMinute) {
      _lastMinute = now.minute;
      _updateTray();
    }
  }

  void _updateTray() {
    if (!DesktopShell.supported) return;
    final tt = store.timetable;
    if (tt == null) return;
    final now = DateTime.now();
    final fmt = TimeFormat(_use24h);
    final live = ScheduleEngine.current(tt, now);
    final next = ScheduleEngine.next(tt, now);
    final String status;
    if (live != null) {
      status = 'Now: ${live.shortTitle} until ${fmt.time(live.end)}';
    } else if (next != null) {
      final day = dateOnlyIsToday(next.start, now) ? '' : '${relativeDay(next.start, now)} ';
      status = 'Next: ${next.shortTitle} · $day${fmt.time(next.start)}';
    } else {
      status = 'No upcoming classes';
    }
    DesktopShell.instance.updateStatus(status);
  }

  bool dateOnlyIsToday(DateTime a, DateTime now) =>
      a.year == now.year && a.month == now.month && a.day == now.day;

  @override
  Widget build(BuildContext context) => AppScope(
    store: store,
    child: ClockScope(
      clock: _clock,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final seed = Color(s.accent ?? kBrandColor);
              final useDynamic =
                  s.useDynamicColor && !kIsWeb && Platform.isAndroid && lightDynamic != null;
              var light = AppTheme.scheme(seed, Brightness.light);
              var dark = AppTheme.scheme(seed, Brightness.dark);
              if (useDynamic) {
                // Re-seed from the wallpaper colour so both brightnesses
                // share one consistent tonal palette.
                light = AppTheme.scheme(lightDynamic.primary, Brightness.light);
                dark = AppTheme.scheme((darkDynamic ?? lightDynamic).primary, Brightness.dark);
              }
              return MaterialApp(
                title: 'Cadence',
                debugShowCheckedModeBanner: false,
                themeMode: s.themeMode,
                theme: AppTheme.build(light),
                darkTheme: AppTheme.build(dark),
                builder: (context, child) => _AlarmOverlay(child: child!),
                home: _Home(store: store),
              );
            },
          );
        },
      ),
    ),
  );
}

class _Home extends StatelessWidget {
  const _Home({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final main = AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: store.settings.onboarded
          ? const Shell(key: ValueKey('shell'))
          : const OnboardingScreen(key: ValueKey('onboarding')),
    );
    if (!DesktopShell.supported) return main;
    return ValueListenableBuilder<bool>(
      valueListenable: DesktopShell.instance.widgetMode,
      builder: (context, widgetMode, _) =>
          widgetMode && store.settings.onboarded ? const DesktopWidgetView() : main,
    );
  }
}

class _AlarmOverlay extends StatelessWidget {
  const _AlarmOverlay({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlannedReminder?>(
    valueListenable: NotificationService.instance.ringing,
    builder: (context, ringing, _) {
      if (ringing != null && DesktopShell.supported) {
        WidgetsBinding.instance.addPostFrameCallback((_) => DesktopShell.instance.showMainWindow());
      }
      return Stack(
        children: [
          child,
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
            child: ringing == null
                ? const SizedBox.shrink()
                : AlarmScreen(key: ValueKey(ringing.key), reminder: ringing),
          ),
        ],
      );
    },
  );
}
