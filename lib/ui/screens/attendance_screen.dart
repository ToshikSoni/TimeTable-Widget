import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/attendance.dart';
import '../../core/models.dart';
import '../../core/schedule.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';
import 'no_timetable.dart';

const _good = Color(0xFF2F9E62);

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final tt = store.timetable;
    if (tt == null) return const NoTimetable();
    final target = store.settings.attendanceTarget;
    final stats = AttendanceCalculator.perSubject(tt, target);
    final overall = AttendanceCalculator.overall(stats, target);
    final marked = overall.total > 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Attendance'),
        actions: [
          TextButton.icon(
            onPressed: () => _pickTarget(context, target),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text('Target $target%'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !marked
          ? EmptyState(
              illustration: const Illustration(Art.chart),
              title: 'Track your attendance',
              message: 'Tap ✓ or ✕ on a class in Today once it has started. Cadence works out how many classes you can still skip.',
              action: OutlinedButton.icon(
                onPressed: () => _markToday(context, tt),
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Mark today’s classes as attended'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                PageBody(
                  child: Entrance(child: _OverallCard(stats: overall)),
                ),
                PageBody(
                  child: SectionHeader(
                    'By subject',
                    trailing: TextButton(
                      onPressed: () => _markToday(context, tt),
                      child: const Text('Mark today attended'),
                    ),
                  ),
                ),
                for (final (i, s) in stats.indexed)
                  PageBody(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Entrance(
                        index: i + 1,
                        child: _SubjectCard(stats: s),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _markToday(BuildContext context, Timetable tt) {
    final store = context.readStore;
    final now = DateTime.now();
    var n = 0;
    for (final o in ScheduleEngine.dayPlan(tt, now).active) {
      if (o.tracksAttendance && !o.start.isAfter(now) && tt.attendance[o.key] == null) {
        store.setAttendance(o.key, AttendanceStatus.present);
        n++;
      }
    }
    context.toast(
      n == 0
          ? 'Nothing left to mark today'
          : 'Marked $n ${n == 1 ? 'class' : 'classes'} as attended',
    );
  }

  Future<void> _pickTarget(BuildContext context, int current) async {
    var value = current.toDouble();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Attendance target'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value.round()}%', style: context.text.displaySmall),
              Slider(
                value: value,
                min: 50,
                max: 100,
                divisions: 50,
                onChanged: (v) => set(() => value = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, value.round()),
              child: const Text('Set'),
            ),
          ],
        ),
      ),
    );
    if (result != null && context.mounted) {
      context.readStore.updateSettings((s) => s.attendanceTarget = result);
    }
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.stats});
  final AttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    final color = stats.onTrack ? _good : context.colors.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            ProgressRing(
              value: stats.ratio,
              color: color,
              size: 96,
              stroke: 10,
              child: Text(
                '${stats.percent.toStringAsFixed(stats.percent >= 99.95 ? 0 : 1)}%',
                style: context.text.titleLarge?.copyWith(fontFeatures: tabular),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall',
                    style: context.text.labelLarge?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats.present} of ${stats.total} classes',
                    style: context.text.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Tag(
                    stats.onTrack ? 'ON TRACK' : 'BELOW ${stats.target}%',
                    color: color,
                    icon: stats.onTrack ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.stats});
  final AttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats.subject!;
    final tone = context.tone(s.color);
    final color = stats.total == 0
        ? context.colors.outline
        : (stats.onTrack ? _good : context.colors.error);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showHistory(context, s),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ProgressRing(
                value: stats.total == 0 ? 0 : stats.ratio,
                color: tone.accent,
                size: 52,
                stroke: 5,
                child: Text(
                  stats.total == 0 ? '–' : '${stats.percent.round()}',
                  style: context.text.labelLarge?.copyWith(fontFeatures: tabular),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats.total == 0
                          ? 'Not marked yet'
                          : '${stats.present}/${stats.total} attended',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(stats.advice, style: context.text.labelMedium?.copyWith(color: color)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context, Subject s) => showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _History(subject: s),
  );
}

class _History extends StatelessWidget {
  const _History({required this.subject});
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final tt = store.timetable!;
    final entryIds = {
      for (final e in tt.entries)
        if (e.subjectId == subject.id) e.id,
      for (final c in tt.changes)
        if (c.extra?.subjectId == subject.id) c.extra!.id,
    };
    final records =
        tt.attendance.entries.where((e) => entryIds.contains(e.key.split('|').last)).toList()
          ..sort((a, b) => b.key.compareTo(a.key));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(subject.name, style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Tap a record to change it',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No records yet')),
            ),
          for (final r in records)
            ListTile(
              leading: Icon(
                r.value == AttendanceStatus.present
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: r.value == AttendanceStatus.present ? _good : context.colors.error,
              ),
              title: Text(DateFormat('EEEE, d MMM y').format(parseDateKey(r.key.split('|').first))),
              subtitle: Text(r.value == AttendanceStatus.present ? 'Attended' : 'Missed'),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => store.setAttendance(r.key, null),
              ),
              onTap: () => store.setAttendance(
                r.key,
                r.value == AttendanceStatus.present
                    ? AttendanceStatus.absent
                    : AttendanceStatus.present,
              ),
            ),
        ],
      ),
    );
  }
}
