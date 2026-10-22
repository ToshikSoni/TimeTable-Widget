import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../app_scope.dart';
import '../editors/misc_editors.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final now = ClockScope.now(context);
    final all = store.data.tasks;
    final open = all.where((t) => !t.done).toList();
    final done = all.where((t) => t.done).toList()
      ..sort((a, b) => (b.due ?? b.createdAt).compareTo(a.due ?? a.createdAt));

    final groups = <String, List<StudyTask>>{};
    final today = dateOnly(now);
    for (final t in open..sort(_byDue)) {
      final key = switch (t.due) {
        null => 'Someday',
        final d when d.isBefore(now) => 'Overdue',
        final d when dateOnly(d) == today => 'Today',
        final d when dateOnly(d) == today.add(const Duration(days: 1)) => 'Tomorrow',
        final d when dateOnly(d).difference(today).inDays < 7 => 'This week',
        _ => 'Later',
      };
      (groups[key] ??= []).add(t);
    }
    const order = ['Overdue', 'Today', 'Tomorrow', 'This week', 'Later', 'Someday'];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Tasks & exams'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: false, label: Text('To do · ${open.length}')),
                ButtonSegment(value: true, label: Text('Done · ${done.length}')),
              ],
              selected: {_showDone},
              onSelectionChanged: (s) => setState(() => _showDone = s.first),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEditor(context, const TaskEditor()),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Task'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _showDone
            ? (done.isEmpty
                  ? const EmptyState(
                      key: ValueKey('done-empty'),
                      illustration: Illustration(Art.tasks),
                      title: 'Nothing completed yet',
                      message: 'Finished tasks will collect here.',
                    )
                  : ListView(
                      key: const ValueKey('done'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      children: [
                        for (final t in done)
                          PageBody(
                            child: _TaskTile(task: t, now: now),
                          ),
                      ],
                    ))
            : (open.isEmpty
                  ? EmptyState(
                      key: const ValueKey('open-empty'),
                      illustration: const Illustration(Art.tasks),
                      title: 'All caught up',
                      message:
                          'Add assignments, exams and readings to get reminded before they’re due.',
                      action: FilledButton.tonalIcon(
                        onPressed: () => showEditor(context, const TaskEditor()),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add a task'),
                      ),
                    )
                  : ListView(
                      key: const ValueKey('open'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      children: [
                        for (final g in order)
                          if (groups[g] != null) ...[
                            PageBody(
                              child: SectionHeader(
                                g,
                                trailing: g == 'Overdue'
                                    ? Tag('${groups[g]!.length}', color: context.colors.error)
                                    : null,
                              ),
                            ),
                            for (final (i, t) in groups[g]!.indexed)
                              PageBody(
                                child: Entrance(
                                  index: i,
                                  child: _TaskTile(task: t, now: now),
                                ),
                              ),
                          ],
                      ],
                    )),
      ),
    );
  }

  static int _byDue(StudyTask a, StudyTask b) {
    if (a.due == null && b.due == null) return a.createdAt.compareTo(b.createdAt);
    if (a.due == null) return 1;
    if (b.due == null) return -1;
    return a.due!.compareTo(b.due!);
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.now});
  final StudyTask task;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final store = context.readStore;
    final s = context.store.timetable?.subject(task.subjectId);
    final tone = s == null ? null : context.tone(s.color);
    final overdue = !task.done && task.due != null && task.due!.isBefore(now);
    final due = task.due == null
        ? null
        : '${relativeDay(task.due!, now)} · ${context.timeFormat.time(task.due!)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(task.id),
        background: _swipe(
          context,
          Icons.check_rounded,
          task.done ? 'Undo' : 'Done',
          const Color(0xFF2F9E62),
          Alignment.centerLeft,
        ),
        secondaryBackground: _swipe(
          context,
          Icons.delete_outline_rounded,
          'Delete',
          context.colors.error,
          Alignment.centerRight,
        ),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            store.upsertTask(task.copyWith(done: !task.done));
            return false;
          }
          return true;
        },
        onDismissed: (_) {
          store.removeTask(task.id);
          context.toast(
            'Task deleted',
            actionLabel: 'Undo',
            onAction: () => store.upsertTask(task),
          );
        },
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showEditor(context, TaskEditor(task: task)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
              child: Row(
                children: [
                  Checkbox(
                    shape: const CircleBorder(),
                    value: task.done,
                    onChanged: (v) => store.upsertTask(task.copyWith(done: v ?? false)),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: context.text.titleSmall?.copyWith(
                            decoration: task.done ? TextDecoration.lineThrough : null,
                            color: task.done ? context.colors.onSurfaceVariant : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Tag(
                              task.type.label.toUpperCase(),
                              color: task.type == TaskType.exam
                                  ? context.colors.tertiary
                                  : context.colors.primary,
                              dense: true,
                            ),
                            if (s != null)
                              Tag(
                                s.label,
                                color: tone!.accent,
                                background: tone.container,
                                dense: true,
                              ),
                            if (due != null)
                              Text(
                                due,
                                style: context.text.labelSmall?.copyWith(
                                  color: overdue
                                      ? context.colors.error
                                      : context.colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (task.due != null && !task.done)
                    _Countdown(due: task.due!, now: now, overdue: overdue),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipe(BuildContext context, IconData icon, String label, Color color, Alignment align) =>
      Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.due, required this.now, required this.overdue});
  final DateTime due;
  final DateTime now;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final diff = due.difference(now);
    final label = overdue
        ? 'late'
        : diff.inDays >= 1
        ? '${diff.inDays}d'
        : diff.inHours >= 1
        ? '${diff.inHours}h'
        : '${diff.inMinutes}m';
    return Tooltip(
      message: DateFormat('EEEE, d MMMM y').format(due),
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: (overdue ? context.colors.errorContainer : context.colors.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.text.labelLarge?.copyWith(
            color: overdue ? context.colors.onErrorContainer : context.colors.onSurfaceVariant,
            fontFeatures: tabular,
          ),
        ),
      ),
    );
  }
}
