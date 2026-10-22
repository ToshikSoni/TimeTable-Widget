import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/sample_data.dart';
import '../../services/desktop.dart';
import '../../services/notifications.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';
import 'settings/data_actions.dart';

enum _Source { example, blank, imported }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  _Source? _source;
  bool _autostart = true;

  bool get _desktop => DesktopShell.supported;

  int get _pageCount => 4;

  void _next() {
    FocusScope.of(context).unfocus();
    if (_page == _pageCount - 1) {
      _finish();
      return;
    }
    _pages.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  void _back() =>
      _pages.previousPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  Future<void> _finish() async {
    final store = context.readStore;
    if (store.data.timetables.isEmpty) {
      store.addTimetable(Timetable(name: 'My timetable', periods: defaultPeriods()));
    }
    if (_desktop && _autostart) {
      await DesktopShell.instance.setLaunchAtStartup(true);
      store.updateSettings((s) => s.launchAtStartup = true);
    }
    store.updateSettings((s) => s.onboarded = true);
  }

  Future<void> _choose(_Source source) async {
    final store = context.readStore;
    if (source == _source && source != _Source.imported) {
      _next();
      return;
    }
    switch (source) {
      case _Source.example:
        if (!store.data.timetables.any((t) => t.id == 'sample-cse-a')) {
          store.addTimetable(buildSampleTimetable());
        } else {
          store.setActive('sample-cse-a');
        }
      case _Source.blank:
        // Going back and switching from the example replaces it.
        if (_source == _Source.example) store.removeTimetable('sample-cse-a');
        store.addTimetable(Timetable(name: 'My timetable', periods: defaultPeriods()));
      case _Source.imported:
        final before = store.data.timetables.length;
        await DataActions.importFile(context);
        if (!mounted || store.data.timetables.length == before) return;
    }
    setState(() => _source = source);
    _next();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _welcome(context),
      _sourcePage(context),
      _personalise(context),
      _reminders(context),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      AnimatedOpacity(
                        opacity: _page > 0 ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: _page > 0 ? _back : null,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const Spacer(),
                      for (var i = 0; i < _pageCount; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i <= _page
                                ? context.colors.primary
                                : context.colors.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (p) => setState(() => _page = p),
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _frame({
    required Widget art,
    required String title,
    required String body,
    required List<Widget> children,
    Widget? action,
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    children: [
      SizedBox(height: 170, child: art),
      const SizedBox(height: 24),
      Text(title, style: context.text.headlineMedium),
      const SizedBox(height: 10),
      Text(body, style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant)),
      const SizedBox(height: 24),
      ...children,
      if (action != null) ...[const SizedBox(height: 24), action],
    ],
  );

  Widget _welcome(BuildContext context) => _frame(
    art: const Illustration(Art.calendar),
    title: 'Your timetable,\nalways a glance away',
    body: 'Cadence keeps your classes on your home screen and desktop, reminds you before each one, and never needs an account.',
    children: const [
      _Feature(
        Icons.widgets_outlined,
        'Widgets everywhere',
        'Home-screen widgets on Android, a desktop widget on Windows and Linux.',
      ),
      _Feature(
        Icons.notifications_active_outlined,
        'Reminders & alarms',
        'A heads-up before class and a wake-up alarm before the first one.',
      ),
      _Feature(
        Icons.groups_2_outlined,
        'Built for real timetables',
        'Lab groups, electives, holidays and “Saturday follows Monday”.',
      ),
      _Feature(
        Icons.insights_outlined,
        'Attendance & tasks',
        'Know how many classes you can skip, and never miss a deadline.',
      ),
    ],
    action: FilledButton(onPressed: _next, child: const Text('Get started')),
  );

  Widget _sourcePage(BuildContext context) => _frame(
    art: const Illustration(Art.widget),
    title: 'Set up your timetable',
    body: 'You can change everything later.',
    children: [
      _OptionCard(
        icon: Icons.auto_awesome_outlined,
        title: 'Use the example',
        subtitle: 'B.Tech CSE (Cyber Security), Semester VI · CSE-A. Great for a quick tour — or if it’s yours!',
        selected: _source == _Source.example,
        onTap: () => _choose(_Source.example),
      ),
      _OptionCard(
        icon: Icons.edit_calendar_outlined,
        title: 'Start fresh',
        subtitle: 'Begin with an empty week and a typical bell schedule.',
        selected: _source == _Source.blank,
        onTap: () => _choose(_Source.blank),
      ),
      _OptionCard(
        icon: Icons.file_open_outlined,
        title: 'Import a file',
        subtitle: 'A timetable a classmate shared with you, or a Cadence backup.',
        selected: _source == _Source.imported,
        onTap: () => _choose(_Source.imported),
      ),
    ],
  );

  Widget _personalise(BuildContext context) {
    final tt = context.store.timetable;
    final hasGroups = tt != null && tt.groups.isNotEmpty;
    final hasSubjects = tt != null && tt.subjects.isNotEmpty;
    return _frame(
      art: const Illustration(Art.chart),
      title: 'Make it yours',
      body: hasGroups || hasSubjects
          ? 'Pick your lab group and the subjects you actually take, so you only see your own classes.'
          : 'Add your subjects and classes from the Week tab whenever you’re ready.',
      children: [
        if (hasGroups) ...[
          Text('My lab group', style: context.text.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in tt.groups)
                ChoiceChip(
                  label: Text('Group $g'),
                  selected: tt.myGroup == g,
                  onSelected: (_) => context.readStore.updateTimetable((t) => t.myGroup = g),
                ),
              ChoiceChip(
                label: const Text('Show all'),
                selected: tt.myGroup == null,
                onSelected: (_) => context.readStore.updateTimetable((t) => t.myGroup = null),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (hasSubjects) ...[
          Text('My subjects', style: context.text.titleSmall),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                for (final s in tt.subjects)
                  SwitchListTile(
                    dense: true,
                    secondary: ColorDot(context.tone(s.color).accent, size: 12),
                    title: Text(s.name),
                    subtitle: s.code.isEmpty ? null : Text(s.code),
                    value: s.enrolled,
                    onChanged: (v) => context.readStore.upsertSubject(s.copyWith(enrolled: v)),
                  ),
              ],
            ),
          ),
        ],
      ],
      action: FilledButton(onPressed: _next, child: const Text('Continue')),
    );
  }

  Widget _reminders(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    return _frame(
      art: const Illustration(Art.bell),
      title: 'Never miss a class',
      body: _desktop
          ? 'Cadence lives in your system tray and taps you on the shoulder before each class.'
          : 'Allow notifications so Cadence can remind you before each class — even when the app is closed.',
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Remind me 10 minutes before class'),
                value: s.remindersEnabled,
                onChanged: (v) => store.updateSettings((s) => s.remindersEnabled = v),
              ),
              SwitchListTile(
                title: const Text('Morning summary of my day'),
                value: s.dailySummary,
                onChanged: (v) => store.updateSettings((s) => s.dailySummary = v),
              ),
              SwitchListTile(
                title: const Text('Wake-up alarm before the first class'),
                subtitle: const Text('One hour before — adjustable in Settings'),
                value: s.morningAlarm,
                onChanged: (v) => store.updateSettings((s) => s.morningAlarm = v),
              ),
              if (_desktop)
                SwitchListTile(
                  title: Text(
                    'Start with ${!kIsWeb && Platform.isWindows ? 'Windows' : 'my desktop session'}',
                  ),
                  subtitle: const Text('Opens quietly in the tray with the desktop widget'),
                  value: _autostart,
                  onChanged: (v) => setState(() => _autostart = v),
                ),
            ],
          ),
        ),
      ],
      action: FilledButton.icon(
        onPressed: () async {
          await NotificationService.instance.requestPermissions();
          if (store.settings.morningAlarm) {
            await NotificationService.instance.requestFullScreenAlarms();
          }
          _next();
        },
        icon: const Icon(Icons.check_rounded),
        label: const Text('Finish setup'),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: context.colors.onPrimaryContainer, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text(
                body,
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: selected ? context.colors.primaryContainer : context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? context.colors.primary : context.colors.outlineVariant,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, size: 28, color: context.colors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
