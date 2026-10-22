import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/formatting.dart';
import '../../../core/models.dart';
import '../../../core/palette.dart';
import '../../../services/desktop.dart';
import '../../../services/home_widget_sync.dart';
import '../../../services/notifications.dart';
import '../../app_scope.dart';
import '../../editors/misc_editors.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'data_actions.dart';
import 'timetable_pages.dart';

const repoUrl = 'https://github.com/ToshikSoni/TimeTable-Widget';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  bool get _desktop => DesktopShell.supported;
  bool get _android => !kIsWeb && Platform.isAndroid;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    final tt = store.timetable;
    void set(void Function(Settings s) f) => store.updateSettings(f);
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(titleSpacing: 20, title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          // Timetable --------------------------------------------------------
          const PageBody(child: SectionHeader('Timetable')),
          PageBody(
            child: _Group(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_view_week_rounded),
                  title: Text(tt?.name ?? 'No timetable'),
                  subtitle: Text(
                    store.data.timetables.length > 1
                        ? '${store.data.timetables.length} timetables · tap to switch'
                        : (tt?.subtitle.isNotEmpty ?? false)
                        ? tt!.subtitle
                        : 'Manage timetables',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => push(const TimetablesPage()),
                ),
                if (tt != null) ...[
                  _NavTile(
                    Icons.info_outline_rounded,
                    'Details & dates',
                    'Name, working days, term dates',
                    () => showEditor(context, TimetableDetailsEditor(timetable: tt)),
                  ),
                  _NavTile(
                    Icons.menu_book_outlined,
                    'Subjects',
                    '${tt.subjects.where((x) => x.enrolled).length} of ${tt.subjects.length} enrolled',
                    () => push(const SubjectsPage()),
                  ),
                  _NavTile(
                    Icons.person_outline_rounded,
                    'Teachers',
                    '${tt.teachers.length} teachers',
                    () => push(const TeachersPage()),
                  ),
                  _NavTile(
                    Icons.notifications_paused_outlined,
                    'Bell schedule',
                    '${tt.periods.where((p) => !p.isBreak).length} periods',
                    () => push(const BellSchedulePage()),
                  ),
                  _NavTile(
                    Icons.groups_2_outlined,
                    'Groups & batches',
                    tt.myGroup == null ? 'Showing all groups' : 'You’re in ${tt.myGroup}',
                    () => push(const GroupsPage()),
                  ),
                  _NavTile(
                    Icons.beach_access_outlined,
                    'Holidays & special days',
                    '${tt.specialDays.length} marked',
                    () => push(const SpecialDaysPage()),
                  ),
                ],
              ],
            ),
          ),

          // Reminders --------------------------------------------------------
          const PageBody(child: SectionHeader('Reminders & alarms')),
          PageBody(
            child: _Group(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Class reminders'),
                  subtitle: Text(s.remindersEnabled ? leadTimeLabel(s.reminderMinutes) : 'Off'),
                  value: s.remindersEnabled,
                  onChanged: (v) async {
                    if (v) await NotificationService.instance.requestPermissions();
                    set((s) => s.remindersEnabled = v);
                  },
                ),
                if (s.remindersEnabled) ...[
                  _ChoiceTile<int>(
                    icon: Icons.timer_outlined,
                    title: 'Remind me',
                    value: s.reminderMinutes,
                    options: const [0, 2, 5, 10, 15, 20, 30, 45, 60],
                    label: leadTimeLabel,
                    onChanged: (v) => set((s) => s.reminderMinutes = v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.play_circle_outline_rounded),
                    title: const Text('Also notify when class starts'),
                    value: s.notifyAtStart,
                    onChanged: (v) => set((s) => s.notifyAtStart = v),
                  ),
                ],
                SwitchListTile(
                  secondary: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Morning summary'),
                  subtitle: Text(
                    s.dailySummary
                        ? 'At ${context.timeFormat.minutes(s.dailySummaryAt)} on days with classes'
                        : 'Off',
                  ),
                  value: s.dailySummary,
                  onChanged: (v) => set((s) => s.dailySummary = v),
                ),
                if (s.dailySummary)
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Summary time'),
                    trailing: Text(
                      context.timeFormat.minutes(s.dailySummaryAt),
                      style: context.text.titleSmall,
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: s.dailySummaryAt ~/ 60,
                          minute: s.dailySummaryAt % 60,
                        ),
                      );
                      if (t != null) set((s) => s.dailySummaryAt = t.hour * 60 + t.minute);
                    },
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_rounded),
                  title: const Text('Wake-up alarm'),
                  subtitle: Text(
                    s.morningAlarm
                        ? leadTimeLabel(s.morningAlarmLead)
                              .replaceAll('before', 'before your first class')
                        : 'Rings before the first class of the day',
                  ),
                  value: s.morningAlarm,
                  onChanged: (v) async {
                    if (v) {
                      await NotificationService.instance.requestPermissions();
                      await NotificationService.instance.requestFullScreenAlarms();
                    }
                    set((s) => s.morningAlarm = v);
                  },
                ),
                if (s.morningAlarm)
                  _ChoiceTile<int>(
                    icon: Icons.more_time_rounded,
                    title: 'Alarm time',
                    value: s.morningAlarmLead,
                    options: const [30, 45, 60, 75, 90, 120, 150, 180],
                    label: (m) => leadTimeLabel(m).replaceAll('before', 'before first class'),
                    onChanged: (v) => set((s) => s.morningAlarmLead = v),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.task_alt_rounded),
                  title: const Text('Task & exam reminders'),
                  value: s.taskReminders,
                  onChanged: (v) => set((s) => s.taskReminders = v),
                ),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Try it out'),
                  subtitle: const Text('Send a test notification or ring the alarm'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Test notification',
                        onPressed: () async {
                          await NotificationService.instance.requestPermissions();
                          await NotificationService.instance.showTest();
                        },
                        icon: const Icon(Icons.notifications_outlined),
                      ),
                      IconButton(
                        tooltip: 'Test alarm',
                        onPressed: NotificationService.instance.testAlarm,
                        icon: const Icon(Icons.alarm_on_rounded),
                      ),
                    ],
                  ),
                ),
                if (_android) const _ExactAlarmTile(),
              ],
            ),
          ),

          // Widgets ---------------------------------------------------------
          const PageBody(child: SectionHeader('Widgets')),
          PageBody(child: _desktop ? const _DesktopWidgetGroup() : const _AndroidWidgetGroup()),

          if (_desktop) ...[
            const PageBody(child: SectionHeader('Startup')),
            const PageBody(child: _StartupGroup()),
          ],

          // Appearance ------------------------------------------------------
          const PageBody(child: SectionHeader('Appearance')),
          PageBody(
            child: _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => set((s) => s.themeMode = v.first),
                  ),
                ),
                if (_android)
                  SwitchListTile(
                    secondary: const Icon(Icons.wallpaper_outlined),
                    title: const Text('Match wallpaper colours'),
                    subtitle: const Text('Material You, on Android 12 and newer'),
                    value: s.useDynamicColor,
                    onChanged: (v) => set((s) => s.useDynamicColor = v),
                  ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Accent colour'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in kAccentChoices)
                          _AccentDot(
                            color: Color(c),
                            selected: (s.accent ?? kBrandColor) == c,
                            onTap: () => set((s) {
                              s.accent = c;
                              s.useDynamicColor = false;
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.access_time_rounded),
                  title: const Text('24-hour clock'),
                  subtitle: Text(
                    s.use24h == null ? 'Following system' : (s.use24h! ? '13:30' : '1:30 PM'),
                  ),
                  value: context.use24h,
                  onChanged: (v) => set((s) => s.use24h = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.weekend_outlined),
                  title: const Text('Always show weekends'),
                  subtitle: const Text('Otherwise only when something is on'),
                  value: s.showWeekends,
                  onChanged: (v) => set((s) => s.showWeekends = v),
                ),
              ],
            ),
          ),

          // Data -------------------------------------------------------------
          const PageBody(child: SectionHeader('Backup & export')),
          PageBody(
            child: _Group(
              children: [
                _NavTile(
                  Icons.ios_share_rounded,
                  'Share timetable',
                  'Send it to classmates as a file',
                  () => DataActions.shareTimetable(context),
                ),
                _NavTile(
                  Icons.file_open_outlined,
                  'Import',
                  'A shared timetable or a backup',
                  () => DataActions.importFile(context),
                ),
                _NavTile(
                  Icons.save_alt_rounded,
                  'Back up everything',
                  'Timetables, tasks, attendance and settings',
                  () => DataActions.exportBackup(context),
                ),
                _NavTile(
                  Icons.event_note_outlined,
                  'Export to calendar',
                  '.ics for Google Calendar, Outlook…',
                  () => DataActions.exportIcs(context),
                ),
                ListTile(
                  leading: Icon(Icons.restart_alt_rounded, color: context.colors.error),
                  title: Text('Erase all data', style: TextStyle(color: context.colors.error)),
                  onTap: () async {
                    if (await confirm(
                      context,
                      title: 'Erase everything?',
                      message: 'All timetables, tasks and attendance will be deleted from this device. Consider making a backup first.',
                      action: 'Erase',
                    )) {
                      store.resetAll();
                    }
                  },
                ),
              ],
            ),
          ),

          const PageBody(child: SectionHeader('About')),
          const PageBody(child: _AboutGroup()),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    ),
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(label(value)),
    trailing: const Icon(Icons.unfold_more_rounded),
    onTap: () async {
      final picked = await showDialog<T>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            RadioGroup<T>(
              groupValue: value,
              onChanged: (v) => Navigator.pop(context, v),
              child: Column(
                children: [
                  for (final o in options) RadioListTile<T>(value: o, title: Text(label(o))),
                ],
              ),
            ),
          ],
        ),
      );
      if (picked != null) onChanged(picked);
    },
  );
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? context.colors.onSurface : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
    ),
  );
}

