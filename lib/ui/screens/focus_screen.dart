import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/focus.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/schedule.dart';
import '../../services/dnd.dart';
import '../../services/focus_timer.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Shows the focus timer: switches to the Focus tab where there is one
/// (wider windows), otherwise opens it as a page on top of the current tab.
Future<void> openFocus(BuildContext context) async {
  final select = FocusTab.select;
  if (select != null && context.isMedium) {
    select();
    return;
  }
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const FocusScreen(standalone: true)));
}

/// Set by the shell while a Focus tab is shown in the navigation.
abstract final class FocusTab {
  static VoidCallback? select;
}

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.standalone = false});

  /// Pushed as its own page (shows a back button) rather than a tab.
  final bool standalone;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  FocusTimer get _timer => FocusTimer.instance;
  final _keys = FocusNode(debugLabel: 'focus-timer');
  bool _wasVisible = false;

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _suggestSubject();
  }

  /// Pre-selects the class that is on now (or the next one today), so a
  /// study session is linked to the right subject without extra taps.
  void _suggestSubject() {
    if (!_timer.idle || _timer.subjectId != null) return;
    final tt = AppScope.read(context).timetable;
    if (tt == null) return;
    final now = DateTime.now();
    final o = ScheduleEngine.current(tt, now) ?? ScheduleEngine.next(tt, now, days: 0);
    _timer.subjectId = o?.subject?.id;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final tt = store.timetable;
    final subjects = tt?.subjects.where((s) => s.enrolled).toList() ?? const <Subject>[];
    final wide = context.isWide;

    final timerPanel = ListenableBuilder(
      listenable: _timer,
      builder: (context, _) => _TimerPanel(timer: _timer, subjects: subjects),
    );
    final statsPanel = _StatsPanel(log: store.data.focusLog, timetable: tt);

    // Tabs that aren't showing are kept alive with tickers off; don't let a
    // hidden Focus tab react to the space bar.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_wasVisible) {
      // Take keyboard focus when the tab is switched to, so Space works.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _keys.requestFocus();
      });
    }
    _wasVisible = visible;
    return CallbackShortcuts(
      bindings: {
        if (visible) ...{
          const SingleActivator(LogicalKeyboardKey.space): _timer.toggle,
          const SingleActivator(LogicalKeyboardKey.keyR): _timer.reset,
          const SingleActivator(LogicalKeyboardKey.keyS): _timer.skip,
        },
      },
      child: Focus(
        focusNode: _keys,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: widget.standalone ? null : 20,
            automaticallyImplyLeading: widget.standalone,
            title: const Text('Focus'),
            actions: [
              IconButton(
                tooltip: 'Timer settings',
                onPressed: () => _showSettings(context),
                icon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: wide
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 8, 12, 40),
                            child: timerPanel,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 8, 24, 40),
                            child: statsPanel,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: [
                    PageBody(child: timerPanel),
                    const SizedBox(height: 8),
                    PageBody(child: statsPanel),
                  ],
                ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) => showModalBottomSheet(
    useRootNavigator: true,
    isScrollControlled: true,
    context: context,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const _FocusSettingsSheet(),
  );
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({required this.timer, required this.subjects});
  final FocusTimer timer;
  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final subject = subjects.where((s) => s.id == timer.subjectId).firstOrNull;
    final color = timer.phase.isBreak
        ? c.tertiary
        : subject == null
        ? c.primary
        : context.tone(subject.color).accent;
    final remaining = timer.remaining;
    final mm = remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final fmt = context.timeFormat;
    final size = math.min(MediaQuery.sizeOf(context).width - 64, 320.0);

    final status = timer.running
        ? 'Ends at ${fmt.time(timer.endsAt!)}'
        : timer.paused
        ? 'Paused'
        : timer.phase.isBreak
        ? 'Stretch, drink some water'
        : 'Ready when you are';

    return Column(
      children: [
        const SizedBox(height: 8),
        SegmentedButton<FocusPhase>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: FocusPhase.focus, label: Text('Focus')),
            ButtonSegment(value: FocusPhase.shortBreak, label: Text('Short break')),
            ButtonSegment(value: FocusPhase.longBreak, label: Text('Long break')),
          ],
          selected: {timer.phase},
          onSelectionChanged: (v) => timer.select(v.first),
        ),
        const SizedBox(height: 28),
        Semantics(
          label: '${timer.phase.label}, $mm minutes $ss seconds left. $status',
          child: _Dial(
            size: size,
            progress: timer.progress,
            color: color,
            running: timer.running,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    timer.phase.label.toUpperCase(),
                    key: ValueKey(timer.phase),
                    style: context.text.labelMedium?.copyWith(color: color, letterSpacing: 1.6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$mm:$ss',
                  style: context.text.displayLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: tabular,
                    fontSize: size * 0.22,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(status, style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                const SizedBox(height: 14),
                _RoundDots(round: timer.round, rounds: timer.rounds, color: color),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Reset (R)',
              iconSize: 26,
              onPressed: timer.idle && timer.round == 1 && timer.phase == FocusPhase.focus
                  ? null
                  : timer.reset,
              icon: const Icon(Icons.replay_rounded),
            ),
            const SizedBox(width: 24),
            _PlayButton(running: timer.running, color: color, onPressed: timer.toggle),
            const SizedBox(width: 24),
            IconButton.filledTonal(
              tooltip: timer.phase.isBreak ? 'Skip break (S)' : 'Finish early (S)',
              iconSize: 26,
              onPressed: timer.idle ? null : timer.skip,
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
        if (subjects.isNotEmpty) ...[
          const SectionHeader('Working on'),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  label: const Text('Anything'),
                  selected: timer.subjectId == null,
                  onSelected: (_) => timer.link(null),
                ),
                for (final s in subjects)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: ColorDot(context.tone(s.color).accent),
                    label: Text(s.label),
                    selected: timer.subjectId == s.id,
                    onSelected: (_) => timer.link(s.id),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The big countdown dial: a track, the remaining arc and a soft glow that
/// breathes while the timer runs.
class _Dial extends StatefulWidget {
  const _Dial({
    required this.size,
    required this.progress,
    required this.color,
    required this.running,
    required this.child,
  });
  final double size;
  final double progress;
  final Color color;
  final bool running;
  final Widget child;

  @override
  State<_Dial> createState() => _DialState();
}

class _DialState extends State<_Dial> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didUpdateWidget(covariant _Dial old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final animate = widget.running && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!animate && _breath.isAnimating) {
      _breath.animateTo(0, duration: const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: widget.progress),
    duration: const Duration(milliseconds: 300),
    builder: (context, p, child) => AnimatedBuilder(
      animation: _breath,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _DialPainter(
          progress: p,
          color: widget.color,
          track: context.colors.surfaceContainerHighest,
          glow: Curves.easeInOut.transform(_breath.value),
        ),
        child: SizedBox.square(
          dimension: widget.size,
          child: Center(child: child),
        ),
      ),
    ),
    child: widget.child,
  );
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.glow,
  });
  final double progress;
  final Color color;
  final Color track;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.045;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Soft halo.
    canvas.drawCircle(
      center,
      radius - stroke * 1.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.10 + glow * 0.08),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    // Minute ticks.
    final tick = Paint()
      ..color = track
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * 2 * math.pi - math.pi / 2;
      final long = i % 5 == 0;
      final r1 = radius - stroke * (long ? 1.6 : 1.3);
      final r2 = radius - stroke * 1.0;
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * r1,
        center + Offset(math.cos(a), math.sin(a)) * r2,
        tick,
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // The arc shows time remaining, shrinking clockwise.
    final sweep = (1 - progress) * 2 * math.pi;
    if (sweep > 0.001) {
      final paint = Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          transform: const GradientRotation(-math.pi / 2),
          colors: [color.withValues(alpha: 0.65), color],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke;
      canvas.drawArc(rect, -math.pi / 2 + progress * 2 * math.pi, sweep, false, paint);

      // A knob at the moving end.
      final a = -math.pi / 2 + progress * 2 * math.pi;
      final knob = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(
        knob,
        stroke * (0.85 + glow * 0.12),
        Paint()..color = color.withValues(alpha: 0.25),
      );
      canvas.drawCircle(knob, stroke * 0.42, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.glow != glow;
}

class _RoundDots extends StatelessWidget {
  const _RoundDots({required this.round, required this.rounds, required this.color});
  final int round;
  final int rounds;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Round $round of $rounds',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= rounds; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == round ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i <= round ? color : context.colors.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    ),
  );
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.running, required this.color, required this.onPressed});
  final bool running;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Tooltip(
      message: running ? 'Pause (Space)' : 'Start (Space)',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(running ? 28 : 42),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(running ? 28 : 42),
            onTap: onPressed,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(running),
                  size: 40,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.log, required this.timetable});
  final List<FocusSession> log;
  final Timetable? timetable;

  @override
  Widget build(BuildContext context) {
    final now = ClockScope.now(context);
    final today = dateOnly(now);
    final daily = FocusStats.dailyMinutes(log, today);
    final week = daily.fold(0, (a, b) => a + b);
    final streak = FocusStats.streak(log, today);
    final subjects = FocusStats.bySubject(
      log,
      DateTime(today.year, today.month, today.day - 6),
    ).take(5).toList();
    final todays = log.reversed.where((s) => dateOnly(s.start) == today).take(8).toList();
    final fmt = context.timeFormat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Your focus'),
        Row(
          children: [
            Expanded(
              child: _Stat(
                icon: Icons.today_rounded,
                value: humanDuration(Duration(minutes: daily.last), short: true),
                label: 'Today',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                icon: Icons.date_range_rounded,
                value: humanDuration(Duration(minutes: week), short: true),
                label: 'Last 7 days',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                icon: Icons.local_fire_department_rounded,
                value: '$streak',
                label: 'Day streak',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _WeekBars(minutes: daily, today: today),
          ),
        ),
        if (subjects.isNotEmpty) ...[
          const SectionHeader('This week by subject'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final e in subjects)
                    _SubjectBar(
                      label: timetable?.subject(e.key)?.label ?? 'Unlinked',
                      color: timetable?.subject(e.key)?.color,
                      minutes: e.value,
                      max: subjects.first.value,
                    ),
                ],
              ),
            ),
          ),
        ],
        if (todays.isNotEmpty) ...[
          const SectionHeader('Today’s sessions'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final s in todays)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.check_circle_rounded,
                      color: timetable?.subject(s.subjectId) == null
                          ? context.colors.primary
                          : context.tone(timetable!.subject(s.subjectId)!.color).accent,
                    ),
                    title: Text(timetable?.subject(s.subjectId)?.name ?? s.label ?? 'Focus'),
                    subtitle: Text('${fmt.time(s.start)} – ${fmt.time(s.end)}'),
                    trailing: Text(
                      humanDuration(Duration(minutes: s.minutes), short: true),
                      style: context.text.labelLarge?.copyWith(fontFeatures: tabular),
                    ),
                    onLongPress: () async {
                      final ok = await confirm(
                        context,
                        title: 'Remove this session?',
                        message: 'It will no longer count towards your totals.',
                        action: 'Remove',
                      );
                      if (ok && context.mounted) context.readStore.removeFocus(s.id);
                    },
                  ),
              ],
            ),
          ),
        ],
        if (log.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
            child: Text(
              'Finished sessions show up here. Work for one round, then take a short break — '
              'after a few rounds, take a longer one.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(height: 8),
          Text(value, style: context.text.titleLarge?.copyWith(fontFeatures: tabular)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.minutes, required this.today});
  final List<int> minutes;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final peak = math.max(30, minutes.fold(0, math.max));
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < minutes.length; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = DateTime(
                    today.year,
                    today.month,
                    today.day - (minutes.length - 1 - i),
                  );
                  final isToday = i == minutes.length - 1;
                  return Tooltip(
                    message:
                        '${DateFormat('EEEE').format(day)}: ${humanDuration(Duration(minutes: minutes[i]))}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          minutes[i] == 0
                              ? ''
                              : humanDuration(Duration(minutes: minutes[i]), short: true),
                          style: context.text.labelSmall?.copyWith(color: c.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: minutes[i] / peak),
                          duration: Duration(milliseconds: 500 + i * 60),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Container(
                            width: 22,
                            height: math.max(4, 96 * v),
                            decoration: BoxDecoration(
                              color: isToday ? c.primary : c.primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('E').format(day).substring(0, 2),
                          style: context.text.labelSmall?.copyWith(
                            color: isToday ? c.primary : c.onSurfaceVariant,
                            fontWeight: isToday ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({
    required this.label,
    required this.color,
    required this.minutes,
    required this.max,
  });
  final String label;
  final int? color;
  final int minutes;
  final int max;

  @override
  Widget build(BuildContext context) {
    final accent = color == null ? context.colors.outline : context.tone(color!).accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: max == 0 ? 0 : minutes / max),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              humanDuration(Duration(minutes: minutes), short: true),
              textAlign: TextAlign.end,
              style: context.text.labelLarge?.copyWith(fontFeatures: tabular),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusSettingsSheet extends StatelessWidget {
  const _FocusSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    void set(void Function(Settings s) f) => store.updateSettings(f);

    Widget stepper(
      String label,
      int value,
      int min,
      int max,
      int step,
      void Function(int) on, {
      String unit = ' min',
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Less',
            onPressed: value - step < min ? null : () => on(value - step),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$value$unit',
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(fontFeatures: tabular),
            ),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: value + step > max ? null : () => on(value + step),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus timer', style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Changes apply from the next session.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (name, f, b, l) in const [
                  ('Classic 25 / 5', 25, 5, 15),
                  ('Deep 50 / 10', 50, 10, 20),
                  ('Short 15 / 3', 15, 3, 10),
                ])
                  ActionChip(
                    label: Text(name),
                    onPressed: () => set((s) {
                      s.focusMinutes = f;
                      s.shortBreakMinutes = b;
                      s.longBreakMinutes = l;
                    }),
                  ),
              ],
            ),
            stepper('Focus', s.focusMinutes, 5, 120, 5, (v) => set((s) => s.focusMinutes = v)),
            stepper(
              'Short break',
              s.shortBreakMinutes,
              1,
              30,
              1,
              (v) => set((s) => s.shortBreakMinutes = v),
            ),
            stepper(
              'Long break',
              s.longBreakMinutes,
              5,
              60,
              5,
              (v) => set((s) => s.longBreakMinutes = v),
            ),
            stepper(
              'Rounds before a long break',
              s.focusRounds,
              1,
              8,
              1,
              (v) => set((s) => s.focusRounds = v),
              unit: '',
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Start breaks automatically'),
              value: s.focusAutoBreaks,
              onChanged: (v) => set((s) => s.focusAutoBreaks = v),
            ),
            if (DndService.supported)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Do not disturb while focusing'),
                subtitle: const Text('Silences the phone during focus sessions'),
                value: s.focusDoNotDisturb,
                onChanged: (v) async {
                  if (v && !await DndService.hasAccess()) await DndService.requestAccess();
                  set((s) => s.focusDoNotDisturb = v);
                },
              ),
          ],
        ),
      ),
    );
  }
}
