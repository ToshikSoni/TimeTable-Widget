import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../services/desktop.dart';
import '../services/notifications.dart';
import 'app_scope.dart';
import 'screens/attendance_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/today_screen.dart';
import 'screens/week_screen.dart';
import 'theme.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Today', Icons.wb_sunny_outlined, Icons.wb_sunny_rounded),
  _Destination('Week', Icons.calendar_view_week_outlined, Icons.calendar_view_week_rounded),
  _Destination('Tasks', Icons.task_alt_outlined, Icons.task_alt_rounded),
  _Destination('Attendance', Icons.insights_outlined, Icons.insights_rounded),
  _Destination('Settings', Icons.tune_outlined, Icons.tune_rounded),
];

/// Adaptive navigation: a bottom bar on phones, a rail on tablets and desktop.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _today = GlobalKey<TodayScreenState>();
  final _navigators = List.generate(_destinations.length, (_) => GlobalKey<NavigatorState>());
  StreamSubscription<String>? _taps;

  late final _pages = <Widget>[
    TodayScreen(key: _today),
    const WeekScreen(),
    const TasksScreen(),
    const AttendanceScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _taps = NotificationService.instance.taps.listen(_handlePayload);
    final launch = NotificationService.instance.takeLaunchPayload();
    if (launch != null) WidgetsBinding.instance.addPostFrameCallback((_) => _handlePayload(launch));
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  void _handlePayload(String payload) {
    if (payload.startsWith('task:')) {
      _select(2);
    } else {
      _select(0);
      final key = payload.startsWith('class:') ? payload.substring(6).split('|').first : null;
      if (key != null) _today.currentState?.showDate(parseDateKey(key));
    }
    if (DesktopShell.supported) DesktopShell.instance.showMainWindow();
  }

  void _select(int i) {
    if (i == _index) {
      // Tapping the current tab pops back to its root.
      _navigators[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _index = i);
  }

  int _taskBadge(BuildContext context) {
    final now = ClockScope.now(context);
    final end = DateTime(now.year, now.month, now.day + 1);
    return context.store.data.tasks
        .where((t) => !t.done && t.due != null && t.due!.isBefore(end))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isMedium;
    final badge = _taskBadge(context);
    final visible = [0, 1, 2, 3, 4];
    if (!visible.contains(_index)) _index = 0;

    Widget icon(int i, bool selected) {
      final d = _destinations[i];
      final child = Icon(selected ? d.selectedIcon : d.icon);
      return i == 2 && badge > 0 ? Badge(label: Text('$badge'), child: child) : child;
    }

    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _pages.length; i++)
          HeroMode(
            enabled: i == _index,
            child: TickerMode(
              enabled: i == _index,
              child: Navigator(
                key: _navigators[i],
                onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _pages[i]),
              ),
            ),
          ),
      ],
    );

    final shortcuts = <ShortcutActivator, VoidCallback>{
      for (final (n, i) in visible.indexed)
        SingleActivator(
          LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + n),
          control: true,
        ): () =>
            _select(i),
      if (DesktopShell.supported)
        const SingleActivator(LogicalKeyboardKey.keyW, control: true, shift: true):
            DesktopShell.instance.toggleWidgetMode,
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final nav = _navigators[_index].currentState;
            if (nav != null && nav.canPop()) {
              nav.pop();
            } else if (_index != 0) {
              setState(() => _index = 0);
            } else {
              SystemNavigator.pop();
            }
          },
          child: wide
              ? Scaffold(
                  body: Row(
                    children: [
                      NavigationRail(
                        extended: context.isWide,
                        minExtendedWidth: 220,
                        selectedIndex: visible.indexOf(_index),
                        onDestinationSelected: (n) => _select(visible[n]),
                        labelType: context.isWide
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
                          child: _Brand(extended: context.isWide),
                        ),
                        trailing: DesktopShell.supported
                            ? Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: context.isWide
                                        ? FilledButton.tonalIcon(
                                            onPressed: DesktopShell.instance.enterWidgetMode,
                                            icon: const Icon(Icons.picture_in_picture_alt_rounded),
                                            label: const Text('Desktop widget'),
                                          )
                                        : IconButton.filledTonal(
                                            tooltip: 'Desktop widget',
                                            onPressed: DesktopShell.instance.enterWidgetMode,
                                            icon: const Icon(Icons.picture_in_picture_alt_rounded),
                                          ),
                                  ),
                                ),
                              )
                            : null,
                        destinations: [
                          for (final i in visible)
                            NavigationRailDestination(
                              icon: icon(i, false),
                              selectedIcon: icon(i, true),
                              label: Text(_destinations[i].label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  ),
                )
              : Scaffold(
                  body: body,
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: visible.indexOf(_index),
                    onDestinationSelected: (n) => _select(visible[n]),
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      for (final i in visible)
                        NavigationDestination(
                          icon: icon(i, false),
                          selectedIcon: icon(i, true),
                          label: _destinations[i].label,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/branding/icon-128.png', width: 40, height: 40),
      ),
      if (extended) ...[const SizedBox(width: 12), Text('Cadence', style: context.text.titleLarge)],
    ],
  );
}