class _ExactAlarmTile extends StatefulWidget {
  const _ExactAlarmTile();

  @override
  State<_ExactAlarmTile> createState() => _ExactAlarmTileState();
}

class _ExactAlarmTileState extends State<_ExactAlarmTile> with WidgetsBindingObserver {
  bool? _exact;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final v = await NotificationService.instance.canScheduleExact();
    if (mounted) setState(() => _exact = v);
  }

  @override
  Widget build(BuildContext context) {
    if (_exact ?? true) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(Icons.warning_amber_rounded, color: context.colors.error),
      title: const Text('Reminders may arrive late'),
      subtitle: const Text('Allow “Alarms & reminders” so notifications fire on time'),
      trailing: FilledButton.tonal(
        onPressed: () async {
          await NotificationService.instance.requestPermissions();
          _check();
        },
        child: const Text('Allow'),
      ),
    );
  }
}

class _AndroidWidgetGroup extends StatelessWidget {
  const _AndroidWidgetGroup();

  @override
  Widget build(BuildContext context) => _Group(
    children: [
      const ListTile(
        leading: Icon(Icons.widgets_outlined),
        title: Text('Home-screen widgets'),
        subtitle: Text('Long-press your home screen → Widgets → Cadence. Or add one right here:'),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _pin(context, today: false),
              icon: const Icon(Icons.crop_square_rounded),
              label: const Text('Up next'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _pin(context, today: true),
              icon: const Icon(Icons.view_agenda_outlined),
              label: const Text('Today'),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _pin(BuildContext context, {required bool today}) async {
    if (!await HomeWidgetSync.canPin()) {
      if (context.mounted) {
        context.toast(
          'Your launcher doesn’t support this — add the widget from the home screen instead.',
        );
      }
      return;
    }
    await HomeWidgetSync.pin(today: today);
  }
}

class _DesktopWidgetGroup extends StatelessWidget {
  const _DesktopWidgetGroup();

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    final shell = DesktopShell.instance;
    return _Group(
      children: [
        ListTile(
          leading: const Icon(Icons.widgets_outlined),
          title: const Text('Desktop widget'),
          subtitle: const Text('A compact now/next view that stays on your desktop'),
          trailing: FilledButton.tonal(onPressed: shell.enterWidgetMode, child: const Text('Show')),
        ),
        _ChoiceTile<WidgetLayer>(
          icon: Icons.layers_outlined,
          title: 'Widget placement',
          value: s.widgetLayer,
          options: WidgetLayer.values,
          label: (l) => switch (l) {
            WidgetLayer.onTop => 'Always on top of other windows',
            WidgetLayer.onDesktop => 'Pinned to the desktop, behind windows',
            WidgetLayer.normal => 'Like a normal window',
          },
          onChanged: (v) {
            store.updateSettings((s) => s.widgetLayer = v);
            shell.applyWidgetLayer();
          },
        ),
        ListTile(
          leading: const Icon(Icons.opacity_rounded),
          title: const Text('Widget opacity'),
          subtitle: Slider(
            value: s.widgetOpacity,
            min: 0.4,
            max: 1,
            divisions: 12,
            label: '${(s.widgetOpacity * 100).round()}%',
            onChanged: (v) {
              store.updateSettings((s) => s.widgetOpacity = v);
              shell.setWidgetOpacity(v);
            },
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.login_rounded),
          title: const Text('Show widget when Cadence starts at login'),
          value: s.widgetOnStartup,
          onChanged: (v) => store.updateSettings((s) => s.widgetOnStartup = v),
        ),
      ],
    );
  }
}

class _StartupGroup extends StatefulWidget {
  const _StartupGroup();

  @override
  State<_StartupGroup> createState() => _StartupGroupState();
}

class _StartupGroupState extends State<_StartupGroup> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    DesktopShell.instance.isLaunchAtStartupEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    return _Group(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.power_settings_new_rounded),
          title: Text(
            'Start Cadence when I sign in to ${Platform.isWindows ? 'Windows' : 'my desktop'}',
          ),
          subtitle: const Text('Runs quietly in the tray so reminders always arrive'),
          value: _enabled ?? s.launchAtStartup,
          onChanged: (v) async {
            await DesktopShell.instance.setLaunchAtStartup(v);
            store.updateSettings((s) => s.launchAtStartup = v);
            final actual = await DesktopShell.instance.isLaunchAtStartupEnabled();
            if (mounted) setState(() => _enabled = actual);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.close_fullscreen_rounded),
          title: const Text('Keep running in the tray when closed'),
          subtitle: const Text('Needed for reminders and alarms on desktop'),
          value: s.closeToTray,
          onChanged: (v) => store.updateSettings((s) => s.closeToTray = v),
        ),
      ],
    );
  }
}

class _AboutGroup extends StatelessWidget {
  const _AboutGroup();

  @override
  Widget build(BuildContext context) => _Group(
    children: [
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) => ListTile(
          leading: Image.asset('assets/branding/icon-128.png', width: 36, height: 36),
          title: const Text('Cadence'),
          subtitle: Text('Version ${snap.data?.version ?? '…'} · free and open source'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Cadence',
            applicationVersion: snap.data?.version,
            applicationIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset('assets/branding/icon-128.png', width: 64),
            ),
            applicationLegalese: '© 2026 Toshik Soni · MIT License',
          ),
        ),
      ),
      _NavTile(
        Icons.code_rounded,
        'Source code',
        'github.com/ToshikSoni/TimeTable-Widget',
        () => launchUrl(Uri.parse(repoUrl)),
      ),
      _NavTile(
        Icons.bug_report_outlined,
        'Report a problem or suggest an idea',
        'Opens GitHub issues',
        () => launchUrl(Uri.parse('$repoUrl/issues/new/choose')),
      ),
      const ListTile(
        leading: Icon(Icons.lock_outline_rounded),
        title: Text('Private by design'),
        subtitle: Text('No accounts, no ads, no tracking. Your data never leaves this device.'),
      ),
    ],
  );
}
